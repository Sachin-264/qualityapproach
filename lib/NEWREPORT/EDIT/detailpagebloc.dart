import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

abstract class DetailPageEvent {}

class FetchDetailData extends DetailPageEvent {
  final String type;
  final String userCode;
  final String companyCode;
  final String recNo;

  FetchDetailData({
    required this.type,
    required this.userCode,
    required this.companyCode,
    required this.recNo,
  });
}

abstract class DetailPageState {}

class DetailPageInitial extends DetailPageState {}

class DetailPageLoading extends DetailPageState {}

class DetailPageLoaded extends DetailPageState {
  final List<Map<String, dynamic>> detailData;

  DetailPageLoaded(this.detailData);
}

class DetailPageError extends DetailPageState {
  final String message;

  DetailPageError(this.message);
}

class DetailPageBloc extends Bloc<DetailPageEvent, DetailPageState> {
  DetailPageBloc() : super(DetailPageInitial()) {
    on<FetchDetailData>(_onFetchDetailData);
  }

  Future<void> _onFetchDetailData(FetchDetailData event, Emitter<DetailPageState> emit) async {
    emit(DetailPageLoading());

    try {
      final url = 'http://localhost/ButtonCustomer.php?type=${event.type}&UserCode=${event.userCode}&CompanyCode=${event.companyCode}&RecNo=${event.recNo}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final detailData = (data['data'] as List).map((item) => item as Map<String, dynamic>).toList();
          emit(DetailPageLoaded(detailData));
        } else {
          emit(DetailPageError('Failed to load data: ${data['message']}'));
        }
      } else {
        emit(DetailPageError('Error fetching data: HTTP ${response.statusCode}'));
      }
    } catch (e) {
      emit(DetailPageError('An error occurred: $e'));
    }
  }
}



