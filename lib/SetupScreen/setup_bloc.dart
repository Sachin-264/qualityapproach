// lib/setup_feature/setup_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../ReportDynamic/ReportAPIService.dart'; // Import the API service

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

class SaveSetup extends SetupEvent {
  const SaveSetup();
}

class ResetSetup extends SetupEvent {
  const ResetSetup();
}

// --- Setup States ---
class SetupState extends Equatable {
  final String configName;
  final String serverIP;
  final String userName;
  final String password;
  final bool isLoading;
  final String? error;
  final bool isSaved; // To indicate successful save and trigger UI clear

  const SetupState({
    this.configName = '',
    this.serverIP = '',
    this.userName = '',
    this.password = '',
    this.isLoading = false,
    this.error,
    this.isSaved = false,
  });

  SetupState copyWith({
    String? configName,
    String? serverIP,
    String? userName,
    String? password,
    bool? isLoading,
    String? error, // Nullable, pass null to clear error
    bool? isSaved,
  }) {
    return SetupState(
      configName: configName ?? this.configName,
      serverIP: serverIP ?? this.serverIP,
      userName: userName ?? this.userName,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  @override
  List<Object?> get props => [
    configName,
    serverIP,
    userName,
    password,
    isLoading,
    error,
    isSaved,
  ];
}

// --- Setup Bloc ---
class SetupBloc extends Bloc<SetupEvent, SetupState> {
  final ReportAPIService _apiService; // Declare the API service

  SetupBloc(this._apiService) : super(const SetupState()) { // Inject the API service
    on<UpdateConfigName>((event, emit) {
      emit(state.copyWith(configName: event.configName, error: null, isSaved: false));
    });
    on<UpdateServerIP>((event, emit) {
      emit(state.copyWith(serverIP: event.serverIP, error: null, isSaved: false));
    });
    on<UpdateUserName>((event, emit) {
      emit(state.copyWith(userName: event.userName, error: null, isSaved: false));
    });
    on<UpdatePassword>((event, emit) {
      emit(state.copyWith(password: event.password, error: null, isSaved: false));
    });
    on<SaveSetup>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null, isSaved: false));
      try {
        // Validate fields before sending to API
        if (state.configName.isEmpty || state.serverIP.isEmpty || state.userName.isEmpty || state.password.isEmpty) {
          throw Exception('All fields are required.');
        }

        // Use the injected API service to save the configuration
        await _apiService.saveSetupConfiguration(
          configName: state.configName,
          serverIP: state.serverIP,
          userName: state.userName,
          password: state.password,
        );

        emit(state.copyWith(isLoading: false, isSaved: true, error: null));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: 'Failed to save configuration: ${e.toString()}', isSaved: false));
      }
    });
    on<ResetSetup>((event, emit) {
      emit(const SetupState());
    });
  }
}