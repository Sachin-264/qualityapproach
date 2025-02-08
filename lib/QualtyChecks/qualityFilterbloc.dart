import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Model
class Branch {
  final String fieldID;
  final String fieldName;

  Branch({required this.fieldID, required this.fieldName});

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      fieldID: json['FieldID'],
      fieldName: json['FieldName'],
    );
  }
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Branch && other.fieldID == fieldID);

  @override
  int get hashCode => fieldID.hashCode;
}

// Bloc Events

abstract class BranchEvent {}

class FetchBranches extends BranchEvent {}

// Bloc States

abstract class BranchState {}

class BranchInitial extends BranchState {}

class BranchLoading extends BranchState {}

class BranchLoaded extends BranchState {
  final List<Branch> branches;
  BranchLoaded({required this.branches});
}

class BranchError extends BranchState {
  final String message;
  BranchError({required this.message});
}

// Bloc

class BranchBloc extends Bloc<BranchEvent, BranchState> {
  BranchBloc() : super(BranchInitial()) {
    on<FetchBranches>(_fetchBranches);
  }

  Future<void> _fetchBranches(
      FetchBranches event, Emitter<BranchState> emit) async {
    emit(BranchLoading());
    try {
      final response = await http.get(Uri.parse(
          "https://www.aquare.co.in/mobileAPI/ERP_getValues.php?type=sp_GetBranchName&ucode=157.0&ccode=0.0&val1=157.0&val2=&val3=&val4=&val5=&val6=&val8=eTFKdGFqMG5ibWN0NGJ4ekIxUG8zbzRrNXZFbGQxaW96dHpteFFQdEdWQ2kzcnNBQlk1b1BpYW0wNy80Q3FXNlFwVnF6Zkl4ZzU1dU9ZS1lwWWxqUWc9PQ=="));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Branch> branches = data.map((e) => Branch.fromJson(e)).toList();
        emit(BranchLoaded(branches: branches));
      } else {
        emit(BranchError(message: "Failed to fetch data"));
      }
    } catch (e) {
      emit(BranchError(message: e.toString()));
    }
  }
}
