import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../ReportAPIService.dart';

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
UpdateParameterValue(this.index, this.value);
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
apiServerURl: apiData['APIServerURl'] ?? '',
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
on<UpdateParameterFieldLabel>(_onUpdateParameterFieldLabel);
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
print('Processing UpdateApiName event with value: ${event.apiName}');
print('Current state.apiName: ${state.apiName}');
emit(state.copyWith(apiName: event.apiName));
print('New state.apiName: ${state.apiName}');
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

void _onUpdateParameterFieldLabel(UpdateParameterFieldLabel event, Emitter<EditDetailAdminState> emit) {
final updatedParameters = List<Map<String, dynamic>>.from(state.parameters);
updatedParameters[event.index] = {
...updatedParameters[event.index],
'field_label': event.fieldLabel,
};
emit(state.copyWith(parameters: updatedParameters));
}

Future<void> _onSaveChanges(SaveChanges event, Emitter<EditDetailAdminState> emit) async {
print('Saving changes with state:');
print('  id: ${state.id}');
print('  serverIP: ${state.serverIP}');
print('  userName: ${state.userName}');
print('  password: ${state.password}');
print('  databaseName: ${state.databaseName}');
print('  apiServerURl: ${state.apiServerURl}');
print('  apiName: ${state.apiName}');
print('  parameters: ${state.parameters}');
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
print('editDatabaseServer API call successful');
emit(state.copyWith(isLoading: false, saveInitiated: true));
} catch (e) {
print('editDatabaseServer API call failed: $e');
emit(state.copyWith(isLoading: false, error: e.toString(), saveInitiated: false));
}
}
}
