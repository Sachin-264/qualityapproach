// editsparedetailbloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../SparePart/global.dart';
import 'dart:developer' as developer;

abstract class EditSparePartEvent {}

class FetchSparePartDetails extends EditSparePartEvent {}

class FetchAllItems extends EditSparePartEvent {}

class SearchItems extends EditSparePartEvent {
  final String query;
  SearchItems(this.query);
}

class SubmitEditedSparePart extends EditSparePartEvent {
  final String userCode;
  final String companyCode;
  final int recNo;
  final int complaintRecNo;
  final String date;
  final String slipNo;
  final double grandTotal;
  final String itemDetails;

  SubmitEditedSparePart({
    required this.userCode,
    required this.companyCode,
    required this.recNo,
    required this.complaintRecNo,
    required this.date,
    required this.slipNo,
    required this.grandTotal,
    required this.itemDetails,
  });
}

abstract class EditSparePartState {}

class EditSparePartInitial extends EditSparePartState {}

class EditSparePartLoading extends EditSparePartState {}

class EditSparePartSearchLoading extends EditSparePartState {}

class EditSparePartLoaded extends EditSparePartState {
  final Map<String, dynamic> headerData;
  final List<Map<String, dynamic>> items;
  final String slipNo;
  final List<Map<String, dynamic>> searchResults;
  final List<Map<String, dynamic>> allItems;

  EditSparePartLoaded({
    required this.headerData,
    required this.items,
    required this.slipNo,
    this.searchResults = const [],
    this.allItems = const [],
  });

  EditSparePartLoaded copyWith({
    Map<String, dynamic>? headerData,
    List<Map<String, dynamic>>? items,
    String? slipNo,
    List<Map<String, dynamic>>? searchResults,
    List<Map<String, dynamic>>? allItems,
  }) {
    return EditSparePartLoaded(
      headerData: headerData ?? this.headerData,
      items: items ?? this.items,
      slipNo: slipNo ?? this.slipNo,
      searchResults: searchResults ?? this.searchResults,
      allItems: allItems ?? this.allItems,
    );
  }
}

class EditSparePartError extends EditSparePartState {
  final String message;
  EditSparePartError(this.message);
}

class EditSparePartSubmitted extends EditSparePartState {
  final bool success;
  final String message;
  final Map<String, dynamic> headerData;
  final List<Map<String, dynamic>> items;
  final String slipNo;

  EditSparePartSubmitted({
    required this.success,
    required this.message,
    required this.headerData,
    required this.items,
    required this.slipNo,
  });
}

class EditSparePartBloc extends Bloc<EditSparePartEvent, EditSparePartState> {
  String _slipNo = '';
  static const int _maxDisplayItems = 10;

  EditSparePartBloc() : super(EditSparePartInitial()) {
    on<FetchSparePartDetails>(_fetchSparePartDetails);
    on<FetchAllItems>(_fetchAllItems);
    on<SearchItems>(_searchItems);
    on<SubmitEditedSparePart>(_submitEditedSparePart);
  }

  Future<void> _fetchSparePartDetails(FetchSparePartDetails event, Emitter<EditSparePartState> emit) async {
    emit(EditSparePartLoading());
    try {
      final recNo = GlobalData.selectedRecNo ?? '2';
      developer.log('Fetching spare part details for RecNo: $recNo');
      final spareResponse = await http.get(Uri.parse(
          'http://localhost/Bestapi/editSpare.php?Type=LoadSpareParts&UserCode=1&CompanyCode=101&RecNo=$recNo'));

      if (spareResponse.statusCode == 200) {
        final spareJson = json.decode(spareResponse.body);
        if (spareJson['status'] == 'success') {
          final headerData = spareJson['data'][0][0];
          final items = List<Map<String, dynamic>>.from(spareJson['data'][1]);
          _slipNo = headerData['SlipNo'] ?? '';
          emit(EditSparePartLoaded(
            headerData: headerData,
            items: items,
            slipNo: _slipNo,
          ));
          add(FetchAllItems());
        } else {
          emit(EditSparePartError('Failed to load spare part details: ${spareJson['message']}'));
        }
      } else {
        emit(EditSparePartError('Failed to connect to the server'));
      }
    } catch (e) {
      emit(EditSparePartError('Error fetching spare part details: $e'));
    }
  }

  Future<void> _fetchAllItems(FetchAllItems event, Emitter<EditSparePartState> emit) async {
    try {
      developer.log('Fetching all items in background');
      final itemsResponse = await http.get(Uri.parse(
          'http://localhost/Bestapi/get_item.php?CompanyCode=101&CallFrom=Direct&search='));

      if (itemsResponse.statusCode == 200) {
        final itemsJson = json.decode(itemsResponse.body);
        if (itemsJson['status'] == 'success') {
          final allItems = List<Map<String, dynamic>>.from(itemsJson['data']);
          developer.log('Loaded ${allItems.length} items in background');
          if (state is EditSparePartLoaded) {
            emit((state as EditSparePartLoaded).copyWith(allItems: allItems));
          }
        } else {
          developer.log('Failed to load items: ${itemsJson['message']}');
        }
      } else {
        developer.log('Failed to connect to server for items');
      }
    } catch (e) {
      developer.log('Error fetching items: $e');
    }
  }

  Future<void> _searchItems(SearchItems event, Emitter<EditSparePartState> emit) async {
    if (event.query.length < 3) {
      if (state is EditSparePartLoaded) {
        emit((state as EditSparePartLoaded).copyWith(searchResults: []));
      }
      return;
    }

    if (state is EditSparePartLoaded) {
      final currentState = state as EditSparePartLoaded;
      emit(EditSparePartSearchLoading());
      final filteredItems = currentState.allItems
          .where((item) =>
      item['FieldName']?.toString().toLowerCase().contains(event.query.toLowerCase()) ?? false)
          .toList();
      developer.log('Filtered ${filteredItems.length} items for query: ${event.query}');
      emit(currentState.copyWith(
        searchResults: filteredItems.take(_maxDisplayItems).toList(),
      ));
    }
  }

  Future<void> _submitEditedSparePart(SubmitEditedSparePart event, Emitter<EditSparePartState> emit) async {
    emit(EditSparePartLoading());
    try {
      final requestBody = {
        "UserCode": event.userCode,
        "CompanyCode": event.companyCode,
        "RecNo": event.recNo,
        "ComplaintRecNo": event.complaintRecNo,
        "Date": event.date,
        "SlipNo": event.slipNo,
        "GrandTotal": event.grandTotal,
        "ItemDetails": event.itemDetails,
      };

      developer.log('Submitting spare part update: ${json.encode(requestBody)}');
      final response = await http.post(
        Uri.parse('http://localhost/Bestapi/post_save.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        // Get current state data if available
        Map<String, dynamic> headerData = {};
        List<Map<String, dynamic>> items = [];
        String slipNo = event.slipNo;

        if (state is EditSparePartLoaded) {
          final currentState = state as EditSparePartLoaded;
          headerData = currentState.headerData;
          items = currentState.items;
          slipNo = currentState.slipNo;
        }

        emit(EditSparePartSubmitted(
          success: jsonData['status'] == 'success',
          message: jsonData['status'] == 'success' ? 'Data is submitted' : 'Failed to submit: ${jsonData['message']}',
          headerData: headerData,
          items: items,
          slipNo: slipNo,
        ));
      } else {
        emit(EditSparePartSubmitted(
          success: false,
          message: 'Failed to connect to the server',
          headerData: state is EditSparePartLoaded ? (state as EditSparePartLoaded).headerData : {},
          items: state is EditSparePartLoaded ? (state as EditSparePartLoaded).items : [],
          slipNo: _slipNo,
        ));
      }
    } catch (e) {
      emit(EditSparePartSubmitted(
        success: false,
        message: 'Error submitting spare part: $e',
        headerData: state is EditSparePartLoaded ? (state as EditSparePartLoaded).headerData : {},
        items: state is EditSparePartLoaded ? (state as EditSparePartLoaded).items : [],
        slipNo: _slipNo,
      ));
    }
  }
}