import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:qualityapproach/QUALITY_API.dart'; // Ensure correct import

// Events (unchanged)
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

  @override
  List<Object> get props => [signature, qualityParameters];
}

class ResetObservedValueEvent extends MRNDetailEvent {}

// States (unchanged)
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

  // Properties
  final String str;
  final double UserCode;
  final int UserGroupCode;
  final String itemSno;
  final String itemNo;
  final String RecNo;
  final String pending; // Add pending parameter

  MRNDetailBloc({
    required this.str,
    required this.UserCode,
    required this.UserGroupCode,
    required this.itemSno,
    required this.itemNo,
    required this.RecNo,
    required this.pending, // Include pending
  }) : super(MRNDetailInitial()) {
    on<FetchMRNDetailEvent>(_onFetchMRNDetail);
    on<ResetObservedValueEvent>(_onResetObservedValue);
    on<SubmitMRNDetailEvent>(_onSubmitMRNDetail);
  }

  Future<void> _onFetchMRNDetail(FetchMRNDetailEvent event, Emitter<MRNDetailState> emit) async {
    emit(MRNDetailLoading());
    try {
      List<Map<String, dynamic>> data;

      if (pending.toUpperCase() == 'Y') {
        // Use getItemQualityParameters when pending is 'Y'
        data = await QualityAPI.getItemQualityParameters(
          branchCode: event.branchCode,
          itemNo: event.itemNo,
          str: event.str,
        );
      } else if (pending.toUpperCase() == 'N') {
        // Use loadMRNItemQualityDetails when pending is 'N'
        data = await QualityAPI. loadMRNItemQualityDetails(
          RecNo: int.tryParse(RecNo) ?? 1,
          ItemNo: itemNo,
          ItemSNo: int.tryParse(itemSno) ?? 0,
          str: str,
        );
      } else {
        throw Exception('Invalid pending value: $pending');
      }

      _initialQualityParameters = data;
      emit(MRNDetailLoaded(qualityParameters: data));
    } catch (e) {
      emit(MRNDetailError(message: e.toString()));
    }
  }

  void _onResetObservedValue(ResetObservedValueEvent event, Emitter<MRNDetailState> emit) {
    if (_initialQualityParameters != null) {
      emit(MRNDetailLoaded(qualityParameters: _initialQualityParameters!));
    }
  }

  Future<void> _onSubmitMRNDetail(SubmitMRNDetailEvent event, Emitter<MRNDetailState> emit) async {
    if (state is MRNDetailLoaded) {
      emit(MRNDetailSubmitting());

      final List<Map<String, dynamic>> fileDetail = event.qualityParameters.map((param) {
        return {
          'SNo': param['SNo'] ?? '1',
          'QualityParameter': param['QualityParameter'].toString(),
          'StdRange': param['StdRange'].toString(),
          'StdOptions': param['StdOptions'].toString(),
          'ObservedValue': param['ObservedValue']?.toString() ?? '',
          'Remarks': param['Remarks']?.toString() ?? '',
          'Pass(Yes/No)': param['Pass(Yes/No)']?.toString() ?? '',
        };
      }).toList();

      try {
        final int parsedRecNo = int.tryParse(RecNo) ?? 1;
        final int parsedItemSno = int.tryParse(itemSno) ?? 0;
        final success = await QualityAPI.submitMRNQualityParameters(
          str: str,
          UserCode: UserCode,
          UserGroupCode: UserGroupCode,
          RecNo: parsedRecNo,
          ItemSno: parsedItemSno,
          ItemNo: itemNo,
          signature: event.signature,
          FileDetail: fileDetail,
        );
        print('RecNo: $RecNo, str:$str, itemSno: $itemSno');

        if (success) {
          emit(MRNDetailSubmitSuccess());
        } else {
          emit(const MRNDetailSubmitError(message: 'Failed to submit data'));
        }
      } catch (e) {
        emit(MRNDetailSubmitError(message: e.toString()));
      }
    }
  }
}