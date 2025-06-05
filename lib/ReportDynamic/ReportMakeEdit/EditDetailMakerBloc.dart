import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../ReportAPIService.dart';

class EditDetailMakerEvent {}

class LoadPreselectedFields extends EditDetailMakerEvent {
  final int recNo;
  final String apiName;
  LoadPreselectedFields(this.recNo, this.apiName);
}

class SelectField extends EditDetailMakerEvent {
  final String field;
  SelectField(this.field);
}

class DeselectField extends EditDetailMakerEvent {
  final String field;
  DeselectField(this.field);
}

class UpdateFieldConfig extends EditDetailMakerEvent {
  final String key;
  final dynamic value;
  UpdateFieldConfig(this.key, this.value);
}

class UpdateCurrentField extends EditDetailMakerEvent {
  final Map<String, dynamic> field;
  UpdateCurrentField(this.field);
}

class SaveReport extends EditDetailMakerEvent {
  final int recNo;
  final String reportName;
  final String reportLabel;
  final String apiName;
  final String parameter;
  final bool needsAction;
  final List<Map<String, dynamic>> actions;

  SaveReport({
    required this.recNo,
    required this.reportName,
    required this.reportLabel,
    required this.apiName,
    required this.parameter,
    required this.needsAction,
    required this.actions,
  });
}

class ResetFields extends EditDetailMakerEvent {}

class ToggleNeedsActionEvent extends EditDetailMakerEvent {
  final bool needsAction;
  ToggleNeedsActionEvent(this.needsAction);
}

class AddAction extends EditDetailMakerEvent {
  final String type; // 'form', 'print', 'table'
  final String id;
  AddAction(this.type, this.id);
}

class RemoveAction extends EditDetailMakerEvent {
  final String id;
  RemoveAction(this.id);
}

class UpdateActionConfig extends EditDetailMakerEvent {
  final String actionId;
  final String key;
  final dynamic value;
  UpdateActionConfig(this.actionId, this.key, this.value);
}

class AddActionParameter extends EditDetailMakerEvent {
  final String actionId;
  final String paramId;
  AddActionParameter(this.actionId, this.paramId);
}

class RemoveActionParameter extends EditDetailMakerEvent {
  final String actionId;
  final String paramId;
  RemoveActionParameter(this.actionId, this.paramId);
}

class UpdateActionParameter extends EditDetailMakerEvent {
  final String actionId;
  final String paramId;
  final String key; // 'parameterName' or 'parameterValue'
  final dynamic value;
  UpdateActionParameter(this.actionId, this.paramId, this.key, this.value);
}

class ExtractParametersFromUrl extends EditDetailMakerEvent {
  final String actionId;
  final String apiUrl;
  ExtractParametersFromUrl(this.actionId, this.apiUrl);
}

class FetchParametersFromApiConfig extends EditDetailMakerEvent {
  final String actionId;
  final String apiName; // The configured APIName from database_server
  FetchParametersFromApiConfig(this.actionId, this.apiName);
}

class UpdateTableActionReport extends EditDetailMakerEvent {
  final String actionId;
  final String reportLabel; // The selected Report_label
  UpdateTableActionReport(this.actionId, this.reportLabel);
}

class FetchAllReports extends EditDetailMakerEvent {}
class FetchAllApiDetails extends EditDetailMakerEvent {}


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
  final Map<String, List<String>> apiParametersCache;
  final bool isFetchingApiParams;
  final String? currentActionIdFetching;

  final List<String> allReportLabels;
  final Map<String, Map<String, dynamic>> reportDetailsMap;
  final Map<String, Map<String, dynamic>> allApisDetails;

  final int? initialRecNo; // NEW: Store the initial RecNo
  final String? initialApiName; // NEW: Store the initial ApiName


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
    this.allReportLabels = const [],
    this.reportDetailsMap = const {},
    this.allApisDetails = const {},
    this.initialRecNo, // Add to constructor
    this.initialApiName, // Add to constructor
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
    List<String>? allReportLabels,
    Map<String, Map<String, dynamic>>? reportDetailsMap,
    Map<String, Map<String, dynamic>>? allApisDetails,
    int? initialRecNo, // Add to copyWith
    String? initialApiName, // Add to copyWith
  }) {
    return EditDetailMakerState(
      fields: fields ?? this.fields,
      selectedFields: selectedFields ?? this.selectedFields,
      preselectedFields: preselectedFields ?? this.preselectedFields,
      currentField: currentField ?? this.currentField,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Pass null explicitly if you want to clear error
      saveSuccess: saveSuccess ?? this.saveSuccess,
      needsAction: needsAction ?? this.needsAction,
      actions: actions ?? this.actions,
      apiParametersCache: apiParametersCache ?? this.apiParametersCache,
      isFetchingApiParams: isFetchingApiParams ?? this.isFetchingApiParams,
      currentActionIdFetching: currentActionIdFetching,
      allReportLabels: allReportLabels ?? this.allReportLabels,
      reportDetailsMap: reportDetailsMap ?? this.reportDetailsMap,
      allApisDetails: allApisDetails ?? this.allApisDetails,
      initialRecNo: initialRecNo ?? this.initialRecNo, // Update copyWith logic
      initialApiName: initialApiName ?? this.initialApiName, // Update copyWith logic
    );
  }
}

class EditDetailMakerBloc extends Bloc<EditDetailMakerEvent, EditDetailMakerState> {
  final ReportAPIService apiService;
  final Uuid _uuid = const Uuid();

  EditDetailMakerBloc(this.apiService) : super(EditDetailMakerState()) {
    debugPrint('Bloc: EditDetailMakerBloc initialized');
    on<LoadPreselectedFields>(_onLoadPreselectedFields);
    on<SelectField>(_onSelectField);
    on<DeselectField>(_onDeselectField);
    on<UpdateFieldConfig>(_onUpdateFieldConfig);
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
  }

  Future<void> _onLoadPreselectedFields(LoadPreselectedFields event, Emitter<EditDetailMakerState> emit) async {
    debugPrint('Bloc: Handling LoadPreselectedFields: recNo=${event.recNo}, apiName=${event.apiName}');
    emit(state.copyWith(
      isLoading: true,
      error: null, // Clear any previous errors
      saveSuccess: false, // Reset save success status
      fields: [],
      selectedFields: [],
      preselectedFields: [],
      currentField: null,
      needsAction: false,
      actions: [],
      apiParametersCache: {},
      allReportLabels: [], // Clear on load
      reportDetailsMap: {}, // Clear on load
      allApisDetails: {}, // Clear on load
      initialRecNo: event.recNo, // Store the initial RecNo
      initialApiName: event.apiName, // Store the initial ApiName
    ));

    try {
      debugPrint('Bloc: Fetching fields, preselected fields, all demo_table reports, and all API details concurrently');
      final results = await Future.wait([
        apiService.fetchApiData(event.apiName), // Get API fields for selection
        apiService.fetchDemoTable2(event.recNo.toString()), // Get fields for current report
        apiService.fetchDemoTable(), // Get all reports to find actions_config and report labels
        apiService.getAvailableApis().then((apiNames) async { // Get all API names, then fetch details for each
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

      final List<String> fields = apiData.isNotEmpty ? apiData[0].keys.map((key) => key.toString()).toList() : [];
      debugPrint('Bloc: Fields extracted from API: ${fields.length}');


// Process allReports for available Report_labels and their details
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
            'API_name': apiName, // Ensure API_name is stored
          };
        }
      }
      debugPrint('Bloc: Available report labels: ${availableReportLabels.length}');


      final formattedFields = preselectedFieldsRaw.map((field) {
        final formatted = {
          'Field_name': field['Field_name']?.toString() ?? '',
          'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
          'Sequence_no': int.tryParse(field['Sequence_no']?.toString() ?? '') ?? 0,
          'width': int.tryParse(field['width']?.toString() ?? '') ?? 100,
          'Total': _parseBoolFromApi(field['Total']),
          'num_alignment': field['num_alignment']?.toString().toLowerCase() ?? 'left',
          'time': _parseBoolFromApi(field['time']),
          'num_format': _parseBoolFromApi(field['indian_format']), // IMPORTANT: Use correct key 'indian_format' and parse to 'num_format' (internal state)
          'decimal_points': int.tryParse(field['decimal_points']?.toString() ?? '') ?? 0,
          'Breakpoint': _parseBoolFromApi(field['Breakpoint']),
          'SubTotal': _parseBoolFromApi(field['SubTotal']),
          'image': _parseBoolFromApi(field['image']),
// Defaulting other fields if not present in API, ensuring they are booleans/strings
          'Group_by': _parseBoolFromApi(field['Group_by']),
          'Filter': _parseBoolFromApi(field['Filter']),
          'filterJson': field['filterJson']?.toString() ?? '',
          'orderby': _parseBoolFromApi(field['orderby']),
          'orderjson': field['orderjson']?.toString() ?? '',
          'groupjson': field['groupjson']?.toString() ?? '',
        };
        return formatted;
      }).toList();
      formattedFields.sort((a, b) => (a['Sequence_no'] as int).compareTo(b['Sequence_no'] as int));

      bool needsAction = false;
      List<Map<String, dynamic>> actions = [];
      final currentReportEntry = allReports.firstWhere(
            (report) => (report['RecNo']?.toString() ?? '0') == event.recNo.toString(),
        orElse: () {
          debugPrint('Bloc: Current report with RecNo ${event.recNo} not found in allReports.');
          return {};
        },
      );

      if (currentReportEntry.isNotEmpty && currentReportEntry['actions_config'] != null) {
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
// Ensure action 'id' is a string UUID for consistency if not already
          if (action['id'] == null || action['id'] is! String) {
            tempActions[i]['id'] = _uuid.v4();
          }

          if (action['type'] == 'print' && action['api'] != null && (action['api'] as String).isNotEmpty) {
// Immediately extract parameters for print actions
            add(ExtractParametersFromUrl(action['id'], action['api']));
          } else if (action['type'] == 'table' && action['reportLabel'] != null && (action['reportLabel'] as String).isNotEmpty) {
            final selectedReportLabel = action['reportLabel'] as String;
            final linkedReport = reportDetailsMap[selectedReportLabel];

            if (linkedReport != null) {
              final apiName = linkedReport['API_name']?.toString();
              final recNoResolved = linkedReport['RecNo']?.toString();
              tempActions[i]['recNo_resolved'] = recNoResolved;
              tempActions[i]['reportLabel'] = selectedReportLabel; // Ensure reportLabel is also set for Autocomplete initialValue

              if (apiName != null && apiName.isNotEmpty) {
                final apiDetail = allApisDetails[apiName];
                if (apiDetail != null) {
                  final apiUrl = apiDetail['url']?.toString() ?? '';
                  tempActions[i]['api'] = apiUrl;
                  tempActions[i]['apiName_resolved'] = apiName;
// Immediately fetch parameters for table actions based on resolved API_name
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

      emit(state.copyWith(
        fields: fields,
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

// Helper to parse API boolean-like values
  bool _parseBoolFromApi(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }


  void _onSelectField(SelectField event, Emitter<EditDetailMakerState> emit) {
    debugPrint('Bloc: Handling SelectField: field=${event.field}');
    if (state.selectedFields.any((f) => f['Field_name'] == event.field)) {
      debugPrint('Bloc: Field already selected: ${event.field}, skipping');
      return;
    }

    final preselectedMatch = state.preselectedFields.firstWhere(
          (f) => f['Field_name'] == event.field,
      orElse: () => {},
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
      'num_alignment': 'left', 'time': false, 'num_format': false, 'decimal_points': 0, // Using 'num_format' as internal name for indian_format
      'Breakpoint': false, 'SubTotal': false, 'image': false,
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
      if (parsed == null && value != null && value.toString().isNotEmpty) { // If value is not null/empty but parsing failed
        debugPrint('Bloc: Invalid value for ${event.key}: $value (must be integer)');
        return; // Don't update state with invalid input
      }
      if (parsed != null && (event.key != 'decimal_points' && parsed < 0)) { // Allow 0 for decimal_points, but not negative
        debugPrint('Bloc: Invalid value for ${event.key}: $value (must be non-negative integer)');
        return;
      }
      value = parsed; // Store parsed int or null
    } else if (['Total', 'num_format', 'time', 'Breakpoint', 'SubTotal', 'image'].contains(event.key)) { // Use 'num_format' here
      value = event.value == true;
      debugPrint('Bloc: Updating boolean field ${event.key}: $value');
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
      error: null, // Clear any errors if update is successful
    ));
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
          'indian_format': _parseBoolToInt(field['num_format']), // FIX: Ensure this is 0 or 1 for backend key 'indian_format' from internal 'num_format'
          'decimal_points': field['decimal_points'] is int ? field['decimal_points'] : int.tryParse(field['decimal_points'].toString()) ?? 0,
          'Breakpoint': _parseBoolToInt(field['Breakpoint']),
          'SubTotal': _parseBoolToInt(field['SubTotal']),
          'image': _parseBoolToInt(field['image']),
          'Group_by': _parseBoolToInt(field['Group_by']), // Ensure these are also 0 or 1
          'Filter': _parseBoolToInt(field['Filter']),
          'filterJson': field['filterJson']?.toString() ?? '',
          'orderby': _parseBoolToInt(field['orderby']),
          'orderjson': field['orderjson']?.toString() ?? '',
          'groupjson': field['groupjson']?.toString() ?? '',
        };
      }).toList();

      final processedActionsToSave = state.actions.map((action) {
        if (action['type'] == 'table') {
          return {
            ...action,
            'reportLabel': action['reportLabel'],
            'api': action['api'],
            'apiName_resolved': action['apiName_resolved'],
            'recNo_resolved': action['recNo_resolved'],
          };
        }
        return action;
      }).toList();

      final List<Map<String, dynamic>> actionsToSaveFinal = event.needsAction ? processedActionsToSave : [];

      debugPrint('Bloc: Calling apiService.editDemoTables for RecNo: ${event.recNo}');
      await apiService.editDemoTables(
        recNo: event.recNo,
        reportName: event.reportName,
        reportLabel: event.reportLabel,
        apiName: event.apiName,
        parameter: 'default',
        fieldConfigs: fieldConfigs,
        actions: actionsToSaveFinal,
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
// Ensure initialRecNo exists before trying to use it
    if (state.initialRecNo == null) {
      debugPrint('Bloc: Cannot reset fields, initialRecNo is null.');
      emit(state.copyWith(
        error: 'Initial report details not loaded. Please reload the page.',
        saveSuccess: false,
      ));
      return;
    }

    emit(state.copyWith(
      selectedFields: List.from(state.preselectedFields),
      currentField: state.preselectedFields.isNotEmpty ? state.preselectedFields.first : null,
      error: null,
      saveSuccess: false,
      needsAction: false, // Reset needsAction, it will be re-evaluated
      actions: [], // Clear actions, they will be re-initialized from original config
      apiParametersCache: {},
      allReportLabels: state.allReportLabels,
      reportDetailsMap: state.reportDetailsMap,
      allApisDetails: state.allApisDetails,
    ));

// Re-trigger the initial action loading if needed based on original config
    final currentReportEntry = state.reportDetailsMap.values.firstWhere(
          (report) => (report['RecNo']?.toString() ?? '0') == state.initialRecNo!.toString(), // FIX: Use state.initialRecNo
      orElse: () {
        debugPrint('Bloc: Current report with RecNo ${state.initialRecNo} not found in allReports during reset.');
        return {};
      },
    );
    if (currentReportEntry.isNotEmpty && currentReportEntry['actions_config'] != null) {
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
            tempActions[i]['id'] = _uuid.v4(); // Assign new UUID if missing
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
    debugPrint('Bloc: State reset to preselected fields and re-initialized actions.');
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

    final newAction = {
      'id': event.id,
      'type': event.type,
      'name': '${event.type.toCapitalized()} ${state.actions.length + 1}',
      'api': '',
      'reportLabel': '', // Only used by 'table' type
      'apiName_resolved': '', // Only used by 'table' type
      'recNo_resolved': '', // Only used by 'table' type
      'params': <Map<String, dynamic>>[],
    };

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

// No need to dispatch ExtractParametersFromUrl here for 'api' change,
// as that's handled in the UI with debouncing for 'print' action.
// For 'table' action, 'api' is resolved by 'reportLabel' change.

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
        final List<Map<String, dynamic>> params = List<Map<String, dynamic>>.from(action['params'] ?? []);
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
          final List<Map<String, dynamic>> currentParams = List<Map<String, dynamic>>.from(action['params'] ?? []);
// Only keep parameters that are still found in the extracted list
          final filteredParams = currentParams.where((p) => parameters.contains(p['parameterName'])).toList();
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
// If API details not in cache, fetch it.
      if (apiDetail == null) {
        apiDetail = await apiService.getApiDetails(event.apiName); // This service call also updates its internal cache
        final newAllApisDetails = Map<String, Map<String, dynamic>>.from(state.allApisDetails);
        newAllApisDetails[event.apiName] = apiDetail;
        emit(state.copyWith(allApisDetails: newAllApisDetails));
      }

      final List<dynamic> rawParams = apiDetail?['parameters'] ?? [];
      List<String> parameterNames = [];
      if (rawParams.isNotEmpty) {
        parameterNames = rawParams.map((p) => p['name']?.toString() ?? '').where((name) => name.isNotEmpty).toList();
        parameterNames.removeWhere((p) => ['type', 'ucode', 'val8'].contains(p.toLowerCase())); // Filter out common fixed parameters
      }

      debugPrint('Bloc: Extracted config parameters for ${event.actionId} (API: ${event.apiName}): $parameterNames');
      final updatedCache = Map<String, List<String>>.from(state.apiParametersCache);
      updatedCache[event.actionId] = parameterNames;

      final updatedActions = state.actions.map((action) {
        if (action['id'] == event.actionId) {
          final List<Map<String, dynamic>> currentParams = List<Map<String, dynamic>>.from(action['params'] ?? []);
          final filteredParams = currentParams.where((p) => parameterNames.contains(p['parameterName'])).toList();
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
// Try to get API details from cache first
          final apiDetail = state.allApisDetails[resolvedApiName];
          if (apiDetail != null) {
            resolvedApiUrl = apiDetail['url']?.toString() ?? '';
            debugPrint('Bloc: Found API details for resolved API_name: $resolvedApiName, URL: $resolvedApiUrl (from cache)');
          } else {
// If not in cache, explicitly fetch it and update state's allApisDetails
            try {
              final fetchedApiDetail = await apiService.getApiDetails(resolvedApiName);
              resolvedApiUrl = fetchedApiDetail['url']?.toString() ?? '';
              final newAllApisDetails = Map<String, Map<String, dynamic>>.from(state.allApisDetails);
              newAllApisDetails[resolvedApiName] = fetchedApiDetail;
              emit(state.copyWith(allApisDetails: newAllApisDetails));
              debugPrint('Bloc: Fetched API details for resolved API_name: $resolvedApiName, URL: $resolvedApiUrl (explicit fetch)');
            } catch (e) {
              error = 'API details (URL) not found for API Name: $resolvedApiName. Error: $e';
              debugPrint('Bloc: ERROR: $error');
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
      updatedAction['api'] = resolvedApiUrl; // Set resolved API URL
      updatedAction['apiName_resolved'] = resolvedApiName;
      updatedAction['recNo_resolved'] = recNoResolved;
      updatedAction['params'] = newParams; // Clear old parameters

      updatedActions[actionIndex] = updatedAction;

      final updatedCache = Map<String, List<String>>.from(state.apiParametersCache);
      if (error != null || event.reportLabel.isEmpty) {
        updatedCache.remove(event.actionId); // Clear cached parameters if there's an error or label is cleared
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


// These are manually triggered in case of a problem, usually done by LoadPreselectedFields
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
}

extension StringCasingExtension on String {
  String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
}