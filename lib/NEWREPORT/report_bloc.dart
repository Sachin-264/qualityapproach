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

class UpdateColumnName extends ReportEvent {
  final int index;
  final String newName;

  const UpdateColumnName(this.index, this.newName);
}

class ResetReport extends ReportEvent {
  const ResetReport();
}

class SubmitReport extends ReportEvent {
  final String reportName;
  final String userCode;
  final String companyCode;
  final String recNo;

  const SubmitReport(this.reportName, this.userCode, this.companyCode, this.recNo);
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
  final String columnName;
  final String columnHeading;
  final String isVisible;

  ReportColumn({
    required this.columnName,
    required this.columnHeading,
    this.isVisible = 'Y',
  });

  ReportColumn copyWith({String? columnName, String? columnHeading, String? isVisible}) {
    return ReportColumn(
      columnName: columnName ?? this.columnName,
      columnHeading: columnHeading ?? this.columnHeading,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toJson() => {
    'ColumnName': columnName,
    'EnterColumnHeading': columnHeading,
    'IsVisible': isVisible,
  };
}

// Bloc
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportBloc() : super(const ReportState()) {
    developer.log('ReportBloc created', name: 'ReportBloc');
    on<FetchReportData>(_onFetchReportData);
    on<UpdateColumnVisibility>(_onUpdateColumnVisibility);
    on<UpdateColumnName>(_onUpdateColumnName);  // New event handler
    on<ResetReport>(_onResetReport);
    on<SubmitReport>(_onSubmitReport);
  }

  @override
  void onChange(Change<ReportState> change) {
    super.onChange(change);
    developer.log('State changed: ${change.nextState.columns.length} columns', name: 'ReportBloc');
  }

  Future<void> _onFetchReportData(FetchReportData event, Emitter<ReportState> emit) async {
    developer.log('Fetching report data for UserCode: ${event.userCode}, '
        'CompanyCode: ${event.companyCode}, RecNo: ${event.recNo}', name: 'ReportBloc');

    emit(state.copyWith(isLoading: true));
    try {
      final response = await http.get(
        Uri.parse(
            'http://localhost/AquavivaAPI/sp_LoadComplaint.php?UserCode=${event.userCode}&CompanyCode=${event.companyCode}&RecNo=${event.recNo}'),
      );

      developer.log('Fetch response: ${response.statusCode} - ${response.body}', name: 'ReportBloc');

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        List<dynamic> dataList = decodedData is List ? decodedData : [];

        final columns = dataList.map((item) {
          final mapItem = item as Map<String, dynamic>;
          final isVisible = mapItem['IsVisible']?.toString().trim();
          return ReportColumn(
            columnName: mapItem['ColumnName'] ?? 'Unknown',
            columnHeading: mapItem['ColumnHeading'] ?? 'Unknown',
            isVisible: (isVisible == null || isVisible.isEmpty || isVisible != 'N') ? 'Y' : 'N',
          );
        }).toList();

        developer.log('Fetched ${columns.length} columns: ${columns.map((c) => c.toJson()).toList()}', name: 'ReportBloc');
        emit(state.copyWith(columns: columns, isLoading: false, error: null));
      } else {
        throw Exception('API returned status code: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching data: $e', name: 'ReportBloc', error: e);
      emit(state.copyWith(error: 'Failed to load data: $e', isLoading: false));
    }
  }

  void _onUpdateColumnVisibility(UpdateColumnVisibility event, Emitter<ReportState> emit) {
    if (event.index >= state.columns.length || event.index < 0) {
      developer.log('Invalid index ${event.index} for columns length ${state.columns.length}', name: 'ReportBloc');
      return;
    }
    developer.log('Updating visibility for index ${event.index} to ${event.isVisible}', name: 'ReportBloc');
    final updatedColumns = List<ReportColumn>.from(state.columns);
    updatedColumns[event.index] = updatedColumns[event.index].copyWith(isVisible: event.isVisible ? 'Y' : 'N');
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onUpdateColumnName(UpdateColumnName event, Emitter<ReportState> emit) {
    if (event.index >= state.columns.length || event.index < 0) {
      developer.log('Invalid index ${event.index} for columns length ${state.columns.length}', name: 'ReportBloc');
      return;
    }
    developer.log('Updating column name for index ${event.index} to ${event.newName}', name: 'ReportBloc');
    final updatedColumns = List<ReportColumn>.from(state.columns);
    updatedColumns[event.index] = updatedColumns[event.index].copyWith(columnHeading: event.newName);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onResetReport(ResetReport event, Emitter<ReportState> emit) {
    developer.log('Resetting report', name: 'ReportBloc');
    final updatedColumns = state.columns.map((column) => column.copyWith(isVisible: 'Y')).toList();
    emit(state.copyWith(columns: updatedColumns));
  }

  Future<void> _onSubmitReport(SubmitReport event, Emitter<ReportState> emit) async {
    developer.log('Submitting report: ${event.reportName}', name: 'ReportBloc');
    developer.log('Current columns before submit: ${state.columns.length}', name: 'ReportBloc');

    if (state.columns.isEmpty) {
      developer.log('No columns to submit!', name: 'ReportBloc');
      emit(state.copyWith(error: 'No report data to submit', isLoading: false));
      return;
    }

    emit(state.copyWith(isLoading: true));

    try {
      final payload = {
        'UserCode': event.userCode,
        'CompanyCode': event.companyCode,
        'RecNo': '1',
        'ReportName': event.reportName,
        'ReportDetails': state.columns.map((column) => column.toJson()).toList(),
      };

      developer.log('Submitting JSON: ${json.encode(payload)}', name: 'ReportBloc');

      final response = await http.post(
        Uri.parse('http://localhost/AquavivaAPI/postcomplaint.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      developer.log('Submit response: ${response.statusCode} - ${response.body}', name: 'ReportBloc');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          emit(state.copyWith(isLoading: false, error: null));
        } else {
          throw Exception('API error: ${responseData['error']}');
        }
      } else {
        throw Exception('Submit failed with status: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error submitting report: $e', name: 'ReportBloc', error: e);
      emit(state.copyWith(error: 'Failed to submit: $e', isLoading: false));
    }
  }
}