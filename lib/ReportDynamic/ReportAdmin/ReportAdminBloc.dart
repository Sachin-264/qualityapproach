// lib/report_admin_feature/report_admin_bloc.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../ReportAPIService.dart'; // Ensure this path is correct
import 'dart:convert'; // For jsonDecode

// --- Events ---
class ReportAdminEvent {
  const ReportAdminEvent();
}

class UpdateServerIP extends ReportAdminEvent {
  final String serverIP;
  const UpdateServerIP(this.serverIP);
}

class UpdateUserName extends ReportAdminEvent {
  final String userName;
  const UpdateUserName(this.userName);
}

class UpdatePassword extends ReportAdminEvent {
  final String password;
  const UpdatePassword(this.password);
}

class UpdateDatabaseName extends ReportAdminEvent {
  final String databaseName;
  const UpdateDatabaseName(this.databaseName);
}

class FetchDatabases extends ReportAdminEvent {}

class UpdateApiServerURL extends ReportAdminEvent {
  final String apiServerURL;
  const UpdateApiServerURL(this.apiServerURL);
}

class UpdateApiName extends ReportAdminEvent {
  final String apiName;
  const UpdateApiName(this.apiName);
}

// --- START: NEW PARAMETER EVENTS ---

class UpdateParameterUIValue extends ReportAdminEvent {
  final int index;
  final String typedText;
  const UpdateParameterUIValue(this.index, this.typedText);
}

class UpdateParameterShow extends ReportAdminEvent {
  final int index;
  final bool show;
  const UpdateParameterShow(this.index, this.show);
}

class UpdateParameterFieldLabel extends ReportAdminEvent {
  final int index;
  final String fieldLabel;
  const UpdateParameterFieldLabel(this.index, this.fieldLabel);
}

class UpdateParameterIsCompanyNameField extends ReportAdminEvent {
  final int index;
  const UpdateParameterIsCompanyNameField(this.index);
}

class UpdateParameterFromModal extends ReportAdminEvent {
  final int index;
  final String newConfigType;
  final String? newValue;
  final String? newDisplayLabel;
  final String? newMasterTable;
  final String? newMasterField;
  final String? newDisplayField;
  final List<Map<String, dynamic>>? newOptions;
  final List<String>? newSelectedValues;

  const UpdateParameterFromModal({
    required this.index,
    required this.newConfigType,
    this.newValue,
    this.newDisplayLabel,
    this.newMasterTable,
    this.newMasterField,
    this.newDisplayField,
    this.newOptions,
    this.newSelectedValues,
  });
}
// --- END: NEW PARAMETER EVENTS ---

class SaveDatabaseServer extends ReportAdminEvent {
  const SaveDatabaseServer();
}

class ResetAdminState extends ReportAdminEvent {
  const ResetAdminState();
}

class FetchSavedConfigurations extends ReportAdminEvent {
  const FetchSavedConfigurations();
}

class SelectSavedConfiguration extends ReportAdminEvent {
  final String configId;
  const SelectSavedConfiguration(this.configId);
}

// --- State ---
class ReportAdminState {
  final String serverIP;
  final String userName;
  final String password;
  final String databaseName;
  final List<String> availableDatabases;
  final String apiServerURL;
  final String apiName;
  final List<Map<String, dynamic>> parameters;
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final List<Map<String, dynamic>> savedConfigurations;
  final String? selectedConfigId;

  ReportAdminState({
    this.serverIP = '',
    this.userName = '',
    this.password = '',
    this.databaseName = '',
    this.availableDatabases = const [],
    this.apiServerURL = '',
    this.apiName = '',
    this.parameters = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.savedConfigurations = const [],
    this.selectedConfigId,
  });

  ReportAdminState copyWith({
    String? serverIP,
    String? userName,
    String? password,
    String? databaseName,
    List<String>? availableDatabases,
    String? apiServerURL,
    String? apiName,
    List<Map<String, dynamic>>? parameters,
    bool? isLoading,
    ValueGetter<String?>? error,
    ValueGetter<String?>? successMessage,
    List<Map<String, dynamic>>? savedConfigurations,
    String? selectedConfigId,
    bool forceClearConfigId = false,
  }) {
    return ReportAdminState(
      serverIP: serverIP ?? this.serverIP,
      userName: userName ?? this.userName,
      password: password ?? this.password,
      databaseName: databaseName ?? this.databaseName,
      availableDatabases: availableDatabases ?? this.availableDatabases,
      apiServerURL: apiServerURL ?? this.apiServerURL,
      apiName: apiName ?? this.apiName,
      parameters: parameters ?? this.parameters,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      successMessage: successMessage != null ? successMessage() : this.successMessage,
      savedConfigurations: savedConfigurations ?? this.savedConfigurations,
      selectedConfigId: forceClearConfigId ? null : selectedConfigId ?? this.selectedConfigId,
    );
  }
}

// --- BLoC ---
class ReportAdminBloc extends Bloc<ReportAdminEvent, ReportAdminState> {
  final ReportAPIService apiService;
  String _lastServerIP = '';
  String _lastUserName = '';
  String _lastPassword = '';

  ReportAdminBloc(this.apiService) : super(ReportAdminState()) {
    on<UpdateServerIP>((event, emit) {
      if (event.serverIP != state.serverIP) {
        emit(state.copyWith(serverIP: event.serverIP, forceClearConfigId: true, availableDatabases: [], databaseName: ''));
        _lastServerIP = event.serverIP;
        _triggerFetchDatabases();
      }
    });

    on<UpdateUserName>((event, emit) {
      if (event.userName != state.userName) {
        emit(state.copyWith(userName: event.userName, forceClearConfigId: true, availableDatabases: [], databaseName: ''));
        _lastUserName = event.userName;
        _triggerFetchDatabases();
      }
    });

    on<UpdatePassword>((event, emit) {
      if (event.password != state.password) {
        emit(state.copyWith(password: event.password, forceClearConfigId: true, availableDatabases: [], databaseName: ''));
        _lastPassword = event.password;
        _triggerFetchDatabases();
      }
    });

    on<UpdateDatabaseName>((event, emit) {
      if (event.databaseName != state.databaseName) {
        emit(state.copyWith(databaseName: event.databaseName, forceClearConfigId: true));
      }
    });

    on<FetchDatabases>((event, emit) async {
      if (_lastServerIP.isEmpty || _lastUserName.isEmpty) {
        return;
      }
      emit(state.copyWith(isLoading: true, error: () => null));
      try {
        final databases = await apiService.fetchDatabases(
          serverIP: _lastServerIP,
          userName: _lastUserName,
          password: _lastPassword,
        );
        emit(state.copyWith(
          isLoading: false,
          availableDatabases: databases,
          databaseName: databases.isNotEmpty && !databases.contains(state.databaseName) ? '' : state.databaseName,
          error: () => null,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, availableDatabases: [], error: () => 'Failed to fetch databases: $e'));
      }
    });

    on<UpdateApiServerURL>((event, emit) {
      // FIX: The merging logic was flawed. This now correctly updates the parameter list.
      final newParams = _parseUrlParameters(event.apiServerURL);
      final mergedParams = _mergeParameters(state.parameters, newParams);
      emit(state.copyWith(apiServerURL: event.apiServerURL, parameters: mergedParams, forceClearConfigId: true));
    });

    on<UpdateApiName>((event, emit) {
      emit(state.copyWith(apiName: event.apiName, forceClearConfigId: true));
    });

    on<UpdateParameterUIValue>((event, emit) {
      final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
      if (event.index < updatedParameters.length) {
        Map<String, dynamic> currentParam = Map<String, dynamic>.from(updatedParameters[event.index]);
        currentParam['value'] = event.typedText;
        currentParam['display_value_cache'] = event.typedText;
        updatedParameters[event.index] = currentParam;
        emit(state.copyWith(parameters: updatedParameters));
      }
    });

    on<UpdateParameterShow>((event, emit) {
      final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
      if (event.index < updatedParameters.length) {
        updatedParameters[event.index] = { ...updatedParameters[event.index], 'show': event.show };
        emit(state.copyWith(parameters: updatedParameters));
      }
    });

    on<UpdateParameterFieldLabel>((event, emit) {
      final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
      if (event.index < updatedParameters.length) {
        updatedParameters[event.index] = { ...updatedParameters[event.index], 'field_label': event.fieldLabel };
        emit(state.copyWith(parameters: updatedParameters));
      }
    });

    on<UpdateParameterIsCompanyNameField>((event, emit) {
      final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
      for (var i = 0; i < updatedParameters.length; i++) {
        updatedParameters[i] = { ...updatedParameters[i], 'is_company_name_field': (i == event.index) };
      }
      emit(state.copyWith(parameters: updatedParameters));
    });

    on<UpdateParameterFromModal>((event, emit) {
      final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
      if (event.index < updatedParameters.length) {
        Map<String, dynamic> currentParam = Map<String, dynamic>.from(updatedParameters[event.index]);

        currentParam['config_type'] = event.newConfigType;
        currentParam['value'] = event.newValue;
        currentParam['display_value_cache'] = event.newDisplayLabel;

        if (event.newConfigType == 'database') {
          currentParam['master_table'] = event.newMasterTable;
          currentParam['master_field'] = event.newMasterField;
          currentParam['display_field'] = event.newDisplayField;
          currentParam['options'] = [];
          currentParam['selected_values'] = [];
        } else if (event.newConfigType == 'radio' || event.newConfigType == 'checkbox') {
          currentParam['options'] = event.newOptions ?? [];
          currentParam['selected_values'] = event.newSelectedValues ?? [];
          currentParam['master_table'] = null;
          currentParam['master_field'] = null;
          currentParam['display_field'] = null;
        }
        updatedParameters[event.index] = currentParam;
        emit(state.copyWith(parameters: updatedParameters));
      }
    });

    on<SaveDatabaseServer>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: () => null, successMessage: () => null));
      try {
        await apiService.saveDatabaseServer(
          serverIP: state.serverIP,
          userName: state.userName,
          password: state.password,
          databaseName: state.databaseName,
          apiServerURL: state.apiServerURL,
          apiName: state.apiName,
          parameters: state.parameters,
        );
        emit(state.copyWith(isLoading: false, successMessage: () => 'Configuration saved successfully!'));
        add(const FetchSavedConfigurations());
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: () => 'Failed to save configuration: ${e.toString()}'));
      }
    });

    on<ResetAdminState>((event, emit) {
      _lastServerIP = '';
      _lastUserName = '';
      _lastPassword = '';
      emit(ReportAdminState(savedConfigurations: state.savedConfigurations));
    });

    on<FetchSavedConfigurations>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: () => null));
      try {
        final Map<String, dynamic> response = await apiService.getSetupConfigurations();
        if (response['status'] == 'success' && response['data'] is List) {
          final List<Map<String, dynamic>> configs = (response['data'] as List).cast<Map<String, dynamic>>();
          configs.sort((a, b) => (a['ConfigName'] as String? ?? '').compareTo(b['ConfigName'] as String? ?? ''));
          emit(state.copyWith(isLoading: false, savedConfigurations: configs, error: () => null));
        } else {
          emit(state.copyWith(isLoading: false, error: () => 'Failed to load configurations: Unexpected format', savedConfigurations: []));
        }
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: () => 'Failed to load configurations: ${e.toString()}', savedConfigurations: []));
      }
    });

    on<SelectSavedConfiguration>((event, emit) {
      final selectedConfig = state.savedConfigurations.firstWhere(
            (config) => config['ConfigID'].toString() == event.configId,
        orElse: () => <String, dynamic>{},
      );

      if (selectedConfig.isNotEmpty) {
        final String serverIP = selectedConfig['ServerIP']?.toString() ?? '';
        final String userName = selectedConfig['UserName']?.toString() ?? '';
        final String password = selectedConfig['Password']?.toString() ?? '';
        final String databaseName = selectedConfig['DatabaseName']?.toString() ?? '';
        final String apiServerURL = selectedConfig['APIServerURl']?.toString() ?? '';
        final String apiName = selectedConfig['APIName']?.toString() ?? '';

        List<Map<String, dynamic>> parsedParams = [];
        if (selectedConfig['Parameter'] != null && selectedConfig['Parameter'].toString().isNotEmpty) {
          try {
            parsedParams = (jsonDecode(selectedConfig['Parameter'].toString()) as List)
                .map((p) => _initializeFullParameter(p as Map<String, dynamic>))
                .toList();
          } catch (e) {
            parsedParams = _parseUrlParameters(apiServerURL);
          }
        } else {
          parsedParams = _parseUrlParameters(apiServerURL);
        }

        emit(state.copyWith(
          serverIP: serverIP,
          userName: userName,
          password: password,
          databaseName: databaseName,
          apiServerURL: apiServerURL,
          apiName: apiName,
          parameters: parsedParams,
          selectedConfigId: event.configId,
          error: () => null,
        ));

        _lastServerIP = serverIP;
        _lastUserName = userName;
        _lastPassword = password;
        _triggerFetchDatabases();
      } else {
        emit(state.copyWith(error: () => 'Selected configuration not found.', selectedConfigId: null));
      }
    });

    add(const FetchSavedConfigurations());
  }

  void _triggerFetchDatabases() {
    if (_lastServerIP.isNotEmpty && _lastUserName.isNotEmpty) {
      add(FetchDatabases());
    }
  }

  Map<String, dynamic> _initializeFullParameter(Map<String, dynamic> p) {
    final param = {
      'name': p['name'],
      'value': p['value'],
      'show': (p['show'] as bool?) ?? false,
      'field_label': p['field_label'] as String? ?? '',
      'master_table': p['master_table'] as String?,
      'master_field': p['master_field'] as String?,
      'display_field': p['display_field'] as String?,
      'is_company_name_field': (p['is_company_name_field'] as bool?) ?? false,
      'config_type': p['config_type'] as String? ?? 'database',
      'options': (p['options'] is List)
          ? (p['options'] as List).map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList()
          : <Map<String, dynamic>>[],
      'selected_values': (p['selected_values'] is List)
          ? (p['selected_values'] as List).map((e) => e.toString()).toList()
          : <String>[],
      'display_value_cache': p['display_value_cache']?.toString(),
    };
    param['display_value_cache'] = _getInitialDisplayValueCache(param);
    return param;
  }

  static String? _getInitialDisplayValueCache(Map<String, dynamic> param) {
    if (param.containsKey('display_value_cache') && param['display_value_cache'] != null && param['display_value_cache'].toString().isNotEmpty) {
      return param['display_value_cache']?.toString();
    }
    return param['value']?.toString();
  }

  List<Map<String, dynamic>> _parseUrlParameters(String url) {
    if (url.isEmpty || !url.contains('?')) return [];
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters.entries.map((entry) {
        return _initializeFullParameter({'name': entry.key, 'value': entry.value});
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // FIX: This function was the source of the parameter parsing bug.
  // It now correctly preserves existing settings while updating based on the new URL.
  List<Map<String, dynamic>> _mergeParameters(List<Map<String, dynamic>> existing, List<Map<String, dynamic>> newParamsFromUrl) {
    // If the new URL has no parameters, the list should be empty.
    if (newParamsFromUrl.isEmpty) return [];

    final merged = <Map<String, dynamic>>[];
    // Create a quick-lookup map of the old parameters by their name.
    final existingMap = {for (var p in existing) p['name']: p};

    for (var newParam in newParamsFromUrl) {
      final name = newParam['name'];
      // Check if we have settings for this parameter from before.
      if (existingMap.containsKey(name)) {
        // If yes, keep the old settings ('show', 'field_label', etc.)
        // but update the 'value' from the new URL.
        merged.add({ ...existingMap[name]!, 'value': newParam['value'] });
      } else {
        // If it's a completely new parameter, add it with its default settings.
        merged.add(newParam);
      }
    }
    return merged;
  }
}