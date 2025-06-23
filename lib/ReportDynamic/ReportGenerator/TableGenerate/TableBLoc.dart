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
  final List<Map<String, dynamic>> actionsConfig;
  final String? error;
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
    this.serverIP,
    this.userName,
    this.password,
    this.databaseName,
    this.actionsConfig = const [],
    this.error,
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
    String? serverIP,
    String? userName,
    String? password,
    String? databaseName,
    List<Map<String, dynamic>>? actionsConfig,
    String? error,
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
      serverIP: serverIP ?? this.serverIP,
      userName: userName ?? this.userName,
      password: password ?? this.password,
      databaseName: databaseName ?? this.databaseName,
      actionsConfig: actionsConfig ?? this.actionsConfig,
      error: error,
      includePdfFooterDateTime: includePdfFooterDateTime ?? this.includePdfFooterDateTime,
    );
  }
}

// --- BLoC Implementation ---
class TableBlocGenerate extends Bloc<ReportEvent, ReportState> {
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
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load reports: $e'));
    }
  }

  // This event handler is now mostly for the main report selection screen, not the table view.
  Future<void> _onFetchApiDetails(FetchApiDetails event, Emitter<ReportState> emit) async {
    emit(state.copyWith(
      isLoading: true, error: null, selectedApiParameters: [],
      userParameterValues: {}, pickerOptions: {}, selectedApiUrl: null,
      serverIP: null, userName: null, password: null, databaseName: null,
      documentData: null, actionsConfig: [], includePdfFooterDateTime: false,
    ));
    try {
      final apiDetails = await apiService.getApiDetails(event.apiName);
      List<Map<String, dynamic>> fetchedParameters = List<Map<String, dynamic>>.from(apiDetails['parameters'] ?? []);
      final Map<String, String> initialUserParameterValues = {};
      final String? serverIP = apiDetails['serverIP']?.toString();
      final String? userName = apiDetails['userName']?.toString();
      final String? password = apiDetails['password']?.toString();
      final String? databaseName = apiDetails['databaseName']?.toString();
      List<Map<String, dynamic>> fetchedActions = List<Map<String, dynamic>>.from(apiDetails['actions_config'] ?? []);
      final bool fetchedIncludePdfFooterDateTime = apiDetails['includePdfFooterDateTime'] ?? false;

      for (var param in fetchedParameters) {
        if (param['name'] != null) {
          String paramName = param['name'].toString();
          String paramValue = param['value']?.toString() ?? '';
          if ((param['type']?.toString().toLowerCase() == 'date') && paramValue.isNotEmpty) {
            try {
              paramValue = DateFormat('dd-MMM-yyyy').format(DateTime.parse(paramValue));
            } catch (e) { /* Ignore parsing errors for default values */ }
          }
          initialUserParameterValues[paramName] = paramValue;
        }
      }

      emit(state.copyWith(
        isLoading: false, selectedApiUrl: apiDetails['url'], selectedApiParameters: fetchedParameters,
        userParameterValues: initialUserParameterValues, serverIP: serverIP, userName: userName, password: password,
        databaseName: databaseName, actionsConfig: fetchedActions, includePdfFooterDateTime: fetchedIncludePdfFooterDateTime,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to fetch API details: $e'));
    }
  }

  void _onUpdateParameter(UpdateParameter event, Emitter<ReportState> emit) {
    final updatedUserParams = Map<String, String>.from(state.userParameterValues);
    updatedUserParams[event.paramName] = event.value;
    emit(state.copyWith(userParameterValues: updatedUserParams));
  }

  // #######################################################
  // #                  START OF FINAL FIX                   #
  // #######################################################
  // This is now the single, consolidated handler for loading a Table View.
  Future<void> _onFetchFieldConfigs(FetchFieldConfigs event, Emitter<ReportState> emit) async {
    // 1. Set loading state and clear previous data AT THE START.
    emit(state.copyWith(
      isLoading: true,
      error: null,
      reportData: [],
      fieldConfigs: [],
      actionsConfig: [],
      documentData: null,
    ));

    try {
      // 2. Fetch API details (for actions, etc.) AND field configurations concurrently.
      final results = await Future.wait([
        apiService.getApiDetails(event.apiName),
        apiService.fetchDemoTable2(event.recNo),
      ]);

      final apiDetails = results[0] as Map<String, dynamic>;
      final fieldConfigs = results[1] as List<Map<String, dynamic>>;

      // Extract actions and footer setting from API details
      final fetchedActions = List<Map<String, dynamic>>.from(apiDetails['actions_config'] ?? []);
      final fetchedIncludePdfFooterDateTime = apiDetails['includePdfFooterDateTime'] ?? false;
      debugPrint('TableBloc (Consolidated): API "${event.apiName}" returned ${fetchedActions.length} actions.');

      // 3. Fetch the actual report data using the provided parameters.
      final apiResponse = await apiService.fetchApiDataWithParams(
        event.apiName,
        event.dynamicApiParams ?? state.userParameterValues,
        actionApiUrlTemplate: event.actionApiUrlTemplate,
      );

      List<Map<String, dynamic>> reportData = [];
      String? errorMessage;

      if (apiResponse['status'] == 200) {
        reportData = List<Map<String, dynamic>>.from(apiResponse['data'] ?? []);
        debugPrint('TableBloc (Consolidated): Fetched ${reportData.length} rows for grid report.');
      } else {
        errorMessage = apiResponse['error'] ?? 'API Error: Could not fetch report data.';
        debugPrint('TableBloc (Consolidated): API response status not 200: $errorMessage');
      }

      // 4. Emit a SINGLE final state with all data populated and isLoading set to false.
      emit(state.copyWith(
        isLoading: false,
        fieldConfigs: fieldConfigs,
        reportData: reportData,
        actionsConfig: fetchedActions, // Set actions from API details
        includePdfFooterDateTime: fetchedIncludePdfFooterDateTime,
        selectedRecNo: event.recNo,
        selectedApiName: event.apiName,
        selectedReportLabel: event.reportLabel,
        error: errorMessage,
      ));
      debugPrint('TableBloc (Consolidated): FetchFieldConfigs success.');

    } catch (e) {
      debugPrint('TableBloc (Consolidated): FetchFieldConfigs Error: $e');
      emit(state.copyWith(
        isLoading: false,
        reportData: [],
        fieldConfigs: [],
        error: 'Failed to load report: $e',
      ));
    }
  }
  // #######################################################
  // #                   END OF FINAL FIX                    #
  // #######################################################


  Future<void> _onFetchDocumentData(FetchDocumentData event, Emitter<ReportState> emit) async {
    // This handler remains the same
    emit(state.copyWith(isLoading: true, error: null, documentData: null));
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
        } else {
          errorMessage = 'No data returned for document view.';
        }
      } else {
        errorMessage = apiResponse['error'] ?? 'Unexpected error occurred.';
      }
      emit(state.copyWith(isLoading: false, documentData: fetchedDocumentData, error: errorMessage));
    } catch (e) {
      emit(state.copyWith(isLoading: false, documentData: null, error: 'Failed to fetch document data: $e'));
    }
  }

  Future<void> _onFetchPickerOptions(FetchPickerOptions event, Emitter<ReportState> emit) async {
    // This handler remains the same
    if (state.pickerOptions.containsKey(event.paramName) && state.pickerOptions[event.paramName]!.isNotEmpty) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final List<Map<String, dynamic>> fetchedData = await apiService.fetchPickerData(
        server: event.serverIP, UID: event.userName, PWD: event.password,
        database: event.databaseName, masterTable: event.masterTable,
        masterField: event.masterField, displayField: event.displayField,
      );
      final List<Map<String, String>> mappedOptions = fetchedData.map((item) => {
        'value': item[event.masterField]?.toString() ?? '',
        'label': item[event.displayField]?.toString() ?? '',
      }).toList();
      final updatedPickerOptions = Map<String, List<Map<String, String>>>.from(state.pickerOptions);
      updatedPickerOptions[event.paramName] = mappedOptions;
      emit(state.copyWith(isLoading: false, pickerOptions: updatedPickerOptions, error: null));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load options for ${event.paramName}: $e'));
    }
  }

  void _onResetReports(ResetReports event, Emitter<ReportState> emit) {
    // This handler remains the same
    emit(state.copyWith(
      isLoading: false, fieldConfigs: [], reportData: [], documentData: null,
      selectedRecNo: null, selectedApiName: null, selectedReportLabel: null,
      selectedApiUrl: null, selectedApiParameters: [], userParameterValues: {},
      pickerOptions: {}, serverIP: null, userName: null, password: null,
      databaseName: null, actionsConfig: [], includePdfFooterDateTime: false, error: null,
    ));
  }
}