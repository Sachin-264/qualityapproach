// lib/Report/Report_MakeBLoc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qualityapproach/ReportDynamic/ReportMakeEdit/EditDetailMaker.dart';
import 'ReportAPIService.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:collection/collection.dart';

class ReportMakerEvent {}

class LoadApis extends ReportMakerEvent {}

class FetchApiData extends ReportMakerEvent {
  final String apiName;
  FetchApiData(this.apiName);
}

class SelectField extends ReportMakerEvent {
  final String field;
  SelectField(this.field);
}

class DeselectField extends ReportMakerEvent {
  final String field;
  DeselectField(this.field);
}

class UpdateFieldConfig extends ReportMakerEvent {
  final String key;
  final dynamic value;
  UpdateFieldConfig(this.key, this.value);
}

class UpdateCurrentField extends ReportMakerEvent {
  final Map<String, dynamic> field;
  UpdateCurrentField(this.field);
}

class SaveReport extends ReportMakerEvent {
  final String reportName;
  final String reportLabel;
  final String apiName;
  final String parameter;
  final String ucode;
  final bool needsAction;
  final List<Map<String, dynamic>> actions;
  final bool includePdfFooterDateTime;

  SaveReport({
    required this.reportName,
    required this.reportLabel,
    required this.apiName,
    required this.parameter,
    required this.ucode,
    required this.needsAction,
    required this.actions,
    required this.includePdfFooterDateTime,
  });
}

class ResetFields extends ReportMakerEvent {}

class ReorderFields extends ReportMakerEvent {
  final int oldIndex;
  final int newIndex;
  ReorderFields(this.oldIndex, this.newIndex);
}

class ToggleFieldApiDriven extends ReportMakerEvent {
  final bool isApiDriven;
  ToggleFieldApiDriven(this.isApiDriven);
}
class UpdateFieldApiUrl extends ReportMakerEvent {
  final String apiUrl;
  UpdateFieldApiUrl(this.apiUrl);
}
class ToggleFieldUserFilling extends ReportMakerEvent {
  final bool isUserFilling;
  ToggleFieldUserFilling(this.isUserFilling);
}
class UpdateFieldUserFillingUrl extends ReportMakerEvent {
  final String updatedUrl;
  UpdateFieldUserFillingUrl(this.updatedUrl);
}
class AddFieldPayloadParameter extends ReportMakerEvent {
  final String paramId;
  AddFieldPayloadParameter(this.paramId);
}
class RemoveFieldPayloadParameter extends ReportMakerEvent {
  final String paramId;
  RemoveFieldPayloadParameter(this.paramId);
}
class UpdateFieldPayloadParameter extends ReportMakerEvent {
  final String paramId;
  final String key;
  final dynamic value;
  UpdateFieldPayloadParameter(this.paramId, this.key, this.value);
}
class ToggleFieldPayloadParameterUserInput extends ReportMakerEvent {
  final String fieldName;
  final String paramId;
  final bool value;
  ToggleFieldPayloadParameterUserInput(this.fieldName, this.paramId, this.value);
}
class ExtractFieldParametersFromUrl extends ReportMakerEvent {
  final String fieldName;
  final String apiUrl;
  ExtractFieldParametersFromUrl(this.fieldName, this.apiUrl);
}
class ToggleNeedsActionEvent extends ReportMakerEvent {
  final bool needsAction;
  ToggleNeedsActionEvent(this.needsAction);
}
class AddAction extends ReportMakerEvent {
  final String type;
  final String id;
  AddAction(this.type, this.id);
}
class RemoveAction extends ReportMakerEvent {
  final String id;
  RemoveAction(this.id);
}
class UpdateActionConfig extends ReportMakerEvent {
  final String actionId;
  final String key;
  final dynamic value;
  UpdateActionConfig(this.actionId, this.key, this.value);
}
class AddActionParameter extends ReportMakerEvent {
  final String actionId;
  final String paramId;
  AddActionParameter(this.actionId, this.paramId);
}
class RemoveActionParameter extends ReportMakerEvent {
  final String actionId;
  final String paramId;
  RemoveActionParameter(this.actionId, this.paramId);
}
class UpdateActionParameter extends ReportMakerEvent {
  final String actionId;
  final String paramId;
  final String key;
  final dynamic value;
  UpdateActionParameter(this.actionId, this.paramId, this.key, this.value);
}
class ExtractParametersFromUrlForAction extends ReportMakerEvent {
  final String actionId;
  final String apiUrl;
  ExtractParametersFromUrlForAction(this.actionId, this.apiUrl);
}
class FetchParametersFromApiConfig extends ReportMakerEvent {
  final String actionId;
  final String apiName;
  FetchParametersFromApiConfig(this.actionId, this.apiName);
}
class UpdateTableActionReport extends ReportMakerEvent {
  final String actionId;
  final String reportLabel;
  UpdateTableActionReport(this.actionId, this.reportLabel);
}
class ToggleIncludePdfFooterDateTime extends ReportMakerEvent {
  final bool include;
  ToggleIncludePdfFooterDateTime(this.include);
}

class ReportMakerState {
  final List<String> apis;
  final List<String> fields;
  final List<Map<String, dynamic>> selectedFields;
  final Map<String, dynamic>? currentField;
  final bool isLoading;
  final String? error;
  final bool saveSuccess;
  final bool needsAction;
  final List<Map<String, dynamic>> actions;
  final Map<String, List<String>> apiParametersCache;
  final bool isFetchingApiParams;
  final String? currentActionIdFetching;
  final Map<String, List<String>> fieldApiParametersCache;
  final bool isFetchingFieldApiParams;
  final String? currentFieldIdFetchingParams;
  final List<String> allReportLabels;
  final Map<String, Map<String, dynamic>> reportDetailsMap;
  final Map<String, Map<String, dynamic>> allApisDetails;
  final bool includePdfFooterDateTime;

  ReportMakerState({
    this.apis = const [],
    this.fields = const [],
    this.selectedFields = const [],
    this.currentField,
    this.isLoading = false,
    this.error,
    this.saveSuccess = false,
    this.needsAction = false,
    this.actions = const [],
    this.apiParametersCache = const {},
    this.isFetchingApiParams = false,
    this.currentActionIdFetching,
    this.fieldApiParametersCache = const {},
    this.isFetchingFieldApiParams = false,
    this.currentFieldIdFetchingParams,
    this.allReportLabels = const [],
    this.reportDetailsMap = const {},
    this.allApisDetails = const {},
    this.includePdfFooterDateTime = false,
  });

  ReportMakerState copyWith({
    List<String>? apis,
    List<String>? fields,
    List<Map<String, dynamic>>? selectedFields,
    Map<String, dynamic>? currentField,
    bool? isLoading,
    String? error,
    bool? saveSuccess,
    bool? needsAction,
    List<Map<String, dynamic>>? actions,
    Map<String, List<String>>? apiParametersCache,
    bool? isFetchingApiParams,
    String? currentActionIdFetching,
    Map<String, List<String>>? fieldApiParametersCache,
    bool? isFetchingFieldApiParams,
    String? currentFieldIdFetchingParams,
    List<String>? allReportLabels,
    Map<String, Map<String, dynamic>>? reportDetailsMap,
    Map<String, Map<String, dynamic>>? allApisDetails,
    bool? includePdfFooterDateTime,
  }) {
    return ReportMakerState(
      apis: apis ?? this.apis,
      fields: fields ?? this.fields,
      selectedFields: selectedFields ?? this.selectedFields,
      currentField: currentField ?? this.currentField,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      saveSuccess: saveSuccess ?? this.saveSuccess,
      needsAction: needsAction ?? this.needsAction,
      actions: actions ?? this.actions,
      apiParametersCache: apiParametersCache ?? this.apiParametersCache,
      isFetchingApiParams: isFetchingApiParams ?? this.isFetchingApiParams,
      currentActionIdFetching: currentActionIdFetching,
      fieldApiParametersCache: fieldApiParametersCache ?? this.fieldApiParametersCache,
      isFetchingFieldApiParams: isFetchingFieldApiParams ?? this.isFetchingFieldApiParams,
      currentFieldIdFetchingParams: currentFieldIdFetchingParams,
      allReportLabels: allReportLabels ?? this.allReportLabels,
      reportDetailsMap: reportDetailsMap ?? this.reportDetailsMap,
      allApisDetails: allApisDetails ?? this.allApisDetails,
      includePdfFooterDateTime: includePdfFooterDateTime ?? this.includePdfFooterDateTime,
    );
  }
}

class ReportMakerBloc extends Bloc<ReportMakerEvent, ReportMakerState> {
  final ReportAPIService apiService;
  final Uuid _uuid = const Uuid();

  ReportMakerBloc(this.apiService) : super(ReportMakerState()) {
    on<LoadApis>(_onLoadApis);
    on<FetchApiData>(_onFetchApiData);
    on<SelectField>(_onSelectField);
    on<DeselectField>(_onDeselectField);
    on<UpdateFieldConfig>(_onUpdateFieldConfig);
    on<UpdateCurrentField>(_onUpdateCurrentField);
    on<SaveReport>(_onSaveReport);
    on<ResetFields>(_onResetFields);
    on<ReorderFields>(_onReorderFields);
    on<ToggleFieldApiDriven>(_onToggleFieldApiDriven);
    on<UpdateFieldApiUrl>(_onUpdateFieldApiUrl);
    on<ToggleFieldUserFilling>(_onToggleFieldUserFilling);
    on<UpdateFieldUserFillingUrl>(_onUpdateFieldUserFillingUrl);
    on<AddFieldPayloadParameter>(_onAddFieldPayloadParameter);
    on<RemoveFieldPayloadParameter>(_onRemoveFieldPayloadParameter);
    on<UpdateFieldPayloadParameter>(_onUpdateFieldPayloadParameter);
    on<ToggleFieldPayloadParameterUserInput>(_onToggleFieldPayloadParameterUserInput);
    on<ExtractFieldParametersFromUrl>(_onExtractFieldParametersFromUrl);
    on<ToggleNeedsActionEvent>(_onToggleNeedsAction);
    on<AddAction>(_onAddAction);
    on<RemoveAction>(_onRemoveAction);
    on<UpdateActionConfig>(_onUpdateActionConfig);
    on<AddActionParameter>(_onAddActionParameter);
    on<RemoveActionParameter>(_onRemoveActionParameter);
    on<UpdateActionParameter>(_onUpdateActionParameter);
    on<ExtractParametersFromUrlForAction>(_onExtractParametersFromUrlForAction);
    on<FetchParametersFromApiConfig>(_onFetchParametersFromApiConfig);
    on<UpdateTableActionReport>(_onUpdateTableActionReport);
    on<ToggleIncludePdfFooterDateTime>(_onToggleIncludePdfFooterDateTime);
  }

  Future<void> _onLoadApis(LoadApis event, Emitter<ReportMakerState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final results = await Future.wait<dynamic>([
        apiService.getAvailableApis(),
        apiService.fetchDemoTable().catchError((e) => <Map<String, dynamic>>[]),
      ]);
      final List<String> apis = results[0];
      final List<Map<String, dynamic>> allReports = results[1];
      final Map<String, Map<String, dynamic>> reportDetailsMap = {
        for (var report in allReports) report['Report_label'].toString(): report
      };
      final List<String> availableReportLabels = reportDetailsMap.keys.toList();
      emit(state.copyWith(
        apis: apis,
        allReportLabels: availableReportLabels,
        reportDetailsMap: reportDetailsMap,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to load APIs: $e', isLoading: false));
    }
  }

  Future<void> _onFetchApiData(FetchApiData event, Emitter<ReportMakerState> emit) async {
    emit(state.copyWith(isLoading: true, error: null, fields: [], selectedFields: [], currentField: null));
    try {
      final data = await apiService.fetchApiData(event.apiName);
      final fields = data.isNotEmpty ? data[0].keys.toList().cast<String>() : <String>[];
      emit(state.copyWith(fields: fields, isLoading: false, error: null));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to fetch API data: $e'));
    }
  }

  void _onSelectField(SelectField event, Emitter<ReportMakerState> emit) {
    if (state.selectedFields.any((f) => f['Field_name'] == event.field)) return;
    final newField = {
      'Field_name': event.field,
      'Field_label': event.field,
      'Sequence_no': state.selectedFields.length + 1,
      'width': 100,
      'Total': false,
      'num_alignment': 'left',
      'time': false,
      'indian_format': false,
      'decimal_points': 0,
      'Breakpoint': false,
      'SubTotal': false,
      'image': false,
      'Group_by': false,
      'Filter': false,
      'filterJson': '',
      'orderby': false,
      'orderjson': '',
      'groupjson': '',
      'is_api_driven': false,
      'api_url': '',
      'field_params': <Map<String, dynamic>>[],
      'is_user_filling': false,
      'updated_url': '',
      'payload_structure': <Map<String, dynamic>>[],
    };
    final updatedFields = [...state.selectedFields, newField];
    emit(state.copyWith(selectedFields: updatedFields, currentField: newField));
  }

  void _onDeselectField(DeselectField event, Emitter<ReportMakerState> emit) {
    final updatedFields = state.selectedFields
        .where((f) => f['Field_name'] != event.field)
        .toList()
        .asMap()
        .map((index, f) => MapEntry(index, {...f, 'Sequence_no': index + 1}))
        .values
        .toList();
    Map<String, dynamic>? newCurrentField = state.currentField;
    if (state.currentField?['Field_name'] == event.field) {
      newCurrentField = updatedFields.isNotEmpty ? updatedFields.first : null;
    }
    emit(state.copyWith(selectedFields: updatedFields, currentField: newCurrentField));
  }

  void _onUpdateFieldConfig(UpdateFieldConfig event, Emitter<ReportMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = {...state.currentField!, event.key: event.value};
    final updatedFields = state.selectedFields
        .map((field) =>
    field['Field_name'] == state.currentField!['Field_name']
        ? updatedField
        : field)
        .toList()
      ..sort((a, b) =>
          (a['Sequence_no'] as int? ?? 9999)
              .compareTo(b['Sequence_no'] as int? ?? 9999));
    emit(state.copyWith(
        selectedFields: updatedFields, currentField: updatedField));
  }

  void _onUpdateCurrentField(UpdateCurrentField event, Emitter<ReportMakerState> emit) {
    emit(state.copyWith(currentField: event.field));
  }

  void _onReorderFields(ReorderFields event, Emitter<ReportMakerState> emit) {
    final List<Map<String, dynamic>> reorderedFields =
    List.from(state.selectedFields);
    int newIndex = event.newIndex;
    if (newIndex > event.oldIndex) {
      newIndex -= 1;
    }
    final Map<String, dynamic> item =
    reorderedFields.removeAt(event.oldIndex);
    reorderedFields.insert(newIndex, item);
    for (int i = 0; i < reorderedFields.length; i++) {
      reorderedFields[i] = {...reorderedFields[i], 'Sequence_no': i + 1};
    }
    emit(state.copyWith(selectedFields: reorderedFields));
  }

  Future<void> _onSaveReport(SaveReport event, Emitter<ReportMakerState> emit) async {
    if (state.selectedFields.isEmpty) {
      emit(state.copyWith(
          isLoading: false,
          error: 'No fields selected to save.',
          saveSuccess: false));
      return;
    }
    emit(state.copyWith(isLoading: true, error: null, saveSuccess: false));
    try {
      final recNo = await apiService.saveReport(
        reportName: event.reportName,
        reportLabel: event.reportLabel,
        apiName: event.apiName,
        parameter: event.parameter,
        ucode: event.ucode,
        fields: state.selectedFields,
        actions: event.needsAction ? state.actions : [],
        includePdfFooterDateTime: event.includePdfFooterDateTime,
      );
      await apiService.saveFieldConfigs(state.selectedFields, recNo);
      emit(state.copyWith(isLoading: false, error: null, saveSuccess: true));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false,
          error: 'Failed to save report: $e',
          saveSuccess: false));
    }
  }

  void _onResetFields(ResetFields event, Emitter<ReportMakerState> emit) {
    emit(ReportMakerState(
      apis: state.apis,
      allReportLabels: state.allReportLabels,
      reportDetailsMap: state.reportDetailsMap,
    ));
  }

  void _onToggleNeedsAction(
      ToggleNeedsActionEvent event, Emitter<ReportMakerState> emit) =>
      emit(state.copyWith(needsAction: event.needsAction));
  void _onToggleIncludePdfFooterDateTime(
      ToggleIncludePdfFooterDateTime event, Emitter<ReportMakerState> emit) =>
      emit(state.copyWith(includePdfFooterDateTime: event.include));

  void _onAddAction(AddAction event, Emitter<ReportMakerState> emit) {
    if (state.actions.length >= 5) {
      emit(state.copyWith(error: 'Maximum 5 actions allowed.'));
      return;
    }
    if (event.type == 'form' && state.actions.any((a) => a['type'] == 'form')) {
      emit(state.copyWith(error: 'Only one Form action is allowed.'));
      return;
    }
    final name = '${event.type.toCapitalized()} ${state.actions.length + 1}';
    Map<String, dynamic> newAction;
    if (event.type == 'print') {
      newAction = {
        'id': event.id,
        'type': event.type,
        'name': name,
        'api': '',
        'params': <Map<String, dynamic>>[],
        'printTemplate': 'premium',
        'printColor': 'Blue'
      };
    } else if (event.type == 'graph') {
      newAction = {
        'id': event.id,
        'type': 'graph',
        'name': name,
        'graphType': 'Line Chart',
        'xAxisField': '',
        'yAxisField': '',
      };
    } else {
      newAction = {
        'id': event.id,
        'type': event.type,
        'name': name,
        'api': '',
        'reportLabel': '',
        'apiName_resolved': '',
        'recNo_resolved': '',
        'params': <Map<String, dynamic>>[]
      };
    }
    emit(state.copyWith(actions: [...state.actions, newAction], error: null));
  }

  void _onRemoveAction(RemoveAction event, Emitter<ReportMakerState> emit) {
    final updatedActions = state.actions.where((a) => a['id'] != event.id).toList();
    final updatedCache = Map<String, List<String>>.from(state.apiParametersCache)..remove(event.id);
    emit(state.copyWith(actions: updatedActions, apiParametersCache: updatedCache));
  }

  void _onUpdateActionConfig(UpdateActionConfig event, Emitter<ReportMakerState> emit) {
    final updatedActions = state.actions.map((a) => a['id'] == event.actionId ? {...a, event.key: event.value} : a).toList();
    emit(state.copyWith(actions: updatedActions));
  }

  void _onAddActionParameter(AddActionParameter event, Emitter<ReportMakerState> emit) {
    final updatedActions = state.actions.map((action) {
      if (action['id'] == event.actionId) {
        final params = List<Map<String, dynamic>>.from(action['params'] ?? []);
        params.add({'id': event.paramId, 'parameterName': '', 'parameterValue': ''});
        return {...action, 'params': params};
      }
      return action;
    }).toList();
    emit(state.copyWith(actions: updatedActions));
  }

  void _onRemoveActionParameter(RemoveActionParameter event, Emitter<ReportMakerState> emit) {
    final updatedActions = state.actions.map((action) {
      if (action['id'] == event.actionId) {
        final params = (action['params'] as List? ?? []).where((p) => p['id'] != event.paramId).toList();
        return {...action, 'params': params};
      }
      return action;
    }).toList();
    emit(state.copyWith(actions: updatedActions));
  }

  void _onUpdateActionParameter(UpdateActionParameter event, Emitter<ReportMakerState> emit) {
    final updatedActions = state.actions.map((action) {
      if (action['id'] == event.actionId) {
        final params = (action['params'] as List? ?? []).map((p) => p['id'] == event.paramId ? {...p, event.key: event.value} : p).toList();
        return {...action, 'params': params};
      }
      return action;
    }).toList();
    emit(state.copyWith(actions: updatedActions));
  }

  Future<void> _onExtractParametersFromUrlForAction(ExtractParametersFromUrlForAction event, Emitter<ReportMakerState> emit) async {
    emit(state.copyWith(isFetchingApiParams: true, currentActionIdFetching: event.actionId));
    try {
      final uri = Uri.tryParse(event.apiUrl);
      final parameters = uri?.queryParameters.keys.where((k) => !['type', 'ucode', 'val8'].contains(k.toLowerCase())).toList() ?? [];
      final updatedCache = {...state.apiParametersCache, event.actionId: parameters};
      final updatedActions = state.actions.map((f) {
        if (f['id'] == event.actionId) {
          final currentParams = (f['params'] as List? ?? []).cast<Map<String, dynamic>>();
          final newParams = parameters.map((name) => currentParams.firstWhere((p) => p['parameterName'] == name, orElse: () => {'id': _uuid.v4(), 'parameterName': name, 'parameterValue': ''})).toList();
          return {...f, 'params': newParams};
        }
        return f;
      }).toList();
      emit(state.copyWith(apiParametersCache: updatedCache, actions: updatedActions, isFetchingApiParams: false, currentActionIdFetching: null));
    } catch (e) {
      emit(state.copyWith(isFetchingApiParams: false, currentActionIdFetching: null, error: e.toString()));
    }
  }

  Future<void> _onFetchParametersFromApiConfig(FetchParametersFromApiConfig event, Emitter<ReportMakerState> emit) async {
    emit(state.copyWith(isFetchingApiParams: true, currentActionIdFetching: event.actionId));
    try {
      final apiDetail = await apiService.getApiDetails(event.apiName);
      final rawParams = apiDetail['parameters'] as List? ?? [];
      final parameterNames = rawParams.map((p) => p['name']?.toString()).where((n) => n != null && !['type', 'ucode', 'val8'].contains(n.toLowerCase())).cast<String>().toList();
      final updatedCache = {...state.apiParametersCache, event.actionId: parameterNames};
      final updatedActions = state.actions.map((f) {
        if (f['id'] == event.actionId) {
          final currentParams = (f['params'] as List? ?? []).cast<Map<String, dynamic>>();
          final newParams = parameterNames.map((name) => currentParams.firstWhere((p) => p['parameterName'] == name, orElse: () => {'id': _uuid.v4(), 'parameterName': name, 'parameterValue': ''})).toList();
          return {...f, 'params': newParams};
        }
        return f;
      }).toList();
      emit(state.copyWith(apiParametersCache: updatedCache, actions: updatedActions, isFetchingApiParams: false, currentActionIdFetching: null));
    } catch (e) {
      emit(state.copyWith(isFetchingApiParams: false, currentActionIdFetching: null, error: 'Failed to fetch API params: $e'));
    }
  }

  Future<void> _onUpdateTableActionReport(UpdateTableActionReport event, Emitter<ReportMakerState> emit) async {
    final actionIndex = state.actions.indexWhere((a) => a['id'] == event.actionId);
    if (actionIndex == -1) return;
    final updatedActions = List<Map<String, dynamic>>.from(state.actions);
    final selectedReportData = state.reportDetailsMap[event.reportLabel];
    if (event.reportLabel.isEmpty || selectedReportData == null) {
      updatedActions[actionIndex] = {...updatedActions[actionIndex], 'reportLabel': event.reportLabel, 'api': '', 'apiName_resolved': '', 'recNo_resolved': '', 'params': <Map<String, dynamic>>[]};
      emit(state.copyWith(actions: updatedActions));
      return;
    }
    String? resolvedApiName = selectedReportData['API_name']?.toString();
    if (resolvedApiName == null || resolvedApiName.isEmpty) {
      emit(state.copyWith(error: 'Selected report has no API name.'));
      return;
    }
    try {
      final apiDetail = await apiService.getApiDetails(resolvedApiName);
      updatedActions[actionIndex] = {
        ...updatedActions[actionIndex],
        'reportLabel': event.reportLabel,
        'api': apiDetail['url']?.toString() ?? '',
        'apiName_resolved': resolvedApiName,
        'recNo_resolved': selectedReportData['RecNo']?.toString(),
        'params': <Map<String, dynamic>>[],
      };
      emit(state.copyWith(actions: updatedActions));
      add(FetchParametersFromApiConfig(event.actionId, resolvedApiName));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to get details for API: $resolvedApiName. Error: $e'));
    }
  }

  void _onToggleFieldApiDriven(ToggleFieldApiDriven event, Emitter<ReportMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = Map<String, dynamic>.from(state.currentField!);
    updatedField['is_api_driven'] = event.isApiDriven;
    if (event.isApiDriven) {
      updatedField['is_user_filling'] = false;
      updatedField['updated_url'] = '';
      updatedField['payload_structure'] = <Map<String, dynamic>>[];
    } else {
      updatedField['api_url'] = '';
      updatedField['field_params'] = <Map<String, dynamic>>[];
    }
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onUpdateFieldApiUrl(UpdateFieldApiUrl event, Emitter<ReportMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = {...state.currentField!, 'api_url': event.apiUrl};
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onToggleFieldUserFilling(ToggleFieldUserFilling event, Emitter<ReportMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = Map<String, dynamic>.from(state.currentField!);
    updatedField['is_user_filling'] = event.isUserFilling;
    if (event.isUserFilling) {
      updatedField['is_api_driven'] = false;
      updatedField['api_url'] = '';
      updatedField['field_params'] = <Map<String, dynamic>>[];
    } else {
      updatedField['updated_url'] = '';
      updatedField['payload_structure'] = <Map<String, dynamic>>[];
    }
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onUpdateFieldUserFillingUrl(UpdateFieldUserFillingUrl event, Emitter<ReportMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = {...state.currentField!, 'updated_url': event.updatedUrl};
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onAddFieldPayloadParameter(AddFieldPayloadParameter event, Emitter<ReportMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = Map<String, dynamic>.from(state.currentField!);
    final payload = List<Map<String, dynamic>>.from(updatedField['payload_structure'] ?? []);
    payload.add({'id': event.paramId, 'key': '', 'value': '', 'value_type': 'dynamic', 'is_user_input': false});
    updatedField['payload_structure'] = payload;
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onRemoveFieldPayloadParameter(RemoveFieldPayloadParameter event, Emitter<ReportMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = Map<String, dynamic>.from(state.currentField!);
    final payload = List<Map<String, dynamic>>.from(updatedField['payload_structure'] ?? []);
    payload.removeWhere((p) => p['id'] == event.paramId);
    updatedField['payload_structure'] = payload;
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onUpdateFieldPayloadParameter(UpdateFieldPayloadParameter event, Emitter<ReportMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = Map<String, dynamic>.from(state.currentField!);
    final payload = (updatedField['payload_structure'] as List? ?? []).cast<Map<String, dynamic>>();
    final updatedPayload = payload.map((p) => p['id'] == event.paramId ? {...p, event.key: event.value} : p).toList();
    updatedField['payload_structure'] = updatedPayload;
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onToggleFieldPayloadParameterUserInput(ToggleFieldPayloadParameterUserInput event, Emitter<ReportMakerState> emit) {
    final fieldIndex = state.selectedFields.indexWhere((f) => f['Field_name'] == event.fieldName);
    if (fieldIndex == -1) return;
    final updatedFields = List<Map<String, dynamic>>.from(state.selectedFields);
    final currentField = Map<String, dynamic>.from(updatedFields[fieldIndex]);
    final payload = (currentField['payload_structure'] as List? ?? []).cast<Map<String, dynamic>>();
    final updatedPayload = payload.map((p) {
      if (p['id'] == event.paramId) return {...p, 'is_user_input': event.value};
      if (event.value) return {...p, 'is_user_input': false};
      return p;
    }).toList();
    currentField['payload_structure'] = updatedPayload;
    updatedFields[fieldIndex] = currentField;
    final updatedCurrentField = state.currentField?['Field_name'] == event.fieldName ? currentField : state.currentField;
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedCurrentField));
  }

  Future<void> _onExtractFieldParametersFromUrl(ExtractFieldParametersFromUrl event, Emitter<ReportMakerState> emit) async {
    final isCurrentField = state.currentField?['Field_name'] == event.fieldName;
    if (isCurrentField) emit(state.copyWith(isFetchingFieldApiParams: true, currentFieldIdFetchingParams: event.fieldName));
    try {
      final uri = Uri.tryParse(event.apiUrl);
      final parameters = uri?.queryParameters.keys.where((k) => !['type', 'ucode', 'val8'].contains(k.toLowerCase())).toList() ?? [];
      final updatedCache = {...state.fieldApiParametersCache, event.fieldName: parameters};
      final updatedFields = state.selectedFields.map((f) {
        if (f['Field_name'] == event.fieldName) {
          final currentParams = (f['field_params'] as List? ?? []).cast<Map<String, dynamic>>();
          final newParams = parameters.map((name) => currentParams.firstWhere((p) => p['parameterName'] == name, orElse: () => {'id': _uuid.v4(), 'parameterName': name, 'parameterValue': ''})).toList();
          return {...f, 'field_params': newParams};
        }
        return f;
      }).toList();
      final newCurrentField = isCurrentField ? updatedFields.firstWhere((f) => f['Field_name'] == event.fieldName) : state.currentField;
      emit(state.copyWith(fieldApiParametersCache: updatedCache, selectedFields: updatedFields, currentField: newCurrentField, isFetchingFieldApiParams: false, currentFieldIdFetchingParams: null));
    } catch (e) {
      emit(state.copyWith(isFetchingFieldApiParams: false, currentFieldIdFetchingParams: null, error: e.toString()));
    }
  }
}