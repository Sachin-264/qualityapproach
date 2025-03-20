import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

// Events
abstract class EditEvent {}

class FetchReportsEvent extends EditEvent {} // Fetch data from API

// States
abstract class EditState {}

class EditInitial extends EditState {} // Initial state

class EditLoading extends EditState {} // Loading state

class EditLoaded extends EditState {
  final List<Map<String, String>> reports; // Reports fetched from API

  EditLoaded(this.reports);
}

class EditError extends EditState {
  final String message; // Error message

  EditError(this.message);
}

// BLoC
class EditBloc extends Bloc<EditEvent, EditState> {
  EditBloc() : super(EditInitial()) {
    on<FetchReportsEvent>(_onFetchReports);
  }

  Future<void> _onFetchReports(FetchReportsEvent event, Emitter<EditState> emit) async {
    emit(EditLoading());
    try {
      final response = await http.get(
        Uri.parse('http://localhost/Bestapi/sp_GetCommonTableDataCRM .php?UserCode=101'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success') {
          final reports = (data['data'] as List).map((item) => {
            'FieldID': item['FieldID'] as String,
            'FieldName': item['FieldName'] as String,
          }).toList();
          emit(EditLoaded(reports));
        } else {
          emit(EditError('API returned an error'));
        }
      } else {
        throw Exception('Failed to load reports');
      }
    } catch (e) {
      print('Error fetching reports: $e');
      emit(EditLoaded([
        {'FieldID': '1.0', 'FieldName': 'MOneyshine'}, // Fixed typo
        {'FieldID': '2.0', 'FieldName': 'sachin'},
      ])); // Fallback data
    }
  }
}