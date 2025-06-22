import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import '../../ReportAPIService.dart'; // Ensure this path is correct
import 'package:flutter/foundation.dart'; // Import for debugPrint

// Events (No changes needed here)
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

// Event for direct text input from UI
class UpdateParameterUIValue extends EditDetailAdminEvent {
  final int index;
  final String typedText; // The text directly entered by the user in the UI field
  UpdateParameterUIValue(this.index, this.typedText);
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

// This event should contain the API value, and the display label
class UpdateParameterFromModal extends EditDetailAdminEvent {
  final int index;
  final String newConfigType;
  final String? newValue; // The API value
  final String? newDisplayLabel; // The user-friendly display value
  final String? newMasterTable;
  final String? newMasterField;
  final String? newDisplayField;
  final List<Map<String, dynamic>>? newOptions; // All options for radio/checkbox
  final List<String>? newSelectedValues; // API values that are selected (for checkbox, or single for radio)

  UpdateParameterFromModal({
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

// These events are less common now that UpdateParameterFromModal is atomic,
// but kept for completeness if you have other flows.
class UpdateParameterOptions extends EditDetailAdminEvent {
  final int index;
  final List<Map<String, dynamic>> options;
  UpdateParameterOptions(this.index, this.options);
}

class UpdateParameterSelectedValues extends EditDetailAdminEvent {
  final int index;
  final List<String> selectedValues; // These should be API values
  UpdateParameterSelectedValues(this.index, this.selectedValues);
}

class UpdateDashboardStatus extends EditDetailAdminEvent {
  final bool isDashboard;
  UpdateDashboardStatus(this.isDashboard);
}

class SaveChanges extends EditDetailAdminEvent {}

// State (No changes needed here)
class EditDetailAdminState {
  final String id;
  final String serverIP;
  final String userName;
  final String password;
  final String databaseName;
  final String apiServerURl;
  final String apiName;
  final bool isDashboard; // NEW
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
    required this.isDashboard, // NEW
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
    bool? isDashboard, // NEW
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
      isDashboard: isDashboard ?? this.isDashboard, // NEW
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
    password: apiData['Password']?.toString() ?? '',
    databaseName: apiData['DatabaseName']?.toString() ?? '',
    apiServerURl: apiData['APIServerURl']?.toString() ?? '',
    apiName: apiData['APIName']?.toString() ?? '',
    userName: apiData['UserName']?.toString() ?? '',
    isDashboard: (apiData['IsDashboard'] as bool?) ?? false, // NEW: Initialize dashboard status
    parameters: (() {
      debugPrint('Bloc Constructor: Parsing initial API parameters.');
      dynamic paramsRaw = apiData['Parameter'];
      List<dynamic> parsedParams = [];
      if (paramsRaw is String && paramsRaw.isNotEmpty) {
        try {
          parsedParams = jsonDecode(paramsRaw);
          debugPrint('  Successfully decoded parameters string: ${paramsRaw.length} chars.');
        } catch (e) {
          debugPrint('  Warning: Failed to decode parameters string: $e. Using empty list.');
          parsedParams = [];
        }
      } else if (paramsRaw is List) {
        parsedParams = paramsRaw;
        debugPrint('  Parameters are already a list. Count: ${parsedParams.length}');
      } else {
        debugPrint('  Parameters are null or unexpected type. Using empty list.');
      }

      return parsedParams.map((p) {
        if (p is! Map<String, dynamic>) {
          debugPrint('  Warning: Parameter element is not a Map: $p. Skipping.');
          return <String, dynamic>{};
        }
        debugPrint('  Processing parameter: ${p['name']}');
        final param = {
          ...p,
          'master_table': p['master_table'] as String?,
          'master_field': p['master_field'] as String?,
          'display_field': p['display_field'] as String?,
          'is_company_name_field': (p['is_company_name_field'] as bool?) ?? false,
          'config_type': p['config_type'] as String? ?? 'database', // Default to 'database' if not specified
          'options': (p['options'] is List)
              ? (p['options'] as List)
              .map((e) {
            if (e is Map && e.containsKey('value') && e.containsKey('label')) {
              return {'value': e['value'].toString(), 'label': e['label'].toString()};
            }
            debugPrint('    Warning: Malformed option found: $e. Returning empty map.');
            return <String, dynamic>{};
          })
              .where((map) => map.isNotEmpty)
              .toList()
              : <Map<String, dynamic>>[],
          'selected_values': (p['selected_values'] is List)
              ? (p['selected_values'] as List).map((e) => e.toString()).toList()
              : <String>[],
          // MODIFICATION 1: Retrieve existing display_value_cache if present in the incoming API data
          'display_value_cache': p['display_value_cache']?.toString(),
        };

        // Set initial display_value_cache using the helper (this will override the above if logic applies)
        param['display_value_cache'] = _getInitialDisplayValueCache(param);
        return param;
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
    on<UpdateParameterUIValue>(_onUpdateParameterUIValue); // Changed event name
    on<UpdateParameterShow>(_onUpdateParameterShow);
    on<UpdateParameterFieldLabel>(_onUpdateParameterFieldLabel);
    on<UpdateParameterMasterSelection>(_onUpdateParameterMasterSelection);
    on<UpdateParameterIsCompanyNameField>(_onUpdateParameterIsCompanyNameField);
    on<UpdateParameterConfigType>(_onUpdateParameterConfigType);
    on<UpdateParameterFromModal>(_onUpdateParameterFromModal);
    on<UpdateParameterOptions>(_onUpdateParameterOptions);
    on<UpdateParameterSelectedValues>(_onUpdateParameterSelectedValues);
    on<UpdateDashboardStatus>(_onUpdateDashboardStatus); // NEW
    on<SaveChanges>(_onSaveChanges);
  }

  // MODIFICATION 2: Update _getInitialDisplayValueCache logic
  // This helper will only set display_value_cache if a distinct label can be found.
  // Otherwise, it returns the 'value' itself, signaling the UI to display the raw value.
  static String? _getInitialDisplayValueCache(Map<String, dynamic> param) {
    final String? configType = param['config_type'] as String?;
    final String? value = param['value']?.toString();

    // 1. Prioritize an existing, non-empty 'display_value_cache' from the incoming data.
    // This handles cases where the API might directly provide the display label.
    if (param.containsKey('display_value_cache') &&
        param['display_value_cache'] != null &&
        param['display_value_cache'].toString().isNotEmpty) {
      debugPrint('  _getInitialDisplayValueCache: Using existing display_value_cache "${param['display_value_cache']}" for ${param['name']}');
      return param['display_value_cache']?.toString();
    }

    // 2. For radio/checkbox types, try to find the label from the 'options' list based on the 'value'.
    if ((configType == 'radio' || configType == 'checkbox') && (param['options'] is List)) {
      final List<Map<String, dynamic>> options = List<Map<String, dynamic>>.from(param['options']);

      if (configType == 'radio' && value != null) {
        final selectedOption = options.firstWhere(
              (opt) => opt['value']?.toString() == value,
          orElse: () => <String, dynamic>{},
        );
        final label = selectedOption['label']?.toString();
        if (label != null && label.isNotEmpty) {
          debugPrint('  _getInitialDisplayValueCache: Found label "${label}" for radio ${param['name']} (value: ${value})');
          return label;
        }
      } else if (configType == 'checkbox') {
        final List<String> selectedValues = (param['selected_values'] as List?)?.cast<String>() ?? [];
        if (selectedValues.isNotEmpty) {
          final List<String> displayLabels = selectedValues.map((sv) {
            final selectedOption = options.firstWhere(
                  (opt) => opt['value']?.toString() == sv,
              orElse: () => <String, dynamic>{},
            );
            return selectedOption['label']?.toString(); // Return label, or null if not found
          }).where((label) => label != null && label.isNotEmpty).cast<String>().toList(); // Filter out nulls/empties

          final joinedLabels = displayLabels.join(', ');
          if (joinedLabels.isNotEmpty) {
            debugPrint('  _getInitialDisplayValueCache: Found labels "${joinedLabels}" for checkbox ${param['name']} (values: ${selectedValues})');
            return joinedLabels;
          }
        }
      }
    }

    // 3. For all other cases (e.g., 'database' type, or text input where no specific display label is provided),
    // the 'value' itself should be displayed in the UI.
    // This is crucial for initial load when a distinct label isn't retrieved from the API or options.
    debugPrint('  _getInitialDisplayCache: Defaulting display_value_cache to the parameter "value" ("$value") for ${param['name']}.');
    return value; // Return the actual value as the display cache
  }


  Future<void> _onFetchDatabases(FetchDatabases event, Emitter<EditDetailAdminState> emit) async {
    debugPrint('Bloc Event: FetchDatabases started.');
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final databases = await apiService.fetchDatabases(
        serverIP: event.serverIP,
        userName: event.userName,
        password: event.password,
      );
      debugPrint('Bloc Event: Successfully fetched ${databases.length} databases.');
      emit(state.copyWith(availableDatabases: databases, isLoading: false));
    } catch (e) {
      debugPrint('Bloc Event: Error fetching databases: $e');
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  void _onUpdateServerIP(UpdateServerIP event, Emitter<EditDetailAdminState> emit) {
    debugPrint('Bloc Event: UpdateServerIP to ${event.serverIP}');
    emit(state.copyWith(serverIP: event.serverIP));
  }

  void _onUpdateUserName(UpdateUserName event, Emitter<EditDetailAdminState> emit) {
    debugPrint('Bloc Event: UpdateUserName to ${event.userName}');
    emit(state.copyWith(userName: event.userName));
  }

  void _onUpdatePassword(UpdatePassword event, Emitter<EditDetailAdminState> emit) {
    debugPrint('Bloc Event: UpdatePassword.');
    emit(state.copyWith(password: event.password));
  }

  void _onUpdateDatabaseName(UpdateDatabaseName event, Emitter<EditDetailAdminState> emit) {
    debugPrint('Bloc Event: UpdateDatabaseName to ${event.databaseName}');
    emit(state.copyWith(databaseName: event.databaseName));
  }

  void _onUpdateApiServerURL(UpdateApiServerURL event, Emitter<EditDetailAdminState> emit) {
    debugPrint('Bloc Event: UpdateApiServerURL to ${event.apiServerURl}');
    emit(state.copyWith(apiServerURl: event.apiServerURl));
  }

  void _onUpdateApiName(UpdateApiName event, Emitter<EditDetailAdminState> emit) {
    debugPrint('Bloc Event: UpdateApiName to ${event.apiName}');
    emit(state.copyWith(apiName: event.apiName));
  }

// Handle direct text input from UI
  void _onUpdateParameterUIValue(UpdateParameterUIValue event, Emitter<EditDetailAdminState> emit) {
    debugPrint('Bloc Event: UpdateParameterUIValue for index ${event.index} to typedText="${event.typedText}"');
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    Map<String, dynamic> currentParam = Map<String, dynamic>.from(updatedParameters[event.index]);

// Always update value and display_value_cache to the typed text.
// For picker types, this will be overwritten when the modal returns.
// For date pickers and plain text, this is the correct behavior.
    debugPrint('  Parameter ${event.index}. Updating "value" and "display_value_cache" to typedText "${event.typedText}".');
    currentParam['value'] = event.typedText;
    currentParam['display_value_cache'] = event.typedText;

    updatedParameters[event.index] = currentParam;
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateParameterShow(UpdateParameterShow event, Emitter<EditDetailAdminState> emit) {
    debugPrint('Bloc Event: UpdateParameterShow for index ${event.index} to ${event.show}');
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    updatedParameters[event.index] = {
      ...updatedParameters[event.index],
      'show': event.show,
    };
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateParameterFieldLabel(UpdateParameterFieldLabel event, Emitter<EditDetailAdminState> emit) {
    debugPrint('Bloc Event: UpdateParameterFieldLabel for index ${event.index} to "${event.fieldLabel}"');
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    updatedParameters[event.index] = {
      ...updatedParameters[event.index],
      'field_label': event.fieldLabel,
    };
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateParameterMasterSelection(UpdateParameterMasterSelection event, Emitter<EditDetailAdminState> emit) {
    debugPrint(
        'Bloc Event: UpdateParameterMasterSelection for index ${event.index}. Table: ${event.masterTable}, Master: ${event.masterField}, Display: ${event.displayField}');
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
    debugPrint('Bloc Event: UpdateParameterIsCompanyNameField to index ${event.index}');
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
    debugPrint('Bloc Event: UpdateParameterConfigType for index ${event.index} to "${event.configType}".');
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    Map<String, dynamic> currentParam = Map<String, dynamic>.from(updatedParameters[event.index]);

    currentParam['config_type'] = event.configType;

// When config type changes, clear irrelevant config data
    if (event.configType == 'database') {
      currentParam['options'] = [];
      currentParam['selected_values'] = [];
// 'value' and 'display_value_cache' for database type will be updated from modal.
    } else if (event.configType == 'radio' || event.configType == 'checkbox') {
      currentParam['master_table'] = null;
      currentParam['master_field'] = null;
      currentParam['display_field'] = null;
// 'value' and 'display_value_cache' for radio/checkbox will be updated from modal.
    } else {
// 'text' or other default
      currentParam['master_table'] = null;
      currentParam['master_field'] = null;
      currentParam['display_field'] = null;
      currentParam['options'] = [];
      currentParam['selected_values'] = [];
// 'value' and 'display_value_cache' are just the text field content.
    }

    updatedParameters[event.index] = currentParam;
    debugPrint('  Parameter ${event.index} config type updated. Other properties cleared as per type.');
    emit(state.copyWith(parameters: updatedParameters));
  }

// Atomically updates parameter properties from modal result
  void _onUpdateParameterFromModal(UpdateParameterFromModal event, Emitter<EditDetailAdminState> emit) {
    debugPrint(
        'Bloc Event: UpdateParameterFromModal for index ${event.index}. Config type: ${event.newConfigType}, Value: ${event.newValue}, DisplayLabel: ${event.newDisplayLabel}');
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    Map<String, dynamic> currentParam = Map<String, dynamic>.from(updatedParameters[event.index]);

    currentParam['config_type'] = event.newConfigType;

// The modal provides the definitive API value and display label.
    currentParam['value'] = event.newValue;
// Set display_value_cache to the newDisplayLabel provided by the modal.
// If newDisplayLabel is null (e.g., if it's a plain text input or API value should be shown), then cache is null.
    currentParam['display_value_cache'] = event.newDisplayLabel; // This will store the label from the modal

    if (event.newConfigType == 'database') {
      currentParam['master_table'] = event.newMasterTable;
      currentParam['master_field'] = event.newMasterField;
      currentParam['display_field'] = event.newDisplayField;
      currentParam['options'] = []; // Clear radio/checkbox specific properties
      currentParam['selected_values'] = [];
    } else if (event.newConfigType == 'radio' || event.newConfigType == 'checkbox') {
      currentParam['options'] = event.newOptions ?? []; // Store all options
      currentParam['selected_values'] = event.newSelectedValues ?? [];
      currentParam['master_table'] = null; // Clear database specific properties
      currentParam['master_field'] = null;
      currentParam['display_field'] = null;
    } else {
// For a 'text' or default type (should ideally not happen from modal), clear all specialized config properties
      currentParam['master_table'] = null;
      currentParam['master_field'] = null;
      currentParam['display_field'] = null;
      currentParam['options'] = [];
      currentParam['selected_values'] = [];
    }

    updatedParameters[event.index] = currentParam;
    debugPrint(
        '  Parameter ${event.index} fully updated from modal. Current value in state: "${currentParam['value']}", Display cache: "${currentParam['display_value_cache']}"');
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateParameterOptions(UpdateParameterOptions event, Emitter<EditDetailAdminState> emit) {
    debugPrint('Bloc Event: UpdateParameterOptions for index ${event.index}. Options count: ${event.options.length}');
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    updatedParameters[event.index] = {
      ...updatedParameters[event.index],
      'options': event.options,
    };
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateParameterSelectedValues(UpdateParameterSelectedValues event, Emitter<EditDetailAdminState> emit) {
    debugPrint('Bloc Event: UpdateParameterSelectedValues for index ${event.index}. Selected values: ${event.selectedValues}');
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    final currentParam = updatedParameters[event.index];

    final String newValue = event.selectedValues.join(','); // This is the API value string
// Derive new display cache from selected values and existing options
    final String? newDisplayCache = event.selectedValues.isNotEmpty
        ? event.selectedValues.map((val) {
      final option = (currentParam['options'] as List<dynamic>?)?.firstWhere(
              (opt) => opt is Map<String, dynamic> && opt['value'] == val,
          orElse: () => <String, dynamic>{});
      return option?['label']?.toString(); // Return label, or null if not found
    }).where((label) => label != null && label.isNotEmpty).cast<String>().join(', ')
        : null; // Set to null if no selected values

    updatedParameters[event.index] = {
      ...currentParam,
      'selected_values': event.selectedValues,
      'value': newValue,
      'display_value_cache': newDisplayCache,
    };
    debugPrint('  Updated parameter ${event.index}: value="$newValue", display_value_cache="$newDisplayCache"');
    emit(state.copyWith(parameters: updatedParameters));
  }

  void _onUpdateDashboardStatus(UpdateDashboardStatus event, Emitter<EditDetailAdminState> emit) {
    debugPrint('Bloc Event: UpdateDashboardStatus to ${event.isDashboard}');
    emit(state.copyWith(isDashboard: event.isDashboard));
  }

  Future<void> _onSaveChanges(SaveChanges event, Emitter<EditDetailAdminState> emit) async {
    debugPrint('Bloc Event: SaveChanges initiated. Current state parameters: ${state.parameters.length}');
    // IMPORTANT: The `state.parameters` at this point should contain all the updated fields
    // including 'config_type', 'master_table', 'master_field', 'display_field', 'options', 'selected_values',
    // and 'display_value_cache'.
    // Ensure your PHP backend for `edit_database_server` correctly receives and persists
    // ALL these properties when it decodes `Parameter` JSON.
    debugPrint('Parameters being sent for save: ${jsonEncode(state.parameters)}'); // Log full parameters being saved
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
        parameters: state.parameters, // Pass the full parameters list
        isDashboard: state.isDashboard, // NEW: Pass dashboard status
      );
      debugPrint('Bloc Event: SaveChanges successful. API call completed.');
      emit(state.copyWith(isLoading: false, saveInitiated: true));
    } catch (e) {
      debugPrint('Bloc Event: SaveChanges failed: $e');
      emit(state.copyWith(isLoading: false, error: e.toString(), saveInitiated: false));
    }
  }
}