// Reportbloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../ReportAPIService.dart';
import 'package:intl/intl.dart';

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

// NEW EVENT: FetchPickerOptions
class FetchPickerOptions extends ReportEvent {
  final String paramName;
  final String serverIP;
  final String userName;
  final String password;
  final String databaseName;
  final String masterTable;
  final String masterField;
  FetchPickerOptions({
    required this.paramName,
    required this.serverIP,
    required this.userName,
    required this.password,
    required this.databaseName,
    required this.masterTable,
    required this.masterField,
  });
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
  final Map<String, List<String>> pickerOptions; // To store fetched picker values
  final String? serverIP; // For picker options fetching
  final String? userName; // For picker options fetching
  final String? password; // For picker options fetching
  final String? databaseName; // For picker options fetching
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
    this.pickerOptions = const {},
    this.serverIP,
    this.userName,
    this.password,
    this.databaseName,
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
    Map<String, List<String>>? pickerOptions,
    String? serverIP,
    String? userName,
    String? password,
    String? databaseName,
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
      pickerOptions: pickerOptions ?? this.pickerOptions,
      serverIP: serverIP ?? this.serverIP,
      userName: userName ?? this.userName,
      password: password ?? this.password,
      databaseName: databaseName ?? this.databaseName,
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
    on<FetchPickerOptions>(_onFetchPickerOptions);
    on<ResetReports>(_onResetReports);
  }

  Future<void> _onLoadReports(LoadReports event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final reports = await apiService.fetchDemoTable();
      emit(state.copyWith(isLoading: false, reports: reports));
      print('Bloc: LoadReports success: reports.length=${reports.length}, sample=${reports.isNotEmpty ? reports.first : {}}');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load reports: $e'));
      print('Bloc: LoadReports error: $e');
    }
  }

  Future<void> _onFetchApiDetails(FetchApiDetails event, Emitter<ReportState> emit) async {
    // Clear relevant parts of the state when fetching new API details
    emit(state.copyWith(
      isLoading: true,
      error: null,
      selectedApiParameters: [], // Clear old parameters
      userParameterValues: {}, // Clear old parameter values
      pickerOptions: {}, // Clear previous picker options
      selectedApiUrl: null, // Clear previous URL
      serverIP: null, // Clear previous server details
      userName: null,
      password: null,
      databaseName: null,
    ));
    try {
      final apiDetails = await apiService.getApiDetails(event.apiName);
      List<Map<String, dynamic>> fetchedParameters = List<Map<String, dynamic>>.from(apiDetails['parameters'] ?? []);

      // Initialize userParameterValues with default values from fetched parameters
      Map<String, String> initialUserParameterValues = {};
      for (var param in fetchedParameters) {
        if (param['name'] != null) {
          String paramValue = param['value']?.toString() ?? '';
          // Date format handling
          if ((param['type']?.toString().toLowerCase() == 'date') || (param['name'].toString().toLowerCase().contains('date') && paramValue.isNotEmpty)) {
            try {
              // Attempt to parse existing date value (e.g. from 'yyyy-MM-dd' to 'dd-MMM-yyyy')
              final DateTime parsedDate = DateTime.parse(paramValue);
              paramValue = DateFormat('dd-MMM-yyyy').format(parsedDate);
            } catch (e) {
              // If backend sends 'dd-MM-yyyy' or 'dd-MMM-yyyy' initially, and DateTime.parse fails
              // try parsing with specific formats or keep as is.
              // For simplicity, we'll log and keep original if direct parse fails for now.
              // The UI's _parseDateSmartly will handle multiple formats for date picker interactions.
              print('Bloc: Warning: Failed to parse initial date parameter ${param['name']}: $paramValue. Error: $e');
            }
          }
          initialUserParameterValues[param['name'].toString()] = paramValue;
        }
      }

      emit(state.copyWith(
        isLoading: false,
        selectedApiUrl: apiDetails['url'],
        selectedApiParameters: fetchedParameters,
        userParameterValues: initialUserParameterValues,
        serverIP: apiDetails['serverIP'], // Store server details from API
        userName: apiDetails['userName'],
        password: apiDetails['password'],
        databaseName: apiDetails['databaseName'],
        error: null, // Clear any previous errors
      ));
      print('Bloc: FetchApiDetails success: url=${apiDetails['url']}, parameters=${apiDetails['parameters']}, initialUserParameterValues=$initialUserParameterValues');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to fetch API details: $e'));
      print('Bloc: FetchApiDetails error: $e');
    }
  }

  void _onUpdateParameter(UpdateParameter event, Emitter<ReportState> emit) {
    final updatedUserParams = Map<String, String>.from(state.userParameterValues);
    updatedUserParams[event.paramName] = event.value;
    emit(state.copyWith(userParameterValues: updatedUserParams));
    print('Bloc: UpdateParameter: paramName=${event.paramName}, value=${event.value}, updatedParams=$updatedUserParams');
  }

  Future<void> _onFetchFieldConfigs(FetchFieldConfigs event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    print('Bloc: FetchFieldConfigs: Starting for RecNo=${event.recNo}, apiName=${event.apiName}, reportLabel=${event.reportLabel}');
    try {
      // Fetch field configurations
      final fieldConfigs = await apiService.fetchDemoTable2(event.recNo);

      // Fetch report data using the current userParameterValues from state
      final apiResponse = await apiService.fetchApiDataWithParams(event.apiName, state.userParameterValues);
      List<Map<String, dynamic>> reportData = [];
      String? errorMessage;

      // Handle HTTP status codes
      if (apiResponse['status'] == 200) {
        reportData = List<Map<String, dynamic>>.from(apiResponse['data'] ?? []);
      } else {
        errorMessage = apiResponse['error'] ?? 'Unexpected error occurred. Please try again.';
      }

      final newState = state.copyWith(
        isLoading: false,
        fieldConfigs: fieldConfigs,
        reportData: reportData,
        selectedRecNo: event.recNo,
        selectedApiName: event.apiName,
        selectedReportLabel: event.reportLabel,
        error: errorMessage,
      );
      emit(newState);
      print('Bloc: FetchFieldConfigs: Success, fieldConfigs.length=${fieldConfigs.length}, reportData.length=${reportData.length}, error=$errorMessage');
    } catch (e) {
      // If fetching fieldConfigs also throws an error, catch it and provide a fallback.
      List<Map<String, dynamic>> fieldConfigsFallback = [];
      try {
        fieldConfigsFallback = await apiService.fetchDemoTable2(event.recNo);
      } catch (e2) {
        print('Bloc: Error fetching field configs fallback: $e2');
      }

      final newState = state.copyWith(
        isLoading: false,
        fieldConfigs: fieldConfigsFallback, // Use fallback if main fetch failed
        reportData: [], // Clear report data on fetch failure
        selectedRecNo: event.recNo,
        selectedApiName: event.apiName,
        selectedReportLabel: event.reportLabel,
        error: e.toString().contains('TimeoutException')
            ? 'API request timed out after multiple attempts. Please check your network or try again later.'
            : 'Failed to fetch report data: $e',
      );
      emit(newState);
      print('Bloc: FetchFieldConfigs: Error, fieldConfigs.length=${fieldConfigsFallback.length}, error=$e');
    }
  }

  // Handler for fetching picker options
  Future<void> _onFetchPickerOptions(FetchPickerOptions event, Emitter<ReportState> emit) async {
    // Check if options are already loaded for this parameter to prevent redundant API calls
    if (state.pickerOptions.containsKey(event.paramName) && state.pickerOptions[event.paramName]!.isNotEmpty) {
      print('Bloc: Picker options for ${event.paramName} already loaded. Skipping fetch.');
      return;
    }

    emit(state.copyWith(isLoading: true, error: null)); // Indicate loading for picker data
    try {
      print('Bloc: Fetching picker values for param: ${event.paramName}, table: ${event.masterTable}, field: ${event.masterField}');
      final values = await apiService.fetchFieldValues(
        server: event.serverIP,
        UID: event.userName,
        PWD: event.password,
        database: event.databaseName,
        table: event.masterTable,
        field: event.masterField,
      );
      final updatedPickerOptions = Map<String, List<String>>.from(state.pickerOptions);
      updatedPickerOptions[event.paramName] = values;
      emit(state.copyWith(isLoading: false, pickerOptions: updatedPickerOptions, error: null));
      print('Bloc: Fetched picker options for ${event.paramName}: ${values.length} items');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load options for ${event.paramName}: $e'));
      print('Bloc: Error fetching picker options for ${event.paramName}: $e');
    }
  }

  void _onResetReports(ResetReports event, Emitter<ReportState> emit) {
    final newState = ReportState();
    emit(newState);
    print('Bloc: ResetReports: State reset, stateHash=${newState.hashCode}');
  }
}