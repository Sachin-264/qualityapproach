import 'package:flutter_bloc/flutter_bloc.dart';
import 'ReportAPIService.dart';

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

class UpdateReportType extends ReportMakerEvent {
  final String reportType;
  UpdateReportType(this.reportType);
}

class SaveReport extends ReportMakerEvent {
  final String reportName;
  final String reportLabel;
  final String apiName;
  final String parameter;
  SaveReport({
    required this.reportName,
    required this.reportLabel,
    required this.apiName,
    required this.parameter,
  });
}

class ResetFields extends ReportMakerEvent {}

class ReportMakerState {
  final List<String> apis;
  final List<String> fields;
  final List<Map<String, dynamic>> selectedFields;
  final Map<String, dynamic>? currentField;
  final bool isLoading;
  final String? error;
  final String reportType;
  final bool saveSuccess;

  ReportMakerState({
    this.apis = const [],
    this.fields = const [],
    this.selectedFields = const [],
    this.currentField,
    this.isLoading = false,
    this.error,
    this.reportType = 'Detailed',
    this.saveSuccess = false,
  });

  ReportMakerState copyWith({
    List<String>? apis,
    List<String>? fields,
    List<Map<String, dynamic>>? selectedFields,
    Map<String, dynamic>? currentField,
    bool? isLoading,
    String? error,
    String? reportType,
    bool? saveSuccess,
  }) {
    return ReportMakerState(
      apis: apis ?? this.apis,
      fields: fields ?? this.fields,
      selectedFields: selectedFields ?? this.selectedFields,
      currentField: currentField ?? this.currentField,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      reportType: reportType ?? this.reportType,
      saveSuccess: saveSuccess ?? this.saveSuccess,
    );
  }
}

class ReportMakerBloc extends Bloc<ReportMakerEvent, ReportMakerState> {
  final ReportAPIService apiService;

  ReportMakerBloc(this.apiService) : super(ReportMakerState()) {
    on<LoadApis>(_onLoadApis);
    on<FetchApiData>(_onFetchApiData);
    on<SelectField>(_onSelectField);
    on<DeselectField>(_onDeselectField);
    on<UpdateFieldConfig>(_onUpdateFieldConfig);
    on<UpdateCurrentField>(_onUpdateCurrentField);
    on<UpdateReportType>(_onUpdateReportType);
    on<SaveReport>(_onSaveReport);
    on<ResetFields>(_onResetFields);
  }

  Future<void> _onLoadApis(LoadApis event, Emitter<ReportMakerState> emit) async {
    try {
      final List<String> apis = await apiService.getAvailableApis();
      emit(state.copyWith(apis: apis));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to load APIs: $e'));
    }
  }

  Future<void> _onFetchApiData(FetchApiData event, Emitter<ReportMakerState> emit) async {
    emit(state.copyWith(isLoading: true));
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
    print('Selected field: ${event.field}, Updated selectedFields: $updatedFields');
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: newField,
    ));
  }

  void _onDeselectField(DeselectField event, Emitter<ReportMakerState> emit) {
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
    print('Deselected field: ${event.field}, Updated selectedFields: $updatedFields');
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: newCurrentField,
    ));
  }

  void _onUpdateFieldConfig(UpdateFieldConfig event, Emitter<ReportMakerState> emit) {
    if (state.currentField == null) return;
    if (event.key == 'Group_by' && state.reportType == 'Detailed') {
      return; // Prevent Group_by changes when reportType is Detailed
    }
    dynamic value = event.value;
    if (event.key == 'Sequence_no') {
      final parsed = value is int ? value : int.tryParse(value.toString());
      if (parsed == null || parsed <= 0) {
        return; // Ignore invalid Sequence_no
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
    emit(state.copyWith(
      selectedFields: updatedFields,
      currentField: updatedField,
    ));
  }

  void _onUpdateCurrentField(UpdateCurrentField event, Emitter<ReportMakerState> emit) {
    emit(state.copyWith(currentField: event.field));
  }

  void _onUpdateReportType(UpdateReportType event, Emitter<ReportMakerState> emit) {
    if (event.reportType == 'Detailed') {
      final updatedFields = state.selectedFields.map((field) {
        return {
          ...field,
          'Group_by': false,
          'groupjson': '',
        };
      }).toList();
      final newCurrentField = state.currentField != null
          ? {...state.currentField!, 'Group_by': false, 'groupjson': ''}
          : null;
      emit(state.copyWith(
        reportType: event.reportType,
        selectedFields: updatedFields,
        currentField: newCurrentField,
      ));
    } else {
      emit(state.copyWith(reportType: event.reportType));
    }
  }

  Future<void> _onSaveReport(SaveReport event, Emitter<ReportMakerState> emit) async {
    if (state.selectedFields.isEmpty) {
      emit(state.copyWith(
        isLoading: false,
        error: 'No fields selected to save.',
        saveSuccess: false,
      ));
      return;
    }

    emit(state.copyWith(isLoading: true, error: null, saveSuccess: false));
    try {
      print('Saving report metadata: {Report_name: ${event.reportName}, Report_label: ${event.reportLabel}, API_name: ${event.apiName}, Parameter: ${event.parameter}}');
      final recNo = await apiService.saveReport(
        reportName: event.reportName,
        reportLabel: event.reportLabel,
        apiName: event.apiName,
        parameter: event.parameter,
        fields: state.selectedFields,
      );
      print('Received RecNo: $recNo');

      await apiService.saveFieldConfigs(state.selectedFields, recNo);

      emit(state.copyWith(isLoading: false, error: null, saveSuccess: true));
    } catch (e) {
      print('Save error: $e');
      emit(state.copyWith(isLoading: false, error: 'Failed to save report: $e', saveSuccess: false));
    }
  }

  void _onResetFields(ResetFields event, Emitter<ReportMakerState> emit) {
    emit(ReportMakerState(apis: state.apis));
  }
}