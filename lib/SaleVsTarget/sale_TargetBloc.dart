import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// Events
abstract class SaleTargetEvent {}

class FetchSaleTargets extends SaleTargetEvent {}

// States
abstract class SaleTargetState {}

class SaleTargetInitial extends SaleTargetState {}

class SaleTargetLoading extends SaleTargetState {}

class SaleTargetLoaded extends SaleTargetState {
  final List<Map<String, dynamic>> saleTargets;

  SaleTargetLoaded(this.saleTargets);
}

class SaleTargetError extends SaleTargetState {}

// BLoC
class SaleTargetBloc extends Bloc<SaleTargetEvent, SaleTargetState> {
  SaleTargetBloc() : super(SaleTargetInitial()) {
    on<FetchSaleTargets>(_onFetchSaleTargets);
  }

  Future<void> _onFetchSaleTargets(
      FetchSaleTargets event, Emitter<SaleTargetState> emit) async {
    emit(SaleTargetLoading());
    try {
      final now = DateTime.now();
      final firstDay = DateFormat('dd-MMM-yyyy').format(DateTime(now.year, now.month, 1));
      final lastDay = DateFormat('dd-MMM-yyyy')
          .format(DateTime(now.year, now.month + 1, 0));

      final url =
          'http://localhost/Bestapi/getsaleTarget.php?UserCode=1&FromDate=$firstDay&ToDate=$lastDay';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          final saleTargets = List<Map<String, dynamic>>.from(jsonData['data']);
          emit(SaleTargetLoaded(saleTargets));
        } else {
          emit(SaleTargetLoaded([]));
        }
      } else {
        emit(SaleTargetLoaded([]));
      }
    } catch (e) {
      emit(SaleTargetError());
    }
  }
}