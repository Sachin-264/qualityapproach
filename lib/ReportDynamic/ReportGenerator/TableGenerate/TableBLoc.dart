// ReportDynamic/TableGenerator/TableBLoc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../ReportAPIService.dart'; // Adjust path
import 'package:flutter/foundation.dart'; // For debugPrint

// --- Events ---
// Keep ReportEvent and ReportState as they are generic enough
abstract class ReportEvent {}

class LoadReports extends ReportEvent {}

class FetchApiDetails extends ReportEvent {
  final String apiName;
  // actionsConfig here is from the ReportMainUI's constructor,
  // typically empty for nested TableMainUI, and will be populated
  // by the BLoC's own fetch of this API's details.
  final List<Map<String, dynamic>> actionsConfig;

  FetchApiDetails(this.apiName, this.actionsConfig);
}

class UpdateParameter extends ReportEvent {
  final String paramName;
  final String value;
  UpdateParameter(this.paramName, this.value);
}

class FetchFieldConfigs extends ReportEvent {
  final String recNo;
  final String apiName; // The API_name used to fetch the actual report data and its details
  final String reportLabel; // The display label
  final String? actionApiUrlTemplate; // For drill-down/print actions
  final Map<String, String>? dynamicApiParams; // Parameters for the API call

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
  final String? serverIP;
  final String? userName;
  final String? password;
  final String? databaseName;
  final List<Map<String, dynamic>> actionsConfig; // This will hold the actions from the *current* report's API details.
  final String? error;
  final bool includePdfFooterDateTime; // NEW: Add includePdfFooterDateTime to state

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
    this.actionsConfig = const [], // Default to empty list
    this.error,
    this.includePdfFooterDateTime = false, // NEW: Initialize to false
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
    List<Map<String, dynamic>>? actionsConfig, // Allow actionsConfig to be copied
    String? error,
    bool? includePdfFooterDateTime, // NEW: Allow copying this field
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
      actionsConfig: actionsConfig ?? this.actionsConfig, // Preserve if not provided
      error: error,
      includePdfFooterDateTime: includePdfFooterDateTime ?? this.includePdfFooterDateTime, // NEW: Assign copied value
    );
  }
}

// --- BLoC Implementation ---
class TableBlocGenerate extends Bloc<ReportEvent, ReportState> { // Renamed from ReportBlocGenerate
  final ReportAPIService apiService;

  TableBlocGenerate(this.apiService) : super(ReportState()) {
    on<LoadReports>(_onLoadReports);
    on<FetchApiDetails>(_onFetchApiDetails);
    on<UpdateParameter>(_onUpdateParameter);
    on<FetchFieldConfigs>(_onFetchFieldConfigs);
    on<FetchDocumentData>(_onFetchDocumentData);
    on<FetchPickerOptions>(_onFetchPickerOptions);
    on<ResetReports>(_onResetReports);
  }

  Future<void> _onLoadReports(LoadReports event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final reports = await apiService.fetchDemoTable();
      emit(state.copyWith(isLoading: false, reports: reports));
      debugPrint('TableBloc: Loaded ${reports.length} reports for selection.');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load reports: $e'));
      debugPrint('TableBloc: LoadReports error: $e');
    }
  }

  // FetchApiDetails is primarily for the *current* report's parameter inputs AND its own actions config
  Future<void> _onFetchApiDetails(FetchApiDetails event, Emitter<ReportState> emit) async {
    // Clear relevant state properties for a new report's details
    emit(state.copyWith(
      isLoading: true,
      error: null,
      selectedApiParameters: [],
      userParameterValues: {},
      pickerOptions: {},
      selectedApiUrl: null,
      serverIP: null,
      userName: null,
      password: null,
      databaseName: null,
      documentData: null,
      // Do NOT clear reportData and fieldConfigs here, as they are fetched by FetchFieldConfigs
      // actionsConfig is cleared, then set by this event's success.
      actionsConfig: [], // Clear actions here to ensure a fresh fetch
      includePdfFooterDateTime: false, // NEW: Reset to false initially
    ));
    try {
      final apiDetails = await apiService.getApiDetails(event.apiName); // This call now waits internally

      List<Map<String, dynamic>> fetchedParameters = List<Map<String, dynamic>>.from(apiDetails['parameters'] ?? []);

      final Map<String, String> initialUserParameterValues = {};
      final Map<String, List<Map<String, String>>> initialPickerOptions = {};

      final String? serverIP = apiDetails['serverIP']?.toString();
      final String? userName = apiDetails['userName']?.toString();
      final String? password = apiDetails['password']?.toString();
      final String? databaseName = apiDetails['databaseName']?.toString();

      // **IMPORTANT CHANGE HERE:** Directly use actions from the API response
      List<Map<String, dynamic>> fetchedActions = List<Map<String, dynamic>>.from(apiDetails['actions_config'] ?? []); // Ensure 'actions_config' matches backend
      debugPrint('TableBloc: API "${event.apiName}" returned ${fetchedActions.length} actions.');

      // NEW: Get includePdfFooterDateTime from API response
      final bool fetchedIncludePdfFooterDateTime = apiDetails['includePdfFooterDateTime'] ?? false;


      for (var param in fetchedParameters) {
        if (param['name'] != null) {
          String paramName = param['name'].toString();
          String paramValue = param['value']?.toString() ?? '';

          if ((param['type']?.toString().toLowerCase() == 'date') && paramValue.isNotEmpty) {
            try {
              final DateTime parsedDate = DateTime.parse(paramValue);
              paramValue = DateFormat('dd-MMM-yyyy').format(parsedDate);
            } catch (e) {
              debugPrint('TableBloc: Warning: Failed to parse initial date parameter $paramName: $paramValue. Error: $e');
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
        actionsConfig: fetchedActions, // Set the actionsConfig in BLoC state based on THIS API's details
        includePdfFooterDateTime: fetchedIncludePdfFooterDateTime, // NEW: Set in state
        error: null,
      ));
      debugPrint('TableBloc: FetchApiDetails success for API: ${event.apiName}. Actions Config loaded: ${fetchedActions.length} items. Include PDF Footer Date/Time: $fetchedIncludePdfFooterDateTime');
    } catch (e) {
      // **Key change:** Instead of immediately emitting an error that causes UI flicker,
      // we can try to proceed if possible or at least set a specific error message.
      // The UI will still show the error if it's the only failure, but it won't be transient.
      emit(state.copyWith(
          isLoading: false,
          error: e.toString().contains('API details not found')
              ? 'Configuration error: API details for "${event.apiName}" not found on server. Please check setup.'
              : 'Failed to fetch API details: $e'
      ));
      debugPrint('TableBloc: FetchApiDetails error: $e');
    }
  }

  void _onUpdateParameter(UpdateParameter event, Emitter<ReportState> emit) {
    final updatedUserParams = Map<String, String>.from(state.userParameterValues);
    updatedUserParams[event.paramName] = event.value;
    emit(state.copyWith(userParameterValues: updatedUserParams));
    debugPrint('TableBloc: Updated parameter ${event.paramName} to: ${event.value}');
  }

  Future<void> _onFetchFieldConfigs(FetchFieldConfigs event, Emitter<ReportState> emit) async {
    // Only set isLoading and clear reportData/error if not already loading from FetchApiDetails
    // (This helps prevent duplicate loading indicators/flicker if FetchApiDetails just started)
    if (!state.isLoading) {
      emit(state.copyWith(isLoading: true, error: null, reportData: [])); // Clear previous report data
    } else {
      // If isLoading is true, it means FetchApiDetails is still working.
      // Just ensure reportData is cleared and error is null for this specific fetch.
      emit(state.copyWith(reportData: [], error: null));
    }


    debugPrint('TableBloc: FetchFieldConfigs: Starting for RecNo=${event.recNo}, apiName=${event.apiName}, reportLabel=${event.reportLabel}');
    debugPrint('TableBloc: FetchFieldConfigs: Dynamic parameters provided for API call: ${event.dynamicApiParams}');

    try {
      final fieldConfigs = await apiService.fetchDemoTable2(event.recNo);

      // We should ideally ensure API details are loaded for the data fetch,
      // but apiService.fetchApiDataWithParams now handles ensuring API details
      // are available, including potentially re-fetching them.
      final apiResponse = await apiService.fetchApiDataWithParams(
        event.apiName, // Use the actual API_name from the config
        event.dynamicApiParams ?? state.userParameterValues, // Use dynamicApiParams if provided, else use state's params
        actionApiUrlTemplate: event.actionApiUrlTemplate,
      );
      List<Map<String, dynamic>> reportData = [];
      String? errorMessage;

      if (apiResponse['status'] == 200) {
        reportData = List<Map<String, dynamic>>.from(apiResponse['data'] ?? []);
        debugPrint('TableBloc: Fetched ${reportData.length} rows for grid report.');
      } else {
        errorMessage = apiResponse['error'] ?? 'Unexpected error occurred. Please try again.';
        debugPrint('TableBloc: API response status not 200 for grid report: $errorMessage');
      }

      final newState = state.copyWith(
        isLoading: false,
        fieldConfigs: fieldConfigs,
        reportData: reportData,
        selectedRecNo: event.recNo,
        selectedApiName: event.apiName,
        selectedReportLabel: event.reportLabel,
        error: errorMessage, // Set error from API response if any
        documentData: null,
      );
      emit(newState);
      debugPrint('TableBloc: FetchFieldConfigs success.');
    } catch (e) {
      List<Map<String, dynamic>> fieldConfigsFallback = [];
      try {
        // Attempt to fetch field configs even if data fetch fails, to display column headers.
        fieldConfigsFallback = await apiService.fetchDemoTable2(event.recNo);
      } catch (e2) {
        debugPrint('TableBloc: Error fetching field configs fallback after data fetch failure: $e2');
      }

      final newState = state.copyWith(
        isLoading: false,
        fieldConfigs: fieldConfigsFallback, // Keep whatever configs were successfully fetched
        reportData: [], // Ensure report data is empty on error
        selectedRecNo: event.recNo,
        selectedApiName: event.apiName,
        selectedReportLabel: event.reportLabel,
        error: e.toString().contains('TimeoutException')
            ? 'API request timed out. Please check your network or try again later.'
            : 'Failed to fetch report data: $e',
        documentData: null,
      );
      emit(newState);
      debugPrint('TableBloc: FetchFieldConfigs: Error, error=$e');
    }
  }

  Future<void> _onFetchDocumentData(FetchDocumentData event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, documentData: null));

    debugPrint('TableBloc: FetchDocumentData: Starting for API=${event.apiName}, URL=${event.actionApiUrlTemplate}');
    debugPrint('TableBloc: FetchDocumentData: Dynamic parameters for API call: ${event.dynamicApiParams}');

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
          debugPrint('TableBloc: Fetched document data successfully.');
        } else {
          errorMessage = 'No data returned for document view.';
          debugPrint('TableBloc: No data for document view.');
        }
      } else {
        errorMessage = apiResponse['error'] ?? 'Unexpected error occurred while fetching document data.';
        debugPrint('TableBloc: API response status not 200 for document data: $errorMessage');
      }

      emit(state.copyWith(
        isLoading: false,
        documentData: fetchedDocumentData,
        error: errorMessage,
      ));
      debugPrint('TableBloc: FetchDocumentData success/failure handled.');
    } catch (e) {
      final newState = state.copyWith(
        isLoading: false,
        documentData: null,
        error: e.toString().contains('TimeoutException')
            ? 'API request timed out. Please check your network or try again later.'
            : 'Failed to fetch document data: $e',
      );
      emit(newState);
      debugPrint('TableBloc: FetchDocumentData error: $e');
    }
  }

  Future<void> _onFetchPickerOptions(FetchPickerOptions event, Emitter<ReportState> emit) async {
    if (state.pickerOptions.containsKey(event.paramName) && state.pickerOptions[event.paramName]!.isNotEmpty) {
      debugPrint('TableBloc: Picker options for ${event.paramName} already loaded. Skipping re-fetch.');
      return;
    }

    emit(state.copyWith(isLoading: true, error: null));
    try {
      debugPrint('TableBloc: Fetching picker values for param: ${event.paramName}, masterTable: ${event.masterTable}, masterField: ${event.masterField}, displayField: ${event.displayField}');
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
      debugPrint('TableBloc: FetchPickerOptions success for ${event.paramName}.');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load options for ${event.paramName}: $e'));
      debugPrint('TableBloc: Error fetching picker options for ${event.paramName}: $e');
    }
  }

  void _onResetReports(ResetReports event, Emitter<ReportState> emit) {
    emit(state.copyWith(
      isLoading: false,
      fieldConfigs: [],
      reportData: [],
      documentData: null,
      selectedRecNo: null,
      selectedApiName: null,
      selectedReportLabel: null,
      selectedApiUrl: null,
      selectedApiParameters: [],
      userParameterValues: {},
      pickerOptions: {},
      serverIP: null,
      userName: null,
      password: null,
      databaseName: null,
      actionsConfig: [], // Clear actions config on a full reset
      includePdfFooterDateTime: false, // NEW: Reset this flag too
      error: null,
    ));
    debugPrint('TableBloc: ResetReports: State reset (parameters, selected API, data cleared), but reports list preserved.');
  }
}