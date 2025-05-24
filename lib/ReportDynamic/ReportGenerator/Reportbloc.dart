
import 'package:flutter_bloc/flutter_bloc.dart';
import '../ReportAPIService.dart';

// Events
abstract class ReportEvent {}

class LoadReports extends ReportEvent {}

class FetchApiDetails extends ReportEvent {
final String apiName;
FetchApiDetails(this.apiName);
}

class UpdateParameter extends ReportEvent {
final String paramName;
final String value;
UpdateParameter(this.paramName, this.value);
}

class FetchFieldConfigs extends ReportEvent {
final String recNo;
final String apiName;
final String reportLabel;
FetchFieldConfigs(this.recNo, this.apiName, this.reportLabel);
}

class ResetReports extends ReportEvent {}

// States
class ReportState {
final bool isLoading;
final List<Map<String, dynamic>> reports;
final List<Map<String, dynamic>> fieldConfigs;
final List<Map<String, dynamic>> reportData;
final String? selectedRecNo;
final String? selectedApiName;
final String? selectedReportLabel;
final String? selectedApiUrl;
final List<Map<String, dynamic>> selectedApiParameters;
final Map<String, String> userParameterValues;
final String? error;

ReportState({
this.isLoading = false,
this.reports = const [],
this.fieldConfigs = const [],
this.reportData = const [],
this.selectedRecNo,
this.selectedApiName,
this.selectedReportLabel,
this.selectedApiUrl,
this.selectedApiParameters = const [],
this.userParameterValues = const {},
this.error,
});

ReportState copyWith({
bool? isLoading,
List<Map<String, dynamic>>? reports,
List<Map<String, dynamic>>? fieldConfigs,
List<Map<String, dynamic>>? reportData,
String? selectedRecNo,
String? selectedApiName,
String? selectedReportLabel,
String? selectedApiUrl,
List<Map<String, dynamic>>? selectedApiParameters,
Map<String, String>? userParameterValues,
String? error,
}) {
return ReportState(
isLoading: isLoading ?? this.isLoading,
reports: reports ?? this.reports,
fieldConfigs: fieldConfigs ?? this.fieldConfigs,
reportData: reportData ?? this.reportData,
selectedRecNo: selectedRecNo ?? this.selectedRecNo,
selectedApiName: selectedApiName ?? this.selectedApiName,
selectedReportLabel: selectedReportLabel ?? this.selectedReportLabel,
selectedApiUrl: selectedApiUrl ?? this.selectedApiUrl,
selectedApiParameters: selectedApiParameters ?? this.selectedApiParameters,
userParameterValues: userParameterValues ?? this.userParameterValues,
error: error,
);
}
}

class ReportBlocGenerate extends Bloc<ReportEvent, ReportState> {
final ReportAPIService apiService;

ReportBlocGenerate(this.apiService) : super(ReportState()) {
on<LoadReports>(_onLoadReports);
on<FetchApiDetails>(_onFetchApiDetails);
on<UpdateParameter>(_onUpdateParameter);
on<FetchFieldConfigs>(_onFetchFieldConfigs);
on<ResetReports>(_onResetReports);
}

Future<void> _onLoadReports(LoadReports event, Emitter<ReportState> emit) async {
emit(state.copyWith(isLoading: true, error: null));

try {
final reports = await apiService.fetchDemoTable();
emit(state.copyWith(isLoading: false, reports: reports));
print('LoadReports success: reports.length=${reports.length}, sample=${reports.isNotEmpty ? reports.first : {}}');
} catch (e) {
emit(state.copyWith(isLoading: false, error: 'Failed to load reports: $e'));
print('LoadReports error: $e');
}
}

Future<void> _onFetchApiDetails(FetchApiDetails event, Emitter<ReportState> emit) async {
emit(state.copyWith(isLoading: true, error: null));
try {
final apiDetails = await apiService.getApiDetails(event.apiName);
emit(state.copyWith(
isLoading: false,
selectedApiUrl: apiDetails['url'],
selectedApiParameters: List<Map<String, dynamic>>.from(apiDetails['parameters'] ?? []),
userParameterValues: {}, // Reset user parameter values
));
print('FetchApiDetails success: url=${apiDetails['url']}, parameters=${apiDetails['parameters']}');
} catch (e) {
emit(state.copyWith(isLoading: false, error: 'Failed to fetch API details: $e'));
print('FetchApiDetails error: $e');
}
}

void _onUpdateParameter(UpdateParameter event, Emitter<ReportState> emit) {
final updatedUserParams = Map<String, String>.from(state.userParameterValues);
updatedUserParams[event.paramName] = event.value;
emit(state.copyWith(userParameterValues: updatedUserParams));
print('UpdateParameter: paramName=${event.paramName}, value=${event.value}, updatedParams=$updatedUserParams');
}

Future<void> _onFetchFieldConfigs(FetchFieldConfigs event, Emitter<ReportState> emit) async {
emit(state.copyWith(isLoading: true, error: null));
print('FetchFieldConfigs: Starting for RecNo=${event.recNo}, apiName=${event.apiName}, reportLabel=${event.reportLabel}');
try {
// Fetch field configurations
final fieldConfigs = await apiService.fetchDemoTable2(event.recNo);
// Fetch report data with status handling
final apiResponse = await apiService.fetchApiDataWithParams(event.apiName, state.userParameterValues);
List<Map<String, dynamic>> reportData = [];
String? errorMessage;

// Handle HTTP status codes
switch (apiResponse['status']) {
case 200:
reportData = List<Map<String, dynamic>>.from(apiResponse['data'] ?? []);
break;
case 400:
errorMessage = 'Invalid parameters provided. Please check your inputs.';
break;
case 404:
errorMessage = 'API endpoint not found. Please verify the API name.';
break;
case 500:
errorMessage = 'Server error occurred. Please try again later.';
break;
default:
errorMessage = 'Unexpected response (status: ${apiResponse['status'] ?? 'unknown'}). Please try again.';
}

final newState = state.copyWith(
isLoading: false,
fieldConfigs: fieldConfigs,
reportData: reportData,
selectedRecNo: event.recNo,
selectedApiName: event.apiName,
selectedReportLabel: event.reportLabel,
error: errorMessage,
);
emit(newState);

} catch (e) {
final fieldConfigs = await apiService.fetchDemoTable2(event.recNo).catchError((_) => []);
final newState = state.copyWith(
isLoading: false,
fieldConfigs: fieldConfigs,
reportData: [],
selectedRecNo: event.recNo,
selectedApiName: event.apiName,
selectedReportLabel: event.reportLabel,
error: 'Failed to fetch report data: ${e.toString()}',
);
emit(newState);

}
}

void _onResetReports(ResetReports event, Emitter<ReportState> emit) {
final newState = ReportState();
emit(newState);
print('ResetReports: State reset, stateHash=${newState.hashCode}');
}
}
