import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:equatable/equatable.dart';

// Events
abstract class MRNReportEvent extends Equatable {
  const MRNReportEvent();

  @override
  List<Object> get props => [];
}

class FetchMRNReport extends MRNReportEvent {
  final String branchCode;
  final String fromDate;
  final String toDate;
  final String pending;

  FetchMRNReport({
    required this.branchCode,
    required this.fromDate,
    required this.toDate,
    required this.pending,
  });

  @override
  List<Object> get props => [branchCode, fromDate, toDate, pending];
}

// States
abstract class MRNReportState extends Equatable {
  const MRNReportState();

  @override
  List<Object> get props => [];
}

class MRNReportInitial extends MRNReportState {}

class MRNReportLoading extends MRNReportState {}

class MRNReportLoaded extends MRNReportState {
  final List<Map<String, dynamic>> reports;

  const MRNReportLoaded({required this.reports});

  @override
  List<Object> get props => [reports];
}

class MRNReportError extends MRNReportState {
  final String errorMessage;

  const MRNReportError(this.errorMessage);

  @override
  List<Object> get props => [errorMessage];

  String get message => errorMessage;
}

// BLoC
class MRNReportBloc extends Bloc<MRNReportEvent, MRNReportState> {
  MRNReportBloc() : super(MRNReportInitial()) {
    on<FetchMRNReport>((event, emit) async {
      print(
          'FetchMRNReport received with branchCode: ${event.branchCode}, fromDate: ${event.fromDate}, toDate: ${event.toDate}, pending: ${event.pending}');
      emit(MRNReportLoading());

      try {
        // Construct the API URL with filter parameters
        final url = Uri.parse(
            'http://192.168.172.119/AquavivaAPI/get_mrn_qc_details.php?BranchCode=${event.branchCode}&FromDate=${event.fromDate}&ToDate=${event.toDate}&Level1=&UserCode=0&Company_QC_SingleLevel=&Branch_QC_Level=0&Pending= ${event.pending}');

        print('API URL: $url');

        // Make the API request
        final response = await http.get(url);

        print('API Response Status Code: ${response.statusCode}');
        print('API Response Body: ${response.body}');

        if (response.statusCode == 200) {
          final List<dynamic> jsonList = json.decode(response.body);
          final reports = jsonList.cast<Map<String, dynamic>>();

          emit(MRNReportLoaded(reports: reports));
        } else {
          emit(
              MRNReportError('Failed to load reports: ${response.statusCode}'));
        }
      } catch (e) {
        print('Error: $e');
        // print('Stack Trace: ${e.stackTrace}');
        emit(MRNReportError('An error occurred: $e'));
      }
    });
  }
}
