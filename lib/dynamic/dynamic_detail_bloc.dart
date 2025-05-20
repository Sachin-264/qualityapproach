import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'api.dart';

abstract class DynamicDetailEvent {}

class FetchFormFields extends DynamicDetailEvent {
  final String recNo;
  FetchFormFields(this.recNo);
}

class FetchAutocompleteOptions extends DynamicDetailEvent {
  final String masterField;
  FetchAutocompleteOptions(this.masterField);
}

class AddTableRow extends DynamicDetailEvent {
  final Map<String, String> rowData;
  AddTableRow(this.rowData);
}

class EditTableRow extends DynamicDetailEvent {
  final int index;
  final Map<String, String> rowData;
  EditTableRow(this.index, this.rowData);
}

class DeleteTableRow extends DynamicDetailEvent {
  final int index;
  DeleteTableRow(this.index);
}

class ResetForm extends DynamicDetailEvent {}

class SaveForm extends DynamicDetailEvent {
  final Map<String, String> formData;
  final List<Map<String, String>> tableData;
  SaveForm(this.formData, this.tableData);
}

abstract class DynamicDetailState {}

class DynamicDetailLoading extends DynamicDetailState {}

class DynamicDetailLoaded extends DynamicDetailState {
  final List<Map<String, dynamic>> fields;
  final bool isInitialLoad;
  final Map<String, List<String>> autocompleteOptions;
  final List<Map<String, String>> tableData;
  final Map<String, String> formData;

  DynamicDetailLoaded(this.fields, {
    this.isInitialLoad = true,
    this.autocompleteOptions = const {},
    this.tableData = const [],
    this.formData = const {},
  });
}

class DynamicDetailError extends DynamicDetailState {
  final String message;
  DynamicDetailError(this.message);
}

class DynamicDetailBloc extends Bloc<DynamicDetailEvent, DynamicDetailState> {
  final DynamicFieldApi _api = DynamicFieldApi();
  final Map<String, List<String>> _autocompleteCache = {};

  DynamicDetailBloc() : super(DynamicDetailLoading()) {
    on<FetchFormFields>(_onFetchFormFields);
    on<FetchAutocompleteOptions>(_onFetchAutocompleteOptions);
    on<AddTableRow>(_onAddTableRow);
    on<EditTableRow>(_onEditTableRow);
    on<DeleteTableRow>(_onDeleteTableRow);
    on<ResetForm>(_onResetForm);
    on<SaveForm>(_onSaveForm);
  }

  Future<void> _onFetchFormFields(FetchFormFields event, Emitter<DynamicDetailState> emit) async {
    emit(DynamicDetailLoading());
    try {
      debugPrint('Fetching form fields for recNo: ${event.recNo}');
      final fields = await _api.fetchFormFields(event.recNo);
      debugPrint('Fetched ${fields.length} fields');

      final autocompleteFields = fields
          .where((field) => field['FromMaster'] == 'YES' && field['MasterField']?.isNotEmpty == true)
          .map((field) => field['MasterField'] as String)
          .toSet();

      for (var masterField in autocompleteFields) {
        if (!_autocompleteCache.containsKey(masterField)) {
          debugPrint('Prefetching autocomplete options for $masterField');
          final options = await _api.fetchAutocompleteOptions(masterField);
          _autocompleteCache[masterField] = options;
        }
      }

      emit(DynamicDetailLoaded(
        fields,
        isInitialLoad: true,
        autocompleteOptions: _autocompleteCache,
      ));
    } catch (e) {
      debugPrint('Error fetching form fields: $e');
      emit(DynamicDetailError('Failed to load form fields: $e'));
    }
  }

  Future<void> _onFetchAutocompleteOptions(FetchAutocompleteOptions event, Emitter<DynamicDetailState> emit) async {
    try {
      if (_autocompleteCache.containsKey(event.masterField)) {
        emit(DynamicDetailLoaded(
          state is DynamicDetailLoaded ? (state as DynamicDetailLoaded).fields : [],
          isInitialLoad: false,
          autocompleteOptions: _autocompleteCache,
          tableData: state is DynamicDetailLoaded ? (state as DynamicDetailLoaded).tableData : [],
          formData: state is DynamicDetailLoaded ? (state as DynamicDetailLoaded).formData : {},
        ));
        return;
      }

      final options = await _api.fetchAutocompleteOptions(event.masterField);
      _autocompleteCache[event.masterField] = options;

      emit(DynamicDetailLoaded(
        state is DynamicDetailLoaded ? (state as DynamicDetailLoaded).fields : [],
        isInitialLoad: false,
        autocompleteOptions: _autocompleteCache,
        tableData: state is DynamicDetailLoaded ? (state as DynamicDetailLoaded).tableData : [],
        formData: state is DynamicDetailLoaded ? (state as DynamicDetailLoaded).formData : {},
      ));
    } catch (e) {
      debugPrint('Error fetching autocomplete options for ${event.masterField}: $e');
      emit(DynamicDetailError('Failed to load autocomplete options: $e'));
    }
  }

  void _onAddTableRow(AddTableRow event, Emitter<DynamicDetailState> emit) {
    if (state is DynamicDetailLoaded) {
      final currentState = state as DynamicDetailLoaded;
      final updatedTableData = List<Map<String, String>>.from(currentState.tableData)..add(event.rowData);
      emit(DynamicDetailLoaded(
        currentState.fields,
        isInitialLoad: false,
        autocompleteOptions: currentState.autocompleteOptions,
        tableData: updatedTableData,
        formData: currentState.formData,
      ));
    }
  }

  void _onEditTableRow(EditTableRow event, Emitter<DynamicDetailState> emit) {
    if (state is DynamicDetailLoaded) {
      final currentState = state as DynamicDetailLoaded;
      final updatedTableData = List<Map<String, String>>.from(currentState.tableData);
      updatedTableData[event.index] = event.rowData;
      emit(DynamicDetailLoaded(
        currentState.fields,
        isInitialLoad: false,
        autocompleteOptions: currentState.autocompleteOptions,
        tableData: updatedTableData,
        formData: currentState.formData,
      ));
    }
  }

  void _onDeleteTableRow(DeleteTableRow event, Emitter<DynamicDetailState> emit) {
    if (state is DynamicDetailLoaded) {
      final currentState = state as DynamicDetailLoaded;
      final updatedTableData = List<Map<String, String>>.from(currentState.tableData)..removeAt(event.index);
      emit(DynamicDetailLoaded(
        currentState.fields,
        isInitialLoad: false,
        autocompleteOptions: currentState.autocompleteOptions,
        tableData: updatedTableData,
        formData: currentState.formData,
      ));
    }
  }

  void _onResetForm(ResetForm event, Emitter<DynamicDetailState> emit) {
    if (state is DynamicDetailLoaded) {
      final currentState = state as DynamicDetailLoaded;
      emit(DynamicDetailLoaded(
        currentState.fields,
        isInitialLoad: false,
        autocompleteOptions: currentState.autocompleteOptions,
        tableData: [],
        formData: {},
      ));
    }
  }

  void _onSaveForm(SaveForm event, Emitter<DynamicDetailState> emit) {
    if (state is DynamicDetailLoaded) {
      final currentState = state as DynamicDetailLoaded;
      debugPrint('Saving form data: ${event.formData}');
      debugPrint('Saving table data: ${event.tableData}');
      // TODO: Implement save API call when provided
      emit(DynamicDetailLoaded(
        currentState.fields,
        isInitialLoad: false,
        autocompleteOptions: currentState.autocompleteOptions,
        tableData: event.tableData,
        formData: event.formData,
      ));
    }
  }
}