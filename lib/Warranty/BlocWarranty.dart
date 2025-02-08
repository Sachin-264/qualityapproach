import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// States
abstract class WarrantyState extends Equatable {
  const WarrantyState();

  @override
  List<Object> get props => [];
}

class WarrantyInitial extends WarrantyState {}

class WarrantyLoaded extends WarrantyState {
  final List<Map<String, String>> Warranty;

  const WarrantyLoaded(this.Warranty);

  @override
  List<Object> get props => [Warranty];
}

class WarrantyError extends WarrantyState {
  final String message;

  const WarrantyError(this.message);

  @override
  List<Object> get props => [message];
}

// Events
abstract class WarrantyEvent extends Equatable {
  const WarrantyEvent();

  @override
  List<Object> get props => [];
}

class LoadWarranty extends WarrantyEvent {}

class DeleteWarranty extends WarrantyEvent {
  final BuildContext context;
  final String recNo;

  const DeleteWarranty(this.recNo, this.context);

  @override
  List<Object> get props => [recNo, context];
}

// Bloc Implementation
class WarrantyBloc extends Bloc<WarrantyEvent, WarrantyState> {
  WarrantyBloc() : super(WarrantyInitial()) {
    on<LoadWarranty>(_onLoadWarranty);
    on<DeleteWarranty>(_onDeleteWarranty);
  }

// pass type in future

  Future<void> _onLoadWarranty(
    LoadWarranty event,
    Emitter<WarrantyState> emit,
  ) async {
    try {
      final response = await http
          .get(Uri.parse("http://localhost/allWarrantyGetAPI.php?type=SlipNo"));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Map<String, String>> Warranty = data.map((item) {
          return {
            "RecNo": item["RecNo"]?.toString() ?? '',
            "WarrantyName": item["WarrantyName"]?.toString() ?? '',
            "Action1": "Edit",
            "Action2": "Delete",
          };
        }).toList();

        emit(WarrantyLoaded(Warranty));
      } else {
        emit(WarrantyError('Server error: ${response.statusCode}'));
      }
    } catch (e) {
      emit(WarrantyError('Failed to load user groups: $e'));
    }
  }

  Future<void> _onDeleteWarranty(
    DeleteWarranty event,
    Emitter<WarrantyState> emit,
  ) async {
    // Keep the current state if it's UserGroupLoaded
    final currentState = state;
    if (currentState is WarrantyLoaded) {
      try {
        final response = await http.post(
          Uri.parse('http://localhost/deleteWarranty.php'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'storedProcedure': 'sp_DeleteWarrantyMasterCRM',
            'recec': event.recNo,
          },
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          print('Delete API response: $responseData');
          // Reload the user groups after successful deletion

          ScaffoldMessenger.of(event.context).showSnackBar(
            SnackBar(
              content: Text(responseData['message']),
              backgroundColor: Colors.black,
            ),
          );
          final updatedResponse =
              await http.get(Uri.parse("http://localhost/getUserGroup.php"));

          if (updatedResponse.statusCode == 200) {
            final List<dynamic> data = json.decode(updatedResponse.body);
            final List<Map<String, String>> Warranty = data.map((item) {
              return {
                "RecNo": item["RecNo"]?.toString() ?? '',
                "UserGroupName": item["UserGroupName"]?.toString() ?? '',
                "Action1": "Edit",
                "Action2": "Delete",
              };
            }).toList();

            emit(WarrantyLoaded(Warranty));
          } else {
            emit(WarrantyError('Failed to reload user groups'));
          }
        } else {
          emit(WarrantyError('Failed to delete user group'));
        }
      } catch (e) {
        emit(WarrantyError('Error during deletion: $e'));
      }
    }
  }
}
