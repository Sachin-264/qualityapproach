import 'package:flutter_bloc/flutter_bloc.dart';
import '../../ReportAPIService.dart';
import 'package:intl/intl.dart';
import 'dart:async';

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
  final String apiServerURL;
  UpdateApiServerURL(this.apiServerURL);
}

class UpdateApiName extends EditDetailAdminEvent {
  final String apiName;
  UpdateApiName(this.apiName);
}

class UpdateParameterValue extends EditDetailAdminEvent {
  final int index;
  final String value;
  UpdateParameterValue(this.index, this.value);
}

class UpdateParameterShow extends EditDetailAdminEvent {
  final int index;
  final bool show;
  UpdateParameterShow(this.index, this.show);
}

class SaveChanges extends EditDetailAdminEvent {}

// State
class EditDetailAdminState {
  final String id;
  final String serverIP;
  final String userName;
  final String password;
  final String databaseName;
  final String apiServerURL;
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
    required this.apiServerURL,
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
    String? apiServerURL,
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
      apiServerURL: apiServerURL ?? this.apiServerURL,
      apiName: apiName ?? this.apiName,
      parameters: parameters ?? this.parameters,
      availableDatabases: availableDatabases ?? this.availableDatabases,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      saveInitiated: saveInitiated ?? this.saveInitiated,
    );
  }
}

// BLoC
class EditDetailAdminBloc extends Bloc<EditDetailAdminEvent, EditDetailAdminState> {
  final ReportAPIService apiService;

  EditDetailAdminBloc(this.apiService, Map<String, dynamic> apiData)
      : super(EditDetailAdminState(
    id: apiData['id']?.toString() ?? '',
    serverIP: apiData['ServerIP'] ?? '',
    userName: apiData['UserName'] ?? '',
    password: apiData['Password'] ?? '',
    databaseName: apiData['DatabaseName'] ?? '',
    apiServerURL: apiData['APIServerURl'] ?? '',
    apiName: apiData['APIName'] ?? '',
    parameters: List<Map<String, dynamic>>.from(apiData['Parameter'] ?? []),
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
    emit(state.copyWith(apiServerURL: event.apiServerURL));
  }

  void _onUpdateApiName(UpdateApiName event, Emitter<EditDetailAdminState> emit) {
    emit(state.copyWith(apiName: event.apiName));
  }

  void _onUpdateParameterValue(UpdateParameterValue event, Emitter<EditDetailAdminState> emit) {
    final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
    updatedParameters[event.index] = {
      ...updatedParameters[event.index],
      'value': event.value,
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

  Future<void> _onSaveChanges(SaveChanges event, Emitter<EditDetailAdminState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, saveInitiated: true));
    try {
      await apiService.editDatabaseServer(
        id: state.id,
        serverIP: state.serverIP,
        userName: state.userName,
        password: state.password,
        databaseName: state.databaseName,
        apiServerURL: state.apiServerURL,
        apiName: state.apiName,
        parameters: state.parameters,
      );
      emit(state.copyWith(isLoading: false, saveInitiated: true)); // Keep saveInitiated true for listener
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString(), saveInitiated: false));
    }
  }
}