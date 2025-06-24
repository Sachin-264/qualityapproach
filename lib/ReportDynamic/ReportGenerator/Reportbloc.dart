import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../ReportAPIService.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

// --- Events ---
abstract class ReportEvent {}

class LoadReports extends ReportEvent {}

// We make this event public so the loader can dispatch it.
class StartPreselectedReportChain extends ReportEvent {
  final Map<String, dynamic> reportDefinition;
  final Map<String, String> initialParameters;
  StartPreselectedReportChain(this.reportDefinition, this.initialParameters);
}

// MODIFIED to carry the optional payload for chaining.
class FetchApiDetails extends ReportEvent {
  final String apiName;
  final List<Map<String, dynamic>> actionsConfig;
  final bool includePdfFooterDateTimeFromReportMetadata;
  final StartPreselectedReportChain? chainPayload; // The special payload

  FetchApiDetails(
      this.apiName,
      this.actionsConfig, {
        this.includePdfFooterDateTimeFromReportMetadata = false,
        this.chainPayload, // Make it an optional named parameter
      });
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

class DeployReportToClient extends ReportEvent {
  final Map<String, dynamic> reportMetadata;
  final List<Map<String, dynamic>> fieldConfigs;
  final String clientApiName;

  DeployReportToClient({
    required this.reportMetadata,
    required this.fieldConfigs,
    required this.clientApiName,
  });
}


// --- State (No changes needed) ---
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
  final Map<String, List<String>> apiDrivenFieldOptions;
  final String? serverIP;
  final String? userName;
  final String? password;
  final String? databaseName;
  final List<Map<String, dynamic>> actionsConfig;
  final String? error;
  final String? successMessage;
  final bool includePdfFooterDateTime;

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
    this.apiDrivenFieldOptions = const {},
    this.serverIP,
    this.userName,
    this.password,
    this.databaseName,
    this.actionsConfig = const [],
    this.error,
    this.successMessage,
    this.includePdfFooterDateTime = false,
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
    Map<String, List<String>>? apiDrivenFieldOptions,
    String? serverIP,
    String? userName,
    String? password,
    String? databaseName,
    List<Map<String, dynamic>>? actionsConfig,
    String? error,
    String? successMessage,
    bool? includePdfFooterDateTime,
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
      apiDrivenFieldOptions: apiDrivenFieldOptions ?? this.apiDrivenFieldOptions,
      serverIP: serverIP ?? this.serverIP,
      userName: userName ?? this.userName,
      password: password ?? this.password,
      databaseName: databaseName ?? this.databaseName,
      actionsConfig: actionsConfig ?? this.actionsConfig,
      error: error,
      successMessage: successMessage,
      includePdfFooterDateTime: includePdfFooterDateTime ?? this.includePdfFooterDateTime,
    );
  }
}

// --- BLoC Implementation ---
class ReportBlocGenerate extends Bloc<ReportEvent, ReportState> {
  final ReportAPIService apiService;

  ReportBlocGenerate(this.apiService) : super(ReportState()) {
    on<StartPreselectedReportChain>(_onStartPreselectedReportChain);
    on<LoadReports>(_onLoadReports);
    on<FetchApiDetails>(_onFetchApiDetails);
    on<UpdateParameter>(_onUpdateParameter);
    on<FetchFieldConfigs>(_onFetchFieldConfigs);
    on<FetchDocumentData>(_onFetchDocumentData);
    on<FetchPickerOptions>(_onFetchPickerOptions);
    on<ResetReports>(_onResetReports);
    on<DeployReportToClient>(_onDeployReportToClient);
  }

  // This new handler starts the sequence.
  void _onStartPreselectedReportChain(StartPreselectedReportChain event, Emitter<ReportState> emit) {
    add(ResetReports());

    final String apiName = event.reportDefinition['API_name'].toString();
    List<Map<String, dynamic>> actionsConfig = [];
    final dynamic rawActions = event.reportDefinition['actions_config'];
    if (rawActions is String && rawActions.isNotEmpty) {
      try {
        actionsConfig = List<Map<String, dynamic>>.from(jsonDecode(rawActions));
      } catch (e) { /* ignore */ }
    } else if (rawActions is List) {
      actionsConfig = List<Map<String, dynamic>>.from(rawActions);
    }
    final bool includePdfFooter = event.reportDefinition['pdf_footer_datetime'] == true;

    // Dispatch the first event and pass the original event as a payload.
    add(FetchApiDetails(
      apiName,
      actionsConfig,
      includePdfFooterDateTimeFromReportMetadata: includePdfFooter,
      chainPayload: event, // Pass the payload
    ));
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

  Future<void> _onFetchApiDetails(FetchApiDetails event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final apiDetails = await apiService.getApiDetails(event.apiName);

      List<Map<String, dynamic>> fetchedParameters = List<Map<String, dynamic>>.from(apiDetails['parameters'] ?? []);
      final Map<String, String> initialUserParameterValues = {};
      final String? serverIP = apiDetails['serverIP']?.toString();
      final String? userName = apiDetails['userName']?.toString();
      final String? password = apiDetails['password']?.toString();
      final String? databaseName = apiDetails['databaseName']?.toString();
      List<Map<String, dynamic>> finalActionsConfig = List<Map<String, dynamic>>.from(apiDetails['actions_config'] ?? []);

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

      // If we have a payload, override default params with initial params from the dashboard.
      if (event.chainPayload != null) {
        initialUserParameterValues.addAll(event.chainPayload!.initialParameters);
      }

      emit(state.copyWith(
        isLoading: false,
        selectedApiUrl: apiDetails['url'],
        selectedApiParameters: fetchedParameters,
        userParameterValues: initialUserParameterValues,
        serverIP: serverIP,
        userName: userName,
        password: password,
        databaseName: databaseName,
        actionsConfig: finalActionsConfig,
        error: null,
        // Also set these from the report definition when chaining
        selectedApiName: event.chainPayload?.reportDefinition['API_name']?.toString() ?? event.apiName,
        selectedRecNo: event.chainPayload?.reportDefinition['RecNo']?.toString(),
        selectedReportLabel: event.chainPayload?.reportDefinition['Report_label']?.toString(),
        includePdfFooterDateTime: event.includePdfFooterDateTimeFromReportMetadata,
      ));
      debugPrint('Bloc: FetchApiDetails success for API: ${event.apiName}.');

      // --- THE CHAINING LOGIC ---
      // If a payload exists, it means we are in the pre-selected flow.
      // Now that API details are loaded, we can dispatch the next event.
      if (event.chainPayload != null) {
        final chainEvent = event.chainPayload!;
        add(FetchFieldConfigs(
          chainEvent.reportDefinition['RecNo'].toString(),
          chainEvent.reportDefinition['API_name'].toString(),
          chainEvent.reportDefinition['Report_label'].toString(),
          dynamicApiParams: state.userParameterValues, // Use the fresh state
        ));
      }

    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to fetch API details: $e'));
      debugPrint('Bloc: FetchApiDetails error: $e');
    }
  }

  Future<void> _onFetchFieldConfigs(FetchFieldConfigs event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, successMessage: null));

    debugPrint('Bloc: FetchFieldConfigs: Starting for RecNo=${event.recNo}, apiName=${event.apiName}, reportLabel=${event.reportLabel}');
    debugPrint('Bloc: FetchFieldConfigs: Dynamic parameters provided for API call: ${event.dynamicApiParams}');

    try {
      final results = await Future.wait([
        apiService.fetchDemoTable2(event.recNo),
        apiService.fetchApiDataWithParams(
          event.apiName,
          event.dynamicApiParams ?? state.userParameterValues,
          actionApiUrlTemplate: event.actionApiUrlTemplate,
        ),
      ]);

      final fieldConfigs = results[0] as List<Map<String, dynamic>>;
      final apiResponse = results[1] as Map<String, dynamic>;

      List<Map<String, dynamic>> reportData = [];
      String? errorMessage;

      if (apiResponse['status'] == 200) {
        reportData = List<Map<String, dynamic>>.from(apiResponse['data'] ?? []);
        debugPrint('Bloc: Fetched ${reportData.length} rows for grid report.');
      } else {
        errorMessage = apiResponse['error'] ?? 'Unexpected error occurred.';
        debugPrint('Bloc: API response status not 200 for grid report: $errorMessage');
      }

      emit(state.copyWith(
        isLoading: false,
        fieldConfigs: fieldConfigs,
        reportData: reportData,
        selectedRecNo: event.recNo,
        selectedApiName: event.apiName,
        selectedReportLabel: event.reportLabel,
        error: errorMessage,
        apiDrivenFieldOptions: {},
      ));
      debugPrint('Bloc: FetchFieldConfigs success. Emitted state with ${fieldConfigs.length} field configs.');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to fetch field configs: $e'));
      debugPrint('Bloc: FetchFieldConfigs error: $e');
    }
  }



  void _onUpdateParameter(UpdateParameter event, Emitter<ReportState> emit) {
    final updatedUserParams = Map<String, String>.from(state.userParameterValues);
    updatedUserParams[event.paramName] = event.value;
    emit(state.copyWith(userParameterValues: updatedUserParams, successMessage: null, error: null));
    debugPrint('Bloc: Updated parameter ${event.paramName} to: ${event.value}');
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
      apiDrivenFieldOptions: {},
      serverIP: null,
      userName: null,
      password: null,
      databaseName: null,
      actionsConfig: [],
      includePdfFooterDateTime: false,
    ));
    debugPrint('Bloc: ResetReports: State reset (parameters, selected API, data cleared), but reports list preserved.');
  }

  Future<void> _onDeployReportToClient(DeployReportToClient event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, successMessage: null));
    debugPrint('Bloc: DeployReportToClient event received for report RecNo: ${event.reportMetadata['RecNo']}');
    try {
      final apiDetails = await apiService.getApiDetails(event.clientApiName);
      final String? clientServerIP = apiDetails['serverIP']?.toString();
      final String? clientUserName = apiDetails['userName']?.toString();
      final String? clientPassword = apiDetails['password']?.toString();
      final String? clientDatabaseName = apiDetails['databaseName']?.toString();
      if (clientServerIP == null || clientUserName == null || clientPassword == null || clientDatabaseName == null) {
        throw Exception('Client database credentials not found for API: ${event.clientApiName}');
      }
      final response = await apiService.deployReportToClient(
        reportMetadata: event.reportMetadata,
        fieldConfigs: event.fieldConfigs,
        clientServerIP: clientServerIP,
        clientUserName: clientUserName,
        clientPassword: clientPassword,
        clientDatabaseName: clientDatabaseName,
      );
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