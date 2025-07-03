// lib/report_admin_feature/report_admin_bloc.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class UpdateParameterValue extends ReportAdminEvent {
  final int index;
  final String value;
  const UpdateParameterValue(this.index, this.value);
}

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
      selectedConfigId: selectedConfigId,
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
        emit(state.copyWith(serverIP: event.serverIP, selectedConfigId: null, availableDatabases: [], databaseName: ''));
        _lastServerIP = event.serverIP;
        _triggerFetchDatabases();
      }
    });

    on<UpdateUserName>((event, emit) {
      if (event.userName != state.userName) {
        emit(state.copyWith(userName: event.userName, selectedConfigId: null, availableDatabases: [], databaseName: ''));
        _lastUserName = event.userName;
        _triggerFetchDatabases();
      }
    });

    on<UpdatePassword>((event, emit) {
      if (event.password != state.password) {
        emit(state.copyWith(password: event.password, selectedConfigId: null, availableDatabases: [], databaseName: ''));
        _lastPassword = event.password;
        _triggerFetchDatabases();
      }
    });

    on<UpdateDatabaseName>((event, emit) {
      if (event.databaseName != state.databaseName) {
        emit(state.copyWith(databaseName: event.databaseName, selectedConfigId: null));
      }
    });

    on<FetchDatabases>((event, emit) async {
      if (_lastServerIP.isEmpty || _lastUserName.isEmpty || _lastPassword.isEmpty) {
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
          databaseName: databases.isNotEmpty && !databases.contains(state.databaseName) ? databases.first : state.databaseName,
          error: () => null,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, availableDatabases: [], error: () => 'Failed to fetch databases: $e'));
      }
    });

    on<UpdateApiServerURL>((event, emit) {
      final newParams = _parseUrlParameters(event.apiServerURL);
      final mergedParams = _mergeParameters(state.parameters, newParams);
      emit(state.copyWith(apiServerURL: event.apiServerURL, parameters: mergedParams));
    });

    on<UpdateApiName>((event, emit) {
      emit(state.copyWith(apiName: event.apiName));
    });

    on<UpdateParameterValue>((event, emit) {
      if (event.index < state.parameters.length) {
        final List<Map<String, dynamic>> updatedParameters = List.from(state.parameters);
        updatedParameters[event.index] = {
          ...updatedParameters[event.index],
          'value': event.value,
        };
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
        emit(state.copyWith(
          isLoading: false,
          successMessage: () => 'Configuration saved successfully!',
        ));
        add(const FetchSavedConfigurations());
      } catch (e) {
        emit(state.copyWith(
          isLoading: false,
          error: () => 'Failed to save configuration: ${e.toString()}',
        ));
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
        final String apiServerURL = selectedConfig['APIServerURl']?.toString() ?? ''; // Correct key
        final String apiName = selectedConfig['APIName']?.toString() ?? '';

        List<Map<String, dynamic>> parsedParams = [];
        if (selectedConfig['Parameter'] != null && selectedConfig['Parameter'].toString().isNotEmpty) {
          try {
            parsedParams = (jsonDecode(selectedConfig['Parameter'].toString()) as List).cast<Map<String, dynamic>>();
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
    if (_lastServerIP.isNotEmpty && _lastUserName.isNotEmpty && _lastPassword.isNotEmpty) {
      add(FetchDatabases());
    }
  }

  List<Map<String, dynamic>> _parseUrlParameters(String url) {
    if (url.isEmpty || !url.contains('?')) return [];
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters.entries.map((entry) {
        return {'name': entry.key, 'value': entry.value, 'show': false, 'field_label': ''};
      }).toList();
    } catch (e) {
      return [];
    }
  }

  List<Map<String, dynamic>> _mergeParameters(List<Map<String, dynamic>> existing, List<Map<String, dynamic>> newParams) {
    if (newParams.isEmpty) return [];

    final merged = <Map<String, dynamic>>[];
    final existingMap = {for (var p in existing) p['name']: p};

    for (var newParam in newParams) {
      final name = newParam['name'];
      if (existingMap.containsKey(name)) {
        merged.add({ ...existingMap[name]!, 'value': newParam['value'] });
      } else {
        merged.add(newParam);
      }
    }
    return merged;
  }
}