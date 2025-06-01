import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  SaveReport({
    required this.recNo,
    required this.reportName,
    required this.reportLabel,
    required this.apiName,
    required this.parameter,
  });
}

class ResetFields extends EditDetailMakerEvent {}

class EditDetailMakerState {
  final List<String> fields;
  final List<Map<String, dynamic>> selectedFields;
  final List<Map<String, dynamic>> preselectedFields;
  final Map<String, dynamic>? currentField;
  final bool isLoading;
  final String? error;
  final bool saveSuccess;

  EditDetailMakerState({
    this.fields = const [],
    this.selectedFields = const [],
    this.preselectedFields = const [],
    this.currentField,
    this.isLoading = false,
    this.error,
    this.saveSuccess = false,
  });

  EditDetailMakerState copyWith({
    List<String>? fields,
    List<Map<String, dynamic>>? selectedFields,
    List<Map<String, dynamic>>? preselectedFields,
    Map<String, dynamic>? currentField,
    bool? isLoading,
    String? error,
    bool? saveSuccess,
  }) {
    return EditDetailMakerState(
      fields: fields ?? this.fields,
      selectedFields: selectedFields ?? this.selectedFields,
      preselectedFields: preselectedFields ?? this.preselectedFields,
      currentField: currentField ?? this.currentField,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      saveSuccess: saveSuccess ?? this.saveSuccess,
    );
  }
}

class EditDetailMakerBloc extends Bloc<EditDetailMakerEvent, EditDetailMakerState> {
  final ReportAPIService apiService;

  EditDetailMakerBloc(this.apiService) : super(EditDetailMakerState()) {
    print('Bloc: EditDetailMakerBloc initialized');
    on<LoadPreselectedFields>(_onLoadPreselectedFields);
    on<SelectField>(_onSelectField);
    on<DeselectField>(_onDeselectField);
    on<UpdateFieldConfig>(_onUpdateFieldConfig);
    on<UpdateCurrentField>(_onUpdateCurrentField);
    on<SaveReport>(_onSaveReport);
    on<ResetFields>(_onResetFields);
  }

  Future<void> _onLoadPreselectedFields(LoadPreselectedFields event, Emitter<EditDetailMakerState> emit) async {
    print('Bloc: Handling LoadPreselectedFields: recNo=${event.recNo}, apiName=${event.apiName}');
    emit(state.copyWith(isLoading: true, error: null, fields: [], selectedFields: [], preselectedFields: [], currentField: null)); // Clear state before loading
    print('Bloc: Emitted initial loading state: isLoading=true');

    try {
      print('Bloc: Fetching fields and preselected fields concurrently');
      final results = await Future.wait([
        apiService.fetchApiData(event.apiName),
        apiService.fetchDemoTable2(event.recNo.toString()),
      ]);

      print('Bloc: All data fetched successfully');
      final apiData = results[0] as List<Map<String, dynamic>>;
      final preselectedFieldsRaw = results[1] as List<Map<String, dynamic>>;

      print('Bloc: Processing apiData: length=${apiData.length}');
      final List<String> fields = apiData.isNotEmpty ? apiData[0].keys.map((key) => key.toString()).toList() : [];
      print('Bloc: Fields extracted: ${fields.length} fields, fields=$fields');

      print('Bloc: Processing preselectedFields (raw): length=${preselectedFieldsRaw.length}');
      final formattedFields = preselectedFieldsRaw.map((field) {
        final formatted = {
          'Field_name': field['Field_name']?.toString() ?? '',
          'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
          'Sequence_no': int.tryParse(field['Sequence_no']?.toString() ?? '') ?? 0,
          'width': int.tryParse(field['width']?.toString() ?? '') ?? 100,
          'Total': field['Total'] == '1' || field['Total'] == true || field['Total'] == 1, // Handle 1 as int or string
          'num_alignment': field['num_alignment']?.toString().toLowerCase() ?? 'left',
          'time': field['time'] == '1' || field['time'] == true || field['time'] == 1, // Handle 1 as int or string
          'num_format': field['indian_format'] == '1' || field['indian_format'] == true || field['indian_format'] == 1, // Handle 1 as int or string
          'decimal_points': int.tryParse(field['decimal_points']?.toString() ?? '') ?? 0,
          'Breakpoint': field['Breakpoint'] == '1' || field['Breakpoint'] == true || field['Breakpoint'] == 1, // New field
          'SubTotal': field['SubTotal'] == '1' || field['SubTotal'] == true || field['SubTotal'] == 1,     // New field
          'image': field['image'] == '1' || field['image'] == true || field['image'] == 1, // NEW: Handle image field
          'Group_by': false, // Assuming these are not retrieved from demo_table2 directly
          'Filter': false,
          'filterJson': '',
          'orderby': false,
          'orderjson': '',
          'groupjson': '',
        };
        print('Bloc: Formatted field: ${formatted['Field_name']}, config=$formatted');
        return formatted;
      }).toList();

      // Sort fields by Sequence_no
      formattedFields.sort((a, b) => (a['Sequence_no'] as int).compareTo(b['Sequence_no'] as int));

      print('Bloc: Emitting final state: fields=${fields.length}, selectedFields=${formattedFields.length}, preselectedFields=${formattedFields.length}');
      emit(state.copyWith(
        fields: fields,
        selectedFields: formattedFields,
        preselectedFields: formattedFields,
        currentField: formattedFields.isNotEmpty ? formattedFields.first : null, // Set first field as current if available
        isLoading: false,
        error: null,
      ));
      print('Bloc: Final state emitted successfully');
    } catch (e, stackTrace) {
      print('Bloc: Error in LoadPreselectedFields: $e');
      print('Bloc: Stack trace: $stackTrace');
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to load fields: $e',
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

    // Try to find if this field was previously preselected (i.e., part of the original report)
    final preselectedMatch = state.preselectedFields.firstWhere(
          (f) => f['Field_name'] == event.field,
      orElse: () => {}, // Return empty map if not found
    );

    final newField = preselectedMatch.isNotEmpty
        ? preselectedMatch // Use existing configuration if it was preselected
        : {
      'Field_name': event.field,
      'Field_label': event.field,
      'Sequence_no': state.selectedFields.isNotEmpty
          ? (state.selectedFields.map((f) => f['Sequence_no'] as int).reduce((a, b) => a > b ? a : b) + 1)
          : 1, // Auto-increment sequence number
      'width': 100,
      'Total': false,
      'Group_by': false,
      'Filter': false,
      'filterJson': '',
      'orderby': false,
      'orderjson': '',
      'groupjson': '',
      'num_alignment': 'left',
      'time': false,
      'num_format': false,
      'decimal_points': 0,
      'Breakpoint': false,
      'SubTotal': false,
      'image': false, // NEW: Initialize new field
    };

    final updatedFields = [...state.selectedFields, newField];
    updatedFields.sort((a, b) => (a['Sequence_no'] as int).compareTo(b['Sequence_no'] as int)); // Keep sorted

    print('Bloc: Selected field: ${event.field}, Updated selectedFields: ${updatedFields.length}');
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: newField, // Set newly selected/preselected field as current
    ));
  }

  void _onDeselectField(DeselectField event, Emitter<EditDetailMakerState> emit) {
    print('Bloc: Handling DeselectField: field=${event.field}');
    final updatedFields = state.selectedFields
        .where((f) => f['Field_name'] != event.field)
        .toList();

    // Re-sequence the remaining fields
    for (int i = 0; i < updatedFields.length; i++) {
      updatedFields[i]['Sequence_no'] = i + 1;
    }
    updatedFields.sort((a, b) => (a['Sequence_no'] as int).compareTo(b['Sequence_no'] as int)); // Keep sorted

    final newCurrentField = updatedFields.isNotEmpty
        ? updatedFields.first // Set first remaining field as current
        : null; // No fields left

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
    } else if (['Total', 'num_format', 'time', 'Breakpoint', 'SubTotal', 'image'].contains(event.key)) { // NEW: Include 'image'
      value = event.value == true; // Ensure boolean types
      print('Bloc: Updating boolean field ${event.key}: $value');
    }
    final updatedField = {...state.currentField!, event.key: value};
    final updatedFields = state.selectedFields.map((field) {
      return field['Field_name'] == state.currentField!['Field_name'] ? updatedField : field;
    }).toList();

    // Sort selected fields after updating, as sequence number might change
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
      final reportMetadata = {
        'RecNo': event.recNo.toString(), // Ensure string for backend if needed
        'Report_name': event.reportName,
        'Report_label': event.reportLabel,
        'API_name': event.apiName,
        'Parameter': event.parameter,
      };

      print('Bloc: Processing field configs for saving.');
      final fieldConfigs = state.selectedFields.map((field) {
        print('Bloc: Processing field for save: ${field['Field_name']}, Total=${field['Total']}, Breakpoint=${field['Breakpoint']}, SubTotal=${field['SubTotal']}, Image=${field['image']}');
        return {
          'Field_name': field['Field_name']?.toString() ?? '',
          'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
          'Sequence_no': field['Sequence_no'] is int ? field['Sequence_no'] : int.tryParse(field['Sequence_no'].toString()) ?? 0,
          'width': field['width'] is int ? field['width'] : int.tryParse(field['width'].toString()) ?? 100,
          'Total': field['Total'] == true ? 1 : 0, // Convert boolean to 0 or 1
          'num_alignment': field['num_alignment']?.toString().toLowerCase() ?? 'left',
          'time': field['time'] == true ? 1 : 0, // Convert boolean to 0 or 1
          'indian_format': field['num_format'] == true ? 1 : 0, // Convert boolean to 0 or 1
          'decimal_points': field['decimal_points'] is int ? field['decimal_points'] : int.tryParse(field['decimal_points'].toString()) ?? 0,
          'Breakpoint': field['Breakpoint'] == true ? 1 : 0, // Convert boolean to 0 or 1
          'SubTotal': field['SubTotal'] == true ? 1 : 0,     // Convert boolean to 0 or 1
          'image': field['image'] == true ? 1 : 0,           // NEW: Convert boolean to 0 or 1
        };
      }).toList();

      print('Bloc: Calling apiService.editDemoTables for RecNo: ${event.recNo}');
      await apiService.editDemoTables(
        recNo: event.recNo,
        reportName: event.reportName,
        reportLabel: event.reportLabel,
        apiName: event.apiName,
        parameter: event.parameter,
        fieldConfigs: fieldConfigs,
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
    // Reset to the initially loaded preselected fields
    emit(state.copyWith(
      selectedFields: List.from(state.preselectedFields), // Create a new list from preselected
      currentField: state.preselectedFields.isNotEmpty ? state.preselectedFields.first : null,
      error: null,
      saveSuccess: false,
    ));
    print('Bloc: State reset to preselected fields.');
  }
}