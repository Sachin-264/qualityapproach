import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import '../../ReportAPIService.dart'; // Ensure this path is correct

// Events
abstract class EditDetailAdminEvent {}

class FetchDatabases extends EditDetailAdminEvent {
  final String serverIP;
  final String userName;
  final String password;

  FetchDatabases({
    required this.serverIP,
    required this.userName,
    required this.password,
  });
}

class UpdateServerIP extends EditDetailAdminEvent {
  final String serverIP;
  UpdateServerIP(this.serverIP);
}

class UpdateUserName extends EditDetailAdminEvent {
  final String userName;
  UpdateUserName(this.userName);
}

class UpdatePassword extends EditDetailAdminEvent {
  final String password;
  UpdatePassword(this.password);
}

class UpdateDatabaseName extends EditDetailAdminEvent {
  final String databaseName;
  UpdateDatabaseName(this.databaseName);
}

class UpdateApiServerURL extends EditDetailAdminEvent {
  final String apiServerURl;
  UpdateApiServerURL(this.apiServerURl);
}

class UpdateApiName extends EditDetailAdminEvent {
  final String apiName;
  UpdateApiName(this.apiName);
}

class UpdateParameterValue extends EditDetailAdminEvent {
  final int index;
  final String value;
  final String displayValueCache;
  UpdateParameterValue(this.index, this.value, this.displayValueCache);
}

class UpdateParameterShow extends EditDetailAdminEvent {
  final int index;
  final bool show;
  UpdateParameterShow(this.index, this.show);
}

class UpdateParameterFieldLabel extends EditDetailAdminEvent {
  final int index;
  final String fieldLabel;
  UpdateParameterFieldLabel(this.index, this.fieldLabel);
}

class UpdateParameterMasterSelection extends EditDetailAdminEvent {
  final int index;
  final String? masterTable;
  final String? masterField;
  final String? displayField;

  UpdateParameterMasterSelection(this.index, this.masterTable, this.masterField, this.displayField);
}

class UpdateParameterIsCompanyNameField extends EditDetailAdminEvent {
  final int index;
  UpdateParameterIsCompanyNameField(this.index);
}

class UpdateParameterConfigType extends EditDetailAdminEvent {
  final int index;
  final String configType;
  UpdateParameterConfigType(this.index, this.configType);
}

class UpdateParameterOptions extends EditDetailAdminEvent {
  final int index;
  final List<Map<String, dynamic>> options;
  UpdateParameterOptions(this.index, this.options);
}

class UpdateParameterSelectedValues extends EditDetailAdminEvent {
  final int index;
  final List<String> selectedValues;
  UpdateParameterSelectedValues(this.index, this.selectedValues);
}

class SaveChanges extends EditDetailAdminEvent {}

// State
class EditDetailAdminState {
  final String id;
  final String serverIP;
  final String userName;
  final String password;
  final String databaseName;
  final String apiServerURl;
  final String apiName;
  final List<Map<String, dynamic>> parameters;
  final List<String> availableDatabases;
  final bool isLoading;
  final String? error;
  final bool saveInitiated;

  EditDetailAdminState({
    required this.id,
    required this.serverIP,
    required this.userName,
    required this.password,
    required this.databaseName,
    required this.apiServerURl,
    required this.apiName,
    required this.parameters,
    this.availableDatabases = const [],
    this.isLoading = false,
    this.error,
    this.saveInitiated = false,
  });

  EditDetailAdminState copyWith({
    String? id,
    String? serverIP,
    String? userName,
    String? password,
    String? databaseName,
    String? apiServerURl,
    String? apiName,
    List<Map<String, dynamic>>? parameters,
    List<String>? availableDatabases,
    bool? isLoading,
    String? error,
    bool? saveInitiated,
  }) {
    return EditDetailAdminState(
      id: id ?? this.id,
      serverIP: serverIP ?? this.serverIP,
      userName: userName ?? this.userName,
      password: password ?? this.password,
      databaseName: databaseName ?? this.databaseName,
      apiServerURl: apiServerURl ?? this.apiServerURl,
      apiName: apiName ?? this.apiName,
      parameters: parameters ?? this.parameters,
      availableDatabases: availableDatabases ?? this.availableDatabases,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      saveInitiated: saveInitiated ?? this.saveInitiated,
    );
  }
}

// Bloc
class EditDetailAdminBloc extends Bloc<EditDetailAdminEvent, EditDetailAdminState> {
  final ReportAPIService apiService;

  EditDetailAdminBloc(this.apiService, Map<String, dynamic> apiData)
      : super(EditDetailAdminState(
    id: apiData['id']?.toString() ?? '',
    serverIP: apiData['ServerIP']?.toString() ?? '',
    userName: apiData['UserName']?.toString() ?? '',
    password: apiData['Password']?.toString() ?? '',
    databaseName: apiData['DatabaseName']?.toString() ?? '',
    apiServerURl: apiData['APIServerURl']?.toString() ?? '',
    apiName: apiData['APIName']?.toString() ?? '',
    parameters: (() {
      dynamic paramsRaw = apiData['Parameter'];
      List<dynamic> parsedParams = [];
      if (paramsRaw is String && paramsRaw.isNotEmpty) {
        try {
          parsedParams = jsonDecode(paramsRaw);
        } catch (e) {
          print('Warning: Failed to decode parameters string: $e');
          parsedParams = [];
        }
      } else if (paramsRaw is List) {
        parsedParams = paramsRaw;
      }

      return parsedParams.map((p) {
        if (p is! Map<String, dynamic>) {
          print('Warning: Parameter element is not a Map: $p');
          return <String, dynamic>{};
        }
        return {
          ...p,
          'master_table': p['master_table'] as String?,
          'master_field': p['master_field'] as String?,
          'display_field': p['display_field'] as String?,
          'is_company_name_field': (p['is_company_name_field'] as bool?) ?? false,
          'config_type': p['config_type'] as String? ?? 'database',
          'options': (p['options'] is List)
              ? (p['options'] as List).cast<Map<String, dynamic>>()
              : [],
          'selected_values': (p['selected_values'] is List)
              ? (p['selected_values'] as List).cast<String>()
              : [],
          'display_value_cache': p['display_value_cache'] as String?,
        };
      }).toList();
    })(),
  )) {
    on<FetchDatabases>(_onFetchDatabases);
    on<UpdateServerIP>(_onUpdateServerIP);
    on<UpdateUserName>(_onUpdateUserName);
    on<UpdatePassword>(_onUpdatePassword);
    on<UpdateDatabaseName>(_onUpdateDatabaseName);
    on<UpdateApiServerURL>(_onUpdateApiServerURL);
    on<UpdateApiName>(_onUpdateApiName);
    on<UpdateParameterValue>(_onUpdateParameterValue);
    on<UpdateParameterShow>(_onUpdateParameterShow);
    on<UpdateParameterFieldLabel>(_onUpdateParameterFieldLabel);
    on<UpdateParameterMasterSelection>(_onUpdateParameterMasterSelection);
    on<UpdateParameterIsCompanyNameField>(_onUpdateParameterIsCompanyNameField);
    on<UpdateParameterConfigType>(_onUpdateParameterConfigType);
    on<UpdateParameterOptions>(_onUpdateParameterOptions);
    on<UpdateParameterSelectedValues>(_onUpdateParameterSelectedValues);
    on<SaveChanges>(_onSaveChanges);
  }

  Future<void> _onFetchDatabases(FetchDatabases event, Emitter<EditDetailAdminState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final databases = await apiService.fetchDatabases(
        serverIP: event.serverIP,
        userName: event.userName,
        password: event.password,
      );
      emit(state.copyWith(availableDatabases: databases, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  void _onUpdateServerIP(UpdateServerIP event, Emitter<EditDetailAdminState> emit) {
    emit(state.copyWith(serverIP: event.serverIP));
  }

  void _onUpdateUserName(UpdateUserName event, Emitter<EditDetailAdminState> emit) {
    emit(state.copyWith(userName: event.userName));
  }

  void _onUpdatePassword(UpdatePassword event, Emitter<EditDetailAdminState> emit) {
    emit(state.copyWith(password: event.password));
  }

  void _onUpdateDatabaseName(UpdateDatabaseName event, Emitter<EditDetailAdminState> emit) {
    emit(state.copyWith(databaseName: event.databaseName));
  }

  void _onUpdateApiServerURL(UpdateApiServerURL event, Emitter<EditDetailAdminState> emit) {
    emit(state.copyWith(apiServerURl: event.apiServerURl));
  }

  void _onUpdateApiName(UpdateApiName event, Emitter<EditDetailAdminState> emit) {
    emit(state.copyWith(apiName: event.apiName));
  }

  void _onUpdateParameterValue(UpdateParameterValue event, Emitter<EditDetailAdminState> emit) {
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    updatedParameters[event.index] = {
      ...updatedParameters[event.index],
      'value': event.value,
      'display_value_cache': event.displayValueCache,
    };
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateParameterShow(UpdateParameterShow event, Emitter<EditDetailAdminState> emit) {
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    updatedParameters[event.index] = {
      ...updatedParameters[event.index],
      'show': event.show,
    };
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateParameterFieldLabel(UpdateParameterFieldLabel event, Emitter<EditDetailAdminState> emit) {
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    updatedParameters[event.index] = {
      ...updatedParameters[event.index],
      'field_label': event.fieldLabel,
    };
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateParameterMasterSelection(UpdateParameterMasterSelection event, Emitter<EditDetailAdminState> emit) {
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    updatedParameters[event.index] = {
      ...updatedParameters[event.index],
      'master_table': event.masterTable,
      'master_field': event.masterField,
      'display_field': event.displayField,
    };
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateParameterIsCompanyNameField(UpdateParameterIsCompanyNameField event, Emitter<EditDetailAdminState> emit) {
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    for (var i = 0; i < updatedParameters.length; i++) {
      updatedParameters[i] = {
        ...updatedParameters[i],
        'is_company_name_field': (i == event.index),
      };
    }
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateParameterConfigType(UpdateParameterConfigType event, Emitter<EditDetailAdminState> emit) {
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    updatedParameters[event.index] = {
      ...updatedParameters[event.index],
      'config_type': event.configType,
      'master_table': null,
      'master_field': null,
      'display_field': null,
      'options': [],
      'selected_values': [],
    };
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateParameterOptions(UpdateParameterOptions event, Emitter<EditDetailAdminState> emit) {
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    updatedParameters[event.index] = {
      ...updatedParameters[event.index],
      'options': event.options,
    };
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateParameterSelectedValues(UpdateParameterSelectedValues event, Emitter<EditDetailAdminState> emit) {
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    updatedParameters[event.index] = {
      ...updatedParameters[event.index],
      'selected_values': event.selectedValues,
      // For radio, 'value' is single selected_value, for checkbox, 'value' is comma-separated list
      'value': event.selectedValues.join(','),
      'display_value_cache': event.selectedValues.map((val) {
        final option = (updatedParameters[event.index]['options'] as List<dynamic>?)
            ?.firstWhere(
                (opt) => opt is Map<String, dynamic> && opt['value'] == val,
            orElse: () => <String, dynamic>{}); // FIXED: Explicitly specify type for the empty map
        return option?['label'] ?? val;
      }).join(', '),
    };
    emit(state.copyWith(parameters: updatedParameters));
  }

  Future<void> _onSaveChanges(SaveChanges event, Emitter<EditDetailAdminState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, saveInitiated: true));
    try {
      await apiService.editDatabaseServer(
        id: state.id,
        serverIP: state.serverIP,
        userName: state.userName,
        password: state.password,
        databaseName: state.databaseName,
        apiServerURL: state.apiServerURl,
        apiName: state.apiName,
        parameters: state.parameters,
      );
      emit(state.copyWith(isLoading: false, saveInitiated: true));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString(), saveInitiated: false));
    }
  }
}