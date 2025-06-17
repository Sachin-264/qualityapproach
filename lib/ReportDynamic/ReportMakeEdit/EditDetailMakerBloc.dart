import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart'; // Needed for PdfColors constants in printTemplate feature
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../ReportAPIService.dart';

// ======== Events ========

class EditDetailMakerEvent {
  const EditDetailMakerEvent(); // Add a const constructor for base class
}

class LoadPreselectedFields extends EditDetailMakerEvent {
  final int recNo;
  final String apiName;
  const LoadPreselectedFields(this.recNo, this.apiName); // Add const
}

class SelectField extends EditDetailMakerEvent {
  final String field;
  const SelectField(this.field); // Add const
}

class DeselectField extends EditDetailMakerEvent {
  final String field;
  const DeselectField(this.field); // Add const
}

class UpdateFieldConfig extends EditDetailMakerEvent {
  final String key;
  final dynamic value;
  const UpdateFieldConfig(this.key, this.value); // Add const
}

// NEW EVENTS for API driven and User Filling fields
class ToggleFieldApiDriven extends EditDetailMakerEvent {
  final bool isApiDriven;
  const ToggleFieldApiDriven(this.isApiDriven); // Add const
}

class UpdateFieldApiUrl extends EditDetailMakerEvent {
  final String apiUrl;
  const UpdateFieldApiUrl(this.apiUrl); // Add const
}

class ToggleFieldUserFilling extends EditDetailMakerEvent {
  final bool isUserFilling;
  const ToggleFieldUserFilling(this.isUserFilling); // Add const
}

class UpdateFieldUserFillingUrl extends EditDetailMakerEvent {
  final String updatedUrl;
  const UpdateFieldUserFillingUrl(this.updatedUrl); // Add const
}

class AddFieldPayloadParameter extends EditDetailMakerEvent {
  final String paramId;
  const AddFieldPayloadParameter(this.paramId); // Add const
}

class RemoveFieldPayloadParameter extends EditDetailMakerEvent {
  final String paramId;
  const RemoveFieldPayloadParameter(this.paramId); // Add const
}

class UpdateFieldPayloadParameter extends EditDetailMakerEvent {
  final String paramId;
  final String key; // 'key' or 'value' for the payload item
  final dynamic value;
  const UpdateFieldPayloadParameter(this.paramId, this.key, this.value); // Add const
}

class ToggleFieldPayloadParameterUserInput extends EditDetailMakerEvent {
  final String fieldName; // The field name for which params are being edited
  final String paramId;
  final bool value; // The new value for is_user_input
  const ToggleFieldPayloadParameterUserInput(this.fieldName, this.paramId, this.value); // Add const
}


class ExtractFieldParametersFromUrl extends EditDetailMakerEvent {
  final String fieldName; // The field name for which params are being extracted
  final String apiUrl;
  const ExtractFieldParametersFromUrl(this.fieldName, this.apiUrl); // Add const
}


class UpdateCurrentField extends EditDetailMakerEvent {
  final Map<String, dynamic> field;
  const UpdateCurrentField(this.field); // Add const
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

  const SaveReport({ // Add const
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
  const ResetFields(); // Add const
}

class ToggleNeedsActionEvent extends EditDetailMakerEvent {
  final bool needsAction;
  const ToggleNeedsActionEvent(this.needsAction); // Add const
}

class AddAction extends EditDetailMakerEvent {
  final String type; // 'form', 'print', 'table'
  final String id;
  const AddAction(this.type, this.id); // Add const
}

class RemoveAction extends EditDetailMakerEvent {
  final String id;
  const RemoveAction(this.id); // Add const
}

class UpdateActionConfig extends EditDetailMakerEvent {
  final String actionId;
  final String key;
  final dynamic value;
  const UpdateActionConfig(this.actionId, this.key, this.value); // Add const
}

class AddActionParameter extends EditDetailMakerEvent {
  final String actionId;
  final String paramId;
  const AddActionParameter(this.actionId, this.paramId); // Add const
}

class RemoveActionParameter extends EditDetailMakerEvent {
  final String actionId;
  final String paramId;
  const RemoveActionParameter(this.actionId, this.paramId); // Add const
}

class UpdateActionParameter extends EditDetailMakerEvent {
  final String actionId;
  final String paramId;
  final String key; // 'parameterName' or 'parameterValue'
  final dynamic value;
  const UpdateActionParameter(this.actionId, this.paramId, this.key, this.value); // Add const
}

class ExtractParametersFromUrl extends EditDetailMakerEvent {
  final String actionId;
  final String apiUrl;
  const ExtractParametersFromUrl(this.actionId, this.apiUrl); // Add const
}

class FetchParametersFromApiConfig extends EditDetailMakerEvent {
  final String actionId;
  final String apiName; // The configured APIName from database_server
  const FetchParametersFromApiConfig(this.actionId, this.apiName); // Add const
}

class UpdateTableActionReport extends EditDetailMakerEvent {
  final String actionId;
  final String reportLabel; // The selected Report_label
  const UpdateTableActionReport(this.actionId, this.reportLabel); // Add const
}

class FetchAllReports extends EditDetailMakerEvent {
  const FetchAllReports(); // Add const
}
class FetchAllApiDetails extends EditDetailMakerEvent {
  const FetchAllApiDetails(); // Add const
}

class ToggleIncludePdfFooterDateTime extends EditDetailMakerEvent {
  final bool include;
  const ToggleIncludePdfFooterDateTime(this.include); // Add const
}

// ======== State ========

class EditDetailMakerState {
  final List<String> fields; // All possible fields from the API
  final List<Map<String, dynamic>> selectedFields; // Configured fields for the current report
  final List<Map<String, dynamic>> preselectedFields; // Original selected fields on load
  final Map<String, dynamic>? currentField;
  final bool isLoading;
  final String? error;
  final bool saveSuccess;

  final bool needsAction;
  final List<Map<String, dynamic>> actions;
  final Map<String, List<String>> apiParametersCache; // For action parameters
  final bool isFetchingApiParams;
  final String? currentActionIdFetching;

  final Map<String, List<String>> fieldApiParametersCache; // NEW: For field-specific API parameters
  final bool isFetchingFieldApiParams; // NEW
  final String? currentFieldIdFetchingParams; // NEW

  final List<String> allReportLabels;
  final Map<String, Map<String, dynamic>> reportDetailsMap;
  final Map<String, Map<String, dynamic>> allApisDetails;

  final int? initialRecNo;
  final String? initialApiName;

  final bool includePdfFooterDateTime;

  EditDetailMakerState({
    this.fields = const [],
    this.selectedFields = const [],
    this.preselectedFields = const [],
    this.currentField,
    this.isLoading = false,
    this.error,
    this.saveSuccess = false,
    this.needsAction = false,
    this.actions = const [],
    this.apiParametersCache = const {},
    this.isFetchingApiParams = false,
    this.currentActionIdFetching,
    this.fieldApiParametersCache = const {}, // NEW
    this.isFetchingFieldApiParams = false, // NEW
    this.currentFieldIdFetchingParams, // NEW
    this.allReportLabels = const [],
    this.reportDetailsMap = const {},
    this.allApisDetails = const {},
    this.initialRecNo,
    this.initialApiName,
    this.includePdfFooterDateTime = false,
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
    Map<String, List<String>>? fieldApiParametersCache, // NEW
    bool? isFetchingFieldApiParams, // NEW
    String? currentFieldIdFetchingParams, // NEW
    List<String>? allReportLabels,
    Map<String, Map<String, dynamic>>? reportDetailsMap,
    Map<String, Map<String, dynamic>>? allApisDetails,
    int? initialRecNo,
    String? initialApiName,
    bool? includePdfFooterDateTime,
  }) {
    return EditDetailMakerState(
      fields: fields ?? this.fields,
      selectedFields: selectedFields ?? this.selectedFields,
      preselectedFields: preselectedFields ?? this.preselectedFields,
      currentField: currentField ?? this.currentField,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Allow setting error to null
      saveSuccess: saveSuccess ?? this.saveSuccess,
      needsAction: needsAction ?? this.needsAction,
      actions: actions ?? this.actions,
      apiParametersCache: apiParametersCache ?? this.apiParametersCache,
      isFetchingApiParams: isFetchingApiParams ?? this.isFetchingApiParams,
      currentActionIdFetching: currentActionIdFetching, // Allow setting to null
      fieldApiParametersCache: fieldApiParametersCache ?? this.fieldApiParametersCache, // NEW
      isFetchingFieldApiParams: isFetchingFieldApiParams ?? this.isFetchingFieldApiParams, // NEW
      currentFieldIdFetchingParams: currentFieldIdFetchingParams, // NEW
      allReportLabels: allReportLabels ?? this.allReportLabels,
      reportDetailsMap: reportDetailsMap ?? this.reportDetailsMap,
      allApisDetails: allApisDetails ?? this.allApisDetails,
      initialRecNo: initialRecNo ?? this.initialRecNo,
      initialApiName: initialApiName ?? this.initialApiName,
      includePdfFooterDateTime: includePdfFooterDateTime ?? this.includePdfFooterDateTime,
    );
  }
}

// ======== BLoC ========

class EditDetailMakerBloc extends Bloc<EditDetailMakerEvent, EditDetailMakerState> {
  final ReportAPIService apiService;
  final Uuid _uuid = const Uuid();

  EditDetailMakerBloc(this.apiService) : super(EditDetailMakerState()) {
    debugPrint('Bloc: EditDetailMakerBloc initialized');
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
    on<ToggleFieldPayloadParameterUserInput>(_onToggleFieldPayloadParameterUserInput); // NEW HANDLER
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
    on<FetchAllReports>(_onFetchAllReports);
    on<FetchAllApiDetails>(_onFetchAllApiDetails);
    on<ToggleIncludePdfFooterDateTime>(_onToggleIncludePdfFooterDateTime);
  }

  Future<void> _onLoadPreselectedFields(LoadPreselectedFields event, Emitter<EditDetailMakerState> emit) async {
    debugPrint('Bloc: Handling LoadPreselectedFields: recNo=${event.recNo}, apiName=${event.apiName}');
    emit(state.copyWith(
      isLoading: true,
      error: null,
      saveSuccess: false,
      fields: [],
      selectedFields: [],
      preselectedFields: [],
      currentField: null,
      needsAction: false,
      actions: [],
      apiParametersCache: {},
      fieldApiParametersCache: {}, // Clear field API parameters cache
      allReportLabels: [],
      reportDetailsMap: {},
      allApisDetails: {},
      initialRecNo: event.recNo,
      initialApiName: event.apiName,
      includePdfFooterDateTime: false, // Reset this to default before loading
    ));

    try {
      debugPrint('Bloc: Fetching fields, preselected fields, all demo_table reports, and all API details concurrently');
      final results = await Future.wait([
        apiService.fetchApiData(event.apiName),
        apiService.fetchDemoTable2(event.recNo.toString()),
        apiService.fetchDemoTable(),
        apiService.getAvailableApis().then((apiNames) async {
          final Map<String, Map<String, dynamic>> allApisDetails = {};
          for (String apiName in apiNames) {
            allApisDetails[apiName] = await apiService.getApiDetails(apiName);
          }
          return allApisDetails;
        }),
      ]);

      final apiData = results[0] as List<Map<String, dynamic>>;
      final preselectedFieldsRaw = results[1] as List<Map<String, dynamic>>;
      final allReports = results[2] as List<Map<String, dynamic>>;
      final Map<String, Map<String, dynamic>> allApisDetails = results[3] as Map<String, Map<String, dynamic>>;

      debugPrint('Bloc: All data fetched successfully');
      debugPrint('Bloc: Available API details populated: ${allApisDetails.length}');

      List<String> fieldsFromApi = apiData.isNotEmpty ? apiData[0].keys.map((key) => key.toString()).toList() : [];
      debugPrint('Bloc: Fields extracted from API: ${fieldsFromApi.length}');

      final List<String> availableReportLabels = [];
      final Map<String, Map<String, dynamic>> reportDetailsMap = {};
      for (var report in allReports) {
        final label = report['Report_label']?.toString();
        final recNo = report['RecNo']?.toString() ?? '';
        final apiName = report['API_name']?.toString() ?? '';
        if (label != null && label.isNotEmpty && !availableReportLabels.contains(label)) {
          availableReportLabels.add(label);
          reportDetailsMap[label] = {
            ...report,
            'RecNo': recNo,
            'API_name': apiName,
          };
        }
      }
      debugPrint('Bloc: Available report labels: ${availableReportLabels.length}');

      final formattedFields = preselectedFieldsRaw.map((field) {
// Ensure payload_structure and field_params are parsed and contain 'is_user_input'
        final List<Map<String, dynamic>> parsedPayload = _parseJsonList(field['payload_structure']);
        final List<Map<String, dynamic>> parsedFieldParams = _parseJsonList(field['field_params']);

// Initialize is_user_input for each payload parameter if not present
        final List<Map<String, dynamic>> finalPayload = parsedPayload.map((param) {
          return {
            ...param,
            'is_user_input': param['is_user_input'] ?? false, // Ensure this property exists
          };
        }).toList();

        return {
          'Field_name': field['Field_name']?.toString() ?? '',
          'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
          'Sequence_no': int.tryParse(field['Sequence_no']?.toString() ?? '') ?? 0,
          'width': int.tryParse(field['width']?.toString() ?? '') ?? 100,
          'Total': _parseBoolFromApi(field['Total']),
          'num_alignment': field['num_alignment']?.toString().toLowerCase() ?? 'left',
          'time': _parseBoolFromApi(field['time']),
          'indian_format': _parseBoolFromApi(field['indian_format']), // Corrected key to indian_format
          'decimal_points': int.tryParse(field['decimal_points']?.toString() ?? '') ?? 0,
          'Breakpoint': _parseBoolFromApi(field['Breakpoint']),
          'SubTotal': _parseBoolFromApi(field['SubTotal']),
          'image': _parseBoolFromApi(field['image']),
          'Group_by': _parseBoolFromApi(field['Group_by']),
          'Filter': _parseBoolFromApi(field['Filter']),
          'filterJson': field['filterJson']?.toString() ?? '',
          'orderby': _parseBoolFromApi(field['orderby']),
          'orderjson': field['orderjson']?.toString() ?? '',
          'groupjson': field['groupjson']?.toString() ?? '',
// NEW: Load API Driven and User Filling properties
          'is_api_driven': _parseBoolFromApi(field['is_api_driven']),
          'api_url': field['api_url']?.toString() ?? '',
          'field_params': parsedFieldParams,
          'is_user_filling': _parseBoolFromApi(field['is_user_filling']),
          'updated_url': field['updated_url']?.toString() ?? '',
          'payload_structure': finalPayload, // Use the processed payload
        };
      }).toList();
      formattedFields.sort((a, b) => (a['Sequence_no'] as int).compareTo(b['Sequence_no'] as int));

// Ensure state.fields includes preselected fields and any new fields from the API
      final Set<String> allUniqueFieldNames = Set.from(fieldsFromApi);
      for (var field in formattedFields) {
        allUniqueFieldNames.add(field['Field_name'] as String);
// If a loaded field is API driven and has an api_url, try to extract its parameters
        if (field['is_api_driven'] == true && (field['api_url'] as String).isNotEmpty) {
// CORRECTED: Explicitly cast to String
          add(ExtractFieldParametersFromUrl(field['Field_name'] as String, field['api_url'] as String));
        }
      }
      final List<String> finalFields = allUniqueFieldNames.toList();
      finalFields.sort(); // Keep them sorted for consistent display
      debugPrint('Bloc: Final fields for display (including preselected): ${finalFields.length}');


      bool needsAction = false;
      List<Map<String, dynamic>> actions = [];
      bool includePdfFooterDateTime = false;

      final currentReportEntry = allReports.firstWhere(
            (report) => (report['RecNo']?.toString() ?? '0') == event.recNo.toString(),
        orElse: () {
          debugPrint('Bloc: Current report with RecNo ${event.recNo} not found in allReports.');
          return {};
        },
      );

      if (currentReportEntry.isNotEmpty) {
        includePdfFooterDateTime = _parseBoolFromApi(currentReportEntry['pdf_footer_datetime']);
        debugPrint('Bloc: Loaded pdf_footer_datetime for RecNo ${event.recNo}: $includePdfFooterDateTime');

        if (currentReportEntry['actions_config'] != null) {
          final dynamic actionsConfigRaw = currentReportEntry['actions_config'];
          if (actionsConfigRaw is List) {
            actions = List<Map<String, dynamic>>.from(actionsConfigRaw);
          } else if (actionsConfigRaw is String && actionsConfigRaw.isNotEmpty) {
            try {
              actions = List<Map<String, dynamic>>.from(jsonDecode(actionsConfigRaw));
            } catch (e) {
              debugPrint('Bloc: Error decoding actions_config: $e. Raw: $actionsConfigRaw');
              actions = [];
            }
          }
          needsAction = actions.isNotEmpty;
          debugPrint('Bloc: Loaded actions_config for RecNo ${event.recNo}: ${actions.length} actions. needsAction=$needsAction');

          final List<Map<String, dynamic>> tempActions = List.from(actions);
          for (int i = 0; i < tempActions.length; i++) {
            final action = tempActions[i];
            if (action['id'] == null || action['id'] is! String) {
              tempActions[i]['id'] = _uuid.v4();
            }

            if (action['type'] == 'print') {
              if (action['printTemplate'] == null) {
                tempActions[i]['printTemplate'] = 'premium';
              }
              if (action['printColor'] == null) {
                tempActions[i]['printColor'] = 'Blue';
              }
            }

            if (action['type'] == 'print' && action['api'] != null && (action['api'] as String).isNotEmpty) {
              add(ExtractParametersFromUrl(action['id'], action['api']));
            } else if (action['type'] == 'table' && action['reportLabel'] != null && (action['reportLabel'] as String).isNotEmpty) {
              final selectedReportLabel = action['reportLabel'] as String;
              final linkedReport = reportDetailsMap[selectedReportLabel];

              if (linkedReport != null) {
                final apiName = linkedReport['API_name']?.toString();
                final recNoResolved = linkedReport['RecNo']?.toString();
                tempActions[i]['recNo_resolved'] = recNoResolved;
                tempActions[i]['reportLabel'] = selectedReportLabel;

                if (apiName != null && apiName.isNotEmpty) {
                  final apiDetail = allApisDetails[apiName];
                  if (apiDetail != null) {
                    final apiUrl = apiDetail['url']?.toString() ?? '';
                    tempActions[i]['api'] = apiUrl;
                    tempActions[i]['apiName_resolved'] = apiName;
                    add(FetchParametersFromApiConfig(action['id'], apiName));
                  } else {
                    debugPrint('Bloc: API details not found for API Name: $apiName for report label: $selectedReportLabel');
                    tempActions[i]['api'] = '';
                    tempActions[i]['params'] = [];
                    tempActions[i]['apiName_resolved'] = '';
                  }
                }
              } else {
                debugPrint('Bloc: Linked report not found for label: $selectedReportLabel. Clearing API info for action.');
                tempActions[i]['api'] = '';
                tempActions[i]['params'] = [];
                tempActions[i]['apiName_resolved'] = '';
                tempActions[i]['recNo_resolved'] = '';
              }
            }
          }
          actions = tempActions;
        }
      }


      emit(state.copyWith(
        fields: finalFields,
        selectedFields: formattedFields,
        preselectedFields: formattedFields,
        currentField: formattedFields.isNotEmpty ? formattedFields.first : null,
        isLoading: false,
        error: null,
        needsAction: needsAction,
        actions: actions,
        allReportLabels: availableReportLabels,
        reportDetailsMap: reportDetailsMap,
        allApisDetails: allApisDetails,
        includePdfFooterDateTime: includePdfFooterDateTime,
      ));
      debugPrint('Bloc: Final state emitted successfully after loading existing actions.');
    } catch (e, stackTrace) {
      debugPrint('Bloc: Error in LoadPreselectedFields: $e');
      debugPrint('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to load fields and report details: $e',
      ));
    }
  }

// Helper to parse API boolean-like values (0/1 or true/false)
  bool _parseBoolFromApi(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

// Helper to parse JSON string to List<Map<String, dynamic>>
  List<Map<String, dynamic>> _parseJsonList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
// Ensure each item is a Map<String, dynamic> and has 'is_user_input'
      return value.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item)..putIfAbsent('is_user_input', () => false);
        }
        return <String, dynamic>{'is_user_input': false};
      }).toList();
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
// Ensure each item is a Map<String, dynamic> and has 'is_user_input'
          return decoded.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item)..putIfAbsent('is_user_input', () => false);
            }
            return <String, dynamic>{'is_user_input': false};
          }).toList();
        }
      } catch (e) {
        debugPrint('Warning: Failed to decode JSON list: $value, Error: $e');
      }
    }
    return [];
  }


  void _onSelectField(SelectField event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling SelectField: field=${event.field}');
    if (state.selectedFields.any((f) => f['Field_name'] == event.field)) {
      debugPrint('Bloc: Field already selected: ${event.field}, skipping');
      return;
    }

    final preselectedMatch = state.preselectedFields.firstWhere(
          (f) => f['Field_name'] == event.field,
      orElse: () => {}, // Returns empty map if not found
    );

    final newField = preselectedMatch.isNotEmpty
        ? preselectedMatch
        : {
      'Field_name': event.field,
      'Field_label': event.field,
      'Sequence_no': state.selectedFields.isNotEmpty
          ? (state.selectedFields.map((f) => f['Sequence_no'] as int).reduce((a, b) => a > b ? a : b) + 1)
          : 1,
      'width': 100,
      'Total': false,
      'Group_by': false, 'Filter': false, 'filterJson': '', 'orderby': false, 'orderjson': '', 'groupjson': '',
      'num_alignment': 'left', 'time': false, 'num_format': false, 'decimal_points': 0,
      'Breakpoint': false, 'SubTotal': false, 'image': false,
// NEW: Default values for API Driven and User Filling fields
      'is_api_driven': false,
      'api_url': '',
      'field_params': <Map<String, dynamic>>[],
      'is_user_filling': false,
      'updated_url': '',
      'payload_structure': <Map<String, dynamic>>[], // Ensure this is initialized as List<Map<String, dynamic>>
    };

    final updatedFields = [...state.selectedFields, newField];
    updatedFields.sort((a, b) => (a['Sequence_no'] as int).compareTo(b['Sequence_no'] as int));

    debugPrint('Bloc: Selected field: ${event.field}, Updated selectedFields: ${updatedFields.length}');
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: newField,
    ));
  }

  void _onDeselectField(DeselectField event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling DeselectField: field=${event.field}');
    final updatedFields = state.selectedFields
        .where((f) => f['Field_name'] != event.field)
        .toList();

// Re-sequence fields after deselection
    for (int i = 0; i < updatedFields.length; i++) {
      updatedFields[i]['Sequence_no'] = i + 1;
    }
    updatedFields.sort((a, b) => (a['Sequence_no'] as int).compareTo(b['Sequence_no'] as int));


    final newCurrentField = updatedFields.isNotEmpty
        ? (state.currentField?['Field_name'] == event.field // If deselected field was current
        ? (updatedFields.isNotEmpty ? updatedFields.first : null) // set to first or null
        : state.currentField) // else keep current if it's still in the list
        : null;

    debugPrint('Bloc: Deselected field: ${event.field}, Updated selectedFields: ${updatedFields.length}');
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: newCurrentField,
    ));
  }

  void _onUpdateFieldConfig(UpdateFieldConfig event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling UpdateFieldConfig: key=${event.key}, value=${event.value}');
    if (state.currentField == null) {
      debugPrint('Bloc: No current field to update');
      return;
    }
    dynamic value = event.value;
    if (event.key == 'Sequence_no' || event.key == 'width' || event.key == 'decimal_points') {
      final parsed = value is int ? value : int.tryParse(value.toString());
      if (parsed == null && value != null && value.toString().isNotEmpty) {
        debugPrint('Bloc: Invalid value for ${event.key}: $value (must be integer)');
        return;
      }
      if (parsed != null && (event.key != 'decimal_points' && parsed < 0)) {
        debugPrint('Bloc: Invalid value for ${event.key}: $value (must be non-negative integer)');
        return;
      }
      value = parsed; // Store parsed int or null
    } else if (['Total', 'num_format', 'time', 'Breakpoint', 'SubTotal', 'image'].contains(event.key)) {
      value = event.value == true;
      debugPrint('Bloc: Updating boolean field ${event.key}: $value');
    }

// Special handling for field_params (list of maps) or payload_structure (list of maps)
    if (event.key == 'field_params' || event.key == 'payload_structure') {
      if (event.value is! List<Map<String, dynamic>>) {
        debugPrint('Bloc: UpdateFieldConfig: ${event.key} value is not List<Map<String, dynamic>>, skipping update.');
        return;
      }
    }


    final updatedField = {...state.currentField!, event.key: value};
    final updatedFields = state.selectedFields.map((field) {
      return field['Field_name'] == state.currentField!['Field_name'] ? updatedField : field;
    }).toList();

    updatedFields.sort((a, b) {
      final aSeq = a['Sequence_no'] as int? ?? 9999;
      final bSeq = b['Sequence_no'] as int? ?? 9999;
      return aSeq.compareTo(bSeq);
    });

    debugPrint('Bloc: Updated field: ${updatedField['Field_name']}, ${event.key}=$value, updatedFields count=${updatedFields.length}');
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: updatedField,
      error: null,
    ));
  }

// NEW: Handle ToggleFieldApiDriven event
  void _onToggleFieldApiDriven(ToggleFieldApiDriven event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling ToggleFieldApiDriven: isApiDriven=${event.isApiDriven}');
    if (state.currentField == null) {
      debugPrint('Bloc: No current field to update api_driven status.');
      return;
    }

    final updatedField = Map<String, dynamic>.from(state.currentField!);
    updatedField['is_api_driven'] = event.isApiDriven;

// Mutual exclusivity: if API Driven is turned on, turn off User Filling
    if (event.isApiDriven) {
      updatedField['is_user_filling'] = false;
      updatedField['updated_url'] = '';
      updatedField['payload_structure'] = <Map<String, dynamic>>[];
    } else {
// If API Driven is turned off, clear its specific fields
      updatedField['api_url'] = '';
      updatedField['field_params'] = <Map<String, dynamic>>[];
    }

    final updatedFields = state.selectedFields.map((field) {
      return field['Field_name'] == state.currentField!['Field_name'] ? updatedField : field;
    }).toList();

    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: updatedField,
      error: null,
    ));
  }

// NEW: Handle UpdateFieldApiUrl event
  void _onUpdateFieldApiUrl(UpdateFieldApiUrl event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling UpdateFieldApiUrl: apiUrl=${event.apiUrl}');
    if (state.currentField == null) {
      debugPrint('Bloc: No current field to update API URL.');
      return;
    }

    final updatedField = Map<String, dynamic>.from(state.currentField!);
    updatedField['api_url'] = event.apiUrl;

    final updatedFields = state.selectedFields.map((field) {
      return field['Field_name'] == state.currentField!['Field_name'] ? updatedField : field;
    }).toList();

    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: updatedField,
      error: null,
    ));
  }

// NEW: Handle ToggleFieldUserFilling event
  void _onToggleFieldUserFilling(ToggleFieldUserFilling event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling ToggleFieldUserFilling: isUserFilling=${event.isUserFilling}');
    if (state.currentField == null) {
      debugPrint('Bloc: No current field to update user_filling status.');
      return;
    }

    final updatedField = Map<String, dynamic>.from(state.currentField!);
    updatedField['is_user_filling'] = event.isUserFilling;

// Mutual exclusivity: if User Filling is turned on, turn off API Driven
    if (event.isUserFilling) {
      updatedField['is_api_driven'] = false;
      updatedField['api_url'] = '';
      updatedField['field_params'] = <Map<String, dynamic>>[];
    } else {
// If User Filling is turned off, clear its specific fields
      updatedField['updated_url'] = '';
      updatedField['payload_structure'] = <Map<String, dynamic>>[];
    }

    final updatedFields = state.selectedFields.map((field) {
      return field['Field_name'] == state.currentField!['Field_name'] ? updatedField : field;
    }).toList();

    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: updatedField,
      error: null,
    ));
  }

// NEW: Handle UpdateFieldUserFillingUrl event
  void _onUpdateFieldUserFillingUrl(UpdateFieldUserFillingUrl event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling UpdateFieldUserFillingUrl: updatedUrl=${event.updatedUrl}');
    if (state.currentField == null) {
      debugPrint('Bloc: No current field to update updated URL.');
      return;
    }

    final updatedField = Map<String, dynamic>.from(state.currentField!);
    updatedField['updated_url'] = event.updatedUrl;

    final updatedFields = state.selectedFields.map((field) {
      return field['Field_name'] == state.currentField!['Field_name'] ? updatedField : field;
    }).toList();

    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: updatedField,
      error: null,
    ));
  }

// NEW: Handle AddFieldPayloadParameter
  void _onAddFieldPayloadParameter(AddFieldPayloadParameter event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling AddFieldPayloadParameter for field: ${state.currentField!['Field_name']}, paramId=${event.paramId}');
    if (state.currentField == null) {
      debugPrint('Bloc: No current field to add payload parameter.');
      return;
    }

    final updatedField = Map<String, dynamic>.from(state.currentField!);
    final List<Map<String, dynamic>> payload = List<Map<String, dynamic>>.from(updatedField['payload_structure'] ?? []);
    payload.add({
      'id': event.paramId,
      'key': '',
      'value': '', // Default to empty string for initial value
      'value_type': 'dynamic', // Default to dynamic
      'is_user_input': false, // NEW: Default to false
    });
    updatedField['payload_structure'] = payload;

    final updatedFields = state.selectedFields.map((field) {
      return field['Field_name'] == state.currentField!['Field_name'] ? updatedField : field;
    }).toList();

    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: updatedField,
      error: null,
    ));
  }

// NEW: Handle RemoveFieldPayloadParameter
  void _onRemoveFieldPayloadParameter(RemoveFieldPayloadParameter event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling RemoveFieldPayloadParameter for field: ${state.currentField!['Field_name']}, paramId=${event.paramId}');
    if (state.currentField == null) {
      debugPrint('Bloc: No current field to remove payload parameter.');
      return;
    }

    final updatedField = Map<String, dynamic>.from(state.currentField!);
    final List<Map<String, dynamic>> payload = List<Map<String, dynamic>>.from(updatedField['payload_structure'] ?? []);
    payload.removeWhere((param) => param['id'] == event.paramId);
    updatedField['payload_structure'] = payload;

    final updatedFields = state.selectedFields.map((field) {
      return field['Field_name'] == state.currentField!['Field_name'] ? updatedField : field;
    }).toList();

    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: updatedField,
      error: null,
    ));
  }

// NEW: Handle UpdateFieldPayloadParameter
  void _onUpdateFieldPayloadParameter(UpdateFieldPayloadParameter event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling UpdateFieldPayloadParameter for field: ${state.currentField!['Field_name']}, paramId=${event.paramId}, key=${event.key}, value=${event.value}');
    if (state.currentField == null) {
      debugPrint('Bloc: No current field to update payload parameter.');
      return;
    }

    final updatedField = Map<String, dynamic>.from(state.currentField!);
    final List<Map<String, dynamic>> payload = List<Map<String, dynamic>>.from(updatedField['payload_structure']?.cast<Map<String, dynamic>>() ?? []);
    final updatedPayload = payload.map((param) {
      if (param['id'] == event.paramId) {
        return {...param, event.key: event.value};
      }
      return param;
    }).toList();
    updatedField['payload_structure'] = updatedPayload;

    final updatedFields = state.selectedFields.map((field) {
      return field['Field_name'] == state.currentField!['Field_name'] ? updatedField : field;
    }).toList();

    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: updatedField,
      error: null,
    ));
  }

// NEW: Handle ToggleFieldPayloadParameterUserInput
  void _onToggleFieldPayloadParameterUserInput(ToggleFieldPayloadParameterUserInput event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling ToggleFieldPayloadParameterUserInput for field: ${event.fieldName}, paramId=${event.paramId}, value=${event.value}');

    final updatedSelectedFields = List<Map<String, dynamic>>.from(state.selectedFields);
    final fieldIndex = updatedSelectedFields.indexWhere((f) => f['Field_name'] == event.fieldName);

    if (fieldIndex != -1) {
      final currentField = Map<String, dynamic>.from(updatedSelectedFields[fieldIndex]);
      final currentPayload = List<Map<String, dynamic>>.from(currentField['payload_structure']?.cast<Map<String, dynamic>>() ?? []);

      final updatedPayload = currentPayload.map((param) {
        if (param['id'] == event.paramId) {
// Set the target parameter's is_user_input
          return {
            ...param,
            'is_user_input': event.value,
          };
        } else if (event.value) { // If the event is to SET one to true, uncheck others
          return {
            ...param,
            'is_user_input': false,
          };
        }
        return param;
      }).toList();

      final updatedField = {
        ...currentField,
        'payload_structure': updatedPayload,
      };
      updatedSelectedFields[fieldIndex] = updatedField;

// Also update currentField if it's the one being edited
      final updatedCurrentField = (state.currentField?['Field_name'] == event.fieldName)
          ? updatedField
          : state.currentField;

      emit(state.copyWith(
        selectedFields: updatedSelectedFields,
        currentField: updatedCurrentField,
        error: null,
      ));
    } else {
      debugPrint('Bloc: Field ${event.fieldName} not found in selectedFields.');
    }
  }


// NEW: Extract parameters from API URL for a field
  Future<void> _onExtractFieldParametersFromUrl(ExtractFieldParametersFromUrl event, Emitter<EditDetailMakerState> emit) async {
    debugPrint('Bloc: ExtractFieldParametersFromUrl for fieldName=${event.fieldName}, apiUrl=${event.apiUrl}');

// Only set loading state if the current field being edited is the one we are fetching for
    final bool isCurrentField = state.currentField?['Field_name'] == event.fieldName;
    if (isCurrentField) {
      emit(state.copyWith(isFetchingFieldApiParams: true, currentFieldIdFetchingParams: event.fieldName, error: null));
    }

    try {
      final Uri? uri = Uri.tryParse(event.apiUrl);
      List<String> parameters = [];
      if (uri != null && uri.hasQuery) {
        parameters = uri.queryParameters.keys.toList();
        parameters.removeWhere((p) => ['type', 'ucode', 'val8'].contains(p.toLowerCase())); // Filter out common fixed parameters
      }

      debugPrint('Bloc: Extracted parameters from field API URL for ${event.fieldName}: $parameters');
      final updatedFieldApiCache = Map<String, List<String>>.from(state.fieldApiParametersCache);
// Explicitly cast event.fieldName to String
      updatedFieldApiCache[event.fieldName] = parameters;

// Update the 'field_params' list in the specific field in selectedFields
      final updatedSelectedFields = state.selectedFields.map((field) {
        if (field['Field_name'] == event.fieldName) {
          final List<Map<String, dynamic>> currentFieldParams = List<Map<String, dynamic>>.from(field['field_params']?.cast<Map<String, dynamic>>() ?? []);
// Keep only existing params that are still present in the new list of extracted parameters
// And ensure they have an 'id' for management in the UI (if new, assign one)
          final filteredFieldParams = <Map<String, dynamic>>[];
          for (var paramName in parameters) {
            final existingParam = currentFieldParams.firstWhere(
                  (p) => p['parameterName'] == paramName,
              orElse: () => {}, // Use an empty map if not found
            );
            if (existingParam.isNotEmpty) {
              filteredFieldParams.add(existingParam);
            } else {
              filteredFieldParams.add({
                'id': _uuid.v4(), // Assign a new ID if it's a newly discovered parameter
                'parameterName': paramName,
                'parameterValue': '', // Default to empty value
              });
            }
          }
          return {...field, 'field_params': filteredFieldParams};
        }
        return field;
      }).toList();

      Map<String, dynamic>? newCurrentField;
      if (isCurrentField) {
// Find the updated version of the current field from the `updatedSelectedFields` list
        newCurrentField = updatedSelectedFields.firstWhere(
              (f) => f['Field_name'] == event.fieldName,
          orElse: () => <String, dynamic>{}, // Return empty map if not found
        );
      }

      emit(state.copyWith(
        fieldApiParametersCache: updatedFieldApiCache,
        isFetchingFieldApiParams: false,
        currentFieldIdFetchingParams: null,
        selectedFields: updatedSelectedFields,
        currentField: newCurrentField ?? state.currentField, // Update currentField if it was the one
        error: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('Bloc: Error extracting field API parameters from URL for ${event.fieldName}: $e');
      debugPrint('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(
        isFetchingFieldApiParams: false,
        currentFieldIdFetchingParams: null,
        error: 'Failed to extract field API parameters from URL: ${e.toString()}',
      ));
    }
  }


  void _onUpdateCurrentField(UpdateCurrentField event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling UpdateCurrentField: field=${event.field['Field_name']}');
    emit(state.copyWith(currentField: event.field));
  }

  Future<void> _onSaveReport(SaveReport event, Emitter<EditDetailMakerState> emit) async {
    debugPrint('Bloc: Handling SaveReport: recNo=${event.recNo}, reportName=${event.reportName}');
    if (state.selectedFields.isEmpty) {
      debugPrint('Bloc: Save failed: No fields selected');
      emit(state.copyWith(
        isLoading: false,
        error: 'No fields selected to save.',
        saveSuccess: false,
      ));
      return;
    }

    emit(state.copyWith(isLoading: true, error: null, saveSuccess: false));
    try {
      debugPrint('Bloc: Preparing report metadata for saving.');

      debugPrint('Bloc: Processing field configs for saving.');
      final fieldConfigs = state.selectedFields.map((field) {
        return {
          'Field_name': field['Field_name']?.toString() ?? '',
          'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
          'Sequence_no': field['Sequence_no'] is int ? field['Sequence_no'] : int.tryParse(field['Sequence_no'].toString()) ?? 0,
          'width': field['width'] is int ? field['width'] : int.tryParse(field['width'].toString()) ?? 100,
          'Total': _parseBoolToInt(field['Total']),
          'num_alignment': field['num_alignment']?.toString().toLowerCase() ?? 'left',
          'time': _parseBoolToInt(field['time']),
          'indian_format': _parseBoolToInt(field['indian_format']), // Corrected key to indian_format
          'decimal_points': field['decimal_points'] is int ? field['decimal_points'] : int.tryParse(field['decimal_points'].toString()) ?? 0,
          'Breakpoint': _parseBoolToInt(field['Breakpoint']),
          'SubTotal': _parseBoolToInt(field['SubTotal']),
          'image': _parseBoolToInt(field['image']),
          'Group_by': _parseBoolToInt(field['Group_by']),
          'Filter': _parseBoolToInt(field['Filter']),
          'filterJson': field['filterJson']?.toString() ?? '',
          'orderby': _parseBoolToInt(field['orderby']),
          'orderjson': field['orderjson']?.toString() ?? '',
          'groupjson': field['groupjson']?.toString() ?? '',
// NEW: Add API Driven and User Filling properties to payload, JSON encode lists
          'is_api_driven': _parseBoolToInt(field['is_api_driven']),
          'api_url': field['api_url']?.toString() ?? '',
          'field_params': jsonEncode(field['field_params'] ?? []), // Convert list of maps to JSON string
          'is_user_filling': _parseBoolToInt(field['is_user_filling']),
          'updated_url': field['updated_url']?.toString() ?? '',
// Ensure 'is_user_input' is present in each payload item when saving
          'payload_structure': jsonEncode((field['payload_structure'] as List?)?.map((p) {
            if (p is Map) {
              return Map<String, dynamic>.from(p)..putIfAbsent('is_user_input', () => false);
            }
            return <String, dynamic>{'is_user_input': false};
          }).toList() ?? []), // Convert list of maps to JSON string
        };
      }).toList();

      debugPrint('Bloc: Payload for Demo_table_2 (fieldConfigs) for RecNo ${event.recNo}:');
      for (var config in fieldConfigs) {
        debugPrint('  Field: ${config['Field_name']}, is_api_driven: ${config['is_api_driven']}, api_url: ${config['api_url']}, field_params: ${config['field_params']}, is_user_filling: ${config['is_user_filling']}, updated_url: ${config['updated_url']}, payload_structure: ${config['payload_structure']}');
      }


      final processedActionsToSave = state.actions.map((action) {
        if (action['type'] == 'table') {
          return {
            ...action,
            'reportLabel': action['reportLabel'],
            'api': action['api'],
            'apiName_resolved': action['apiName_resolved'],
            'recNo_resolved': action['recNo_resolved'],
          };
        } else if (action['type'] == 'print') {
          return {
            ...action,
            'printTemplate': action['printTemplate']?.toString() ?? 'premium',
            'printColor': action['printColor']?.toString() ?? 'Blue',
          };
        }
        return action;
      }).toList();

      final List<Map<String, dynamic>> actionsToSaveFinal = event.needsAction ? processedActionsToSave : [];

      debugPrint('Bloc: Calling apiService.editDemoTables for RecNo: ${event.recNo}');
      debugPrint('Bloc: includePdfFooterDateTime being sent to API: ${event.includePdfFooterDateTime}');
      await apiService.editDemoTables(
        recNo: event.recNo,
        reportName: event.reportName, // Corrected: Using event parameter
        reportLabel: event.reportLabel, // Corrected: Using event parameter
        apiName: event.apiName, // Corrected: Using event parameter
        parameter: 'default',
        fieldConfigs: fieldConfigs,
        actions: actionsToSaveFinal,
        includePdfFooterDateTime: event.includePdfFooterDateTime,
      );

      debugPrint('Bloc: Save successful');
      emit(state.copyWith(isLoading: false, error: null, saveSuccess: true));
    } catch (e, stackTrace) {
      debugPrint('Bloc: Save error: $e');
      debugPrint('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(isLoading: false, error: 'Failed to update report: $e', saveSuccess: false));
    }
  }

// Helper to convert boolean to 0 or 1 for API
  int _parseBoolToInt(dynamic value) {
    if (value == true || value == 1) return 1;
    return 0;
  }


  void _onResetFields(ResetFields event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling ResetFields');
    if (state.initialRecNo == null) {
      debugPrint('Bloc: Cannot reset fields, initialRecNo is null.');
      emit(state.copyWith(
        error: 'Initial report details not loaded. Please reload the page.',
        saveSuccess: false,
      ));
      return;
    }

// Resetting to preselectedFields means re-parsing payload_structure to ensure
// 'is_user_input' defaults are applied if they weren't explicitly saved.
    final List<Map<String, dynamic>> reParsedPreselectedFields = state.preselectedFields.map((field) {
      if (field['is_user_filling'] == true) {
        final List<Map<String, dynamic>> parsedPayload = _parseJsonList(field['payload_structure']);
        final List<Map<String, dynamic>> finalPayload = parsedPayload.map((param) {
          return {
            ...param,
            'is_user_input': param['is_user_input'] ?? false,
          };
        }).toList();
        return {...field, 'payload_structure': finalPayload};
      }
      return field;
    }).toList();


    emit(state.copyWith(
      selectedFields: List.from(reParsedPreselectedFields), // Use re-parsed fields
      currentField: reParsedPreselectedFields.isNotEmpty ? reParsedPreselectedFields.first : null,
      error: null,
      saveSuccess: false,
      needsAction: false, // Reset needsAction, it will be re-evaluated
      actions: [], // Clear actions, they will be re-initialized from original config
      apiParametersCache: {},
      fieldApiParametersCache: {}, // Clear field API parameters cache on reset
      allReportLabels: state.allReportLabels,
      reportDetailsMap: state.reportDetailsMap,
      allApisDetails: state.allApisDetails,
      includePdfFooterDateTime: false, // Reset this to default (it will be re-loaded below)
    ));

    final currentReportEntry = state.reportDetailsMap.values.firstWhere(
          (report) => (report['RecNo']?.toString() ?? '0') == state.initialRecNo!.toString(),
      orElse: () {
        debugPrint('Bloc: Current report with RecNo ${state.initialRecNo} not found in allReports during reset.');
        return {};
      },
    );
    if (currentReportEntry.isNotEmpty) {
// Re-load includePdfFooterDateTime on reset from original config
      final bool initialPdfFooterDateTime = _parseBoolFromApi(currentReportEntry['pdf_footer_datetime']);
      debugPrint('Bloc: Re-loaded pdf_footer_datetime during reset: $initialPdfFooterDateTime');
      emit(state.copyWith(includePdfFooterDateTime: initialPdfFooterDateTime));

      if (currentReportEntry['actions_config'] != null) {
        final dynamic actionsConfigRaw = currentReportEntry['actions_config'];
        List<Map<String, dynamic>> initialActions = [];
        if (actionsConfigRaw is List) {
          initialActions = List<Map<String, dynamic>>.from(actionsConfigRaw);
        } else if (actionsConfigRaw is String && actionsConfigRaw.isNotEmpty) {
          try {
            initialActions = List<Map<String, dynamic>>.from(jsonDecode(actionsConfigRaw));
          } catch (e) {
            debugPrint('Bloc: Error decoding actions_config during reset: $e');
          }
        }
        if (initialActions.isNotEmpty) {
          final List<Map<String, dynamic>> tempActions = List.from(initialActions);
          for (int i = 0; i < tempActions.length; i++) {
            final action = tempActions[i];
            if (action['id'] == null || action['id'] is! String) {
              tempActions[i]['id'] = _uuid.v4();
            }

            if (action['type'] == 'print') {
              if (action['printTemplate'] == null) {
                tempActions[i]['printTemplate'] = 'premium';
              }
              if (action['printColor'] == null) {
                tempActions[i]['printColor'] = 'Blue';
              }
            }

            if (action['type'] == 'print' && action['api'] != null && (action['api'] as String).isNotEmpty) {
              add(ExtractParametersFromUrl(action['id'], action['api']));
            } else if (action['type'] == 'table' && action['reportLabel'] != null && (action['reportLabel'] as String).isNotEmpty) {
              final selectedReportLabel = action['reportLabel'] as String;
              final linkedReport = state.reportDetailsMap[selectedReportLabel];
              if (linkedReport != null) {
                final apiName = linkedReport['API_name']?.toString();
                if (apiName != null && apiName.isNotEmpty) {
                  tempActions[i]['api'] = state.allApisDetails[apiName]?['url']?.toString() ?? '';
                  tempActions[i]['apiName_resolved'] = apiName;
                  tempActions[i]['recNo_resolved'] = linkedReport['RecNo']?.toString() ?? '';
                  add(FetchParametersFromApiConfig(action['id'], apiName));
                }
              }
            }
          }
          emit(state.copyWith(actions: tempActions, needsAction: true));
        }
      }
    }
    debugPrint('Bloc: State reset to preselected fields and re-initialized actions and footer datetime.');
  }

  void _onToggleNeedsAction(ToggleNeedsActionEvent event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: ToggleNeedsAction: ${event.needsAction}');
    emit(state.copyWith(needsAction: event.needsAction));
  }

  void _onAddAction(AddAction event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: AddAction type=${event.type}, id=${event.id}');
    if (state.actions.length >= 5) {
      emit(state.copyWith(error: 'Maximum 5 actions allowed.'));
      return;
    }
    if (event.type == 'form' && state.actions.any((action) => action['type'] == 'form')) {
      emit(state.copyWith(error: 'Only one Form action is allowed.'));
      return;
    }

    final Map<String, dynamic> newAction;
    if (event.type == 'print') {
      newAction = {
        'id': event.id,
        'type': event.type,
        'name': '${event.type.toCapitalized()} ${state.actions.length + 1}',
        'api': '',
        'params': <Map<String, dynamic>>[],
        'printTemplate': 'premium',
        'printColor': 'Blue',
      };
    } else { // 'form' or 'table'
      newAction = {
        'id': event.id,
        'type': event.type,
        'name': '${event.type.toCapitalized()} ${state.actions.length + 1}',
        'api': '',
        'reportLabel': '',
        'apiName_resolved': '',
        'recNo_resolved': '',
        'params': <Map<String, dynamic>>[],
      };
    }

    final updatedActions = List<Map<String, dynamic>>.from(state.actions)..add(newAction);
    emit(state.copyWith(actions: updatedActions, error: null));
  }

  void _onRemoveAction(RemoveAction event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: RemoveAction id=${event.id}');
    final updatedActions = state.actions.where((action) => action['id'] != event.id).toList();
    final updatedCache = Map<String, List<String>>.from(state.apiParametersCache);
    updatedCache.remove(event.id);

    emit(state.copyWith(actions: updatedActions, apiParametersCache: updatedCache));
  }

  void _onUpdateActionConfig(UpdateActionConfig event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: UpdateActionConfig id=${event.actionId}, key=${event.key}, value=${event.value}');
    final updatedActions = state.actions.map((action) {
      if (action['id'] == event.actionId) {
        final Map<String, dynamic> updatedAction = Map<String, dynamic>.from(action);
        updatedAction[event.key] = event.value;

        return updatedAction;
      }
      return action;
    }).toList();
    emit(state.copyWith(actions: updatedActions));
  }

  void _onAddActionParameter(AddActionParameter event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: AddActionParameter actionId=${event.actionId}, paramId=${event.paramId}');
    final updatedActions = state.actions.map((action) {
      if (action['id'] == event.actionId) {
        final List<Map<String, dynamic>> params = List<Map<String, dynamic>>.from(action['params'] ?? []);
        params.add({
          'id': event.paramId,
          'parameterName': '',
          'parameterValue': '',
        });
        return {...action, 'params': params};
      }
      return action;
    }).toList();
    emit(state.copyWith(actions: updatedActions));
  }

  void _onRemoveActionParameter(RemoveActionParameter event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: RemoveActionParameter actionId=${event.actionId}, paramId=${event.paramId}');
    final updatedActions = state.actions.map((action) {
      if (action['id'] == event.actionId) {
        final List<Map<String, dynamic>> params = List<Map<String, dynamic>>.from(action['params'] ?? []);
        final updatedParams = params.where((param) => param['id'] != event.paramId).toList();
        return {...action, 'params': updatedParams};
      }
      return action;
    }).toList();
    emit(state.copyWith(actions: updatedActions));
  }

  void _onUpdateActionParameter(UpdateActionParameter event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: UpdateActionParameter actionId=${event.actionId}, paramId=${event.paramId}, key=${event.key}, value=${event.value}');
    final updatedActions = state.actions.map((action) {
      if (action['id'] == event.actionId) {
        final List<Map<String, dynamic>> params = List<Map<String, dynamic>>.from(action['params']?.cast<Map<String, dynamic>>() ?? []);
        final updatedParams = params.map((param) {
          if (param['id'] == event.paramId) {
            return {...param, event.key: event.value};
          }
          return param;
        }).toList();
        return {...action, 'params': updatedParams};
      }
      return action;
    }).toList();
    emit(state.copyWith(actions: updatedActions));
  }

  Future<void> _onExtractParametersFromUrl(ExtractParametersFromUrl event, Emitter<EditDetailMakerState> emit) async {
    debugPrint('Bloc: ExtractParametersFromUrl for actionId=${event.actionId}, apiUrl=${event.apiUrl}');

    emit(state.copyWith(isFetchingApiParams: true, currentActionIdFetching: event.actionId, error: null));

    try {
      final Uri? uri = Uri.tryParse(event.apiUrl);
      List<String> parameters = [];
      if (uri != null && uri.hasQuery) {
        parameters = uri.queryParameters.keys.toList();
        parameters.removeWhere((p) => ['type', 'ucode', 'val8'].contains(p.toLowerCase())); // Filter out common fixed parameters
      }

      debugPrint('Bloc: Extracted parameters from URL for ${event.actionId}: $parameters');
      final updatedCache = Map<String, List<String>>.from(state.apiParametersCache);
      updatedCache[event.actionId] = parameters;

      final updatedActions = state.actions.map((action) {
        if (action['id'] == event.actionId) {
          final List<Map<String, dynamic>> currentParams = List<Map<String, dynamic>>.from(action['params']?.cast<Map<String, dynamic>>() ?? []);
// Only keep parameters that are still present in the URL
          final filteredParams = <Map<String, dynamic>>[];
          for (var paramName in parameters) {
            final existingParam = currentParams.firstWhere(
                  (p) => p['parameterName'] == paramName,
              orElse: () => {}, // Use empty map if not found
            );
            if (existingParam.isNotEmpty) {
              filteredParams.add(existingParam);
            } else {
              filteredParams.add({
                'id': _uuid.v4(), // Assign new ID if newly discovered
                'parameterName': paramName,
                'parameterValue': '', // Default to empty
              });
            }
          }
          return {...action, 'params': filteredParams};
        }
        return action;
      }).toList();


      emit(state.copyWith(
        apiParametersCache: updatedCache,
        isFetchingApiParams: false,
        currentActionIdFetching: null,
        actions: updatedActions,
        error: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('Bloc: Error extracting API parameters from URL for ${event.actionId}: $e');
      debugPrint('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(
        isFetchingApiParams: false,
        currentActionIdFetching: null,
        error: 'Failed to extract API parameters from URL: ${e.toString()}',
      ));
    }
  }

  Future<void> _onFetchParametersFromApiConfig(FetchParametersFromApiConfig event, Emitter<EditDetailMakerState> emit) async {
    debugPrint('Bloc: FetchParametersFromApiConfig for actionId=${event.actionId}, apiName=${event.apiName}');
    emit(state.copyWith(isFetchingApiParams: true, currentActionIdFetching: event.actionId, error: null));

    try {
      Map<String, dynamic>? apiDetail = state.allApisDetails[event.apiName];
      if (apiDetail == null) {
        apiDetail = await apiService.getApiDetails(event.apiName);
        final newAllApisDetails = Map<String, Map<String, dynamic>>.from(state.allApisDetails);
        newAllApisDetails[event.apiName] = apiDetail;
        emit(state.copyWith(allApisDetails: newAllApisDetails));
      }

      final List<dynamic> rawParams = apiDetail?['parameters'] ?? [];
      List<String> parameterNames = [];
      if (rawParams.isNotEmpty) {
        parameterNames = rawParams.map((p) => p['name']?.toString() ?? '').where((name) => name.isNotEmpty).toList();
        parameterNames.removeWhere((p) => ['type', 'ucode', 'val8'].contains(p.toLowerCase()));
      }

      debugPrint('Bloc: Extracted config parameters for ${event.actionId} (API: ${event.apiName}): $parameterNames');
      final updatedCache = Map<String, List<String>>.from(state.apiParametersCache);
      updatedCache[event.actionId] = parameterNames;

      final updatedActions = state.actions.map((action) {
        if (action['id'] == event.actionId) {
          final List<Map<String, dynamic>> currentParams = List<Map<String, dynamic>>.from(action['params']?.cast<Map<String, dynamic>>() ?? []);
// Filter out existing parameters that are no longer in the API's configuration
          final filteredParams = <Map<String, dynamic>>[];
          for (var paramName in parameterNames) {
            final existingParam = currentParams.firstWhere(
                  (p) => p['parameterName'] == paramName,
              orElse: () => {}, // Use empty map if not found
            );
            if (existingParam.isNotEmpty) {
              filteredParams.add(existingParam);
            } else {
              filteredParams.add({
                'id': _uuid.v4(),
                'parameterName': paramName,
                'parameterValue': '',
              });
            }
          }
          return {...action, 'params': filteredParams};
        }
        return action;
      }).toList();

      emit(state.copyWith(
        apiParametersCache: updatedCache,
        isFetchingApiParams: false,
        currentActionIdFetching: null,
        actions: updatedActions,
        error: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('Bloc: Error fetching API config parameters for ${event.actionId}: $e');
      debugPrint('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(
        isFetchingApiParams: false,
        currentActionIdFetching: null,
        error: 'Failed to fetch API parameters from config: $e',
      ));
    }
  }

  Future<void> _onUpdateTableActionReport(UpdateTableActionReport event, Emitter<EditDetailMakerState> emit) async {
    debugPrint('Bloc: Handling UpdateTableActionReport for actionId=${event.actionId}, reportLabel=${event.reportLabel}');

    final updatedActions = List<Map<String, dynamic>>.from(state.actions);
    final actionIndex = updatedActions.indexWhere((a) => a['id'] == event.actionId);

    if (actionIndex != -1) {
      debugPrint('Bloc: Found action at index $actionIndex.');
      final selectedReportData = state.reportDetailsMap[event.reportLabel];
      String resolvedApiUrl = '';
      String? resolvedApiName;
      String? recNoResolved;
      String? error;
      List<Map<String, dynamic>> newParams = []; // Clear parameters on report label change

      if (event.reportLabel.isEmpty) {
        debugPrint('Bloc: Report label cleared. Clearing resolved API and params.');
        resolvedApiUrl = '';
        resolvedApiName = '';
        recNoResolved = '';
      } else if (selectedReportData != null) {
        debugPrint('Bloc: Found report details for label: ${event.reportLabel}');
        resolvedApiName = selectedReportData['API_name']?.toString();
        recNoResolved = selectedReportData['RecNo']?.toString();
        debugPrint('Bloc: Resolved RecNo from report details: $recNoResolved');

        if (resolvedApiName != null && resolvedApiName.isNotEmpty) {
          debugPrint('Bloc: Resolved API_name from report details: $resolvedApiName');
          final apiDetail = state.allApisDetails[resolvedApiName];
          if (apiDetail != null) {
            resolvedApiUrl = apiDetail['url']?.toString() ?? '';
            debugPrint('Bloc: Found API details for resolved API_name: $resolvedApiName, URL: $resolvedApiUrl (from cache)');
          } else {
            try {
              final fetchedApiDetail = await apiService.getApiDetails(resolvedApiName);
              resolvedApiUrl = fetchedApiDetail['url']?.toString() ?? '';
              final newAllApisDetails = Map<String, Map<String, dynamic>>.from(state.allApisDetails);
              newAllApisDetails[resolvedApiName] = fetchedApiDetail;
              emit(state.copyWith(allApisDetails: newAllApisDetails));
              debugPrint('Bloc: Fetched API details for resolved API_name: $resolvedApiName, URL: $resolvedApiUrl (explicit fetch)');
            } catch (e) {
              error = 'API details (URL) not found for API Name: $resolvedApiName. Error: $e';
              debugPrint('Bloc: ERROR: $e');
            }
          }
        } else {
          error = 'API Name not found for Report Label: ${event.reportLabel}. Check demo_table configuration.';
          debugPrint('Bloc: ERROR: $error');
        }
      } else {
        error = 'Report details not found for label: ${event.reportLabel}. This report might not exist in demo_table.';
        debugPrint('Bloc: ERROR: $error');
      }

      final updatedAction = Map<String, dynamic>.from(updatedActions[actionIndex]);
      updatedAction['reportLabel'] = event.reportLabel;
      updatedAction['api'] = resolvedApiUrl;
      updatedAction['apiName_resolved'] = resolvedApiName;
      updatedAction['recNo_resolved'] = recNoResolved;
      updatedAction['params'] = newParams; // Clear old parameters

      updatedActions[actionIndex] = updatedAction;

      final updatedCache = Map<String, List<String>>.from(state.apiParametersCache);
      if (error != null || event.reportLabel.isEmpty) {
        updatedCache.remove(event.actionId);
      }

      emit(state.copyWith(actions: updatedActions, error: error, apiParametersCache: updatedCache));

      if (resolvedApiName != null && resolvedApiName.isNotEmpty && error == null && resolvedApiUrl.isNotEmpty) {
        debugPrint('Bloc: Dispatching FetchParametersFromApiConfig for actionId: ${event.actionId}, apiName: $resolvedApiName');
        add(FetchParametersFromApiConfig(event.actionId, resolvedApiName));
      } else {
        debugPrint('Bloc: Not dispatching FetchParametersFromApiConfig due to missing resolved API name, URL or error.');
      }
    } else {
      debugPrint('Bloc: UpdateTableActionReport: Action with ID ${event.actionId} not found.');
    }
  }


  Future<void> _onFetchAllReports(FetchAllReports event, Emitter<EditDetailMakerState> emit) async {
    debugPrint('Bloc: FetchAllReports initiated (manual trigger, usually handled by LoadPreselectedFields)');
    try {
      final reports = await apiService.fetchDemoTable();
      final List<String> availableReportLabels = [];
      final Map<String, Map<String, dynamic>> reportDetailsMap = {};
      for (var report in reports) {
        final label = report['Report_label']?.toString();
        final recNo = report['RecNo']?.toString() ?? '';
        final apiName = report['API_name']?.toString() ?? '';
        if (label != null && label.isNotEmpty && !availableReportLabels.contains(label)) {
          availableReportLabels.add(label);
          reportDetailsMap[label] = {
            ...report,
            'RecNo': recNo,
            'API_name': apiName,
          };
        }
      }
      emit(state.copyWith(allReportLabels: availableReportLabels, reportDetailsMap: reportDetailsMap));
      debugPrint('Bloc: Fetched ${reports.length} reports for autocomplete.');
    } catch (e, stackTrace) {
      debugPrint('Bloc: Error fetching all reports: $e');
      debugPrint('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(error: 'Failed to load reports for autocomplete: $e'));
    }
  }

  Future<void> _onFetchAllApiDetails(FetchAllApiDetails event, Emitter<EditDetailMakerState> emit) async {
    debugPrint('Bloc: FetchAllApiDetails initiated (manual trigger, usually handled by LoadPreselectedFields)');
    try {
      final List<String> apiNames = await apiService.getAvailableApis();
      final Map<String, Map<String, dynamic>> apiDetailsMap = {};
      for (String name in apiNames) {
        apiDetailsMap[name] = await apiService.getApiDetails(name);
      }
      emit(state.copyWith(allApisDetails: apiDetailsMap));
      debugPrint('Bloc: Fetched ${apiNames.length} API details.');
    } catch (e, stackTrace) {
      debugPrint('Bloc: Error fetching all API details: $e');
      debugPrint('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(error: 'Failed to load API details: $e'));
    }
  }

  void _onToggleIncludePdfFooterDateTime(ToggleIncludePdfFooterDateTime event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Toggling includePdfFooterDateTime to: ${event.include}');
    emit(state.copyWith(includePdfFooterDateTime: event.include));
  }
}

extension StringCasingExtension on String {
  String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
}