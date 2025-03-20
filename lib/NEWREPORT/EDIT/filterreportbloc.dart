import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

// Events
abstract class FilterEvent {}

class FetchReportsEvent extends FilterEvent {}

class ResetFilterEvent extends FilterEvent {}

class SubmitFilterEvent extends FilterEvent {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? selectedReport;

  SubmitFilterEvent(this.fromDate, this.toDate, this.selectedReport);
}

// States
abstract class FilterState {}

class FilterInitial extends FilterState {}

class FilterLoading extends FilterState {}

class FilterLoaded extends FilterState {
  final List<Map<String, String>> reports;

  FilterLoaded(this.reports);
}

class FilterError extends FilterState {
  final String message;

  FilterError(this.message);
}

class FilterSubmitted extends FilterState {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? selectedReport;

  FilterSubmitted(this.fromDate, this.toDate, this.selectedReport);
}

// BLoC
class FilterBloc extends Bloc<FilterEvent, FilterState> {
  FilterBloc() : super(FilterInitial()) {
    on<FetchReportsEvent>(_onFetchReports);
    on<ResetFilterEvent>(_onResetFilter);
    on<SubmitFilterEvent>(_onSubmitFilter);
  }

  Future<void> _onFetchReports(FetchReportsEvent event, Emitter<FilterState> emit) async {
    emit(FilterLoading());
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
          emit(FilterLoaded(reports));
        } else {
          emit(FilterError('API returned an error'));
        }
      } else {
        throw Exception('Failed to load reports');
      }
    } catch (e) {
      print('Error fetching reports: $e');
      emit(FilterLoaded([
        {'FieldID': '1.0', 'FieldName': 'Moneyshine'},
        {'FieldID': '2.0', 'FieldName': 'sachin'},
      ])); // Fallback data
    }
  }

  void _onResetFilter(ResetFilterEvent event, Emitter<FilterState> emit) {
    emit(FilterInitial());
  }

  void _onSubmitFilter(SubmitFilterEvent event, Emitter<FilterState> emit) {
    emit(FilterSubmitted(event.fromDate, event.toDate, event.selectedReport));
  }
}