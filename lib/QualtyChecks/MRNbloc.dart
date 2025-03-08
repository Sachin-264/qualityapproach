import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:qualityapproach/QUALITY_API.DART';
// Import API file

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
  final String str;

  FetchMRNReport({
    required this.branchCode,
    required this.fromDate,
    required this.toDate,
    required this.pending,
    required this.str,
  });

  @override
  List<Object> get props => [branchCode, fromDate, toDate, pending, str];
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
  final String message;

  MRNReportError(this.message);

  @override
  List<Object> get props => [message];
}

// Bloc
class MRNReportBloc extends Bloc<MRNReportEvent, MRNReportState> {
  MRNReportBloc() : super(MRNReportInitial()) {
    on<FetchMRNReport>((event, emit) async {
      print(
          'Fetching MRNReport with branchCode: ${event.branchCode}, fromDate: ${event.fromDate}, toDate: ${event.toDate}, pending: ${event.pending}');

      emit(MRNReportLoading());

      try {
        final reports = await QualityAPI.getMRNReport(
          branchCode: event.branchCode,
          fromDate: event.fromDate,
          toDate: event.toDate,
          pending: event.pending,
          str: event.str,
        );



        emit(MRNReportLoaded(reports: reports));
      } catch (e) {
        emit(MRNReportError('An error occurred: $e'));
      }
    });
  }
}
