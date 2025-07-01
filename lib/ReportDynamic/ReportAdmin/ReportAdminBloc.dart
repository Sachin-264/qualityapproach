import 'package:flutter_bloc/flutter_bloc.dart';
import '../ReportAPIService.dart'; // Ensure this path is correct for your project
import 'dart:convert'; // For jsonDecode

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

class ParseParameters extends ReportAdminEvent {}

class UpdateApiName extends ReportAdminEvent {
  final String apiName;
  const UpdateApiName(this.apiName);
}

class UpdateParameterValue extends ReportAdminEvent {
  final int index;
  final String value;
  const UpdateParameterValue(this.index, this.value);
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
    String? error, // Pass null to clear
    List<Map<String, dynamic>>? savedConfigurations,
    String? selectedConfigId, // Pass null to clear
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
      error: error,
      savedConfigurations: savedConfigurations ?? this.savedConfigurations,
      selectedConfigId: selectedConfigId,
    );
  }
}

class ReportAdminBloc extends Bloc<ReportAdminEvent, ReportAdminState> {
  final ReportAPIService apiService;
  // These variables hold the last known values that successfully triggered (or would trigger) a fetch.
  // They are kept in sync with the state's serverIP, userName, password.
  String _lastServerIP = '';
  String _lastUserName = '';
  String _lastPassword = '';

  ReportAdminBloc(this.apiService) : super(ReportAdminState()) {
    on<UpdateServerIP>((event, emit) {
      if (event.serverIP != state.serverIP) {
        emit(state.copyWith(serverIP: event.serverIP, selectedConfigId: null));
        _lastServerIP = event.serverIP; // Keep internal tracking variable in sync
        _triggerFetchDatabases();
      }
    });

    on<UpdateUserName>((event, emit) {
      if (event.userName != state.userName) {
        emit(state.copyWith(userName: event.userName, selectedConfigId: null));
        _lastUserName = event.userName; // Keep internal tracking variable in sync
        _triggerFetchDatabases();
      }
    });

    on<UpdatePassword>((event, emit) {
      if (event.password != state.password) {
        emit(state.copyWith(password: event.password, selectedConfigId: null));
        _lastPassword = event.password; // Keep internal tracking variable in sync
        _triggerFetchDatabases();
      }
    });

    on<UpdateDatabaseName>((event, emit) {
      if (event.databaseName != state.databaseName) {
        emit(state.copyWith(databaseName: event.databaseName, selectedConfigId: null));
      }
    });

    on<FetchDatabases>((event, emit) async {
      // Use the *current* values of _lastServerIP, _lastUserName, _lastPassword
      // which are always kept in sync by the update handlers.
      if (_lastServerIP.isEmpty || _lastUserName.isEmpty || _lastPassword.isEmpty) {
        // Only proceed if all credentials are present
        return;
      }
      emit(state.copyWith(isLoading: true, error: null));
      try {
        final databases = await apiService.fetchDatabases(
          serverIP: _lastServerIP,
          userName: _lastUserName,
          password: _lastPassword,
        );
        emit(state.copyWith(
          isLoading: false,
          availableDatabases: databases,
          // Set databaseName to the first available if current is not in the list
          // or if current is empty/null, otherwise keep current.
          databaseName: databases.isNotEmpty && !databases.contains(state.databaseName)
              ? databases.first
              : state.databaseName,
          error: null,
        ));
      } catch (e) {
        emit(state.copyWith(
          isLoading: false,
          availableDatabases: [], // Clear databases on error
          error: 'Failed to fetch databases: $e',
        ));
      }
    });

    on<UpdateApiServerURL>((event, emit) {
      if (event.apiServerURL != state.apiServerURL) {
        emit(state.copyWith(apiServerURL: event.apiServerURL, selectedConfigId: null));
      }
    });

    on<ParseParameters>((event, emit) {
      try {
        final newParameters = _parseUrlParameters(state.apiServerURL);
        final mergedParameters = _mergeParameters(state.parameters, newParameters);
        emit(state.copyWith(parameters: List.from(mergedParameters), error: null));
      } catch (e) {
        emit(state.copyWith(parameters: [], error: 'Failed to parse URL parameters'));
      }
    });

    on<UpdateApiName>((event, emit) {
      if (event.apiName != state.apiName) {
        emit(state.copyWith(apiName: event.apiName, selectedConfigId: null));
      }
    });

    on<UpdateParameterValue>((event, emit) {
      final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
      if (event.index >= 0 && event.index < updatedParameters.length) {
        updatedParameters[event.index] = {
          ...updatedParameters[event.index],
          'value': event.value,
        };
        emit(state.copyWith(parameters: List.from(updatedParameters), selectedConfigId: null));
      }
    });

    on<UpdateParameterShow>((event, emit) {
      final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
      if (event.index >= 0 && event.index < updatedParameters.length) {
        updatedParameters[event.index] = {
          ...updatedParameters[event.index],
          'show': event.show,
        };
        emit(state.copyWith(parameters: List.from(updatedParameters), selectedConfigId: null));
      }
    });

    on<UpdateParameterFieldLabel>((event, emit) {
      final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
      if (event.index >= 0 && event.index < updatedParameters.length) {
        updatedParameters[event.index] = {
          ...updatedParameters[event.index],
          'field_label': event.fieldLabel,
        };
        emit(state.copyWith(parameters: List.from(updatedParameters), selectedConfigId: null));
      }
    });

    on<SaveDatabaseServer>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null));
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
        emit(state.copyWith(isLoading: false, selectedConfigId: null)); // Clear selection on save
        add(const FetchSavedConfigurations()); // Refresh saved list
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<ResetAdminState>((event, emit) {
      // Clear internal tracking variables on reset
      _lastServerIP = '';
      _lastUserName = '';
      _lastPassword = '';
      emit(ReportAdminState()); // Reset to initial state
      add(const FetchSavedConfigurations()); // Re-fetch available configurations
    });

    on<FetchSavedConfigurations>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null));
      try {
        final Map<String, dynamic> response = await apiService.getSetupConfigurations();

        if (response['status'] == 'success' && response['data'] is List) {
          final List<Map<String, dynamic>> configs = (response['data'] as List)
              .cast<Map<String, dynamic>>();

          configs.sort((a, b) => (a['ConfigName'] as String? ?? '').compareTo(b['ConfigName'] as String? ?? ''));
          emit(state.copyWith(
            isLoading: false,
            savedConfigurations: configs,
            error: null,
          ));
        } else {
          emit(state.copyWith(
            isLoading: false,
            error: 'Failed to load saved configurations: Unexpected response format',
            savedConfigurations: [],
          ));
        }
      } catch (e) {
        emit(state.copyWith(
          isLoading: false,
          error: 'Failed to load saved configurations: ${e.toString()}',
          savedConfigurations: [],
        ));
      }
    });

    on<SelectSavedConfiguration>((event, emit) {
      final selectedConfig = state.savedConfigurations.firstWhere(
            (config) => config['ConfigID'].toString() == event.configId,
        orElse: () => <String, dynamic>{}, // Return empty map if not found
      );

      if (selectedConfig.isNotEmpty) {
        final String serverIP = selectedConfig['ServerIP']?.toString() ?? '';
        final String userName = selectedConfig['UserName']?.toString() ?? '';
        final String password = selectedConfig['password']?.toString() ?? ''; // Make sure key matches your API: 'password' (lowercase) or 'Password'
        final String databaseName = selectedConfig['DatabaseName']?.toString() ?? '';
        final String apiServerURL = selectedConfig['APIServerURl']?.toString() ?? '';
        final String apiName = selectedConfig['APIName']?.toString() ?? '';

        List<Map<String, dynamic>> parsedParams = [];
        // Attempt to decode JSON parameters first if the 'Parameter' field exists and is not empty
        if (selectedConfig['Parameter'] != null && selectedConfig['Parameter'].toString().isNotEmpty) {
          try {
            parsedParams = (jsonDecode(selectedConfig['Parameter'].toString()) as List)
                .cast<Map<String, dynamic>>();
            print('Bloc: Decoded parameters from JSON: $parsedParams'); // Debug print
          } catch (e) {
            print('Bloc: Error decoding parameters from JSON: $e. Falling back to URL parsing.'); // Debug print
            parsedParams = _parseUrlParameters(apiServerURL); // Fallback to URL parsing
          }
        } else {
          print('Bloc: Parameter field is empty or null. Parsing parameters from API URL.'); // Debug print
          parsedParams = _parseUrlParameters(apiServerURL); // If 'Parameter' is empty, parse from URL
        }

        // Debug print the password before emitting
        print('Bloc: SelectSavedConfiguration - Password to be set in state: $password');

        // Emit the new state with all selected configuration details
        emit(state.copyWith(
          serverIP: serverIP,
          userName: userName,
          password: password,
          databaseName: databaseName,
          apiServerURL: apiServerURL,
          apiName: apiName,
          parameters: parsedParams,
          selectedConfigId: event.configId,
          error: null,
        ));

        // CRITICAL: Update the internal tracking variables BEFORE triggering FetchDatabases
        _lastServerIP = serverIP;
        _lastUserName = userName;
        _lastPassword = password;

        _triggerFetchDatabases(); // Trigger database fetch for the newly selected configuration
      } else {
        // If config not found, reset selectedId and show error
        emit(state.copyWith(error: 'Selected configuration not found.', selectedConfigId: null));
      }
    });

    // This immediately fetches saved configurations when the Bloc is created
    add(const FetchSavedConfigurations());
  }

  // Helper method to trigger FetchDatabases if all required credentials are available
  void _triggerFetchDatabases() {
    if (_lastServerIP.isNotEmpty && _lastUserName.isNotEmpty && _lastPassword.isNotEmpty) {
      add(FetchDatabases());
    }
  }

  // Parses URL query parameters into a list of maps
  List<Map<String, dynamic>> _parseUrlParameters(String url) {
    if (url.isEmpty) return [];
    try {
      final uri = Uri.parse(url);
      final queryParameters = uri.queryParametersAll;
      return queryParameters.entries.expand((entry) {
        final key = entry.key;
        final values = entry.value;
        return values.map((value) {
          return {
            'name': key,
            'value': value ?? '',
            'show': false,
            'field_label': '',
          };
        });
      }).toList();
    } catch (e) {
      throw Exception('Invalid URL format: $e');
    }
  }

  // Merges new parameters with existing ones, preserving existing values and properties if names match
  List<Map<String, dynamic>> _mergeParameters(
      List<Map<String, dynamic>> existing, List<Map<String, dynamic>> newParams) {
    final merged = <Map<String, dynamic>>[];
    final existingMap = {
      for (var param in existing) param['name']: param, // Map existing by 'name' for quick lookup
    };

    // Add new parameters, merging with existing if names match
    for (var newParam in newParams) {
      final name = newParam['name'];
      if (existingMap.containsKey(name)) {
        merged.add({
          'name': name,
          'value': existingMap[name]!['value'], // Keep existing value
          'show': existingMap[name]!['show'] ?? false, // Keep existing 'show'
          'field_label': existingMap[name]!['field_label'] ?? '', // Keep existing 'field_label'
        });
      } else {
        merged.add(newParam); // Add new parameter as is
      }
    }

    // Add back any existing parameters that are no longer present in newParams (i.e., removed from URL)
    // This part ensures that if a parameter was manually configured (show/label) but later
    // removed from the URL, its configured state is still preserved if needed.
    // However, for typical URL parsing, you might only want parameters currently in the URL.
    // Consider if you really need to preserve "old" parameters. If not, remove this loop.
    for (var existingParam in existing) {
      if (!newParams.any((p) => p['name'] == existingParam['name'])) {
        merged.add(existingParam);
      }
    }

    return merged;
  }
}