import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../ReportAPIService.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

// --- Events ---
abstract class ReportEvent {}

class LoadReports extends ReportEvent {}

class FetchApiDetails extends ReportEvent {
  final String apiName;
  final List<Map<String, dynamic>> actionsConfig; // Kept as requested

  FetchApiDetails(this.apiName, this.actionsConfig);
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
  final String? actionApiUrlTemplate;
  final Map<String, String>? dynamicApiParams;

  FetchFieldConfigs(
      this.recNo,
      this.apiName,
      this.reportLabel, {
        this.actionApiUrlTemplate,
        this.dynamicApiParams,
      });
}

class FetchDocumentData extends ReportEvent {
  final String apiName;
  final String actionApiUrlTemplate;
  final Map<String, String> dynamicApiParams;

  FetchDocumentData({
    required this.apiName,
    required this.actionApiUrlTemplate,
    required this.dynamicApiParams,
  });
}

class FetchPickerOptions extends ReportEvent {
  final String paramName;
  final String serverIP;
  final String userName;
  final String password;
  final String databaseName;
  final String masterTable;
  final String masterField;
  final String displayField;

  FetchPickerOptions({
    required this.paramName,
    required this.serverIP,
    required this.userName,
    required this.password,
    required this.databaseName,
    required this.masterTable,
    required this.masterField,
    required this.displayField,
  });
}

class ResetReports extends ReportEvent {}

// NEW EVENT: DeployReportToClient
class DeployReportToClient extends ReportEvent {
  final Map<String, dynamic> reportMetadata;
  final List<Map<String, dynamic>> fieldConfigs;
  final String clientApiName; // The API name associated with this report, used to get client DB credentials

  DeployReportToClient({
    required this.reportMetadata,
    required this.fieldConfigs,
    required this.clientApiName,
  });
}


// --- State ---
class ReportState {
  final bool isLoading;
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> fieldConfigs;
  final List<Map<String, dynamic>> reportData;
  final Map<String, dynamic>? documentData;
  final String? selectedRecNo;
  final String? selectedApiName;
  final String? selectedReportLabel;
  final String? selectedApiUrl;
  final List<Map<String, dynamic>> selectedApiParameters;
  final Map<String, String> userParameterValues;
  final Map<String, List<Map<String, String>>> pickerOptions;
  final String? serverIP; // Client's ServerIP for picker options, *not* your main system's
  final String? userName; // Client's UserName for picker options
  final String? password; // Client's Password for picker options
  final String? databaseName; // Client's DatabaseName for picker options
  final List<Map<String, dynamic>> actionsConfig;
  final String? error;
  final String? successMessage; // New field for success messages

  ReportState({
    this.isLoading = false,
    this.reports = const [],
    this.fieldConfigs = const [],
    this.reportData = const [],
    this.documentData,
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
    this.actionsConfig = const [],
    this.error,
    this.successMessage, // Initialize success message
  });

  ReportState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? reports,
    List<Map<String, dynamic>>? fieldConfigs,
    List<Map<String, dynamic>>? reportData,
    Map<String, dynamic>? documentData,
    String? selectedRecNo,
    String? selectedApiName,
    String? selectedReportLabel,
    String? selectedApiUrl,
    List<Map<String, dynamic>>? selectedApiParameters,
    Map<String, String>? userParameterValues,
    Map<String, List<Map<String, String>>>? pickerOptions,
    String? serverIP,
    String? userName,
    String? password,
    String? databaseName,
    List<Map<String, dynamic>>? actionsConfig,
    String? error,
    String? successMessage, // Allow copying success message
  }) {
    return ReportState(
      isLoading: isLoading ?? this.isLoading,
      reports: reports ?? this.reports,
      fieldConfigs: fieldConfigs ?? this.fieldConfigs,
      reportData: reportData ?? this.reportData,
      documentData: documentData,
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
      actionsConfig: actionsConfig ?? this.actionsConfig,
      error: error,
      successMessage: successMessage, // Copy success message
    );
  }
}

// --- BLoC Implementation ---
class ReportBlocGenerate extends Bloc<ReportEvent, ReportState> {
  final ReportAPIService apiService;

  ReportBlocGenerate(this.apiService) : super(ReportState()) {
    on<LoadReports>(_onLoadReports);
    on<FetchApiDetails>(_onFetchApiDetails);
    on<UpdateParameter>(_onUpdateParameter);
    on<FetchFieldConfigs>(_onFetchFieldConfigs);
    on<FetchDocumentData>(_onFetchDocumentData);
    on<FetchPickerOptions>(_onFetchPickerOptions);
    on<ResetReports>(_onResetReports);
    on<DeployReportToClient>(_onDeployReportToClient); // NEW: Handle deployment event
  }

  Future<void> _onLoadReports(LoadReports event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, successMessage: null));
    try {
      final reports = await apiService.fetchDemoTable();
      emit(state.copyWith(isLoading: false, reports: reports));
      debugPrint('Bloc: Loaded ${reports.length} reports for selection.');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load reports: $e'));
      debugPrint('Bloc: LoadReports error: $e');
    }
  }

  // FetchApiDetails is primarily for the *current* report's parameter inputs AND its own actions config
  Future<void> _onFetchApiDetails(FetchApiDetails event, Emitter<ReportState> emit) async {
    // Clear relevant state properties for a new report's details, but do NOT clear fieldConfigs here
    // as fieldConfigs is handled by FetchFieldConfigs.
    emit(state.copyWith(
      isLoading: true,
      error: null,
      successMessage: null, // Clear any previous success message
      selectedApiParameters: [],
      userParameterValues: {},
      pickerOptions: {},
      selectedApiUrl: null,
      serverIP: null,
      userName: null,
      password: null,
      databaseName: null,
      // fieldConfigs is intentionally NOT cleared here; it's managed by FetchFieldConfigs
      documentData: null,
      reportData: [], // Clear report data as new API details mean new data
    ));
    try {
      final apiDetails = await apiService.getApiDetails(event.apiName);

      List<Map<String, dynamic>> fetchedParameters = List<Map<String, dynamic>>.from(apiDetails['parameters'] ?? []);

      final Map<String, String> initialUserParameterValues = {};
      final Map<String, List<Map<String, String>>> initialPickerOptions = {};

      final String? serverIP = apiDetails['serverIP']?.toString();
      final String? userName = apiDetails['userName']?.toString();
      final String? password = apiDetails['password']?.toString();
      final String? databaseName = apiDetails['databaseName']?.toString();

      // Determine the final actions config for the state:
      // Prefer actions from the API response for this specific API.
      List<Map<String, dynamic>> finalActionsConfig = List<Map<String, dynamic>>.from(apiDetails['actions'] ?? []);

      // Fallback: If API did not provide actions, but the event did (e.g., from main UI's metadata), use event's actions.
      // This ensures that the main report's actions, which might be sourced from its initial metadata fetch, are preserved.
      if (finalActionsConfig.isEmpty && event.actionsConfig.isNotEmpty) {
        finalActionsConfig = event.actionsConfig;
      }


      for (var param in fetchedParameters) {
        if (param['name'] != null) {
          String paramName = param['name'].toString();
          String paramValue = param['value']?.toString() ?? '';

          if ((param['type']?.toString().toLowerCase() == 'date') && paramValue.isNotEmpty) {
            try {
              final DateTime parsedDate = DateTime.parse(paramValue);
              paramValue = DateFormat('dd-MMM-yyyy').format(parsedDate);
            } catch (e) {
              debugPrint('Bloc: Warning: Failed to parse initial date parameter $paramName: $paramValue. Error: $e');
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
        pickerOptions: initialPickerOptions,
        serverIP: serverIP,
        userName: userName,
        password: password,
        databaseName: databaseName,
        actionsConfig: finalActionsConfig, // Set the actionsConfig in BLoC state
        error: null,
      ));
      debugPrint('Bloc: FetchApiDetails success for API: ${event.apiName}. Actions Config loaded: ${finalActionsConfig.isNotEmpty ? finalActionsConfig.length : 'empty'} items.');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to fetch API details: $e'));
      debugPrint('Bloc: FetchApiDetails error: $e');
    }
  }

  void _onUpdateParameter(UpdateParameter event, Emitter<ReportState> emit) {
    final updatedUserParams = Map<String, String>.from(state.userParameterValues);
    updatedUserParams[event.paramName] = event.value;
    emit(state.copyWith(userParameterValues: updatedUserParams, successMessage: null, error: null)); // Clear messages on param update
    debugPrint('Bloc: Updated parameter ${event.paramName} to: ${event.value}');
  }

  Future<void> _onFetchFieldConfigs(FetchFieldConfigs event, Emitter<ReportState> emit) async {
    // Keep loading state until both field configs and report data (if any) are fetched.
    // reportData is cleared here as we are fetching new data.
    emit(state.copyWith(isLoading: true, error: null, successMessage: null, reportData: [], documentData: null));

    debugPrint('Bloc: FetchFieldConfigs: Starting for RecNo=${event.recNo}, apiName=${event.apiName}, reportLabel=${event.reportLabel}');
    debugPrint('Bloc: FetchFieldConfigs: Dynamic parameters provided for API call: ${event.dynamicApiParams}');

    try {
      final fieldConfigs = await apiService.fetchDemoTable2(event.recNo);

      // --- ADDED DEBUGGING LOG ---
      debugPrint('Bloc: _onFetchFieldConfigs - fieldConfigs received from API service (length): ${fieldConfigs.length}');
      debugPrint('Bloc: _onFetchFieldConfigs - First field config item (if any): ${fieldConfigs.isNotEmpty ? fieldConfigs.first : 'N/A'}');
      // --- END ADDITION ---

      final apiResponse = await apiService.fetchApiDataWithParams(
        event.apiName,
        event.dynamicApiParams ?? state.userParameterValues, // Use dynamicApiParams if provided, else use state's params
        actionApiUrlTemplate: event.actionApiUrlTemplate,
      );
      List<Map<String, dynamic>> reportData = [];
      String? errorMessage;

      if (apiResponse['status'] == 200) {
        reportData = List<Map<String, dynamic>>.from(apiResponse['data'] ?? []);
        debugPrint('Bloc: Fetched ${reportData.length} rows for grid report.');
      } else {
        errorMessage = apiResponse['error'] ?? 'Unexpected error occurred. Please try again.';
        debugPrint('Bloc: API response status not 200 for grid report: $errorMessage');
      }

      final newState = state.copyWith(
        isLoading: false,
        fieldConfigs: fieldConfigs, // This is where the fieldConfigs are updated in the state
        reportData: reportData,
        selectedRecNo: event.recNo,
        selectedApiName: event.apiName,
        selectedReportLabel: event.reportLabel,
        error: errorMessage,
      );
      emit(newState);
      debugPrint('Bloc: FetchFieldConfigs success. Emitted state with ${newState.fieldConfigs.length} field configs.');
    } catch (e) {
      // Fallback field configs in case primary API data fetch fails but field configs might still be accessible.
      List<Map<String, dynamic>> fieldConfigsFallback = [];
      try {
        fieldConfigsFallback = await apiService.fetchDemoTable2(event.recNo);
        debugPrint('Bloc: Successfully fetched field configs as fallback during error: ${fieldConfigsFallback.length}');
      } catch (e2) {
        debugPrint('Bloc: Error fetching field configs fallback: $e2');
      }

      final newState = state.copyWith(
        isLoading: false,
        fieldConfigs: fieldConfigsFallback, // Use fallback field configs
        reportData: [], // Clear report data on error
        selectedRecNo: event.recNo,
        selectedApiName: event.apiName,
        selectedReportLabel: event.reportLabel,
        error: e.toString().contains('TimeoutException')
            ? 'API request timed out after multiple attempts. Please check your network or try again later.'
            : 'Failed to fetch report data: $e',
        documentData: null,
      );
      emit(newState);
      debugPrint('Bloc: FetchFieldConfigs: Error, error=$e');
    }
  }

  Future<void> _onFetchDocumentData(FetchDocumentData event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, successMessage: null, documentData: null));

    debugPrint('Bloc: FetchDocumentData: Starting for API=${event.apiName}, URL=${event.actionApiUrlTemplate}');
    debugPrint('Bloc: FetchDocumentData: Dynamic parameters for API call: ${event.dynamicApiParams}');

    try {
      final apiResponse = await apiService.fetchApiDataWithParams(
        event.apiName,
        event.dynamicApiParams,
        actionApiUrlTemplate: event.actionApiUrlTemplate,
      );

      Map<String, dynamic>? fetchedDocumentData;
      String? errorMessage;

      if (apiResponse['status'] == 200) {
        final List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(apiResponse['data'] ?? []);
        if (rawData.isNotEmpty) {
          fetchedDocumentData = rawData.first;
          debugPrint('Bloc: Fetched document data successfully.');
        } else {
          errorMessage = 'No data returned for document view.';
          debugPrint('Bloc: No data for document view.');
        }
      } else {
        errorMessage = apiResponse['error'] ?? 'Unexpected error occurred while fetching document data.';
        debugPrint('Bloc: API response status not 200 for document data: $errorMessage');
      }

      emit(state.copyWith(
        isLoading: false,
        documentData: fetchedDocumentData,
        error: errorMessage,
      ));
      debugPrint('Bloc: FetchDocumentData success/failure handled.');
    } catch (e) {
      final newState = state.copyWith(
        isLoading: false,
        documentData: null,
        error: e.toString().contains('TimeoutException')
            ? 'API request timed out. Please check your network or try again later.'
            : 'Failed to fetch document data: $e',
      );
      emit(newState);
      debugPrint('Bloc: FetchDocumentData error: $e');
    }
  }

  Future<void> _onFetchPickerOptions(FetchPickerOptions event, Emitter<ReportState> emit) async {
    if (state.pickerOptions.containsKey(event.paramName) && state.pickerOptions[event.paramName]!.isNotEmpty) {
      debugPrint('Bloc: Picker options for ${event.paramName} already loaded. Skipping re-fetch.');
      return;
    }

    emit(state.copyWith(isLoading: true, error: null, successMessage: null));
    try {
      debugPrint('Bloc: Fetching picker values for param: ${event.paramName}, masterTable: ${event.masterTable}, masterField: ${event.masterField}, displayField: ${event.displayField}');
      final List<Map<String, dynamic>> fetchedData = await apiService.fetchPickerData(
        server: event.serverIP!,
        UID: event.userName!,
        PWD: event.password!,
        database: event.databaseName!,
        masterTable: event.masterTable,
        masterField: event.masterField,
        displayField: event.displayField,
      );

      final List<Map<String, String>> mappedOptions = fetchedData.map((item) {
        return {
          'value': item[event.masterField]?.toString() ?? '',
          'label': item[event.displayField]?.toString() ?? '',
        };
      }).toList();

      final updatedPickerOptions = Map<String, List<Map<String, String>>>.from(state.pickerOptions);
      updatedPickerOptions[event.paramName] = mappedOptions;

      emit(state.copyWith(isLoading: false, pickerOptions: updatedPickerOptions, error: null));
      debugPrint('Bloc: FetchPickerOptions success for ${event.paramName}.');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load options for ${event.paramName}: $e'));
      debugPrint('Bloc: Error fetching picker options for ${event.paramName}: $e');
    }
  }

  void _onResetReports(ResetReports event, Emitter<ReportState> emit) {
    emit(ReportState(
      reports: state.reports, // Preserve the loaded reports list
      isLoading: false,
      error: null,
      successMessage: null,
      fieldConfigs: [], // Clear field configs
      reportData: [], // Clear report data
      documentData: null, // Clear document data
      selectedRecNo: null,
      selectedApiName: null,
      selectedReportLabel: null,
      selectedApiUrl: null,
      selectedApiParameters: [], // Clear selected parameters
      userParameterValues: {}, // Clear user parameter values
      pickerOptions: {}, // Clear picker options
      serverIP: null, // Clear client credentials
      userName: null,
      password: null,
      databaseName: null,
      actionsConfig: [], // Clear actions config
    ));
    debugPrint('Bloc: ResetReports: State reset (parameters, selected API, data cleared), but reports list preserved.');
  }

  // NEW: Handler for DeployReportToClient event
  Future<void> _onDeployReportToClient(DeployReportToClient event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, successMessage: null)); // Indicate loading, clear previous messages
    debugPrint('Bloc: DeployReportToClient event received for report RecNo: ${event.reportMetadata['RecNo']}');

    try {
      // 1. Get client database connection details from cache
      // The `clientApiName` in the event is the API_name of the report,
      // which corresponds to an entry in your main system's DatabaseServerMaster.
      final apiDetails = await apiService.getApiDetails(event.clientApiName);

      final String? clientServerIP = apiDetails['serverIP']?.toString();
      final String? clientUserName = apiDetails['userName']?.toString();
      final String? clientPassword = apiDetails['password']?.toString();
      final String? clientDatabaseName = apiDetails['databaseName']?.toString();

      if (clientServerIP == null || clientUserName == null || clientPassword == null || clientDatabaseName == null) {
        throw Exception('Client database credentials not found for API: ${event.clientApiName}');
      }

      // 2. Call the new API service method to deploy
      final response = await apiService.deployReportToClient(
        reportMetadata: event.reportMetadata,
        fieldConfigs: event.fieldConfigs,
        clientServerIP: clientServerIP,
        clientUserName: clientUserName,
        clientPassword: clientPassword,
        clientDatabaseName: clientDatabaseName,
      );

      // 3. Handle the response from the deployment PHP script
      if (response['status'] == 'success') {
        emit(state.copyWith(
          isLoading: false,
          successMessage: response['message'] ?? 'Report deployed successfully to client!',
          error: null,
        ));
        debugPrint('Bloc: Report deployed successfully: ${response['message']}');
      } else {
        emit(state.copyWith(
          isLoading: false,
          error: response['message'] ?? 'Failed to deploy report to client.',
          successMessage: null,
        ));
        debugPrint('Bloc: Report deployment failed: ${response['message']}');
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to deploy report: $e',
        successMessage: null,
      ));
      debugPrint('Bloc: DeployReportToClient error: $e');
    }
  }
}