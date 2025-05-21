import 'package:flutter_bloc/flutter_bloc.dart';
import '../ReportAPIService.dart';

// Events
abstract class ReportEvent {}

class LoadReports extends ReportEvent {}

class FetchApiDetails extends ReportEvent {
  final String apiName;
  FetchApiDetails(this.apiName);
}

class UpdateParameter extends ReportEvent {
  final String paramName;
  final String value;
  UpdateParameter(this.paramName, this.value);
}

class FetchFieldConfigs extends ReportEvent {
  final String recNo;
  final String apiName;
  final String reportLabel;
  FetchFieldConfigs(this.recNo, this.apiName, this.reportLabel);
}

class ResetReports extends ReportEvent {}

// States
class ReportState {
  final bool isLoading;
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> fieldConfigs;
  final List<Map<String, dynamic>> reportData;
  final String? selectedRecNo;
  final String? selectedApiName;
  final String? selectedReportLabel;
  final String? selectedApiUrl;
  final List<Map<String, dynamic>> selectedApiParameters;
  final Map<String, String> userParameterValues;
  final String? error;

  ReportState({
    this.isLoading = false,
    this.reports = const [],
    this.fieldConfigs = const [],
    this.reportData = const [],
    this.selectedRecNo,
    this.selectedApiName,
    this.selectedReportLabel,
    this.selectedApiUrl,
    this.selectedApiParameters = const [],
    this.userParameterValues = const {},
    this.error,
  });

  ReportState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? reports,
    List<Map<String, dynamic>>? fieldConfigs,
    List<Map<String, dynamic>>? reportData,
    String? selectedRecNo,
    String? selectedApiName,
    String? selectedReportLabel,
    String? selectedApiUrl,
    List<Map<String, dynamic>>? selectedApiParameters,
    Map<String, String>? userParameterValues,
    String? error,
  }) {
    return ReportState(
      isLoading: isLoading ?? this.isLoading,
      reports: reports ?? this.reports,
      fieldConfigs: fieldConfigs ?? this.fieldConfigs,
      reportData: reportData ?? this.reportData,
      selectedRecNo: selectedRecNo ?? this.selectedRecNo,
      selectedApiName: selectedApiName ?? this.selectedApiName,
      selectedReportLabel: selectedReportLabel ?? this.selectedReportLabel,
      selectedApiUrl: selectedApiUrl ?? this.selectedApiUrl,
      selectedApiParameters: selectedApiParameters ?? this.selectedApiParameters,
      userParameterValues: userParameterValues ?? this.userParameterValues,
      error: error,
    );
  }
}

class ReportBlocGenerate extends Bloc<ReportEvent, ReportState> {
  final ReportAPIService apiService;

  ReportBlocGenerate(this.apiService) : super(ReportState()) {
    on<LoadReports>(_onLoadReports);
    on<FetchApiDetails>(_onFetchApiDetails);
    on<UpdateParameter>(_onUpdateParameter);
    on<FetchFieldConfigs>(_onFetchFieldConfigs);
    on<ResetReports>(_onResetReports);
  }

  Future<void> _onLoadReports(LoadReports event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    print('LoadReports: Starting fetch');
    try {
      final reports = await apiService.fetchDemoTable();
      emit(state.copyWith(isLoading: false, reports: reports));
      print('LoadReports success: reports.length=${reports.length}, sample=${reports.isNotEmpty ? reports.first : {}}');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
      print('LoadReports error: $e');
    }
  }

  Future<void> _onFetchApiDetails(FetchApiDetails event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    print('FetchApiDetails: Starting for apiName=${event.apiName}');
    try {
      final apiDetails = await apiService.getApiDetails(event.apiName);
      emit(state.copyWith(
        isLoading: false,
        selectedApiUrl: apiDetails['url'],
        selectedApiParameters: List<Map<String, dynamic>>.from(apiDetails['parameters'] ?? []),
        userParameterValues: {}, // Reset user parameter values
      ));
      print('FetchApiDetails success: url=${apiDetails['url']}, parameters=${apiDetails['parameters']}');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to fetch API details: $e'));
      print('FetchApiDetails error: $e');
    }
  }

  void _onUpdateParameter(UpdateParameter event, Emitter<ReportState> emit) {
    final updatedUserParams = Map<String, String>.from(state.userParameterValues);
    updatedUserParams[event.paramName] = event.value;
    emit(state.copyWith(userParameterValues: updatedUserParams));
    print('UpdateParameter: paramName=${event.paramName}, value=${event.value}, updatedParams=$updatedUserParams');
  }

  Future<void> _onFetchFieldConfigs(FetchFieldConfigs event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    print('FetchFieldConfigs: Starting for RecNo=${event.recNo}, apiName=${event.apiName}, reportLabel=${event.reportLabel}');
    try {
      // Fetch field configurations
      final fieldConfigs = await apiService.fetchDemoTable2(event.recNo);
      // Fetch report data using constructed URL with user parameters
      final reportData = await apiService.fetchApiDataWithParams(
        event.apiName,
        state.userParameterValues,
      );
      final newState = state.copyWith(
        isLoading: false,
        fieldConfigs: fieldConfigs,
        reportData: reportData,
        selectedRecNo: event.recNo,
        selectedApiName: event.apiName,
        selectedReportLabel: event.reportLabel,
      );
      emit(newState);
      print('FetchFieldConfigs success: fieldConfigs.length=${fieldConfigs.length}, '
          'reportData.length=${reportData.length}, '
          'fieldConfigs.sample=${fieldConfigs.isNotEmpty ? fieldConfigs.first : {}}, '
          'reportData.sample=${reportData.isNotEmpty ? reportData.first : {}}, '
          'stateHash=${newState.hashCode}');
    } catch (e) {
      final fieldConfigs = await apiService.fetchDemoTable2(event.recNo).catchError((_) => []);
      final newState = state.copyWith(
        isLoading: false,
        fieldConfigs: fieldConfigs,
        error: e.toString(),
        selectedRecNo: event.recNo,
        selectedApiName: event.apiName,
        selectedReportLabel: event.reportLabel,
      );
      emit(newState);
      print('FetchFieldConfigs error: $e, '
          'fieldConfigs.length=${fieldConfigs.length}, '
          'fieldConfigs.sample=${fieldConfigs.isNotEmpty ? fieldConfigs.first : {}}, '
          'stateHash=${newState.hashCode}');
    }
  }

  void _onResetReports(ResetReports event, Emitter<ReportState> emit) {
    final newState = ReportState();
    emit(newState);
    print('ResetReports: State reset, stateHash=${newState.hashCode}');
  }
}