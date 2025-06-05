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
  final String apiName;
  final String reportLabel;
  final String? actionApiUrlTemplate;
  final Map<String, String>? dynamicApiParams; // NEW: Pass dynamic parameters from the row for tables

  FetchFieldConfigs(
      this.recNo,
      this.apiName,
      this.reportLabel, {
        this.actionApiUrlTemplate,
        this.dynamicApiParams, // NEW
      });
}

// NEW EVENT FOR PRINTING/DOCUMENT VIEWS
class FetchDocumentData extends ReportEvent {
  final String apiName; // The apiName to fetch details from (for potential default params)
  final String actionApiUrlTemplate; // The specific URL template for this action
  final Map<String, String> dynamicApiParams; // The dynamic parameters from the row

  FetchDocumentData({
    required this.apiName,
    required this.actionApiUrlTemplate,
    required this.dynamicApiParams,
  });
}

class FetchPickerOptions extends ReportEvent {
  // ... (remains the same) ...
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
  final List<Map<String, dynamic>> reportData; // For grid data
  final Map<String, dynamic>? documentData; // NEW: For single document data (e.g., print)
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
  final List<Map<String, dynamic>> actionsConfig;
  final String? error;

  ReportState({
    this.isLoading = false,
    this.reports = const [],
    this.fieldConfigs = const [],
    this.reportData = const [],
    this.documentData, // NEW: Initialized as null
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
  });

  ReportState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? reports,
    List<Map<String, dynamic>>? fieldConfigs,
    List<Map<String, dynamic>>? reportData,
    Map<String, dynamic>? documentData, // NEW: Add to copyWith
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
  }) {
    return ReportState(
      isLoading: isLoading ?? this.isLoading,
      reports: reports ?? this.reports,
      fieldConfigs: fieldConfigs ?? this.fieldConfigs,
      reportData: reportData ?? this.reportData,
      documentData: documentData, // Allow passing null to clear it
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
    on<FetchDocumentData>(_onFetchDocumentData); // NEW handler for document data
    on<FetchPickerOptions>(_onFetchPickerOptions);
    on<ResetReports>(_onResetReports);
  }

  // ... (LoadReports, UpdateParameter remain the same) ...

  Future<void> _onLoadReports(LoadReports event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final reports = await apiService.fetchDemoTable();
      emit(state.copyWith(isLoading: false, reports: reports));
      debugPrint('Bloc: Loaded ${reports.length} reports for selection.');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load reports: $e'));
      debugPrint('Bloc: LoadReports error: $e');
    }
  }

  // FetchApiDetails is primarily for the *main* report's parameter inputs
  Future<void> _onFetchApiDetails(FetchApiDetails event, Emitter<ReportState> emit) async {
    emit(state.copyWith(
      isLoading: true,
      error: null,
      selectedApiParameters: [],
      userParameterValues: {}, // Cleared here because this is for the MAIN report's parameters
      pickerOptions: {},
      selectedApiUrl: null,
      serverIP: null,
      userName: null,
      password: null,
      databaseName: null,
      actionsConfig: [],
      documentData: null, // Clear document data when fetching new API details
      reportData: [], // Clear report data when fetching new API details
      fieldConfigs: [], // Clear field configs when fetching new API details
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

      final List<Map<String, dynamic>> finalActionsConfig = event.actionsConfig;

      for (var param in fetchedParameters) {
        if (param['name'] != null) {
          String paramName = param['name'].toString();
          String paramValue = param['value']?.toString() ?? '';

          if ((param['type']?.toString().toLowerCase() == 'date') || (paramName.toLowerCase().contains('date') && paramValue.isNotEmpty)) {
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
        actionsConfig: finalActionsConfig,
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
    emit(state.copyWith(userParameterValues: updatedUserParams));
    debugPrint('Bloc: Updated parameter ${event.paramName} to: ${event.value}');
  }

  Future<void> _onFetchFieldConfigs(FetchFieldConfigs event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, reportData: [])); // Clear previous report data

    debugPrint('Bloc: FetchFieldConfigs: Starting for RecNo=${event.recNo}, apiName=${event.apiName}, reportLabel=${event.reportLabel}');
    debugPrint('Bloc: FetchFieldConfigs: Dynamic parameters provided for API call: ${event.dynamicApiParams}');

    try {
      final fieldConfigs = await apiService.fetchDemoTable2(event.recNo);

      final apiResponse = await apiService.fetchApiDataWithParams(
        event.apiName,
        // CRITICAL FIX: Use event.dynamicApiParams if provided (from action button),
        // otherwise use state.userParameterValues (for main report).
        event.dynamicApiParams ?? state.userParameterValues,
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
        fieldConfigs: fieldConfigs,
        reportData: reportData,
        selectedRecNo: event.recNo,
        selectedApiName: event.apiName,
        selectedReportLabel: event.reportLabel,
        error: errorMessage,
        documentData: null, // Ensure document data is null when fetching grid data
      );
      emit(newState);
      debugPrint('Bloc: FetchFieldConfigs success.');
    } catch (e) {
      // Fallback to fetch field configs even if main data fetch fails
      List<Map<String, dynamic>> fieldConfigsFallback = [];
      try {
        fieldConfigsFallback = await apiService.fetchDemoTable2(event.recNo);
      } catch (e2) {
        debugPrint('Bloc: Error fetching field configs fallback: $e2');
      }

      final newState = state.copyWith(
        isLoading: false,
        fieldConfigs: fieldConfigsFallback,
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

  // NEW HANDLER FOR PRINT/DOCUMENT DATA
  Future<void> _onFetchDocumentData(FetchDocumentData event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, documentData: null)); // Clear previous document data

    debugPrint('Bloc: FetchDocumentData: Starting for API=${event.apiName}, URL=${event.actionApiUrlTemplate}');
    debugPrint('Bloc: FetchDocumentData: Dynamic parameters for API call: ${event.dynamicApiParams}');

    try {
      final apiResponse = await apiService.fetchApiDataWithParams(
        event.apiName, // Use the action's configured API name (e.g., sp_GetSaleOrderPrint)
        event.dynamicApiParams, // Use the specific dynamic parameters from the row
        actionApiUrlTemplate: event.actionApiUrlTemplate, // Use the specific URL template for this action
      );

      Map<String, dynamic>? fetchedDocumentData;
      String? errorMessage;

      if (apiResponse['status'] == 200) {
        // The API returns a List of Maps for both grid and document data.
        // For document, we expect a single item in the list, or we take the first.
        final List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(apiResponse['data'] ?? []);
        if (rawData.isNotEmpty) {
          fetchedDocumentData = rawData.first; // Take the first item for a single document view
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
    // Only fetch if options aren't already loaded for this parameter
    if (state.pickerOptions.containsKey(event.paramName) && state.pickerOptions[event.paramName]!.isNotEmpty) {
      return;
    }

    emit(state.copyWith(isLoading: true, error: null));
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
    final newState = ReportState(actionsConfig: []); // Reset to a clean state, retaining no actions config
    emit(newState);
    debugPrint('Bloc: ResetReports: State reset.');
  }
}