import 'dart:convert';
import 'dart:developer' as developer;
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;

// Events
abstract class EditSpareEvent extends Equatable {
  const EditSpareEvent();
  @override
  List<Object> get props => [];
}

class LoadEditSpares extends EditSpareEvent {
  final String userCode;
  final String companyCode;
  final String fromDate;
  final String toDate;

  const LoadEditSpares({
    required this.userCode,
    required this.companyCode,
    required this.fromDate,
    required this.toDate,
  });

  @override
  List<Object> get props => [userCode, companyCode, fromDate, toDate];
}

class DeleteEditSpare extends EditSpareEvent {
  final String userCode;
  final String companyCode;
  final String recNo;

  const DeleteEditSpare({
    required this.userCode,
    required this.companyCode,
    required this.recNo,
  });

  @override
  List<Object> get props => [userCode, companyCode, recNo];
}

// States
abstract class EditSpareState extends Equatable {
  const EditSpareState();
  @override
  List<Object> get props => [];
}

class EditSpareInitial extends EditSpareState {}

class EditSpareLoading extends EditSpareState {}

class EditSpareLoaded extends EditSpareState {
  final List<dynamic> EditSpares;

  const EditSpareLoaded(this.EditSpares);

  @override
  List<Object> get props => [EditSpares];
}

class EditSpareError extends EditSpareState {
  final String message;

  const EditSpareError(this.message);

  @override
  List<Object> get props => [message];
}

class EditSpareDeleted extends EditSpareState {}

// BLoC
class EditSpareBloc extends Bloc<EditSpareEvent, EditSpareState> {
  EditSpareBloc() : super(EditSpareInitial()) {
    on<LoadEditSpares>(_onLoadEditSpares);
    on<DeleteEditSpare>(_onDeleteEditSpare);

    developer.log('EditSpareBloc initialized', name: 'EditSpareBloc');
  }

  Future<void> _onLoadEditSpares(
      LoadEditSpares event,
      Emitter<EditSpareState> emit,
      ) async {
    developer.log(
        'Loading EditSpares with params: '
            'UserCode=${event.userCode}, '
            'CompanyCode=${event.companyCode}, '
            'FromDate=${event.fromDate}, '
            'ToDate=${event.toDate}',
        name: 'EditSpareBloc'
    );

    emit(EditSpareLoading());
    developer.log('State changed to EditSpareLoading', name: 'EditSpareBloc');

    try {
      final url = Uri.parse(
          'http://localhost/Bestapi/editSpare.php?Type=GetSparePartsDetails&'
              'UserCode=${event.userCode}&'
              'CompanyCode=${event.companyCode}&'
              'FromDate=${event.fromDate}&'
              'ToDate=${event.toDate}'
      );

      developer.log('Making GET request to: $url', name: 'EditSpareBloc');

      final response = await http.get(url);
      developer.log('Received response with status: ${response.statusCode}',
          name: 'EditSpareBloc');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        developer.log('Response body: $data', name: 'EditSpareBloc');

        if (data['status'] == 'success') {
          final editSpares = data['data'];
          developer.log('Successfully loaded ${editSpares.length} EditSpare parts',
              name: 'EditSpareBloc');
          emit(EditSpareLoaded(editSpares));
          developer.log('State changed to EditSpareLoaded', name: 'EditSpareBloc');
        } else {
          final errorMsg = 'Failed to load EditSpare parts: ${data['message']}';
          developer.log(errorMsg, name: 'EditSpareBloc');
          emit(EditSpareError(errorMsg));
          developer.log('State changed to EditSpareError', name: 'EditSpareBloc');
        }
      } else {
        final errorMsg = 'Failed to load EditSpare parts: ${response.statusCode}';
        developer.log(errorMsg, name: 'EditSpareBloc');
        emit(EditSpareError(errorMsg));
        developer.log('State changed to EditSpareError', name: 'EditSpareBloc');
      }
    } catch (e) {
      final errorMsg = 'Error loading EditSpare parts: $e';
      developer.log(errorMsg, name: 'EditSpareBloc', error: e);
      emit(EditSpareError(errorMsg));
      developer.log('State changed to EditSpareError', name: 'EditSpareBloc');
    }
  }

  Future<void> _onDeleteEditSpare(
      DeleteEditSpare event,
      Emitter<EditSpareState> emit,
      ) async {
    developer.log(
        'Deleting EditSpare with params: '
            'UserCode=${event.userCode}, '
            'CompanyCode=${event.companyCode}, '
            'RecNo=${event.recNo}',
        name: 'EditSpareBloc'
    );

    emit(EditSpareLoading());
    developer.log('State changed to EditSpareLoading', name: 'EditSpareBloc');

    try {
      final url = Uri.parse(
          'http://localhost/Bestapi/editSpare.php?Type=DeleteSpareParts&'
              'UserCode=${event.userCode}&'
              'CompanyCode=${event.companyCode}&'
              'RecNo=${event.recNo}'
      );

      developer.log('Making DELETE request to: $url', name: 'EditSpareBloc');

      final response = await http.get(url);
      developer.log('Received response with status: ${response.statusCode}',
          name: 'EditSpareBloc');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        developer.log('Response body: $data', name: 'EditSpareBloc');

        if (data['status'] == 'success') {
          developer.log('Successfully deleted EditSpare part with RecNo: ${event.recNo}',
              name: 'EditSpareBloc');
          emit(EditSpareDeleted());
          developer.log('State changed to EditSpareDeleted', name: 'EditSpareBloc');
        } else {
          final errorMsg = 'Failed to delete EditSpare part: ${data['message']}';
          developer.log(errorMsg, name: 'EditSpareBloc');
          emit(EditSpareError(errorMsg));
          developer.log('State changed to EditSpareError', name: 'EditSpareBloc');
        }
      } else {
        final errorMsg = 'Failed to delete EditSpare part: ${response.statusCode}';
        developer.log(errorMsg, name: 'EditSpareBloc');
        emit(EditSpareError(errorMsg));
        developer.log('State changed to EditSpareError', name: 'EditSpareBloc');
      }
    } catch (e) {
      final errorMsg = 'Error deleting EditSpare part: $e';
      developer.log(errorMsg, name: 'EditSpareBloc', error: e);
      emit(EditSpareError(errorMsg));
      developer.log('State changed to EditSpareError', name: 'EditSpareBloc');
    }
  }
}