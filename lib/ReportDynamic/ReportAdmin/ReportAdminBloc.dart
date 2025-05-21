import 'package:flutter_bloc/flutter_bloc.dart';
import '../ReportAPIService.dart';

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

class SaveDatabaseServer extends ReportAdminEvent {
  const SaveDatabaseServer();
}

class ResetAdminState extends ReportAdminEvent {
  const ResetAdminState();
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
    String? error,
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
    );
  }
}

class ReportAdminBloc extends Bloc<ReportAdminEvent, ReportAdminState> {
  final ReportAPIService apiService;
  String _lastServerIP = '';
  String _lastUserName = '';
  String _lastPassword = '';

  ReportAdminBloc(this.apiService) : super(ReportAdminState()) {
    on<UpdateServerIP>((event, emit) {
      if (event.serverIP != state.serverIP) {
        emit(state.copyWith(serverIP: event.serverIP));
        _lastServerIP = event.serverIP;
        _triggerFetchDatabases();
      }
    });

    on<UpdateUserName>((event, emit) {
      if (event.userName != state.userName) {
        emit(state.copyWith(userName: event.userName));
        _lastUserName = event.userName;
        _triggerFetchDatabases();
      }
    });

    on<UpdatePassword>((event, emit) {
      if (event.password != state.password) {
        emit(state.copyWith(password: event.password));
        _lastPassword = event.password;
        _triggerFetchDatabases();
      }
    });

    on<UpdateDatabaseName>((event, emit) {
      if (event.databaseName != state.databaseName) {
        emit(state.copyWith(databaseName: event.databaseName));
      }
    });

    on<FetchDatabases>((event, emit) async {
      if (_lastServerIP.isEmpty || _lastUserName.isEmpty || _lastPassword.isEmpty) {
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
          databaseName: databases.isNotEmpty && !databases.contains(state.databaseName)
              ? databases.first
              : state.databaseName,
        ));
      } catch (e) {
        emit(state.copyWith(
          isLoading: false,
          availableDatabases: [],
          error: 'Failed to fetch databases: $e',
        ));
      }
    });

    on<UpdateApiServerURL>((event, emit) {
      if (event.apiServerURL != state.apiServerURL) {
        emit(state.copyWith(apiServerURL: event.apiServerURL));
      }
    });

    on<ParseParameters>((event, emit) {
      try {
        final newParameters = _parseUrlParameters(state.apiServerURL);
        print('Parsed parameters: $newParameters');
        final mergedParameters = _mergeParameters(state.parameters, newParameters);
        print('Merged parameters: $mergedParameters');
        emit(state.copyWith(parameters: List.from(mergedParameters), error: null));
      } catch (e) {
        print('Error in ParseParameters: $e');
        emit(state.copyWith(parameters: [], error: 'Failed to parse URL parameters'));
      }
    });

    on<UpdateApiName>((event, emit) {
      if (event.apiName != state.apiName) {
        emit(state.copyWith(apiName: event.apiName));
      }
    });

    on<UpdateParameterValue>((event, emit) {
      final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
      if (event.index >= 0 && event.index < updatedParameters.length) {
        updatedParameters[event.index] = {
          ...updatedParameters[event.index],
          'value': event.value,
        };
        emit(state.copyWith(parameters: List.from(updatedParameters)));
      }
    });

    on<UpdateParameterShow>((event, emit) {
      final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
      if (event.index >= 0 && event.index < updatedParameters.length) {
        updatedParameters[event.index] = {
          ...updatedParameters[event.index],
          'show': event.show,
        };
        emit(state.copyWith(parameters: List.from(updatedParameters)));
      }
    });

    on<SaveDatabaseServer>((event, emit) async {
      print('SaveDatabaseServer State: serverIP=${state.serverIP}, '
          'userName=${state.userName}, password=${state.password}, '
          'databaseName=${state.databaseName}, apiServerURL=${state.apiServerURL}, '
          'apiName=${state.apiName}, parameters=${state.parameters}');

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
        emit(state.copyWith(isLoading: false));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<ResetAdminState>((event, emit) {
      _lastServerIP = '';
      _lastUserName = '';
      _lastPassword = '';
      emit(ReportAdminState());
    });
  }

  void _triggerFetchDatabases() {
    if (_lastServerIP.isNotEmpty && _lastUserName.isNotEmpty && _lastPassword.isNotEmpty) {
      add(FetchDatabases());
    }
  }

  List<Map<String, dynamic>> _parseUrlParameters(String url) {
    if (url.isEmpty) return [];
    try {
      final uri = Uri.parse(url);
      final queryParameters = uri.queryParametersAll;
      print('Raw query parameters: $queryParameters');
      return queryParameters.entries.expand((entry) {
        final key = entry.key;
        final values = entry.value;
        return values.map((value) {
          return {
            'name': key,
            'value': value ?? '',
            'show': false,
          };
        });
      }).toList();
    } catch (e) {
      print('Error parsing URL parameters: $e');
      throw Exception('Invalid URL format: $e');
    }
  }

  List<Map<String, dynamic>> _mergeParameters(
      List<Map<String, dynamic>> existing, List<Map<String, dynamic>> newParams) {
    final merged = <Map<String, dynamic>>[];
    final existingMap = {
      for (var param in existing) param['name']: param,
    };

    for (var newParam in newParams) {
      final name = newParam['name'];
      if (existingMap.containsKey(name)) {
        merged.add({
          'name': name,
          'value': existingMap[name]!['value'],
          'show': existingMap[name]!['show'] ?? false,
        });
      } else {
        merged.add(newParam);
      }
    }

    for (var existingParam in existing) {
      if (!newParams.any((p) => p['name'] == existingParam['name'])) {
        merged.add(existingParam);
      }
    }

    return merged;
  }
}