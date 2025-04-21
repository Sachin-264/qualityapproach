import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

// Events
abstract class DetailDashEvent extends Equatable {
  const DetailDashEvent();

  @override
  List<Object> get props => [];
}

class FetchDetailDashData extends DetailDashEvent {
  final Map<String, String> boxData;

  const FetchDetailDashData(this.boxData);

  @override
  List<Object> get props => [boxData];
}

// States
abstract class DetailDashState extends Equatable {
  const DetailDashState();

  @override
  List<Object> get props => [];
}

class DetailDashInitial extends DetailDashState {}

class DetailDashLoading extends DetailDashState {}

class DetailDashLoaded extends DetailDashState {
  final List<dynamic> data;
  final Map<String, String> mergedData;

  const DetailDashLoaded({required this.data, required this.mergedData});

  @override
  List<Object> get props => [data, mergedData];
}

class DetailDashError extends DetailDashState {
  final String message;

  const DetailDashError({required this.message});

  @override
  List<Object> get props => [message];
}

// BLoC
class DetailDashBloc extends Bloc<DetailDashEvent, DetailDashState> {
  DetailDashBloc() : super(DetailDashInitial()) {
    on<FetchDetailDashData>(_onFetchDetailDashData);
  }

  Future<void> _onFetchDetailDashData(
      FetchDetailDashData event, Emitter<DetailDashState> emit) async {
    print('DetailDashBloc: Starting fetch data with boxData: ${event.boxData}');
    emit(DetailDashLoading());
    print('DetailDashBloc: Emitted DetailDashLoading');

    // Default parameters
    final Map<String, String> defaultData = {
      'UserGroupCode': '1',
      'UserCode': '1',
      'BranchCode': 'E',
      'FromDate': '01-Apr-2025',
      'ToDate': '31-Mar-2026',
      'AccountCode': '',
      'PassedUserID': '',
      'VendorQuotationRecNo': '0',
      'CalledWith': 'VendorQuotationAuthorisation',
      'Check1': 'N',
      'Check2': 'N',
      'Branch_VendorQuotation_Authorisation_SingleLevel': 'N',
      'VendorQuotation_Auth_Level': '2',
      'Level1': 'Y',
      'Opt1': 'N',
      'Opt2': 'Y',
      'ActionTaken': '',
      'DepartmentRecNo': '0',
      'IndentNo': '0',
    };

    // Merge default data with box-specific data
    final mergedData = {...defaultData, ...event.boxData};
    print('DetailDashBloc: Merged data for API: $mergedData');

    // Construct API URL with query parameters
    final uri = Uri.http('localhost', '/Dash/detail.php', mergedData);
    print('DetailDashBloc: API URL: $uri');

    try {
      final response = await http.get(uri);
      print('DetailDashBloc: API response status code: ${response.statusCode}');
      print('DetailDashBloc: API response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('DetailDashBloc: Parsed JSON data: $jsonData');

        if (jsonData['status'] == 'success') {
          final data = jsonData['data'] as List<dynamic>;
          print('DetailDashBloc: API data length: ${data.length}');
          print('DetailDashBloc: First data item: ${data.isNotEmpty ? data.first : 'No data'}');
          print('DetailDashBloc: Emitting DetailDashLoaded');
          emit(DetailDashLoaded(data: data, mergedData: mergedData));
        } else {
          final errorMessage = jsonData['message'] ?? 'Failed to load data';
          print('DetailDashBloc: API error: $errorMessage');
          emit(DetailDashError(message: errorMessage));
        }
      } else {
        final errorMessage = 'Server error: ${response.statusCode}';
        print('DetailDashBloc: Server error: $errorMessage');
        emit(DetailDashError(message: errorMessage));
      }
    } catch (e) {
      final errorMessage = 'Error: $e';
      print('DetailDashBloc: Exception caught: $errorMessage');
      emit(DetailDashError(message: errorMessage));
    }
  }
}