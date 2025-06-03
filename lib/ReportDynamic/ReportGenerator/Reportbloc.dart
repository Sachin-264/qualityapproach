// Reportbloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../ReportAPIService.dart';

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
  final String? actionApiUrlTemplate; // NEW: Add the URL template here

  FetchFieldConfigs(this.recNo, this.apiName, this.reportLabel, {this.actionApiUrlTemplate}); // Update constructor
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

class ReportState {
  final bool isLoading;
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> fieldConfigs;
  final List<Map<String, dynamic>> reportData;
  final String? selectedRecNo;
  final String? selectedApiName;
  final String? selectedReportLabel;
  final String? selectedApiUrl; // This is the base URL from database_server config
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
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load reports: $e'));
      print('Bloc: LoadReports error: $e');
    }
  }

  Future<void> _onFetchApiDetails(FetchApiDetails event, Emitter<ReportState> emit) async {
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
      actionsConfig: [],
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
              print('Bloc: Warning: Failed to parse initial date parameter $paramName: $paramValue. Error: $e');
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
      print('Bloc: FetchApiDetails success for API: ${event.apiName}. Actions Config loaded: ${finalActionsConfig.isNotEmpty ? finalActionsConfig.length : 'empty'} items.');
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to fetch API details: $e'));
      print('Bloc: FetchApiDetails error: $e');
    }
  }

  void _onUpdateParameter(UpdateParameter event, Emitter<ReportState> emit) {
    final updatedUserParams = Map<String, String>.from(state.userParameterValues);
    updatedUserParams[event.paramName] = event.value;
    emit(state.copyWith(userParameterValues: updatedUserParams));
  }

  Future<void> _onFetchFieldConfigs(FetchFieldConfigs event, Emitter<ReportState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    print('Bloc: FetchFieldConfigs: Starting for RecNo=${event.recNo}, apiName=${event.apiName}, reportLabel=${event.reportLabel}');
    try {
      final fieldConfigs = await apiService.fetchDemoTable2(event.recNo);

      // MODIFIED: Pass the actionApiUrlTemplate if it exists
      final apiResponse = await apiService.fetchApiDataWithParams(
        event.apiName,
        state.userParameterValues,
        actionApiUrlTemplate: event.actionApiUrlTemplate, // Pass the template
      );
      List<Map<String, dynamic>> reportData = [];
      String? errorMessage;

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
    } catch (e) {
      List<Map<String, dynamic>> fieldConfigsFallback = [];
      try {
        fieldConfigsFallback = await apiService.fetchDemoTable2(event.recNo);
      } catch (e2) {
        print('Bloc: Error fetching field configs fallback: $e2');
      }

      final newState = state.copyWith(
        isLoading: false,
        fieldConfigs: fieldConfigsFallback,
        reportData: [],
        selectedRecNo: event.recNo,
        selectedApiName: event.apiName,
        selectedReportLabel: event.reportLabel,
        error: e.toString().contains('TimeoutException')
            ? 'API request timed out after multiple attempts. Please check your network or try again later.'
            : 'Failed to fetch report data: $e',
      );
      emit(newState);
      print('Bloc: FetchFieldConfigs: Error, error=$e');
    }
  }

  Future<void> _onFetchPickerOptions(FetchPickerOptions event, Emitter<ReportState> emit) async {
    if (state.pickerOptions.containsKey(event.paramName) && state.pickerOptions[event.paramName]!.isNotEmpty) {
      return;
    }

    emit(state.copyWith(isLoading: true, error: null));
    try {
      print('Bloc: Fetching picker values for param: ${event.paramName}, masterTable: ${event.masterTable}, masterField: ${event.masterField}, displayField: ${event.displayField}');
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
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load options for ${event.paramName}: $e'));
      print('Bloc: Error fetching picker options for ${event.paramName}: $e');
    }
  }

  void _onResetReports(ResetReports event, Emitter<ReportState> emit) {
    final newState = ReportState(actionsConfig: []);
    emit(newState);
    print('Bloc: ResetReports: State reset.');
  }
}