import 'package:bloc/bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

abstract class DashboardEvent {}

class FetchDashboardData extends DashboardEvent {}

abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final List<Map<String, dynamic>> data;
  final List<String> fields;

  DashboardLoaded(this.data, this.fields);
}

class DashboardError extends DashboardState {
  final String message;

  DashboardError(this.message);
}

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc() : super(DashboardInitial()) {
    on<FetchDashboardData>(_onFetchDashboardData);
  }

  Future<void> _onFetchDashboardData(FetchDashboardData event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      // Get current date and first date of the month
      final now = DateTime.now();
      final fromDate = DateFormat('dd-MMM-yyyy').format(now);
      final toDate = DateFormat('dd-MMM-yyyy').format(DateTime(now.year, now.month, 1));

      final url = 'http://localhost/Dash/Box.php?BranchCode=E&FromDate=$toDate&ToDate=$fromDate';
      developer.log('Fetching data from URL: $url', name: 'DashboardBloc');

      final response = await http.get(Uri.parse(url));
      developer.log('API Response Status: ${response.statusCode}', name: 'DashboardBloc');
      developer.log('API Response Body: ${response.body}', name: 'DashboardBloc');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        developer.log('Parsed JSON Data: $jsonData', name: 'DashboardBloc');

        if (jsonData['status'] == 'success') {
          final data = List<Map<String, dynamic>>.from(jsonData['data']);
          // Extract field keys dynamically from the first data item and cast to List<String>
          final fields = data.isNotEmpty
              ? data[0].keys.map((key) => key.toString()).toList()
              : <String>[];
          developer.log('Data List Length: ${data.length}', name: 'DashboardBloc');
          developer.log('Fields Extracted: $fields', name: 'DashboardBloc');
          developer.log('Data Content: $data', name: 'DashboardBloc');
          emit(DashboardLoaded(data, fields));
        } else {
          developer.log('API returned non-success status: ${jsonData['status']}', name: 'DashboardBloc');
          emit(DashboardError('Failed to load data'));
        }
      } else {
        developer.log('Server error with status code: ${response.statusCode}', name: 'DashboardBloc');
        emit(DashboardError('Server error: ${response.statusCode}'));
      }
    } catch (e) {
      developer.log('Error during API call: $e', name: 'DashboardBloc', error: e);
      emit(DashboardError('Error: $e'));
    }
  }
}