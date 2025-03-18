import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Events
abstract class RetailCustomerEvent {}

class FetchRetailCustomers extends RetailCustomerEvent {
  String UserCode;
  String CompanyCode;
  String str;
  final String fromDate;
  final String toDate;

  FetchRetailCustomers(this.UserCode, this.CompanyCode, this.str, this.fromDate, this.toDate);
}

class ClearRetailCustomers extends RetailCustomerEvent {} // New event for reset

// States
abstract class RetailCustomerState {}

class RetailCustomerNoData extends RetailCustomerState {}

class RetailCustomerInitial extends RetailCustomerState {}

class RetailCustomerLoading extends RetailCustomerState {}

class RetailCustomerLoaded extends RetailCustomerState {
  final List<Map<String, dynamic>> customers;
  RetailCustomerLoaded(this.customers);
}

class RetailCustomerError extends RetailCustomerState {
  final String message;
  RetailCustomerError(this.message);
}

// BLoC
class RetailCustomerBloc extends Bloc<RetailCustomerEvent, RetailCustomerState> {
  RetailCustomerBloc() : super(RetailCustomerInitial()) {
    on<FetchRetailCustomers>((event, emit) async {
      print('Fetching customers from: ${event.fromDate} to ${event.toDate}');
      emit(RetailCustomerLoading());

      try {
        final url = 'http://localhost/AquavivaAPI/GetRetailCustomerMasterList .php?UserCode=${event.UserCode}&CompanyCode=${event.CompanyCode}&CustomerName=&FromDate=01-Jan-2025&ToDate=11-Mar-2025&str=${event.str}';
        print('API URL: $url');

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final List<dynamic> responseBody = json.decode(response.body);

          if (responseBody.isEmpty) {
            emit(RetailCustomerNoData()); // Emit no data state
          } else {
            final List<Map<String, dynamic>> data = responseBody.cast<Map<String, dynamic>>();
            print('Number of records: ${data.length}');
            emit(RetailCustomerLoaded(data));
          }
        } else {
          emit(RetailCustomerError('Failed to load data. Status code: ${response.statusCode}'));
        }
      } catch (e) {
        print('Error caught: $e');
        emit(RetailCustomerError('Error: $e'));
      }
    });

    // Handle the reset event
    on<ClearRetailCustomers>((event, emit) {
      emit(RetailCustomerInitial()); // Reset to the initial state
    });
  }
}