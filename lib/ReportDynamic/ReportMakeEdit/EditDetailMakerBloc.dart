// lib/Report/EditDetailMakerBloc.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

import '../ReportAPIService.dart';

// ======== Events ========
// (No changes to events)
class EditDetailMakerEvent {
  const EditDetailMakerEvent();
}
class LoadPreselectedFields extends EditDetailMakerEvent {
  final int recNo;
  final String apiName;
  const LoadPreselectedFields(this.recNo, this.apiName);
}
class SelectField extends EditDetailMakerEvent {
  final String field;
  const SelectField(this.field);
}
class DeselectField extends EditDetailMakerEvent {
  final String field;
  const DeselectField(this.field);
}
class UpdateFieldConfig extends EditDetailMakerEvent {
  final String key;
  final dynamic value;
  const UpdateFieldConfig(this.key, this.value);
}
class ToggleFieldApiDriven extends EditDetailMakerEvent {
  final bool isApiDriven;
  const ToggleFieldApiDriven(this.isApiDriven);
}
class UpdateFieldApiUrl extends EditDetailMakerEvent {
  final String apiUrl;
  const UpdateFieldApiUrl(this.apiUrl);
}
class ToggleFieldUserFilling extends EditDetailMakerEvent {
  final bool isUserFilling;
  const ToggleFieldUserFilling(this.isUserFilling);
}
class UpdateFieldUserFillingUrl extends EditDetailMakerEvent {
  final String updatedUrl;
  const UpdateFieldUserFillingUrl(this.updatedUrl);
}
class AddFieldPayloadParameter extends EditDetailMakerEvent {
  final String paramId;
  const AddFieldPayloadParameter(this.paramId);
}
class RemoveFieldPayloadParameter extends EditDetailMakerEvent {
  final String paramId;
  const RemoveFieldPayloadParameter(this.paramId);
}
class UpdateFieldPayloadParameter extends EditDetailMakerEvent {
  final String paramId;
  final String key;
  final dynamic value;
  const UpdateFieldPayloadParameter(this.paramId, this.key, this.value);
}
class ToggleFieldPayloadParameterUserInput extends EditDetailMakerEvent {
  final String fieldName;
  final String paramId;
  final bool value;
  const ToggleFieldPayloadParameterUserInput(this.fieldName, this.paramId, this.value);
}
class ExtractFieldParametersFromUrl extends EditDetailMakerEvent {
  final String fieldName;
  final String apiUrl;
  const ExtractFieldParametersFromUrl(this.fieldName, this.apiUrl);
}
class UpdateCurrentField extends EditDetailMakerEvent {
  final Map<String, dynamic> field;
  const UpdateCurrentField(this.field);
}
class SaveReport extends EditDetailMakerEvent {
  final int recNo;
  final String reportName;
  final String reportLabel;
  final String apiName;
  final String parameter;
  final bool needsAction;
  final List<Map<String, dynamic>> actions;
  final bool includePdfFooterDateTime;

  const SaveReport({
    required this.recNo,
    required this.reportName,
    required this.reportLabel,
    required this.apiName,
    required this.parameter,
    required this.needsAction,
    required this.actions,
    required this.includePdfFooterDateTime,
  });
}
class ResetFields extends EditDetailMakerEvent {
  const ResetFields();
}
class ToggleNeedsActionEvent extends EditDetailMakerEvent {
  final bool needsAction;
  const ToggleNeedsActionEvent(this.needsAction);
}
class AddAction extends EditDetailMakerEvent {
  final String type;
  final String id;
  const AddAction(this.type, this.id);
}
class RemoveAction extends EditDetailMakerEvent {
  final String id;
  const RemoveAction(this.id);
}
class UpdateActionConfig extends EditDetailMakerEvent {
  final String actionId;
  final String key;
  final dynamic value;
  const UpdateActionConfig(this.actionId, this.key, this.value);
}
class AddActionParameter extends EditDetailMakerEvent {
  final String actionId;
  final String paramId;
  const AddActionParameter(this.actionId, this.paramId);
}
class RemoveActionParameter extends EditDetailMakerEvent {
  final String actionId;
  final String paramId;
  const RemoveActionParameter(this.actionId, this.paramId);
}
class UpdateActionParameter extends EditDetailMakerEvent {
  final String actionId;
  final String paramId;
  final String key;
  final dynamic value;
  const UpdateActionParameter(this.actionId, this.paramId, this.key, this.value);
}
class ExtractParametersFromUrl extends EditDetailMakerEvent {
  final String actionId;
  final String apiUrl;
  const ExtractParametersFromUrl(this.actionId, this.apiUrl);
}
class FetchParametersFromApiConfig extends EditDetailMakerEvent {
  final String actionId;
  final String apiName;
  const FetchParametersFromApiConfig(this.actionId, this.apiName);
}
class UpdateTableActionReport extends EditDetailMakerEvent {
  final String actionId;
  final String reportLabel;
  const UpdateTableActionReport(this.actionId, this.reportLabel);
}
class FetchAllReports extends EditDetailMakerEvent {
  const FetchAllReports();
}
class FetchAllApiDetails extends EditDetailMakerEvent {
  const FetchAllApiDetails();
}
class ToggleIncludePdfFooterDateTime extends EditDetailMakerEvent {
  final bool include;
  const ToggleIncludePdfFooterDateTime(this.include);
}

// ======== State ========
class EditDetailMakerState {
  final List<String> fields;
  final List<Map<String, dynamic>> selectedFields;
  final List<Map<String, dynamic>> preselectedFields;
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
  final int? initialRecNo;
  final String? initialApiName;
  final bool includePdfFooterDateTime;
  // MODIFIED: Added ucode property
  final String? ucode;

  EditDetailMakerState({
    this.fields = const <String>[],
    this.selectedFields = const <Map<String, dynamic>>[],
    this.preselectedFields = const <Map<String, dynamic>>[],
    this.currentField,
    this.isLoading = false,
    this.error,
    this.saveSuccess = false,
    this.needsAction = false,
    this.actions = const <Map<String, dynamic>>[],
    this.apiParametersCache = const {},
    this.isFetchingApiParams = false,
    this.currentActionIdFetching,
    this.fieldApiParametersCache = const {},
    this.isFetchingFieldApiParams = false,
    this.currentFieldIdFetchingParams,
    this.allReportLabels = const <String>[],
    this.reportDetailsMap = const {},
    this.allApisDetails = const {},
    this.initialRecNo,
    this.initialApiName,
    this.includePdfFooterDateTime = false,
    // MODIFIED: Added ucode to constructor
    this.ucode,
  });

  EditDetailMakerState copyWith({
    List<String>? fields,
    List<Map<String, dynamic>>? selectedFields,
    List<Map<String, dynamic>>? preselectedFields,
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
    int? initialRecNo,
    String? initialApiName,
    bool? includePdfFooterDateTime,
    // MODIFIED: Added ucode to copyWith
    String? ucode,
  }) {
    return EditDetailMakerState(
      fields: fields ?? this.fields,
      selectedFields: selectedFields ?? this.selectedFields,
      preselectedFields: preselectedFields ?? this.preselectedFields,
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
      initialRecNo: initialRecNo ?? this.initialRecNo,
      initialApiName: initialApiName ?? this.initialApiName,
      includePdfFooterDateTime: includePdfFooterDateTime ?? this.includePdfFooterDateTime,
      // MODIFIED: Handle ucode in copyWith
      ucode: ucode ?? this.ucode,
    );
  }
}

// ======== BLoC ========
class EditDetailMakerBloc extends Bloc<EditDetailMakerEvent, EditDetailMakerState> {
  final ReportAPIService apiService;
  final Uuid _uuid = const Uuid();

  EditDetailMakerBloc(this.apiService) : super(EditDetailMakerState()) {
    on<LoadPreselectedFields>(_onLoadPreselectedFields);
    on<SelectField>(_onSelectField);
    on<DeselectField>(_onDeselectField);
    on<UpdateFieldConfig>(_onUpdateFieldConfig);
    on<ToggleFieldApiDriven>(_onToggleFieldApiDriven);
    on<UpdateFieldApiUrl>(_onUpdateFieldApiUrl);
    on<ToggleFieldUserFilling>(_onToggleFieldUserFilling);
    on<UpdateFieldUserFillingUrl>(_onUpdateFieldUserFillingUrl);
    on<AddFieldPayloadParameter>(_onAddFieldPayloadParameter);
    on<RemoveFieldPayloadParameter>(_onRemoveFieldPayloadParameter);
    on<UpdateFieldPayloadParameter>(_onUpdateFieldPayloadParameter);
    on<ToggleFieldPayloadParameterUserInput>(_onToggleFieldPayloadParameterUserInput);
    on<ExtractFieldParametersFromUrl>(_onExtractFieldParametersFromUrl);
    on<UpdateCurrentField>(_onUpdateCurrentField);
    on<SaveReport>(_onSaveReport);
    on<ResetFields>(_onResetFields);
    on<ToggleNeedsActionEvent>(_onToggleNeedsAction);
    on<AddAction>(_onAddAction);
    on<RemoveAction>(_onRemoveAction);
    on<UpdateActionConfig>(_onUpdateActionConfig);
    on<AddActionParameter>(_onAddActionParameter);
    on<RemoveActionParameter>(_onRemoveActionParameter);
    on<UpdateActionParameter>(_onUpdateActionParameter);
    on<ExtractParametersFromUrl>(_onExtractParametersFromUrl);
    on<FetchParametersFromApiConfig>(_onFetchParametersFromApiConfig);
    on<UpdateTableActionReport>(_onUpdateTableActionReport);
    on<ToggleIncludePdfFooterDateTime>(_onToggleIncludePdfFooterDateTime);
  }

  Future<void> _onLoadPreselectedFields(LoadPreselectedFields event, Emitter<EditDetailMakerState> emit) async {
    emit(state.copyWith(
      isLoading: true,
      error: null,
      saveSuccess: false,
      initialRecNo: event.recNo,
      initialApiName: event.apiName,
    ));

    try {
      final results = await Future.wait<dynamic>([
        apiService.fetchApiData(event.apiName).catchError((e) => <Map<String, dynamic>>[]),
        apiService.fetchDemoTable2(event.recNo.toString()).catchError((e) => <Map<String, dynamic>>[]),
        apiService.fetchDemoTable().catchError((e) => <Map<String, dynamic>>[]),
        apiService.getAvailableApis().then((names) async {
          final details = <String, Map<String, dynamic>>{};
          for (var name in names) {
            details[name] = await apiService.getApiDetails(name);
          }
          return details;
        }).catchError((e) {
          throw Exception('Failed to load API configurations: $e');
        }),
      ]);

      final List<Map<String, dynamic>> apiData = results[0];
      final List<Map<String, dynamic>> preselectedFieldsRaw = results[1];
      final List<Map<String, dynamic>> allReports = results[2];
      final Map<String, Map<String, dynamic>> allApisDetails = results[3];

      final List<String> fieldsFromApi = apiData.isNotEmpty ? apiData[0].keys.toList() : <String>[];

      final Map<String, Map<String, dynamic>> reportDetailsMap = {for (var report in allReports) report['Report_label'].toString(): report};
      final List<String> availableReportLabels = reportDetailsMap.keys.toList();

      final List<Map<String, dynamic>> formattedFields = preselectedFieldsRaw.map((field) {
        return {
          'Field_name': field['Field_name']?.toString() ?? '',
          'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
          'Sequence_no': int.tryParse(field['Sequence_no']?.toString() ?? '0') ?? 0,
          'width': int.tryParse(field['width']?.toString() ?? '100') ?? 100,
          'Total': _parseBoolFromApi(field['Total']),
          'num_alignment': field['num_alignment']?.toString() ?? 'left',
          'time': _parseBoolFromApi(field['time']),
          'indian_format': _parseBoolFromApi(field['indian_format']),
          'decimal_points': int.tryParse(field['decimal_points']?.toString() ?? '0') ?? 0,
          'Breakpoint': _parseBoolFromApi(field['Breakpoint']),
          'SubTotal': _parseBoolFromApi(field['SubTotal']),
          'image': _parseBoolFromApi(field['image']),
          'Group_by': _parseBoolFromApi(field['Group_by']),
          'Filter': _parseBoolFromApi(field['Filter']),
          'filterJson': field['filterJson']?.toString() ?? '',
          'orderby': _parseBoolFromApi(field['orderby']),
          'orderjson': field['orderjson']?.toString() ?? '',
          'groupjson': field['groupjson']?.toString() ?? '',
          'is_api_driven': _parseBoolFromApi(field['is_api_driven']),
          'api_url': field['api_url']?.toString() ?? '',
          'field_params': _parseJsonList(field['field_params']),
          'is_user_filling': _parseBoolFromApi(field['is_user_filling']),
          'updated_url': field['updated_url']?.toString() ?? '',
          'payload_structure': _parseJsonList(field['payload_structure']),
        };
      }).toList();
      formattedFields.sort((a, b) => (a['Sequence_no'] as int).compareTo(b['Sequence_no'] as int));

      final allUniqueFieldNames = {...fieldsFromApi, ...formattedFields.map((f) => f['Field_name'] as String)}.toList()..sort();

      final currentReportEntry = allReports.firstWhere((r) => r['RecNo'].toString() == event.recNo.toString(), orElse: () => <String, dynamic>{});

      // MODIFIED: Fetch the ucode
      final String? ucode = currentReportEntry['ucode']?.toString();

      List<Map<String, dynamic>> actions = <Map<String, dynamic>>[];
      if (currentReportEntry.isNotEmpty && currentReportEntry['actions_config'] != null) {
        final dynamic actionsConfigRaw = currentReportEntry['actions_config'];
        if (actionsConfigRaw is List) {
          actions = List<Map<String, dynamic>>.from(actionsConfigRaw);
        } else if (actionsConfigRaw is String && actionsConfigRaw.isNotEmpty) {
          try {
            actions = List<Map<String, dynamic>>.from(jsonDecode(actionsConfigRaw));
          } catch(e) { /* ignore parse error */ }
        }
      }

      for(var action in actions) {
        if(action['id'] == null) action['id'] = _uuid.v4();
        if (action['type'] == 'print' && action['api'] != null && (action['api'] as String).isNotEmpty) {
          add(ExtractParametersFromUrl(action['id'], action['api']));
        } else if (action['type'] == 'table' && action['reportLabel'] != null && (action['reportLabel'] as String).isNotEmpty) {
          final linkedReport = reportDetailsMap[action['reportLabel']];
          if(linkedReport != null && linkedReport['API_name'] != null) {
            add(FetchParametersFromApiConfig(action['id'], linkedReport['API_name']));
          }
        }
      }

      emit(state.copyWith(
        fields: allUniqueFieldNames,
        selectedFields: formattedFields,
        preselectedFields: formattedFields,
        currentField: formattedFields.isNotEmpty ? formattedFields.first : null,
        isLoading: false,
        needsAction: actions.isNotEmpty,
        actions: actions,
        allReportLabels: availableReportLabels,
        reportDetailsMap: reportDetailsMap,
        allApisDetails: allApisDetails,
        includePdfFooterDateTime: _parseBoolFromApi(currentReportEntry['pdf_footer_datetime']),
        // MODIFIED: Store the ucode in the state
        ucode: ucode,
      ));

    } catch (e, stackTrace) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
      debugPrint('CRITICAL BLoC Error: $e\n$stackTrace');
    }
  }

  void _onAddAction(AddAction event, Emitter<EditDetailMakerState> emit) {
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
      newAction = {'id': event.id, 'type': event.type, 'name': name, 'api': '', 'params': <Map<String, dynamic>>[], 'printTemplate': 'premium', 'printColor': 'Blue'};
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
      newAction = {'id': event.id, 'type': event.type, 'name': name, 'api': '', 'reportLabel': '', 'apiName_resolved': '', 'recNo_resolved': '', 'params': <Map<String, dynamic>>[]};
    }

    emit(state.copyWith(actions: [...state.actions, newAction], error: null));
  }

  // ... (All other BLoC methods remain unchanged)
  // ...
  bool _parseBoolFromApi(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  List<Map<String, dynamic>> _parseJsonList(dynamic value) {
    if (value == null) return <Map<String, dynamic>>[];
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    if (value is String && value.trim().startsWith('[') && value.trim().endsWith(']')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.whereType<Map<String, dynamic>>().toList();
        }
      } catch (e) {
        debugPrint('JSON parsing failed for string: "$value". Error: $e');
      }
    }
    return <Map<String, dynamic>>[];
  }

  void _onSelectField(SelectField event, Emitter<EditDetailMakerState> emit) {
    if (state.selectedFields.any((f) => f['Field_name'] == event.field)) return;

    final List<Map<String, dynamic>> preselectedFields = state.preselectedFields;

    final preselectedMatch = preselectedFields.firstWhereOrNull(
          (f) => f['Field_name'] == event.field,
    );

    final newField = preselectedMatch != null
        ? preselectedMatch
        : {
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

    final updatedFields = List<Map<String, dynamic>>.from(state.selectedFields)..add(newField);
    updatedFields.sort((a, b) => (a['Sequence_no'] as int).compareTo(b['Sequence_no'] as int));

    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: newField,
    ));
  }

  void _onDeselectField(DeselectField event, Emitter<EditDetailMakerState> emit) {
    final updatedFields = state.selectedFields.where((f) => f['Field_name'] != event.field).toList();
    for (int i = 0; i < updatedFields.length; i++) {
      updatedFields[i]['Sequence_no'] = i + 1;
    }
    final newCurrentField = state.currentField?['Field_name'] == event.field ? (updatedFields.isNotEmpty ? updatedFields.first : null) : state.currentField;
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: newCurrentField,
    ));
  }

  void _onUpdateFieldConfig(UpdateFieldConfig event, Emitter<EditDetailMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = {...state.currentField!, event.key: event.value};
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    updatedFields.sort((a, b) => (a['Sequence_no'] as int? ?? 999).compareTo(b['Sequence_no'] as int? ?? 999));
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onToggleFieldApiDriven(ToggleFieldApiDriven event, Emitter<EditDetailMakerState> emit) {
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

  void _onUpdateFieldApiUrl(UpdateFieldApiUrl event, Emitter<EditDetailMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = {...state.currentField!, 'api_url': event.apiUrl};
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onToggleFieldUserFilling(ToggleFieldUserFilling event, Emitter<EditDetailMakerState> emit) {
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

  void _onUpdateFieldUserFillingUrl(UpdateFieldUserFillingUrl event, Emitter<EditDetailMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = {...state.currentField!, 'updated_url': event.updatedUrl};
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onAddFieldPayloadParameter(AddFieldPayloadParameter event, Emitter<EditDetailMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = Map<String, dynamic>.from(state.currentField!);
    final payload = List<Map<String, dynamic>>.from(updatedField['payload_structure'] ?? []);
    payload.add({'id': event.paramId, 'key': '', 'value': '', 'value_type': 'dynamic', 'is_user_input': false});
    updatedField['payload_structure'] = payload;
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onRemoveFieldPayloadParameter(RemoveFieldPayloadParameter event, Emitter<EditDetailMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = Map<String, dynamic>.from(state.currentField!);
    final payload = List<Map<String, dynamic>>.from(updatedField['payload_structure'] ?? []);
    payload.removeWhere((p) => p['id'] == event.paramId);
    updatedField['payload_structure'] = payload;
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onUpdateFieldPayloadParameter(UpdateFieldPayloadParameter event, Emitter<EditDetailMakerState> emit) {
    if (state.currentField == null) return;
    final updatedField = Map<String, dynamic>.from(state.currentField!);
    final payload = (updatedField['payload_structure'] as List? ?? []).cast<Map<String, dynamic>>();
    final updatedPayload = payload.map((p) => p['id'] == event.paramId ? {...p, event.key: event.value} : p).toList();
    updatedField['payload_structure'] = updatedPayload;
    final updatedFields = state.selectedFields.map((f) => f['Field_name'] == state.currentField!['Field_name'] ? updatedField : f).toList();
    emit(state.copyWith(selectedFields: updatedFields, currentField: updatedField));
  }

  void _onToggleFieldPayloadParameterUserInput(ToggleFieldPayloadParameterUserInput event, Emitter<EditDetailMakerState> emit) {
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

  Future<void> _onExtractFieldParametersFromUrl(ExtractFieldParametersFromUrl event, Emitter<EditDetailMakerState> emit) async {
    final isCurrentField = state.currentField?['Field_name'] == event.fieldName;
    if (isCurrentField) emit(state.copyWith(isFetchingFieldApiParams: true, currentFieldIdFetchingParams: event.fieldName));
    try {
      final uri = Uri.tryParse(event.apiUrl);
      final parameters = uri?.queryParameters.keys.where((k) => !['type', 'ucode', 'val8'].contains(k.toLowerCase())).toList() ?? [];
      final updatedCache = {...state.fieldApiParametersCache, event.fieldName: parameters};
      final updatedFields = state.selectedFields.map((f) {
        if (f['Field_name'] == event.fieldName) {
          final currentParams = (f['field_params'] as List? ?? []).cast<Map<String, dynamic>>();
          final newParams = parameters.map((name) {
            return currentParams.firstWhere((p) => p['parameterName'] == name, orElse: () => {'id': _uuid.v4(), 'parameterName': name, 'parameterValue': ''});
          }).toList();
          return {...f, 'field_params': newParams};
        }
        return f;
      }).toList();
      final newCurrentField = isCurrentField ? updatedFields.firstWhere((f) => f['Field_name'] == event.fieldName, orElse: () => <String, dynamic>{}) : state.currentField;
      emit(state.copyWith(fieldApiParametersCache: updatedCache, selectedFields: updatedFields, currentField: newCurrentField, isFetchingFieldApiParams: false, currentFieldIdFetchingParams: null));
    } catch (e) {
      emit(state.copyWith(isFetchingFieldApiParams: false, currentFieldIdFetchingParams: null, error: e.toString()));
    }
  }

  void _onUpdateCurrentField(UpdateCurrentField event, Emitter<EditDetailMakerState> emit) {
    emit(state.copyWith(currentField: event.field));
  }

  Future<void> _onSaveReport(SaveReport event, Emitter<EditDetailMakerState> emit) async {
    if (state.selectedFields.isEmpty) { emit(state.copyWith(error: 'No fields selected to save.')); return; }
    emit(state.copyWith(isLoading: true));
    try {
      await apiService.editDemoTables(recNo: event.recNo, reportName: event.reportName, reportLabel: event.reportLabel, apiName: event.apiName, parameter: event.parameter, fieldConfigs: state.selectedFields, actions: event.needsAction ? state.actions : [], includePdfFooterDateTime: event.includePdfFooterDateTime);
      emit(state.copyWith(isLoading: false, saveSuccess: true));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to save: $e'));
    }
  }

  void _onResetFields(ResetFields event, Emitter<EditDetailMakerState> emit) {
    if (state.initialRecNo == null || state.initialApiName == null) {
      emit(state.copyWith(error: 'Initial report details not loaded.'));
      return;
    }
    add(LoadPreselectedFields(state.initialRecNo!, state.initialApiName!));
  }

  void _onToggleNeedsAction(ToggleNeedsActionEvent event, Emitter<EditDetailMakerState> emit) => emit(state.copyWith(needsAction: event.needsAction));

  void _onRemoveAction(RemoveAction event, Emitter<EditDetailMakerState> emit) {
    final updatedActions = state.actions.where((a) => a['id'] != event.id).toList();
    final updatedCache = Map<String, List<String>>.from(state.apiParametersCache)..remove(event.id);
    emit(state.copyWith(actions: updatedActions, apiParametersCache: updatedCache));
  }

  void _onUpdateActionConfig(UpdateActionConfig event, Emitter<EditDetailMakerState> emit) {
    final updatedActions = state.actions.map((a) => a['id'] == event.actionId ? {...a, event.key: event.value} : a).toList();
    emit(state.copyWith(actions: updatedActions));
  }

  void _onAddActionParameter(AddActionParameter event, Emitter<EditDetailMakerState> emit) {
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

  void _onRemoveActionParameter(RemoveActionParameter event, Emitter<EditDetailMakerState> emit) {
    final updatedActions = state.actions.map((action) {
      if (action['id'] == event.actionId) {
        final params = (action['params'] as List? ?? []).where((p) => p['id'] != event.paramId).toList();
        return {...action, 'params': params};
      }
      return action;
    }).toList();
    emit(state.copyWith(actions: updatedActions));
  }

  void _onUpdateActionParameter(UpdateActionParameter event, Emitter<EditDetailMakerState> emit) {
    final updatedActions = state.actions.map((action) {
      if (action['id'] == event.actionId) {
        final params = (action['params'] as List? ?? []).map((p) => p['id'] == event.paramId ? {...p, event.key: event.value} : p).toList();
        return {...action, 'params': params};
      }
      return action;
    }).toList();
    emit(state.copyWith(actions: updatedActions));
  }

  Future<void> _onExtractParametersFromUrl(ExtractParametersFromUrl event, Emitter<EditDetailMakerState> emit) async {
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

  Future<void> _onFetchParametersFromApiConfig(FetchParametersFromApiConfig event, Emitter<EditDetailMakerState> emit) async {
    emit(state.copyWith(isFetchingApiParams: true, currentActionIdFetching: event.actionId));
    try {
      var apiDetail = state.allApisDetails[event.apiName] ?? await apiService.getApiDetails(event.apiName);
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

  Future<void> _onUpdateTableActionReport(UpdateTableActionReport event, Emitter<EditDetailMakerState> emit) async {
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
      final apiDetail = state.allApisDetails[resolvedApiName] ?? await apiService.getApiDetails(resolvedApiName);
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

  void _onToggleIncludePdfFooterDateTime(ToggleIncludePdfFooterDateTime event, Emitter<EditDetailMakerState> emit) {
    emit(state.copyWith(includePdfFooterDateTime: event.include));
  }
}

// Keep the extension at the bottom as it's a utility
extension StringCasingExtension on String {
  String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
}