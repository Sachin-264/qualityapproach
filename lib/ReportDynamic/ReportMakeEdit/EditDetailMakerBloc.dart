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
    print('EditDetailMakerBloc initialized');
    on<LoadPreselectedFields>(_onLoadPreselectedFields);
    on<SelectField>(_onSelectField);
    on<DeselectField>(_onDeselectField);
    on<UpdateFieldConfig>(_onUpdateFieldConfig);
    on<UpdateCurrentField>(_onUpdateCurrentField);
    on<SaveReport>(_onSaveReport);
    on<ResetFields>(_onResetFields);
  }

  Future<void> _onLoadPreselectedFields(LoadPreselectedFields event, Emitter<EditDetailMakerState> emit) async {
    print('Handling LoadPreselectedFields: recNo=${event.recNo}, apiName=${event.apiName}');
    emit(state.copyWith(isLoading: true, error: null, fields: [], selectedFields: [], preselectedFields: []));
    print('Emitted initial loading state: isLoading=true');

    try {
      print('Fetching fields and preselected fields concurrently');
      final results = await Future.wait([
        apiService.fetchApiData(event.apiName),
        apiService.fetchDemoTable2(event.recNo.toString()),
      ]);

      print('All data fetched successfully');
      final apiData = results[0] as List<Map<String, dynamic>>;
      final preselectedFields = results[1] as List<Map<String, dynamic>>;

      print('Processing apiData: length=${apiData.length}');
      final List<String> fields = apiData.isNotEmpty ? apiData[0].keys.map((key) => key.toString()).toList() : [];
      print('Fields extracted: ${fields.length} fields, fields=$fields');

      print('Processing preselectedFields: length=${preselectedFields.length}');
      final formattedFields = preselectedFields.map((field) {
        final formatted = {
          'Field_name': field['Field_name']?.toString() ?? '',
          'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
          'Sequence_no': int.tryParse(field['Sequence_no']?.toString() ?? '') ?? 0,
          'width': int.tryParse(field['width']?.toString() ?? '') ?? 100,
          'Total': field['Total'] == '1' || field['Total'] == true || field['Total'] == 'Yes',
          'num_alignment': field['num_alignment']?.toString().toLowerCase() ?? 'left',
          'time': field['time'] == '1' || field['time'] == true || field['time'] == 'Yes',
          'num_format': field['indian_format'] == '1' || field['indian_format'] == true || field['indian_format'] == 'Yes',
          'decimal_points': int.tryParse(field['decimal_points']?.toString() ?? '') ?? 0,
          'Group_by': false,
          'Filter': false,
          'filterJson': '',
          'orderby': false,
          'orderjson': '',
          'groupjson': '',
        };
        print('Formatted field: ${formatted['Field_name']}, config=$formatted');
        return formatted;
      }).toList();

      print('Emitting final state: fields=${fields.length}, selectedFields=${formattedFields.length}, preselectedFields=${formattedFields.length}');
      emit(state.copyWith(
        fields: fields,
        selectedFields: formattedFields,
        preselectedFields: formattedFields,
        currentField: formattedFields.isNotEmpty ? formattedFields.first : null,
        isLoading: false,
        error: null,
      ));
      print('Final state emitted');
    } catch (e, stackTrace) {
      print('Error in LoadPreselectedFields: $e');
      print('Stack trace: $stackTrace');
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to load fields: $e',
      ));
      print('Error state emitted');
    }
  }

  void _onSelectField(SelectField event, Emitter<EditDetailMakerState> emit) {
    print('Handling SelectField: field=${event.field}');
    // Prevent adding the same field multiple times
    if (state.selectedFields.any((f) => f['Field_name'] == event.field)) {
      print('Field already selected: ${event.field}, skipping');
      return;
    }
    final isPreselected = state.preselectedFields.any((f) => f['Field_name'] == event.field);
    final newField = isPreselected
        ? state.preselectedFields.firstWhere((f) => f['Field_name'] == event.field)
        : {
      'Field_name': event.field,
      'Field_label': event.field,
      'Sequence_no': state.selectedFields.isNotEmpty
          ? (state.selectedFields.map((f) => f['Sequence_no'] as int).reduce((a, b) => a > b ? a : b) + 1)
          : 1,
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
    };
    final updatedFields = [...state.selectedFields, newField];
    print('Selected field: ${event.field}, Updated selectedFields: ${updatedFields.length}, isPreselected=$isPreselected');
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: newField,
    ));
  }

  void _onDeselectField(DeselectField event, Emitter<EditDetailMakerState> emit) {
    print('Handling DeselectField: field=${event.field}');
    final updatedFields = state.selectedFields
        .where((f) => f['Field_name'] != event.field)
        .toList()
        .asMap()
        .map((index, f) => MapEntry(index, {
      ...f,
      'Sequence_no': index + 1,
    }))
        .values
        .toList();
    final newCurrentField = updatedFields.isNotEmpty
        ? updatedFields.first
        : state.currentField?['Field_name'] == event.field
        ? null
        : state.currentField;
    print('Deselected field: ${event.field}, Updated selectedFields: ${updatedFields.length}');
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: newCurrentField,
    ));
  }

  void _onUpdateFieldConfig(UpdateFieldConfig event, Emitter<EditDetailMakerState> emit) {
    print('Handling UpdateFieldConfig: key=${event.key}, value=${event.value}');
    if (state.currentField == null) {
      print('No current field to update');
      return;
    }
    dynamic value = event.value;
    if (event.key == 'Sequence_no') {
      final parsed = value is int ? value : int.tryParse(value.toString());
      if (parsed == null || parsed <= 0) {
        print('Invalid Sequence_no: $value');
        return;
      }
      value = parsed;
    }
    final updatedField = {...state.currentField!, event.key: value};
    final updatedFields = state.selectedFields.map((field) {
      return field['Field_name'] == state.currentField!['Field_name'] ? updatedField : field;
    }).toList()
      ..sort((a, b) {
        final aSeq = a['Sequence_no'] as int? ?? 9999;
        final bSeq = b['Sequence_no'] as int? ?? 9999;
        return aSeq.compareTo(bSeq);
      });
    print('Updated field: ${updatedField['Field_name']}, ${event.key}=$value');
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: updatedField,
    ));
  }

  void _onUpdateCurrentField(UpdateCurrentField event, Emitter<EditDetailMakerState> emit) {
    print('Handling UpdateCurrentField: field=${event.field['Field_name']}');
    emit(state.copyWith(currentField: event.field));
  }

  Future<void> _onSaveReport(SaveReport event, Emitter<EditDetailMakerState> emit) async {
    print('Handling SaveReport: recNo=${event.recNo}, reportName=${event.reportName}');
    if (state.selectedFields.isEmpty) {
      print('Save failed: No fields selected');
      emit(state.copyWith(
        isLoading: false,
        error: 'No fields selected to save.',
        saveSuccess: false,
      ));
      return;
    }

    emit(state.copyWith(isLoading: true, error: null, saveSuccess: false));
    try {
      print('Saving report metadata: {RecNo: ${event.recNo}, Report_name: ${event.reportName}, Report_label: ${event.reportLabel}, API_name: ${event.apiName}, Parameter: ${event.parameter}}');

      // Remove duplicates by Field_name, keeping the last occurrence
      final uniqueFields = <String, Map<String, dynamic>>{};
      for (var field in state.selectedFields) {
        uniqueFields[field['Field_name']] = field;
      }
      final fieldConfigs = uniqueFields.values.map((field) => ({
        'Field_name': field['Field_name']?.toString() ?? '',
        'Field_label': field['Field_label']?.toString() ?? field['Field_name']?.toString() ?? '',
        'Sequence_no': field['Sequence_no'] is int ? field['Sequence_no'] : int.tryParse(field['Sequence_no'].toString()) ?? 0,
        'width': field['width'] is int ? field['width'] : int.tryParse(field['width'].toString()) ?? 100,
        'Total': field['Total'] == true ? 1 : 0,
        'num_alignment': field['num_alignment']?.toString().toLowerCase() ?? 'left',
        'time': field['time'] == true ? 1 : 0,
        'indian_format': field['num_format'] == true ? 1 : 0,
        'decimal_points': field['decimal_points'] is int ? field['decimal_points'] : int.tryParse(field['decimal_points'].toString()) ?? 0,
      })).toList();

      print('Saving field configs: $fieldConfigs');
      await apiService.editDemoTables(
        recNo: event.recNo,
        reportName: event.reportName,
        reportLabel: event.reportLabel,
        apiName: event.apiName,
        parameter: event.parameter,
        fieldConfigs: fieldConfigs,
      );

      print('Save successful');
      emit(state.copyWith(isLoading: false, error: null, saveSuccess: true));
    } catch (e) {
      print('Save error: $e');
      emit(state.copyWith(isLoading: false, error: 'Failed to update report: $e', saveSuccess: false));
    }
  }

  void _onResetFields(ResetFields event, Emitter<EditDetailMakerState> emit) {
    print('Handling ResetFields');
    emit(state.copyWith(
      selectedFields: state.preselectedFields,
      currentField: state.preselectedFields.isNotEmpty ? state.preselectedFields.first : null,
      error: null,
      saveSuccess: false,
    ));
  }
}