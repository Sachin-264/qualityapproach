import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../ReportAPIService.dart';

abstract class ReportEvent {}

class LoadReports extends ReportEvent {}

class FetchApiDetails extends ReportEvent {
  final String apiName;
  FetchApiDetails(this.apiName);
// @override List<Object?> get props => [apiName]; // If Equatable
}

class UpdateParameter extends ReportEvent {
  final String paramName;
  final String value;
  UpdateParameter(this.paramName, this.value);
// @override List<Object?> get props => [paramName, value]; // If Equatable
}

class FetchFieldConfigs extends ReportEvent {
  final String recNo;
  final String apiName;
  final String reportLabel;
  FetchFieldConfigs(this.recNo, this.apiName, this.reportLabel);
// @override List<Object?> get props => [recNo, apiName, reportLabel]; // If Equatable
}

// NEW EVENT: FetchPickerOptions - Now includes displayField
class FetchPickerOptions extends ReportEvent {
  final String paramName;
  final String serverIP;
  final String userName;
  final String password;
  final String databaseName;
  final String masterTable;
  final String masterField;
  final String displayField; // NEW: Added displayField

  FetchPickerOptions({
    required this.paramName,
    required this.serverIP,
    required this.userName,
    required this.password,
    required this.databaseName,
    required this.masterTable,
    required this.masterField,
    required this.displayField, // NEW: Added displayField
  });
// @override List<Object?> get props => [paramName, serverIP, userName, password, databaseName, masterTable, masterField, displayField]; // If Equatable
}

class ResetReports extends ReportEvent {}

// States
// class ReportState extends Equatable { // Uncomment and extend Equatable if you use it
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
  // UPDATED TYPE: Now stores List of Maps for picker options (value and label)
  final Map<String, List<Map<String, String>>> pickerOptions;
  final String? serverIP;
  final String? userName;
  final String? password;
  final String? databaseName;
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
    this.pickerOptions = const {}, // Initialize with empty map
    this.serverIP,
    this.userName,
    this.password,
    this.databaseName,
    this.error,
  });

  // @override List<Object?> get props => [ /* list all properties here */ ]; // If Equatable

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
    // UPDATED PARAMETER TYPE for copyWith
    Map<String, List<Map<String, String>>>? pickerOptions,
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
      pickerOptions: pickerOptions ?? this.pickerOptions, // Update pickerOptions in copyWith
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
      pickerOptions: {}, // Clear previous picker options for new report selection
      selectedApiUrl: null, // Clear previous URL
      serverIP: null, // Clear previous server details
      userName: null,
      password: null,
      databaseName: null,
    ));
    try {
      final apiDetails = await apiService.getApiDetails(event.apiName);
      List<Map<String, dynamic>> fetchedParameters = List<Map<String, dynamic>>.from(apiDetails['parameters'] ?? []);

      final Map<String, String> initialUserParameterValues = {};
      final Map<String, List<Map<String, String>>> initialPickerOptions = {}; // For immediate population of picker data

      // Extract server details from API details for fetching picker options
      final String? serverIP = apiDetails['serverIP']?.toString();
      final String? userName = apiDetails['userName']?.toString();
      final String? password = apiDetails['password']?.toString();
      final String? databaseName = apiDetails['databaseName']?.toString();


      // Step 1: Pre-load picker options synchronously before emitting state (if needed for initial values)
      // This ensures pickerOptions are available if initial values need label lookup.
      // However, usually we load picker options on demand in UI. If API initial parameter has
      // a picker value (e.g. 'E' for Branch), we want to show its 'label' (e.g., 'EAST').
      // To do this, we need the pickerOptions to be loaded BEFORE setting userParameterValues for display.
      // This can be complex if there are many pickers and you need to ensure all their options are ready.
      // For this solution, we will load options *after* emitting the main parameters, and the UI
      // will trigger the fetch, making the initial controller text potentially show the value
      // (like 'E') temporarily until the labels load and are updated in UI.

      for (var param in fetchedParameters) {
        if (param['name'] != null) {
          String paramName = param['name'].toString();
          String paramValue = param['value']?.toString() ?? '';

          // Date format handling for initial value
          if ((param['type']?.toString().toLowerCase() == 'date') || (paramName.toLowerCase().contains('date') && paramValue.isNotEmpty)) {
            // Check if it can be parsed to an existing format before applying new format
            // To be safe, rely on UI's _parseDateSmartly for robust parsing and formatting.
            // For Bloc, it's safer to store original 'yyyy-MM-dd' from backend if applicable,
            // or if it already comes in 'dd-MM-yyyy' or 'dd-MMM-yyyy', just store it.
            try {
              final DateTime parsedDate = DateTime.parse(paramValue); // Assume backend returns yyyy-MM-dd initially
              paramValue = DateFormat('dd-MMM-yyyy').format(parsedDate); // Format for consistent display if needed
            } catch (e) {
              print('Bloc: Warning: Failed to parse initial date parameter $paramName: $paramValue. Error: $e');
              // Keep original value if parsing to default foramt fails.
            }
          }

          initialUserParameterValues[paramName] = paramValue;
        }
      }

      emit(state.copyWith(
        isLoading: false,
        selectedApiUrl: apiDetails['url'],
        selectedApiParameters: fetchedParameters,
        userParameterValues: initialUserParameterValues,
        pickerOptions: initialPickerOptions, // Initial empty picker options
        serverIP: serverIP,
        userName: userName,
        password: password,
        databaseName: databaseName,
        error: null,
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

  // Handler for fetching picker options - NOW USES fetchPickerData AND CORRECTLY MAPS
  Future<void> _onFetchPickerOptions(FetchPickerOptions event, Emitter<ReportState> emit) async {
    // Only set loading for the specific picker if other things aren't already loading
    // And, only if pickerOptions for this param are not yet loaded (or empty)
    if (state.pickerOptions.containsKey(event.paramName) && state.pickerOptions[event.paramName]!.isNotEmpty) {
      print('Bloc: Picker options for ${event.paramName} already loaded. Skipping fetch.');
      return;
    }

    // Indicate loading, but prevent overall app loading spinner if it's just a picker field loading.
    // This is tricky, a simpler approach might just be to emit `isLoading: true` and then `isLoading: false`.
    emit(state.copyWith(isLoading: true, error: null));
    try {
      print('Bloc: Fetching picker values for param: ${event.paramName}, masterTable: ${event.masterTable}, masterField: ${event.masterField}, displayField: ${event.displayField}');

      // >>> CORRECTED: Call the new fetchPickerData which returns List<Map<String, dynamic>>
      final List<Map<String, dynamic>> fetchedData = await apiService.fetchPickerData(
        server: event.serverIP,
        UID: event.userName,
        PWD: event.password,
        database: event.databaseName,
        masterTable: event.masterTable,
        masterField: event.masterField,
        displayField: event.displayField, // Pass the display field
      );

      // Map the fetched data to the { 'value': 'master_value', 'label': 'display_label' } format
      final List<Map<String, String>> mappedOptions = fetchedData.map((item) {
        return {
          'value': item[event.masterField]?.toString() ?? '', // Get value using masterField key
          'label': item[event.displayField]?.toString() ?? '', // Get label using displayField key
        };
      }).toList();

      final updatedPickerOptions = Map<String, List<Map<String, String>>>.from(state.pickerOptions);
      updatedPickerOptions[event.paramName] = mappedOptions;

      emit(state.copyWith(isLoading: false, pickerOptions: updatedPickerOptions, error: null));
      print('Bloc: Fetched picker options for ${event.paramName}: ${mappedOptions.length} items. Sample: ${mappedOptions.isNotEmpty ? mappedOptions.first : {}}');
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