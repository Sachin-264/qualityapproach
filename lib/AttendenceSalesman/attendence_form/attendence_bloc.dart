// lib/.../attendence_bloc.dart

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

// --- EVENTS ---

abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();
  @override
  List<Object?> get props => [];
}

class AttendanceSelfieCaptureStarted extends AttendanceEvent {}

class AttendanceSelfieCaptureSucceeded extends AttendanceEvent {
  final String imagePath;
  final DateTime captureTime; // To show on the confirmation screen
  const AttendanceSelfieCaptureSucceeded({required this.imagePath, required this.captureTime});
  @override
  List<Object?> get props => [imagePath, captureTime];
}

class AttendanceSelfieCaptureFailed extends AttendanceEvent {
  final String error;
  const AttendanceSelfieCaptureFailed({required this.error});
  @override
  List<Object?> get props => [error];
}

class AttendanceSubmitted extends AttendanceEvent {
  final String salesmanName;
  const AttendanceSubmitted({required this.salesmanName});
  @override
  List<Object?> get props => [salesmanName];
}

class AttendanceReset extends AttendanceEvent {}

// --- STATES ---

abstract class AttendanceState extends Equatable {
  const AttendanceState();
  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {}

class AttendanceSelfieInProgress extends AttendanceState {}

class AttendanceNameEntry extends AttendanceState {
  final String imagePath;
  final DateTime captureTime; // Passed to the UI
  const AttendanceNameEntry({required this.imagePath, required this.captureTime});
  @override
  List<Object?> get props => [imagePath, captureTime];
}

class AttendanceSubmissionLoading extends AttendanceState {}

class AttendanceSubmissionSuccess extends AttendanceState {
  final String salesmanName;
  final String imagePath;
  final DateTime submissionTime;
  const AttendanceSubmissionSuccess({
    required this.salesmanName,
    required this.imagePath,
    required this.submissionTime,
  });
  @override
  List<Object?> get props => [salesmanName, imagePath, submissionTime];
}

class AttendanceSubmissionFailure extends AttendanceState {
  final String error;
  const AttendanceSubmissionFailure({required this.error});
  @override
  List<Object?> get props => [error];
}

// --- BLOC ---

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  AttendanceBloc() : super(AttendanceInitial()) {
    on<AttendanceSelfieCaptureStarted>(_onSelfieCaptureStarted);
    on<AttendanceSelfieCaptureSucceeded>(_onSelfieCaptureSucceeded);
    on<AttendanceSelfieCaptureFailed>(_onSelfieCaptureFailed);
    on<AttendanceSubmitted>(_onAttendanceSubmitted);
    on<AttendanceReset>(_onAttendanceReset);
  }

  void _onSelfieCaptureStarted(
      AttendanceSelfieCaptureStarted event, Emitter<AttendanceState> emit) {
    emit(AttendanceSelfieInProgress());
  }

  void _onSelfieCaptureSucceeded(
      AttendanceSelfieCaptureSucceeded event, Emitter<AttendanceState> emit) {
    emit(AttendanceNameEntry(
      imagePath: event.imagePath,
      captureTime: event.captureTime,
    ));
  }

  void _onSelfieCaptureFailed(
      AttendanceSelfieCaptureFailed event, Emitter<AttendanceState> emit) {
    emit(AttendanceSubmissionFailure(error: event.error));
  }

  Future<void> _onAttendanceSubmitted(
      AttendanceSubmitted event, Emitter<AttendanceState> emit) async {
    if (state is AttendanceNameEntry) {
      final currentState = state as AttendanceNameEntry;
      emit(AttendanceSubmissionLoading());
      await Future.delayed(const Duration(seconds: 1)); // Simulates a network call
      emit(AttendanceSubmissionSuccess(
        salesmanName: event.salesmanName,
        imagePath: currentState.imagePath,
        submissionTime: DateTime.now(),
      ));
    }
  }

  void _onAttendanceReset(AttendanceReset event, Emitter<AttendanceState> emit) {
    emit(AttendanceInitial());
  }
}