import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Events
abstract class EditReportEvent extends Equatable {
  const EditReportEvent();
  @override
  List<Object> get props => [];
}

class FetchEditReportData extends EditReportEvent {
  final String userCode;
  final String companyCode;
  final String recNo;

  const FetchEditReportData(this.userCode, this.companyCode, this.recNo);
}

class UpdateEditColumnVisibility extends EditReportEvent {
  final int index;
  final bool isVisible;

  const UpdateEditColumnVisibility(this.index, this.isVisible);
}

class UpdateEditColumnName extends EditReportEvent {
  final int index;
  final String newName;

  const UpdateEditColumnName(this.index, this.newName);
}

class ResetEditReport extends EditReportEvent {
  const ResetEditReport();
}

class SubmitEditReport extends EditReportEvent {
  final String reportName;
  final String userCode;
  final String companyCode;
  final String recNo;

  const SubmitEditReport(this.reportName, this.userCode, this.companyCode, this.recNo);
}

// State
class EditReportState extends Equatable {
  final String reportName;
  final List<EditReportColumn> columns;
  final bool isLoading;
  final String? error;

  const EditReportState({
    this.reportName = '',
    this.columns = const [],
    this.isLoading = false,
    this.error,
  });

  EditReportState copyWith({
    String? reportName,
    List<EditReportColumn>? columns,
    bool? isLoading,
    String? error,
  }) {
    return EditReportState(
      reportName: reportName ?? this.reportName,
      columns: columns ?? this.columns,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [reportName, columns, isLoading, error];
}

class EditReportColumn {
  final String fullColumnName; // e.g., "CustomerComplaintEntry.ComplaintNo"
  final String columnName; // e.g., "Complaint No" (for UI)
  final String columnHeading; // e.g., user-edited value or empty
  final String isVisible;

  EditReportColumn({
    required this.fullColumnName,
    required this.columnName,
    required this.columnHeading,
    this.isVisible = 'Y',
  });

  EditReportColumn copyWith({
    String? fullColumnName,
    String? columnName,
    String? columnHeading,
    String? isVisible,
  }) {
    return EditReportColumn(
      fullColumnName: fullColumnName ?? this.fullColumnName,
      columnName: columnName ?? this.columnName,
      columnHeading: columnHeading ?? this.columnHeading,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toJson() => {
    'ColumnName': fullColumnName, // Send full "CustomerComplaintEntry.ComplaintNo"
    'EnterColumnHeading': columnHeading.isEmpty ? columnName : columnHeading, // Use columnName if columnHeading is empty
    'IsVisible': isVisible,
  };
}

// Bloc
class EditReportBloc extends Bloc<EditReportEvent, EditReportState> {
  EditReportBloc() : super(const EditReportState()) {
    on<FetchEditReportData>(_onFetchEditReportData);
    on<UpdateEditColumnVisibility>(_onUpdateEditColumnVisibility);
    on<UpdateEditColumnName>(_onUpdateEditColumnName);
    on<ResetEditReport>(_onResetEditReport);
    on<SubmitEditReport>(_onSubmitEditReport);
  }

  Future<void> _onFetchEditReportData(FetchEditReportData event, Emitter<EditReportState> emit) async {
    print('API URL: http://localhost/Bestapi/sp_LoadComplaintReportDesignMaster.php?UserCode=${event.userCode}&CompanyCode=${event.companyCode}&RecNo=${event.recNo}');

    emit(state.copyWith(isLoading: true));
    try {
      final response = await http.get(
        Uri.parse(
            'http://localhost/Bestapi/sp_LoadComplaintReportDesignMaster.php?UserCode=${event.userCode}&CompanyCode=${event.companyCode}&RecNo=${event.recNo}'),
      );

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        List<dynamic> dataList = decodedData['data'] ?? [];

        final columns = dataList.map((item) {
          final mapItem = item as Map<String, dynamic>;
          final isVisible = mapItem['IsVisible']?.toString().trim();
          return EditReportColumn(
            fullColumnName: mapItem['ColumnName'] ?? 'Unknown', // Store full ColumnName
            columnName: mapItem['ColumnHeading'] ?? 'Unknown', // Use ColumnHeading for UI
            columnHeading: mapItem['EnterColumnHeading'] ?? '', // User-edited value
            isVisible: (isVisible == null || isVisible.isEmpty || isVisible != 'N') ? 'Y' : 'N',
          );
        }).toList();

        emit(state.copyWith(columns: columns, isLoading: false, error: null));
      } else {
        throw Exception('API returned status code: ${response.statusCode}');
      }
    } catch (e) {
      emit(state.copyWith(error: 'Failed to load data: $e', isLoading: false));
    }
  }

  void _onUpdateEditColumnVisibility(UpdateEditColumnVisibility event, Emitter<EditReportState> emit) {
    if (event.index < 0 || event.index >= state.columns.length) return;
    final updatedColumns = List<EditReportColumn>.from(state.columns);
    updatedColumns[event.index] = updatedColumns[event.index].copyWith(isVisible: event.isVisible ? 'Y' : 'N');
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onUpdateEditColumnName(UpdateEditColumnName event, Emitter<EditReportState> emit) {
    if (event.index < 0 || event.index >= state.columns.length) return;
    final updatedColumns = List<EditReportColumn>.from(state.columns);
    updatedColumns[event.index] = updatedColumns[event.index].copyWith(columnHeading: event.newName);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onResetEditReport(ResetEditReport event, Emitter<EditReportState> emit) {
    final updatedColumns = state.columns.map((column) => column.copyWith(columnHeading: '', isVisible: 'Y')).toList();
    emit(state.copyWith(columns: updatedColumns));
  }

  Future<void> _onSubmitEditReport(SubmitEditReport event, Emitter<EditReportState> emit) async {
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
        'RecNo': event.recNo,
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