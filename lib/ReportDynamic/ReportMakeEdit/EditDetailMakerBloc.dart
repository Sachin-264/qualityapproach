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

// MODIFIED: Event for extracting parameters from a URL string (for 'print' action)
class ExtractParametersFromUrl extends EditDetailMakerEvent {
  final String actionId;
  final String apiUrl;
  ExtractParametersFromUrl(this.actionId, this.apiUrl);
}

// NEW: Event for fetching parameters from a configured API (for 'table' action)
class FetchParametersFromApiConfig extends EditDetailMakerEvent {
  final String actionId;
  final String apiName; // The configured APIName from database_server
  FetchParametersFromApiConfig(this.actionId, this.apiName);
}

// NEW: Event for selecting a report label for a Table action
class UpdateTableActionReport extends EditDetailMakerEvent {
  final String actionId;
  final String reportLabel; // The selected Report_label
  UpdateTableActionReport(this.actionId, this.reportLabel);
}

// Events to manually trigger fetching all reports and APIs (useful for initial state population)
class FetchAllReports extends EditDetailMakerEvent {}
class FetchAllApiDetails extends EditDetailMakerEvent {}


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

  // NEW: Report labels and their details for Table action
  final List<String> allReportLabels;
  final Map<String, Map<String, dynamic>> reportDetailsMap; // Maps Report_label to its full demo_table entry
  final Map<String, Map<String, dynamic>> allApisDetails; // Maps APIName to its full database_server entry (for URL lookup)


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
  }) {
    return EditDetailMakerState(
      fields: fields ?? this.fields,
      selectedFields: selectedFields ?? this.selectedFields,
      preselectedFields: preselectedFields ?? this.preselectedFields,
      currentField: currentField ?? this.currentField,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      saveSuccess: saveSuccess ?? this.saveSuccess,
      needsAction: needsAction ?? this.needsAction,
      actions: actions ?? this.actions,
      apiParametersCache: apiParametersCache ?? this.apiParametersCache,
      isFetchingApiParams: isFetchingApiParams ?? this.isFetchingApiParams,
      currentActionIdFetching: currentActionIdFetching,
      allReportLabels: allReportLabels ?? this.allReportLabels,
      reportDetailsMap: reportDetailsMap ?? this.reportDetailsMap,
      allApisDetails: allApisDetails ?? this.allApisDetails,
    );
  }
}

class EditDetailMakerBloc extends Bloc<EditDetailMakerEvent, EditDetailMakerState> {
  final ReportAPIService apiService;
  final Uuid _uuid = const Uuid();

  EditDetailMakerBloc(this.apiService) : super(EditDetailMakerState()) {
    print('Bloc: EditDetailMakerBloc initialized');
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

    // New/Modified handlers for API parameters
    on<ExtractParametersFromUrl>(_onExtractParametersFromUrl);
    on<FetchParametersFromApiConfig>(_onFetchParametersFromApiConfig);

    // NEW: Table action specific handlers
    on<UpdateTableActionReport>(_onUpdateTableActionReport);
    on<FetchAllReports>(_onFetchAllReports); // Can be called manually if needed
    on<FetchAllApiDetails>(_onFetchAllApiDetails); // Can be called manually if needed
  }

  Future<void> _onLoadPreselectedFields(LoadPreselectedFields event, Emitter<EditDetailMakerState> emit) async {
    print('Bloc: Handling LoadPreselectedFields: recNo=${event.recNo}, apiName=${event.apiName}');
    emit(state.copyWith(
      isLoading: true,
      error: null,
      fields: [],
      selectedFields: [],
      preselectedFields: [],
      currentField: null,
      needsAction: false,
      actions: [],
      apiParametersCache: {},
      allReportLabels: [], // Clear previous
      reportDetailsMap: {}, // Clear previous
      allApisDetails: {}, // Clear previous
    ));
    print('Bloc: Emitted initial loading state: isLoading=true');

    try {
      print('Bloc: Fetching fields, preselected fields, all demo_table reports, and all API details concurrently');
      final results = await Future.wait([
        apiService.fetchApiData(event.apiName), // Get API fields for selection
        apiService.fetchDemoTable2(event.recNo.toString()), // Get fields for current report
        apiService.fetchDemoTable(), // Get all reports to find actions_config
        apiService.getAvailableApis().then((apiNames) async { // Get all API names, then fetch details for each
          final Map<String, Map<String, dynamic>> allApisDetails = {};
          for (String apiName in apiNames) {
            allApisDetails[apiName] = await apiService.getApiDetails(apiName);
          }
          return allApisDetails;
        }),
      ]);

      print('Bloc: All data fetched successfully');
      final apiData = results[0] as List<Map<String, dynamic>>;
      final preselectedFieldsRaw = results[1] as List<Map<String, dynamic>>;
      final allReports = results[2] as List<Map<String, dynamic>>;
      final Map<String, Map<String, dynamic>> allApisDetails = results[3] as Map<String, Map<String, dynamic>>;
      print('Bloc: Available API details populated: ${allApisDetails.length}');

      // Process allReports for available Report_labels and their details
      final List<String> availableReportLabels = [];
      final Map<String, Map<String, dynamic>> reportDetailsMap = {};
      for (var report in allReports) {
        final label = report['Report_label']?.toString();
        // Ensure RecNo is explicitly converted to String to match potential future use in UIs, or keep as int if always int
        final recNo = report['RecNo']?.toString() ?? '';
        if (label != null && label.isNotEmpty && !availableReportLabels.contains(label)) {
          availableReportLabels.add(label);
          reportDetailsMap[label] = {
            ...report, // Keep all existing report data
            'RecNo': recNo, // Ensure RecNo is consistently string or int as needed
          };
        }
      }
      print('Bloc: Available report labels: ${availableReportLabels.length}');


      final List<String> fields = apiData.isNotEmpty ? apiData[0].keys.map((key) => key.toString()).toList() : [];
      print('Bloc: Fields extracted from API: ${fields.length}');

      final formattedFields = preselectedFieldsRaw.map((field) {
        final formatted = {
          'Field_name': field['Field_name']?.toString() ?? '',
          'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
          'Sequence_no': int.tryParse(field['Sequence_no']?.toString() ?? '') ?? 0,
          'width': int.tryParse(field['width']?.toString() ?? '') ?? 100,
          'Total': field['Total'] == '1' || field['Total'] == true || field['Total'] == 1,
          'num_alignment': field['num_alignment']?.toString().toLowerCase() ?? 'left',
          'time': field['time'] == '1' || field['time'] == true || field['time'] == 1,
          'num_format': field['indian_format'] == '1' || field['indian_format'] == true || field['indian_format'] == 1,
          'decimal_points': int.tryParse(field['decimal_points']?.toString() ?? '') ?? 0,
          'Breakpoint': field['Breakpoint'] == '1' || field['Breakpoint'] == true || field['Breakpoint'] == 1,
          'SubTotal': field['SubTotal'] == '1' || field['SubTotal'] == true || field['SubTotal'] == 1,
          'image': field['image'] == '1' || field['image'] == true || field['image'] == 1,
          'Group_by': false, 'Filter': false, 'filterJson': '', 'orderby': false, 'orderjson': '', 'groupjson': '',
        };
        return formatted;
      }).toList();
      formattedFields.sort((a, b) => (a['Sequence_no'] as int).compareTo(b['Sequence_no'] as int));

      bool needsAction = false;
      List<Map<String, dynamic>> actions = [];
      final currentReportEntry = allReports.firstWhere(
            (report) => (report['RecNo']?.toString() ?? '0') == event.recNo.toString(),
        orElse: () => {},
      );

      if (currentReportEntry.isNotEmpty && currentReportEntry['actions_config'] != null) {
        final dynamic actionsConfigRaw = currentReportEntry['actions_config'];
        if (actionsConfigRaw is List) {
          actions = List<Map<String, dynamic>>.from(actionsConfigRaw);
        } else if (actionsConfigRaw is String && actionsConfigRaw.isNotEmpty) {
          try {
            actions = List<Map<String, dynamic>>.from(jsonDecode(actionsConfigRaw));
          } catch (e) {
            print('Bloc: Error decoding actions_config: $e. Raw: $actionsConfigRaw');
            actions = [];
          }
        }
        needsAction = actions.isNotEmpty;
        print('Bloc: Loaded actions_config for RecNo ${event.recNo}: ${actions.length} actions. needsAction=$needsAction');

        // For existing actions, trigger parameter fetching based on type
        // Use a temporary list to allow modification during iteration
        final List<Map<String, dynamic>> tempActions = List.from(actions);
        for (int i = 0; i < tempActions.length; i++) {
          final action = tempActions[i];
          if (action['type'] == 'print' && action['api'] != null && (action['api'] as String).isNotEmpty) {
            // For 'print' actions, parameters are extracted from the URL query string
            add(ExtractParametersFromUrl(action['id'], action['api']));
          } else if (action['type'] == 'table' && action['reportLabel'] != null && (action['reportLabel'] as String).isNotEmpty) {
            final selectedReportLabel = action['reportLabel'] as String;
            final linkedReport = reportDetailsMap[selectedReportLabel];

            if (linkedReport != null) {
              final apiName = linkedReport['API_name']?.toString();
              final recNoResolved = linkedReport['RecNo']?.toString();
              tempActions[i]['recNo_resolved'] = recNoResolved; // Update in temp list
              tempActions[i]['reportLabel'] = selectedReportLabel; // Ensure reportLabel is also set for Autocomplete initialValue

              if (apiName != null && apiName.isNotEmpty) {
                final apiDetail = allApisDetails[apiName];
                if (apiDetail != null) {
                  final apiUrl = apiDetail['url']?.toString() ?? '';
                  tempActions[i]['api'] = apiUrl; // Update the action's API field with the resolved URL
                  tempActions[i]['apiName_resolved'] = apiName; // Store the resolved API name
                  add(FetchParametersFromApiConfig(action['id'], apiName)); // Get params from database_server config
                } else {
                  print('Bloc: API details not found for API Name: $apiName for report label: $selectedReportLabel');
                  tempActions[i]['api'] = ''; // Clear API if lookup fails
                  tempActions[i]['params'] = []; // Clear params if API fails
                  tempActions[i]['apiName_resolved'] = ''; // Clear resolved API name
                }
              }
            } else {
              print('Bloc: Linked report not found for label: $selectedReportLabel');
              tempActions[i]['api'] = ''; // Clear API if linked report not found
              tempActions[i]['params'] = []; // Clear params
              tempActions[i]['apiName_resolved'] = ''; // Clear resolved API name
              tempActions[i]['recNo_resolved'] = ''; // Clear resolved RecNo if linked report not found
            }
          }
        }
        actions = tempActions; // Assign the potentially modified list back
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
      print('Bloc: Final state emitted successfully after loading existing actions.');
    } catch (e, stackTrace) {
      print('Bloc: Error in LoadPreselectedFields: $e');
      print('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to load fields and report details: $e',
      ));
      print('Bloc: Error state emitted');
    }
  }

  void _onSelectField(SelectField event, Emitter<EditDetailMakerState> emit) {
    print('Bloc: Handling SelectField: field=${event.field}');
    if (state.selectedFields.any((f) => f['Field_name'] == event.field)) {
      print('Bloc: Field already selected: ${event.field}, skipping');
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
      'num_alignment': 'left', 'time': false, 'num_format': false, 'decimal_points': 0,
      'Breakpoint': false, 'SubTotal': false, 'image': false,
    };

    final updatedFields = [...state.selectedFields, newField];
    updatedFields.sort((a, b) => (a['Sequence_no'] as int).compareTo(b['Sequence_no'] as int));

    print('Bloc: Selected field: ${event.field}, Updated selectedFields: ${updatedFields.length}');
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: newField,
    ));
  }

  void _onDeselectField(DeselectField event, Emitter<EditDetailMakerState> emit) {
    print('Bloc: Handling DeselectField: field=${event.field}');
    final updatedFields = state.selectedFields
        .where((f) => f['Field_name'] != event.field)
        .toList();

    for (int i = 0; i < updatedFields.length; i++) {
      updatedFields[i]['Sequence_no'] = i + 1;
    }
    updatedFields.sort((a, b) => (a['Sequence_no'] as int).compareTo(b['Sequence_no'] as int));

    final newCurrentField = updatedFields.isNotEmpty
        ? updatedFields.first
        : null;

    print('Bloc: Deselected field: ${event.field}, Updated selectedFields: ${updatedFields.length}');
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: newCurrentField,
    ));
  }

  void _onUpdateFieldConfig(UpdateFieldConfig event, Emitter<EditDetailMakerState> emit) {
    print('Bloc: Handling UpdateFieldConfig: key=${event.key}, value=${event.value}');
    if (state.currentField == null) {
      print('Bloc: No current field to update');
      return;
    }
    dynamic value = event.value;
    if (event.key == 'Sequence_no' || event.key == 'width' || event.key == 'decimal_points') {
      final parsed = value is int ? value : int.tryParse(value.toString());
      if (parsed == null || (event.key != 'decimal_points' && parsed <= 0)) {
        print('Bloc: Invalid value for ${event.key}: $value');
        return;
      }
      value = parsed;
    } else if (['Total', 'num_format', 'time', 'Breakpoint', 'SubTotal', 'image'].contains(event.key)) {
      value = event.value == true;
      print('Bloc: Updating boolean field ${event.key}: $value');
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

    print('Bloc: Updated field: ${updatedField['Field_name']}, ${event.key}=$value, updatedFields count=${updatedFields.length}');
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: updatedField,
    ));
  }

  void _onUpdateCurrentField(UpdateCurrentField event, Emitter<EditDetailMakerState> emit) {
    print('Bloc: Handling UpdateCurrentField: field=${event.field['Field_name']}');
    emit(state.copyWith(currentField: event.field));
  }

  Future<void> _onSaveReport(SaveReport event, Emitter<EditDetailMakerState> emit) async {
    print('Bloc: Handling SaveReport: recNo=${event.recNo}, reportName=${event.reportName}');
    if (state.selectedFields.isEmpty) {
      print('Bloc: Save failed: No fields selected');
      emit(state.copyWith(
        isLoading: false,
        error: 'No fields selected to save.',
        saveSuccess: false,
      ));
      return;
    }

    emit(state.copyWith(isLoading: true, error: null, saveSuccess: false));
    try {
      print('Bloc: Preparing report metadata for saving.');

      print('Bloc: Processing field configs for saving.');
      final fieldConfigs = state.selectedFields.map((field) {
        return {
          'Field_name': field['Field_name']?.toString() ?? '',
          'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
          'Sequence_no': field['Sequence_no'] is int ? field['Sequence_no'] : int.tryParse(field['Sequence_no'].toString()) ?? 0,
          'width': field['width'] is int ? field['width'] : int.tryParse(field['width'].toString()) ?? 100,
          'Total': field['Total'] == true ? 1 : 0,
          'num_alignment': field['num_alignment']?.toString().toLowerCase() ?? 'left',
          'time': field['time'] == true ? 1 : 0,
          'indian_format': field['num_format'] == true ? 1 : 0,
          'decimal_points': field['decimal_points'] is int ? field['decimal_points'] : int.tryParse(field['decimal_points'].toString()) ?? 0,
          'Breakpoint': field['Breakpoint'] == true ? 1 : 0,
          'SubTotal': field['SubTotal'] == true ? 1 : 0,
          'image': field['image'] == true ? 1 : 0,
        };
      }).toList();

      // For 'table' actions, ensure we save the 'reportLabel' and the resolved 'api' (URL) and 'apiName_resolved'
      final processedActionsToSave = state.actions.map((action) {
        if (action['type'] == 'table') {
          return {
            // Keep all existing fields from the action
            ...action,
            // Ensure these specific fields are explicitly included if they might have been added/updated
            'reportLabel': action['reportLabel'],
            'api': action['api'],
            'apiName_resolved': action['apiName_resolved'],
            'recNo_resolved': action['recNo_resolved'],
          };
        }
        return action;
      }).toList();

      // Only include actions if needsAction is true
      final List<Map<String, dynamic>> actionsToSaveFinal = event.needsAction ? processedActionsToSave : [];

      print('Bloc: Calling apiService.editDemoTables for RecNo: ${event.recNo}');
      await apiService.editDemoTables(
        recNo: event.recNo,
        reportName: event.reportName,
        reportLabel: event.reportLabel,
        apiName: event.apiName,
        parameter: 'default',
        fieldConfigs: fieldConfigs,
        actions: actionsToSaveFinal,
      );

      print('Bloc: Save successful');
      emit(state.copyWith(isLoading: false, error: null, saveSuccess: true));
    } catch (e, stackTrace) {
      print('Bloc: Save error: $e');
      print('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(isLoading: false, error: 'Failed to update report: $e', saveSuccess: false));
    }
  }

  void _onResetFields(ResetFields event, Emitter<EditDetailMakerState> emit) {
    print('Bloc: Handling ResetFields');
    emit(state.copyWith(
      selectedFields: List.from(state.preselectedFields),
      currentField: state.preselectedFields.isNotEmpty ? state.preselectedFields.first : null,
      error: null,
      saveSuccess: false,
      needsAction: state.preselectedFields.isNotEmpty, // Reset needsAction based on original load
      actions: [], // Clear actions on reset (or restore original actions if stored in a separate state property)
      apiParametersCache: {},
      allReportLabels: state.allReportLabels, // Keep static data
      reportDetailsMap: state.reportDetailsMap, // Keep static data
      allApisDetails: state.allApisDetails, // Keep static data
    ));
    print('Bloc: State reset to preselected fields and cleared actions.');
  }

  void _onToggleNeedsAction(ToggleNeedsActionEvent event, Emitter<EditDetailMakerState> emit) {
    print('Bloc: ToggleNeedsAction: ${event.needsAction}');
    emit(state.copyWith(needsAction: event.needsAction));
  }

  void _onAddAction(AddAction event, Emitter<EditDetailMakerState> emit) {
    print('Bloc: AddAction type=${event.type}, id=${event.id}');
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
      'api': '', // For Table type, this will be auto-populated from Report_label
      'reportLabel': '', // For 'table' type, store the selected report label
      'apiName_resolved': '', // Store the resolved APIName for 'table' type
      'recNo_resolved': '', // Store the resolved RecNo for 'table' type
      'params': <Map<String, dynamic>>[],
    };

    final updatedActions = List<Map<String, dynamic>>.from(state.actions)..add(newAction);
    emit(state.copyWith(actions: updatedActions, error: null));
  }

  void _onRemoveAction(RemoveAction event, Emitter<EditDetailMakerState> emit) {
    print('Bloc: RemoveAction id=${event.id}');
    final updatedActions = state.actions.where((action) => action['id'] != event.id).toList();
    final updatedCache = Map<String, List<String>>.from(state.apiParametersCache);
    updatedCache.remove(event.id);

    emit(state.copyWith(actions: updatedActions, apiParametersCache: updatedCache));
  }

  void _onUpdateActionConfig(UpdateActionConfig event, Emitter<EditDetailMakerState> emit) {
    print('Bloc: UpdateActionConfig id=${event.actionId}, key=${event.key}, value=${event.value}');
    final updatedActions = state.actions.map((action) {
      if (action['id'] == event.actionId) {
        final Map<String, dynamic> updatedAction = Map<String, dynamic>.from(action);
        updatedAction[event.key] = event.value;

        // If it's a 'print' action and the 'api' (URL) is being updated, extract parameters
        if (updatedAction['type'] == 'print' && event.key == 'api' && (event.value as String).isNotEmpty) {
          // Add a small delay to prevent rapid updates while user types
          Future.delayed(const Duration(milliseconds: 700), () {
            add(ExtractParametersFromUrl(event.actionId, event.value));
          });
        }
        // IMPORTANT: For 'table' actions, the 'reportLabel' update should NOT trigger
        // API resolution here on every keystroke. That's handled by UpdateTableActionReport event.
        // This 'UpdateActionConfig' only updates the string value in the state.
        return updatedAction;
      }
      return action;
    }).toList();
    emit(state.copyWith(actions: updatedActions));
  }

  void _onAddActionParameter(AddActionParameter event, Emitter<EditDetailMakerState> emit) {
    print('Bloc: AddActionParameter actionId=${event.actionId}, paramId=${event.paramId}');
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
    print('Bloc: RemoveActionParameter actionId=${event.actionId}, paramId=${event.paramId}');
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
    print('Bloc: UpdateActionParameter actionId=${event.actionId}, paramId=${event.paramId}, key=${event.key}, value=${event.value}');
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
    print('Bloc: ExtractParametersFromUrl for actionId=${event.actionId}, apiUrl=${event.apiUrl}');

    emit(state.copyWith(isFetchingApiParams: true, currentActionIdFetching: event.actionId, error: null));

    try {
      final Uri? uri = Uri.tryParse(event.apiUrl);
      List<String> parameters = [];
      if (uri != null && uri.hasQuery) {
        parameters = uri.queryParameters.keys.toList();
        parameters.removeWhere((p) => ['type', 'ucode', 'val8'].contains(p.toLowerCase()));
      }

      print('Bloc: Extracted parameters from URL for ${event.actionId}: $parameters');
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
      ));
    } catch (e, stackTrace) {
      print('Bloc: Error extracting API parameters from URL for ${event.actionId}: $e');
      print('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(
        isFetchingApiParams: false,
        currentActionIdFetching: null,
        error: 'Failed to extract API parameters from URL: ${e.toString()}',
      ));
    }
  }

  Future<void> _onFetchParametersFromApiConfig(FetchParametersFromApiConfig event, Emitter<EditDetailMakerState> emit) async {
    print('Bloc: FetchParametersFromApiConfig for actionId=${event.actionId}, apiName=${event.apiName}');
    emit(state.copyWith(isFetchingApiParams: true, currentActionIdFetching: event.actionId, error: null));

    try {
      // Use the cached API details if available, otherwise fetch
      Map<String, dynamic>? apiDetail = state.allApisDetails[event.apiName];
      if (apiDetail == null) {
        // Fallback if not already cached (should ideally be cached by LoadPreselectedFields)
        apiDetail = await apiService.getApiDetails(event.apiName);
        // Also update allApisDetails in state if new detail is fetched
        final newAllApisDetails = Map<String, Map<String, dynamic>>.from(state.allApisDetails);
        newAllApisDetails[event.apiName] = apiDetail;
        emit(state.copyWith(allApisDetails: newAllApisDetails));
      }

      final List<dynamic> rawParams = apiDetail?['parameters'] ?? []; // Use null-safe access here
      List<String> parameterNames = [];
      if (rawParams.isNotEmpty) {
        // Extract just the 'name' from each parameter object
        parameterNames = rawParams.map((p) => p['name']?.toString() ?? '').where((name) => name.isNotEmpty).toList();
      }

      print('Bloc: Extracted config parameters for ${event.actionId} (API: ${event.apiName}): $parameterNames');
      final updatedCache = Map<String, List<String>>.from(state.apiParametersCache);
      updatedCache[event.actionId] = parameterNames;

      final updatedActions = state.actions.map((action) {
        if (action['id'] == event.actionId) {
          final List<Map<String, dynamic>> currentParams = List<Map<String, dynamic>>.from(action['params'] ?? []);
          // Only keep parameters that are still found in the fetched list
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
      ));
    } catch (e, stackTrace) {
      print('Bloc: Error fetching API config parameters for ${event.actionId}: $e');
      print('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(
        isFetchingApiParams: false,
        currentActionIdFetching: null,
        error: 'Failed to fetch API parameters from config: $e',
      ));
    }
  }

  Future<void> _onUpdateTableActionReport(UpdateTableActionReport event, Emitter<EditDetailMakerState> emit) async {
    print('Bloc: Handling UpdateTableActionReport for actionId=${event.actionId}, reportLabel=${event.reportLabel}');

    final updatedActions = List<Map<String, dynamic>>.from(state.actions);
    final actionIndex = updatedActions.indexWhere((a) => a['id'] == event.actionId);

    if (actionIndex != -1) {
      print('Bloc: Found action at index $actionIndex.');
      final selectedReportData = state.reportDetailsMap[event.reportLabel];
      String resolvedApiUrl = '';
      String? resolvedApiName;
      String? recNoResolved;
      String? error;
      List<Map<String, dynamic>> newParams = []; // To clear params if lookup fails

      if (event.reportLabel.isEmpty) { // Handle case where reportLabel is cleared
        print('Bloc: Report label cleared. Clearing resolved API and params.');
        resolvedApiUrl = '';
        resolvedApiName = '';
        recNoResolved = '';
        newParams = [];
        // No error, as clearing is a valid action
      } else if (selectedReportData != null) {
        print('Bloc: Found report details for label: ${event.reportLabel}');
        resolvedApiName = selectedReportData['API_name']?.toString();
        recNoResolved = selectedReportData['RecNo']?.toString();
        print('Bloc: Resolved RecNo from report details: $recNoResolved');

        if (resolvedApiName != null && resolvedApiName.isNotEmpty) {
          print('Bloc: Resolved API_name from report details: $resolvedApiName');
          final apiDetail = state.allApisDetails[resolvedApiName];
          if (apiDetail != null) {
            resolvedApiUrl = apiDetail['url']?.toString() ?? '';
            print('Bloc: Found API details for resolved API_name: $resolvedApiName, URL: $resolvedApiUrl');
          } else {
            error = 'API details (URL) not found for API Name: $resolvedApiName. Please configure API details in database server.';
            print('Bloc: ERROR: $error');
          }
        } else {
          error = 'API Name not found for Report Label: ${event.reportLabel}. Check demo_table configuration.';
          print('Bloc: ERROR: $error');
        }
      } else {
        error = 'Report details not found for label: ${event.reportLabel}. This report might not exist in demo_table.';
        print('Bloc: ERROR: $error');
      }

      final updatedAction = Map<String, dynamic>.from(updatedActions[actionIndex]);
      updatedAction['reportLabel'] = event.reportLabel;
      updatedAction['api'] = resolvedApiUrl;
      updatedAction['apiName_resolved'] = resolvedApiName;
      updatedAction['recNo_resolved'] = recNoResolved;
      updatedAction['params'] = newParams; // Clear params on selection/resolution

      updatedActions[actionIndex] = updatedAction;

      // Also clear the cached parameters for this action if an error occurred or label was cleared
      final updatedCache = Map<String, List<String>>.from(state.apiParametersCache);
      if (error != null || event.reportLabel.isEmpty) {
        updatedCache.remove(event.actionId);
      }

      emit(state.copyWith(actions: updatedActions, error: error, apiParametersCache: updatedCache));

      // Trigger parameter fetching using the resolved API_name ONLY if resolved and no error
      if (resolvedApiName != null && resolvedApiName.isNotEmpty && error == null) {
        print('Bloc: Dispatching FetchParametersFromApiConfig for actionId: ${event.actionId}, apiName: $resolvedApiName');
        add(FetchParametersFromApiConfig(event.actionId, resolvedApiName));
      } else {
        print('Bloc: Not dispatching FetchParametersFromApiConfig due to missing resolved API name or error.');
      }
    } else {
      print('Bloc: UpdateTableActionReport: Action with ID ${event.actionId} not found.');
    }
  }

  Future<void> _onFetchAllReports(FetchAllReports event, Emitter<EditDetailMakerState> emit) async {
    print('Bloc: FetchAllReports initiated (manual trigger, usually handled by LoadPreselectedFields)');
    try {
      final reports = await apiService.fetchDemoTable();
      final List<String> availableReportLabels = [];
      final Map<String, Map<String, dynamic>> reportDetailsMap = {};
      for (var report in reports) {
        final label = report['Report_label']?.toString();
        final recNo = report['RecNo']?.toString() ?? '';
        if (label != null && label.isNotEmpty && !availableReportLabels.contains(label)) {
          availableReportLabels.add(label);
          reportDetailsMap[label] = {
            ...report,
            'RecNo': recNo,
          };
        }
      }
      emit(state.copyWith(allReportLabels: availableReportLabels, reportDetailsMap: reportDetailsMap));
      print('Bloc: Fetched ${reports.length} reports for autocomplete.');
    } catch (e, stackTrace) {
      print('Bloc: Error fetching all reports: $e');
      print('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(error: 'Failed to load reports for autocomplete: $e'));
    }
  }

  Future<void> _onFetchAllApiDetails(FetchAllApiDetails event, Emitter<EditDetailMakerState> emit) async {
    print('Bloc: FetchAllApiDetails initiated (manual trigger, usually handled by LoadPreselectedFields)');
    try {
      final List<String> apiNames = await apiService.getAvailableApis();
      final Map<String, Map<String, dynamic>> apiDetailsMap = {};
      for (String name in apiNames) {
        apiDetailsMap[name] = await apiService.getApiDetails(name);
      }
      emit(state.copyWith(allApisDetails: apiDetailsMap));
      print('Bloc: Fetched ${apiNames.length} API details.');
    } catch (e, stackTrace) {
      print('Bloc: Error fetching all API details: $e');
      print('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(error: 'Failed to load API details: $e'));
    }
  }
}

extension StringCasingExtension on String {
  String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
}