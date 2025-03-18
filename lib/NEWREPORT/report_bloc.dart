import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Events
abstract class ReportEvent extends Equatable {
  const ReportEvent();
  @override
  List<Object> get props => [];
}

class FetchReportData extends ReportEvent {
  final String userCode;
  final String companyCode;
  final String recNo;

  const FetchReportData(this.userCode, this.companyCode, this.recNo);
}

class UpdateColumnVisibility extends ReportEvent {
  final int index;
  final bool isVisible;

  const UpdateColumnVisibility(this.index, this.isVisible);
}

class ResetReport extends ReportEvent {
  const ResetReport();
}

// State
class ReportState extends Equatable {
  final String reportName;
  final List<ReportColumn> columns;
  final bool isLoading;
  final String? error;

  const ReportState({
    this.reportName = '',
    this.columns = const [],
    this.isLoading = false,
    this.error,
  });

  ReportState copyWith({
    String? reportName,
    List<ReportColumn>? columns,
    bool? isLoading,
    String? error,
  }) {
    return ReportState(
      reportName: reportName ?? this.reportName,
      columns: columns ?? this.columns,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [reportName, columns, isLoading, error];
}

class ReportColumn {
  final String columnHeading;
  final bool isVisible;

  ReportColumn({required this.columnHeading, required this.isVisible});

  ReportColumn copyWith({String? columnHeading, bool? isVisible}) {
    return ReportColumn(
      columnHeading: columnHeading ?? this.columnHeading,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

// Bloc
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportBloc() : super(const ReportState()) {
    on<FetchReportData>(_onFetchReportData);
    on<UpdateColumnVisibility>(_onUpdateColumnVisibility);
    on<ResetReport>(_onResetReport);
  }

  Future<void> _onFetchReportData(
      FetchReportData event, Emitter<ReportState> emit) async {
    developer.log('Fetching report data for UserCode: ${event.userCode}, '
        'CompanyCode: ${event.companyCode}, RecNo: ${event.recNo}',
        name: 'ReportBloc');

    emit(state.copyWith(isLoading: true));
    try {
      final response = await http.get(
        Uri.parse(
            'http://localhost/AquavivaAPI/sp_LoadComplaint.php?UserCode=${event.userCode}&CompanyCode=${event.companyCode}&RecNo=${event.recNo}'),
      );

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        List<dynamic> dataList;
        if (decodedData is List) {
          dataList = decodedData;
          print('list');
        } else if (decodedData is Map) {
          print('map');
          if (decodedData.containsKey('data')) {
            dataList = decodedData['data'] as List<dynamic>;
            print('key');
          } else {
            dataList = [decodedData];
            print('i dont know');
          }
        } else {
          throw Exception('Unexpected data format: ${decodedData.runtimeType}');
        }

        final columns = dataList.map((item) {
          final mapItem = item as Map<String, dynamic>;
          final columnHeading = mapItem['ColumnHeading'] ?? 'Unknown';
          return ReportColumn(
            columnHeading: columnHeading,
            isVisible: true,
          );
        }).toList();

        developer.log('Created ${columns.length} columns', name: 'ReportBloc');
        emit(state.copyWith(columns: columns, isLoading: false, error: null));
      } else {
        throw Exception('API returned status code: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error: $e', name: 'ReportBloc', error: e);
      emit(state.copyWith(
        error: 'Failed to load data: ${e.toString()}',
        isLoading: false,
      ));
    }
  }

  void _onUpdateColumnVisibility(
      UpdateColumnVisibility event, Emitter<ReportState> emit) {
    developer.log('Updating visibility for index ${event.index} to ${event.isVisible}',
        name: 'ReportBloc');

    final updatedColumns = List<ReportColumn>.from(state.columns);
    updatedColumns[event.index] = updatedColumns[event.index]
        .copyWith(isVisible: event.isVisible);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onResetReport(ResetReport event, Emitter<ReportState> emit) {
    developer.log('Resetting report', name: 'ReportBloc');

    // Reset all column visibility to true without making an API call
    final updatedColumns = state.columns.map((column) =>
        column.copyWith(isVisible: true)
    ).toList();

    emit(state.copyWith(
        columns: updatedColumns
    ));
  }
}