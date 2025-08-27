// lib/ReportDynamic/ReportGenerator/Reportbloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../ReportAPIService.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:collection/collection.dart'; // For firstWhereOrNull

// --- Events ---
abstract class ReportEvent {}

class LoadReports extends ReportEvent {}

class StartPreselectedReportChain extends ReportEvent {
  final Map<String, dynamic> reportDefinition;
  final Map<String, String> initialParameters;
  StartPreselectedReportChain(this.reportDefinition, this.initialParameters);
}

// MODIFIED: Added reportSelectionPayload for chaining from the UI
class FetchApiDetails extends ReportEvent {
  final String apiName;
  final List<Map<String, dynamic>> actionsConfig;
  final bool includePdfFooterDateTimeFromReportMetadata;
  final StartPreselectedReportChain? chainPayload;
  final Map<String, dynamic>? reportSelectionPayload; // NEW PAYLOAD

  FetchApiDetails(
      this.apiName,
      this.actionsConfig, {
        this.includePdfFooterDateTimeFromReportMetadata = false,
        this.chainPayload,
        this.reportSelectionPayload, // NEW
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

// =========================================================================
// == START: NEW EVENT FOR DYNAMIC DATABASE TRANSFER
// =========================================================================
class TransferReportToDatabase extends ReportEvent {
  final Map<String, dynamic> reportMetadata;
  final List<Map<String, dynamic>> fieldConfigs;
  final String targetServerIP;
  final String targetUserName;
  final String targetPassword;
  final String targetDatabaseName;
  final String targetConnectionString;

  TransferReportToDatabase({
    required this.reportMetadata,
    required this.fieldConfigs,
    required this.targetServerIP,
    required this.targetUserName,
    required this.targetPassword,
    required this.targetDatabaseName,
    required this.targetConnectionString,
  });
}
// =========================================================================
// == END: NEW EVENT
// =========================================================================


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
    on<TransferReportToDatabase>(_onTransferReportToDatabase); // ADDED
  }

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

    add(FetchApiDetails(
      apiName,
      actionsConfig,
      includePdfFooterDateTimeFromReportMetadata: includePdfFooter,
      chainPayload: event,
    ));
  }

  // =========== MODIFICATION STARTS HERE: Corrected logic with extensive logging ===========
  Future<void> _onLoadReports(LoadReports event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, successMessage: null));
    try {
      // 1. Fetch the initial list of reports.
      final reports = await apiService.fetchDemoTable();
      if (reports.isEmpty) {
        emit(state.copyWith(isLoading: false, reports: []));
        debugPrint('Bloc: No reports found.');
        return;
      }

      // 2. Get a unique list of API names from the reports to avoid duplicate calls.
      final Set<String> apiNames = reports
          .map((report) => report['API_name']?.toString())
          .whereType<String>()
          .where((apiName) => apiName.isNotEmpty)
          .toSet();

      debugPrint('Bloc: Found ${apiNames.length} unique API names to fetch details for: $apiNames');

      // 3. Fetch all API details concurrently.
      // We map each name to a future that will return a map containing BOTH the original name and its details.
      final apiDetailsFutures = apiNames.map((name) async {
        try {
          final details = await apiService.getApiDetails(name);
          // IMPORTANT: Combine the original name with the fetched details to avoid losing the link.
          return {'originalApiName': name, ...details};
        } catch (e) {
          debugPrint("Bloc: Could not fetch details for '$name', it will be skipped. Error: $e");
          // Return at least the name on error so we know which one failed.
          return {'originalApiName': name};
        }
      });
      final allApiDetailsList = await Future.wait(apiDetailsFutures);

      // 4. Create a lookup map from API name to Database name.
      debugPrint('Bloc: Building API-to-Database map...');
      final Map<String, String> apiToDbNameMap = {};
      for (var details in allApiDetailsList) {
        // Use the original name we explicitly saved.
        final apiName = details['originalApiName']?.toString();
        final dbName = details['databaseName']?.toString();

        if (apiName != null && dbName != null) {
          apiToDbNameMap[apiName] = dbName;
          debugPrint("Bloc: Mapped '$apiName' -> '$dbName'");
        } else {
          debugPrint("Bloc: Could not create mapping for '$apiName' (DB name was null).");
        }
      }
      debugPrint('Bloc: Finished building map. Mapped ${apiToDbNameMap.length} items.');

      // 5. Enrich the original reports list with the database name.
      final List<Map<String, dynamic>> enrichedReports = reports.map((report) {
        final apiName = report['API_name']?.toString();
        // Look up using the report's API name.
        final dbName = apiToDbNameMap[apiName];
        // Return a new map with the added DatabaseName key. It will be null if not found.
        return {...report, 'DatabaseName': dbName};
      }).toList();

      if (enrichedReports.isNotEmpty) {
        debugPrint("Bloc: Sample of first enriched report: ${jsonEncode(enrichedReports.first)}");
      }

      emit(state.copyWith(isLoading: false, reports: enrichedReports));
      debugPrint('Bloc: Loaded and enriched ${enrichedReports.length} reports with database names.');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load reports: $e'));
      debugPrint('Bloc: LoadReports error: $e');
    }
  }
  // =========== MODIFICATION ENDS HERE ===========


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

      debugPrint('Bloc: [_onFetchApiDetails] - Determined final actionsConfig to use: ${jsonEncode(finalActionsConfig)}');

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

      // ========== START: FIX FOR MISSING PICKER OPTIONS ==========
      // Proactively fetch picker options as soon as the parameters and DB details are known.
      // This solves the problem where ResetReports clears pickerOptions and they aren't re-fetched.
      debugPrint('Bloc: [_onFetchApiDetails] - Proactively checking for and fetching picker options...');
      if (serverIP != null && userName != null && password != null && databaseName != null) {
        for (var param in fetchedParameters) {
          final String paramName = param['name']?.toString() ?? '';
          final String configType = param['config_type']?.toString().toLowerCase() ?? '';
          final String? masterTable = param['master_table']?.toString();

          if (configType == 'database' && masterTable != null && masterTable.isNotEmpty) {
            debugPrint('Bloc: -> Found database picker for "$paramName". Dispatching FetchPickerOptions.');
            // 'add' dispatches a new event for the BLoC to process.
            add(FetchPickerOptions(
              paramName: paramName,
              serverIP: serverIP,
              userName: userName,
              password: password,
              databaseName: databaseName,
              masterTable: masterTable,
              masterField: param['master_field'].toString(),
              displayField: param['display_field'].toString(),
            ));
          }
        }
      } else {
        debugPrint('Bloc: [_onFetchApiDetails] - Skipping picker options fetch because database connection details are missing.');
      }
      // ========== END: FIX FOR MISSING PICKER OPTIONS ==========


      if (event.chainPayload != null) {
        initialUserParameterValues.addAll(event.chainPayload!.initialParameters);
      }

      // Determine what to set in the state based on the event payload type
      String? recNo, reportLabel;
      if (event.chainPayload != null) {
        recNo = event.chainPayload!.reportDefinition['RecNo']?.toString();
        reportLabel = event.chainPayload!.reportDefinition['Report_label']?.toString();
      } else if (event.reportSelectionPayload != null) {
        recNo = event.reportSelectionPayload!['RecNo']?.toString();
        reportLabel = event.reportSelectionPayload!['Report_label']?.toString();
      }

      debugPrint('Bloc: [_onFetchApiDetails] - Preparing to emit state with:');
      debugPrint('  - selectedApiName: ${event.apiName}');
      debugPrint('  - selectedRecNo: $recNo');
      debugPrint('  - selectedReportLabel: $reportLabel');
      debugPrint('  - actionsConfig count: ${finalActionsConfig.length}');
      debugPrint('  - initialUserParameterValues count: ${initialUserParameterValues.length}');

      emit(state.copyWith(
        isLoading: false, // Will be set to true again by FetchFieldConfigs
        selectedApiUrl: apiDetails['url'],
        selectedApiParameters: fetchedParameters,
        userParameterValues: initialUserParameterValues,
        serverIP: serverIP,
        userName: userName,
        password: password,
        databaseName: databaseName,
        actionsConfig: finalActionsConfig,
        error: null,
        selectedApiName: event.apiName,
        selectedRecNo: recNo,
        selectedReportLabel: reportLabel,
        includePdfFooterDateTime: event.includePdfFooterDateTimeFromReportMetadata,
      ));
      debugPrint('Bloc: [_onFetchApiDetails] - State emitted. Now checking for chaining.');

      // --- MODIFIED CHAINING LOGIC ---
      if (event.chainPayload != null) {
        final chainEvent = event.chainPayload!;
        debugPrint('Bloc: [_onFetchApiDetails] - Chaining FetchFieldConfigs for pre-selected report.');
        add(FetchFieldConfigs(
          chainEvent.reportDefinition['RecNo'].toString(),
          chainEvent.reportDefinition['API_name'].toString(),
          chainEvent.reportDefinition['Report_label'].toString(),
          dynamicApiParams: state.userParameterValues,
        ));
      } else if (event.reportSelectionPayload != null) { // CHAIN FROM UI SELECTION
        final selection = event.reportSelectionPayload!;
        debugPrint('Bloc: [_onFetchApiDetails] - Chaining FetchFieldConfigs from UI selection for RecNo: ${selection['RecNo']}');
        add(FetchFieldConfigs(
          selection['RecNo'].toString(),
          selection['API_name'].toString(),
          selection['Report_label'].toString(),
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

    debugPrint('Bloc: [_onFetchFieldConfigs] - START for RecNo=${event.recNo}, apiName=${event.apiName}');
    debugPrint('Bloc: [_onFetchFieldConfigs] - Dynamic parameters for API call: ${event.dynamicApiParams}');

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

      debugPrint('Bloc: [_onFetchFieldConfigs] - Fetched ${fieldConfigs.length} field configs.');
      debugPrint('Bloc: [_onFetchFieldConfigs] - Fetched grid data API response status: ${apiResponse['status']}');

      List<Map<String, dynamic>> reportData = [];
      String? errorMessage;

      if (apiResponse['status'] == 200) {
        reportData = List<Map<String, dynamic>>.from(apiResponse['data'] ?? []);
        debugPrint('Bloc: [_onFetchFieldConfigs] - Fetched ${reportData.length} rows for grid report.');
      } else {
        errorMessage = apiResponse['error'] ?? 'Unexpected error occurred.';
        debugPrint('Bloc: [_onFetchFieldConfigs] - API response status not 200 for grid report: $errorMessage');
      }

      debugPrint('Bloc: [_onFetchFieldConfigs] - Preparing to emit final state with:');
      debugPrint('  - isLoading: false');
      debugPrint('  - fieldConfigs count: ${fieldConfigs.length}');
      debugPrint('  - reportData count: ${reportData.length}');
      debugPrint('  - error: $errorMessage');

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
      debugPrint('Bloc: [_onFetchFieldConfigs] - SUCCESS. State emitted with field configs.');
    } catch (e) {
      debugPrint('Bloc: [_onFetchFieldConfigs] - ERROR: $e');
      emit(state.copyWith(isLoading: false, error: 'Failed to fetch field configs: $e'));
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
    // Note: Do not emit isLoading: true here, as it's a background task that shouldn't block the whole UI
    try {
      debugPrint('Bloc: Fetching picker values for param: ${event.paramName}, masterTable: ${event.masterTable}, masterField: ${event.masterField}, displayField: ${event.displayField}');
      final List<Map<String, dynamic>> fetchedData = await apiService.fetchPickerData(
        server: event.serverIP,
        UID: event.userName,
        PWD: event.password,
        database: event.databaseName,
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
      emit(state.copyWith(pickerOptions: updatedPickerOptions, error: null));
      debugPrint('Bloc: FetchPickerOptions success for ${event.paramName}.');
    } catch (e) {
      emit(state.copyWith(error: 'Failed to load options for ${event.paramName}: $e'));
      debugPrint('Bloc: Error fetching picker options for ${event.paramName}: $e');
    }
  }

  void _onResetReports(ResetReports event, Emitter<ReportState> emit) {
    emit(ReportState(
      reports: state.reports,
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
    debugPrint('\n--- Bloc: [_onDeployReportToClient] - START ---');
    debugPrint('Received clientApiName: ${event.clientApiName}');
    debugPrint('Received reportMetadata: ${jsonEncode(event.reportMetadata)}');
    debugPrint('Received fieldConfigs count: ${event.fieldConfigs.length}');
    if (event.fieldConfigs.isEmpty) {
      debugPrint('!! WARNING: fieldConfigs list is EMPTY. Deployment will likely fail or be incorrect.');
    }

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
    } finally {
      debugPrint('--- Bloc: [_onDeployReportToClient] - END ---\n');
    }
  }

  // =========================================================================
  // == START: NEW HANDLER FOR DYNAMIC DATABASE TRANSFER
  // =========================================================================
  Future<void> _onTransferReportToDatabase(TransferReportToDatabase event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, successMessage: null));
    debugPrint('\n--- Bloc: [_onTransferReportToDatabase] - START ---');
    debugPrint('Target DB: ${event.targetDatabaseName} @ ${event.targetServerIP}');
    debugPrint('Received reportMetadata: ${jsonEncode(event.reportMetadata)}');
    debugPrint('Received fieldConfigs count: ${event.fieldConfigs.length}');

    try {
      final response = await apiService.transferReportToDatabase(
        reportMetadata: event.reportMetadata,
        fieldConfigs: event.fieldConfigs,
        targetServerIP: event.targetServerIP,
        targetUserName: event.targetUserName,
        targetPassword: event.targetPassword,
        targetDatabaseName: event.targetDatabaseName,
        targetConnectionString: event.targetConnectionString,
      );

      if (response['status'] == 'success') {
        emit(state.copyWith(
          isLoading: false,
          successMessage: response['message'] ?? 'Report transferred successfully!',
          error: null,
        ));
        debugPrint('Bloc: Report transferred successfully: ${response['message']}');
      } else {
        emit(state.copyWith(
          isLoading: false,
          error: response['message'] ?? 'Failed to transfer report.',
          successMessage: null,
        ));
        debugPrint('Bloc: Report transfer failed: ${response['message']}');
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to transfer report: $e',
        successMessage: null,
      ));
      debugPrint('Bloc: TransferReportToDatabase error: $e');
    } finally {
      debugPrint('--- Bloc: [_onTransferReportToDatabase] - END ---\n');
    }
  }

}