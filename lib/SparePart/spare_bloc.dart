import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import 'global.dart';

// Events
abstract class SparePartEvent extends Equatable {
  const SparePartEvent();
  @override
  List<Object> get props => [];
}

class FetchSpareParts extends SparePartEvent {}

class SelectSparePart extends SparePartEvent {
  final Map<String, dynamic> sparePart;
  const SelectSparePart(this.sparePart);
  @override
  List<Object> get props => [sparePart];
}

// States
abstract class SparePartState extends Equatable {
  const SparePartState();
  @override
  List<Object> get props => [];
}

class SparePartInitial extends SparePartState {}

class SparePartLoading extends SparePartState {}

class SparePartLoaded extends SparePartState {
  final List<Map<String, dynamic>> spareParts;
  const SparePartLoaded(this.spareParts);
  @override
  List<Object> get props => [spareParts];
}

class SparePartError extends SparePartState {
  final String message;
  const SparePartError(this.message);
  @override
  List<Object> get props => [message];
}

// Bloc
class SparePartBloc extends Bloc<SparePartEvent, SparePartState> {
  SparePartBloc() : super(SparePartInitial()) {
    on<FetchSpareParts>(_onFetchSpareParts);
    on<SelectSparePart>(_onSelectSparePart);
  }

  Future<void> _onFetchSpareParts(
      FetchSpareParts event,
      Emitter<SparePartState> emit,
      ) async {
    emit(SparePartLoading());
    try {
      final response = await http.get(Uri.parse(
          'http://localhost/Bestapi/get_spare.php?UserCode=1&CompanyCode=101'));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          emit(SparePartLoaded(List<Map<String, dynamic>>.from(jsonData['data'])));
        } else {
          emit(SparePartError('Failed to load data'));
        }
      } else {
        emit(SparePartError('Failed to load data'));
      }
    } catch (e) {
      emit(SparePartError('Failed to load data: $e'));
    }
  }

  void _onSelectSparePart(
      SelectSparePart event,
      Emitter<SparePartState> emit,
      ) {
    if (state is SparePartLoaded) {
      GlobalData.selectedCustomerName = event.sparePart['AccountName'] ?? '';
      GlobalData.selectedAddress = event.sparePart['CustomerAddress'] ?? '';
      GlobalData.selectedMobileNo = event.sparePart['CustomerMobileNo'] ?? '';
      GlobalData.selectedComplaintNo = event.sparePart['ComplaintNo'] ?? '';
    }
  }
}