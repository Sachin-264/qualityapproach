import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';

// SubtleLoader Widget
class SubtleLoader extends StatefulWidget {
  const SubtleLoader({super.key});

  @override
  State<SubtleLoader> createState() => _SubtleLoaderState();
}

class _SubtleLoaderState extends State<SubtleLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 40,
        height: 40,
        child: RotationTransition(
          turns: Tween(begin: 0.0, end: 1.0).animate(_controller),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue[800]!.withOpacity(0.6),
                width: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// MainReportEvent
abstract class MainReportEvent {}

class FetchReportData extends MainReportEvent {
  final String userCode;
  final String companyCode;
  final String fromDate;
  final String toDate;
  final String recNo;

  FetchReportData({
    required this.userCode,
    required this.companyCode,
    required this.fromDate,
    required this.toDate,
    required this.recNo,
  });
}

// MainReportState
abstract class MainReportState {}

class MainReportInitial extends MainReportState {}

class MainReportLoading extends MainReportState {}

class MainReportLoaded extends MainReportState {
  final List<Map<String, String>> visibleColumns;
  final List<Map<String, dynamic>> reportData;

  MainReportLoaded(this.visibleColumns, this.reportData);
}

class MainReportError extends MainReportState {
  final String message;

  MainReportError(this.message);
}

// MainReportBloc
class MainReportBloc extends Bloc<MainReportEvent, MainReportState> {
  MainReportBloc() : super(MainReportInitial()) {
    on<FetchReportData>(_onFetchReportData);
  }

  final DateFormat _dateFormatter = DateFormat('dd-MMM-yyyy');

  Future<void> _onFetchReportData(FetchReportData event, Emitter<MainReportState> emit) async {
    emit(MainReportLoading());
    developer.log('Fetching report data...', name: 'MainReportBloc');

    try {
      String formattedFromDate;
      String formattedToDate;

      try {
        final fromDateTime = DateTime.parse(event.fromDate);
        final toDateTime = DateTime.parse(event.toDate);
        formattedFromDate = _dateFormatter.format(fromDateTime);
        formattedToDate = _dateFormatter.format(toDateTime);
      } catch (e) {
        formattedFromDate = event.fromDate;
        formattedToDate = event.toDate;
      }

      developer.log('Formatted From Date: $formattedFromDate', name: 'MainReportBloc');
      developer.log('Formatted To Date: $formattedToDate', name: 'MainReportBloc');

      final designUrl =
          'http://localhost/Bestapi/sp_LoadComplaintReportDesignMaster.php?UserCode=1&CompanyCode=101&RecNo=${event.recNo}';
      developer.log('Fetching design from: $designUrl', name: 'MainReportBloc');
      final designResponse = await http.get(Uri.parse(designUrl));

      if (designResponse.statusCode == 200) {
        final designData = jsonDecode(designResponse.body);
        developer.log('Design API Response: ${designData.toString()}', name: 'MainReportBloc');

        if (designData['status'] == 'success') {
          final visibleColumns = (designData['data'] as List)
              .where((column) => column['IsVisible'] == 'Y')
              .map((column) {
            final columnName = column['ColumnName'] as String;
            final headerName = columnName.split('.').last;
            final titleName = column['ColumnHeading'] as String;

            developer.log(
              'Column: $columnName -> Header: $headerName -> Title: $titleName',
              name: 'MainReportBloc',
            );

            return {
              'headerName': headerName,
              'titleName': titleName,
            };
          })
              .toList();

          developer.log('Visible columns: $visibleColumns', name: 'MainReportBloc');

          final reportUrl =
              'http://localhost/Bestapi/sp_GetComplaintReportDesignMasterDetails.php?UserCode=1&CompanyCode=101&FromDate=$formattedFromDate&ToDate=$formattedToDate';
          developer.log('Fetching report from: $reportUrl', name: 'MainReportBloc');

          final reportResponse = await http.get(Uri.parse(reportUrl));

          if (reportResponse.statusCode == 200) {
            final reportData = jsonDecode(reportResponse.body);
            developer.log('Report API Response: ${reportData.toString()}', name: 'MainReportBloc');

            if (reportData['status'] == 'success') {
              final List<Map<String, dynamic>> typedReportData = (reportData['data'] as List)
                  .map((item) => item as Map<String, dynamic>)
                  .toList();

              emit(MainReportLoaded(visibleColumns, typedReportData));
            } else {
              emit(MainReportError('Failed to load report data'));
            }
          } else {
            emit(MainReportError('Error fetching report data'));
          }
        } else {
          emit(MainReportError('Failed to load column design'));
        }
      } else {
        emit(MainReportError('Error fetching column design'));
      }
    } catch (e) {
      emit(MainReportError('An error occurred: $e'));
    }
  }
}

// MainReport Widget
class MainReport extends StatelessWidget {
  final String fromDate;
  final String toDate;
  final String fieldId;

  const MainReport({
    super.key,
    required this.fromDate,
    required this.toDate,
    required this.fieldId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MainReportBloc()
        ..add(FetchReportData(
          userCode: '1',
          companyCode: '101',
          fromDate: fromDate,
          toDate: toDate,
          recNo: fieldId,
        )),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue[800],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Complaint Report',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 2,
        ),
        body: BlocBuilder<MainReportBloc, MainReportState>(
          builder: (context, state) {
            if (state is MainReportLoading) {
              return const SubtleLoader();
            } else if (state is MainReportLoaded) {
              final columns = state.visibleColumns
                  .map((column) => PlutoColumn(
                title: column['titleName'] as String,
                field: column['headerName'] as String,
                type: PlutoColumnType.text(),
              ))
                  .toList();

              final rows = state.reportData.map((data) {
                final rowCells = <String, PlutoCell>{};
                for (var column in state.visibleColumns) {
                  final headerName = column['headerName'] as String;
                  rowCells[headerName] = PlutoCell(value: data[headerName] ?? '');
                }
                return PlutoRow(cells: rowCells);
              }).toList();

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: PlutoGrid(
                  columns: columns,
                  rows: rows,
                  onLoaded: (PlutoGridOnLoadedEvent event) {
                    event.stateManager.setShowColumnFilter(true);
                  },
                  configuration: PlutoGridConfiguration(
                    style: PlutoGridStyleConfig(
                      gridBorderColor: Colors.grey[300]!,
                      columnTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      cellTextStyle: GoogleFonts.poppins(),
                    ),
                  ),
                ),
              );
            } else if (state is MainReportError) {
              return Center(
                child: Text(
                  state.message,
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}