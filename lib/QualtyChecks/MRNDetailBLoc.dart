import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:qualityapproach/QUALITY_API.dart'; // Ensure the file name is correct

// Events
abstract class MRNDetailEvent extends Equatable {
  const MRNDetailEvent();
  @override
  List<Object> get props => [];
}

class FetchMRNDetailEvent extends MRNDetailEvent {
  final String branchCode;
  final String itemNo;
  final String str;

  const FetchMRNDetailEvent({
    required this.branchCode,
    required this.itemNo,
    required this.str,
  });

  @override
  List<Object> get props => [branchCode, itemNo, str];
}

class SubmitMRNDetailEvent extends MRNDetailEvent {
  final String signature;

  final List<Map<String, dynamic>> qualityParameters;

  SubmitMRNDetailEvent({
    required this.signature,
    required this.qualityParameters,
  });
}

class ResetObservedValueEvent extends MRNDetailEvent {}

// States
abstract class MRNDetailState extends Equatable {
  const MRNDetailState();
  @override
  List<Object> get props => [];
}

class MRNDetailInitial extends MRNDetailState {}

class MRNDetailLoading extends MRNDetailState {}

class MRNDetailLoaded extends MRNDetailState {
  final List<Map<String, dynamic>> qualityParameters;

  const MRNDetailLoaded({required this.qualityParameters});

  @override
  List<Object> get props => [qualityParameters];
}

class MRNDetailError extends MRNDetailState {
  final String message;

  const MRNDetailError({required this.message});

  @override
  List<Object> get props => [message];
}

class MRNDetailSubmitting extends MRNDetailState {}

class MRNDetailSubmitSuccess extends MRNDetailState {}

class MRNDetailSubmitError extends MRNDetailState {
  final String message;

  const MRNDetailSubmitError({required this.message});

  @override
  List<Object> get props => [message];
}

// BLoC
class MRNDetailBloc extends Bloc<MRNDetailEvent, MRNDetailState> {
  List<Map<String, dynamic>>? _initialQualityParameters;

  // Add properties needed for submission
  final String str;
  final double UserCode;
  final int UserGroupCode;
  final String itemSno;
  final String itemNo;
  final String RecNo;

  MRNDetailBloc({
    required this.str,
    required this.UserCode,
    required this.UserGroupCode,
    required this.itemSno,
    required this.itemNo,
    required this.RecNo,
  }) : super(MRNDetailInitial()) {
    on<FetchMRNDetailEvent>(_onFetchMRNDetail);
    on<ResetObservedValueEvent>(_onResetObservedValue);
    on<SubmitMRNDetailEvent>(_onSubmitMRNDetail);
  }

  Future<void> _onFetchMRNDetail(
      FetchMRNDetailEvent event, Emitter<MRNDetailState> emit) async {
    emit(MRNDetailLoading());
    try {
      final data = await QualityAPI.getItemQualityParameters(
        branchCode: event.branchCode,
        itemNo: event.itemNo,
        str: event.str,
      );

      _initialQualityParameters = data;
      emit(MRNDetailLoaded(qualityParameters: data));
    } catch (e) {
      emit(MRNDetailError(message: e.toString()));
    }
  }

  void _onResetObservedValue(
      ResetObservedValueEvent event, Emitter<MRNDetailState> emit) {
    if (_initialQualityParameters != null) {
      emit(MRNDetailLoaded(qualityParameters: _initialQualityParameters!));
    }
  }

  Future<void> _onSubmitMRNDetail(
      SubmitMRNDetailEvent event, Emitter<MRNDetailState> emit) async {
    if (state is MRNDetailLoaded) {
      final currentState = state as MRNDetailLoaded;
      emit(MRNDetailSubmitting());

      print('Submitting MRN Detail...');
      print('Current State: $currentState');

      // Validate and parse RecNo
      int recNoInt;
      try {
        recNoInt = double.parse(RecNo).toInt(); // Convert "1.0" to 1
      } catch (e) {
        print('Error parsing RecNo: $e');
        emit(const MRNDetailSubmitError(message: 'Invalid RecNo format'));
        return;
      }

      // Prepare FileDetail with correct SNo as int
      final List<Map<String, dynamic>> fileDetail =
          event.qualityParameters.asMap().entries.map((entry) {
        final int index = entry.key;
        final Map<String, dynamic> param = entry.value;

        return {
          'SNo': index + 1, // Ensure SNo is an integer starting from 1
          'QualityParameter': param['QualityParameter'].toString(),
          'StdRange': param['StdRange'].toString(),
          'StdOptions': param['StdOptions'].toString(),
          'Remarks': param['Remarks'].toString(),
        };
      }).toList();

      try {
        final qualityAPI = QualityAPI();
        print('Calling submitMRNQualityParameters API...');
        print('Parameters:');
        print('str: $str');
        print('UserCode: $UserCode');
        print('UserGroupCode: $UserGroupCode');
        print('RecNo: $recNoInt');
        print('itemSno: $itemSno');
        print('itemNo: $itemNo');
        print('signature: ${event.signature}');
        print('qualityParameters: $fileDetail');

        final success = await QualityAPI.submitMRNQualityParameters(
          str: str,
          UserCode: UserCode,
          UserGroupCode: UserGroupCode,
          RecNo: recNoInt, // Use the parsed integer value
          ItemSno: int.parse(itemSno),
          ItemNo: itemNo,
          signature: event.signature,
          FileDetail: fileDetail, // Use the formatted FileDetail
        );

        print('API Response: $success');

        if (success) {
          print('MRN Detail submitted successfully.');
          emit(MRNDetailSubmitSuccess());
        } else {
          print('Failed to submit MRN Detail.');
          emit(const MRNDetailSubmitError(message: 'Failed to submit data'));
        }
      } catch (e) {
        print('Error submitting MRN Detail: $e');
        emit(MRNDetailSubmitError(message: e.toString()));
      }
    }
  }
}
