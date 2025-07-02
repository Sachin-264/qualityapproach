// lib/setup_feature/setup_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../ReportDynamic/ReportAPIService.dart'; // Ensure this path is correct

// --- Setup Status Enum ---
enum SetupStatus {
  initial,
  loadingDatabases,
  loading,
  success,
  failure,
}

// --- Setup Events ---
abstract class SetupEvent extends Equatable {
  const SetupEvent();
  @override
  List<Object?> get props => [];
}

class UpdateConfigName extends SetupEvent {
  final String configName;
  const UpdateConfigName(this.configName);
  @override
  List<Object?> get props => [configName];
}

class UpdateServerIP extends SetupEvent {
  final String serverIP;
  const UpdateServerIP(this.serverIP);
  @override
  List<Object?> get props => [serverIP];
}

class UpdateUserName extends SetupEvent {
  final String userName;
  const UpdateUserName(this.userName);
  @override
  List<Object?> get props => [userName];
}

class UpdatePassword extends SetupEvent {
  final String password;
  const UpdatePassword(this.password);
  @override
  List<Object?> get props => [password];
}

// NEW: Event to update the connection string
class UpdateConnectionString extends SetupEvent {
  final String connectionString;
  const UpdateConnectionString(this.connectionString);
  @override
  List<Object?> get props => [connectionString];
}

class FetchDatabases extends SetupEvent {
  const FetchDatabases();
}

class UpdateDatabaseName extends SetupEvent {
  final String databaseName;
  const UpdateDatabaseName(this.databaseName);
  @override
  List<Object?> get props => [databaseName];
}

class SaveSetup extends SetupEvent {
  const SaveSetup();
}

class ResetSetup extends SetupEvent {
  const ResetSetup();
}


// --- Setup State ---
class SetupState extends Equatable {
  final SetupStatus status;
  final String configName;
  final String serverIP;
  final String userName;
  final String password;
  final String connectionString; // NEW: Added connectionString property
  final String databaseName;
  final List<String> availableDatabases;
  final String? errorMessage;

  const SetupState({
    this.status = SetupStatus.initial,
    this.configName = '',
    this.serverIP = '',
    this.userName = '',
    this.password = '',
    this.connectionString = '', // NEW: Default value
    this.databaseName = '',
    this.availableDatabases = const [],
    this.errorMessage,
  });

  SetupState copyWith({
    SetupStatus? status,
    String? configName,
    String? serverIP,
    String? userName,
    String? password,
    String? connectionString, // NEW: Added to copyWith
    String? databaseName,
    List<String>? availableDatabases,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SetupState(
      status: status ?? this.status,
      configName: configName ?? this.configName,
      serverIP: serverIP ?? this.serverIP,
      userName: userName ?? this.userName,
      password: password ?? this.password,
      connectionString: connectionString ?? this.connectionString, // NEW
      databaseName: databaseName ?? this.databaseName,
      availableDatabases: availableDatabases ?? this.availableDatabases,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    configName,
    serverIP,
    userName,
    password,
    connectionString, // NEW: Added to props
    databaseName,
    availableDatabases,
    errorMessage,
  ];
}


// --- Setup Bloc ---
class SetupBloc extends Bloc<SetupEvent, SetupState> {
  final ReportAPIService _apiService;

  SetupBloc(this._apiService) : super(const SetupState()) {
    on<UpdateConfigName>((event, emit) {
      emit(state.copyWith(configName: event.configName, status: SetupStatus.initial, clearError: true));
    });

    on<UpdateServerIP>((event, emit) {
      emit(state.copyWith(serverIP: event.serverIP, status: SetupStatus.initial, clearError: true, availableDatabases: [], databaseName: ''));
      _triggerFetchDatabases();
    });

    on<UpdateUserName>((event, emit) {
      emit(state.copyWith(userName: event.userName, status: SetupStatus.initial, clearError: true, availableDatabases: [], databaseName: ''));
      _triggerFetchDatabases();
    });

    on<UpdatePassword>((event, emit) {
      emit(state.copyWith(password: event.password, status: SetupStatus.initial, clearError: true, availableDatabases: [], databaseName: ''));
      _triggerFetchDatabases();
    });

    // NEW: Handler for updating the connection string
    on<UpdateConnectionString>((event, emit) {
      emit(state.copyWith(connectionString: event.connectionString, status: SetupStatus.initial, clearError: true));
    });

    on<UpdateDatabaseName>((event, emit) {
      emit(state.copyWith(databaseName: event.databaseName, status: SetupStatus.initial, clearError: true));
    });

    on<FetchDatabases>((event, emit) async {
      if (state.serverIP.isEmpty || state.userName.isEmpty || state.password.isEmpty) return;

      emit(state.copyWith(status: SetupStatus.loadingDatabases));
      try {
        final databases = await _apiService.fetchDatabases(
          serverIP: state.serverIP,
          userName: state.userName,
          password: state.password,
        );
        emit(state.copyWith(
          status: SetupStatus.initial,
          availableDatabases: databases,
          databaseName: databases.isNotEmpty ? databases.first : '',
          clearError: true,
        ));
      } catch (e) {
        emit(state.copyWith(
          status: SetupStatus.failure,
          errorMessage: 'Failed to fetch databases: ${e.toString()}',
          availableDatabases: [],
          databaseName: '',
        ));
      }
    });

    on<SaveSetup>((event, emit) async {
      emit(state.copyWith(status: SetupStatus.loading, clearError: true));
      try {
        // NOTE: Make sure your ReportAPIService.saveSetupConfiguration method
        // is updated to accept the `connectionString` parameter.
        await _apiService.saveSetupConfiguration(
          configName: state.configName,
          serverIP: state.serverIP,
          userName: state.userName,
          password: state.password,
          databaseName: state.databaseName,
          connectionString: state.connectionString,
        );
        emit(state.copyWith(status: SetupStatus.success));
      } catch (e) {
        emit(state.copyWith(
          status: SetupStatus.failure,
          errorMessage: 'Failed to save configuration: ${e.toString()}',
        ));
      }
    });

    on<ResetSetup>((event, emit) {
      emit(const SetupState());
    });
  }

  void _triggerFetchDatabases() {
    if (state.serverIP.isNotEmpty && state.userName.isNotEmpty && state.password.isNotEmpty) {
      add(const FetchDatabases());
    }
  }
}