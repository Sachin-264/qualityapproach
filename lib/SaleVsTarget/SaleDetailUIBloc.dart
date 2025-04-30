import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Events
abstract class SaleDetailEvent {}

class FetchSaleDetails extends SaleDetailEvent {
  final String salesManRecNo;
  final String fromDate;
  final String toDate;

  FetchSaleDetails({
    required this.salesManRecNo,
    required this.fromDate,
    required this.toDate,
  });
}

// States
abstract class SaleDetailState {}

class SaleDetailInitial extends SaleDetailState {}

class SaleDetailLoading extends SaleDetailState {}

class SaleDetailLoaded extends SaleDetailState {
  final List<Map<String, dynamic>> saleDetails;

  SaleDetailLoaded(this.saleDetails);
}

class SaleDetailError extends SaleDetailState {}

// BLoC
class SaleDetailBloc extends Bloc<SaleDetailEvent, SaleDetailState> {
  SaleDetailBloc() : super(SaleDetailInitial()) {
    on<FetchSaleDetails>(_onFetchSaleDetails);
  }

  Future<void> _onFetchSaleDetails(
      FetchSaleDetails event, Emitter<SaleDetailState> emit) async {
    emit(SaleDetailLoading());
    try {
      final url =
          'http://localhost/Bestapi/dashboarddetail.php?BranchCode=E&FromDate=${event.fromDate}&ToDate=${event.toDate}&SalesManRecNo=${event.salesManRecNo}';

      print('Fetching data from URL: $url'); // Debugging line

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          final saleDetails = List<Map<String, dynamic>>.from(jsonData['data']);
          emit(SaleDetailLoaded(saleDetails));
        } else {
          emit(SaleDetailLoaded([]));
        }
      } else {
        emit(SaleDetailLoaded([]));
      }
    } catch (e) {
      emit(SaleDetailError());
    }
  }
}