import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';

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

abstract class MainReportState {}

class MainReportInitial extends MainReportState {}

class MainReportLoading extends MainReportState {}

class MainReportLoaded extends MainReportState {
  final List<Map<String, String>> visibleColumns; // Now a list of maps with headerName and titleName
  final List<Map<String, dynamic>> reportData;

  MainReportLoaded(this.visibleColumns, this.reportData);
}

class MainReportError extends MainReportState {
  final String message;

  MainReportError(this.message);
}

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
            final headerName = columnName.split('.').last; // e.g., "IsComplaintType"
            final titleName = column['ColumnHeading'] as String; // e.g., "Type of Complaint"

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