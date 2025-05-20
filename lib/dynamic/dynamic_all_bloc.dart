import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

abstract class DynamicAllEvent {}

class FetchForms extends DynamicAllEvent {}

abstract class DynamicAllState {}

class DynamicAllLoading extends DynamicAllState {}

class DynamicAllLoaded extends DynamicAllState {
  final List<Map<String, dynamic>> forms;

  DynamicAllLoaded(this.forms);
}

class DynamicAllError extends DynamicAllState {
  final String message;

  DynamicAllError(this.message);
}

class DynamicAllBloc extends Bloc<DynamicAllEvent, DynamicAllState> {
  DynamicAllBloc() : super(DynamicAllLoading()) {
    on<FetchForms>(_onFetchForms);
  }

  Future<void> _onFetchForms(FetchForms event, Emitter<DynamicAllState> emit) async {
    emit(DynamicAllLoading());
    try {
      final response = await http.get(
        Uri.parse('http://localhost/Dash/dynamic.php?action=GET_FORM_1'),
      );
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          emit(DynamicAllLoaded(List<Map<String, dynamic>>.from(jsonData['data'])));
        } else {
          emit(DynamicAllError('Failed to load forms'));
        }
      } else {
        emit(DynamicAllError('Server error: ${response.statusCode}'));
      }
    } catch (e) {
      emit(DynamicAllError('Error: $e'));
    }
  }
}