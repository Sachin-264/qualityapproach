import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'global.dart';


// Your ItemBloc and related classes
abstract class ItemEvent {}

class FetchInitialItems extends ItemEvent {}

class SearchItems extends ItemEvent {
  final String query;
  SearchItems(this.query);
}

class SelectItem extends ItemEvent {
  final String fieldId;
  SelectItem(this.fieldId);
}

class FetchSlipNo extends ItemEvent {}

class SubmitItem extends ItemEvent {
  final String userCode;
  final String companyCode;
  final int recNo;
  final int complaintRecNo;
  final String date;
  final String slipNo;
  final double grandTotal;
  final String itemDetails;

  SubmitItem({
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

abstract class ItemState {}

class ItemInitial extends ItemState {}

class ItemLoading extends ItemState {}

class ItemLoaded extends ItemState {
  final List<Map<String, dynamic>> items;
  ItemLoaded(this.items);
}

class ItemSearchResults extends ItemState {
  final List<Map<String, dynamic>> items;
  ItemSearchResults(this.items);
}

class ItemError extends ItemState {
  final String message;
  ItemError(this.message);
}

class ItemSelected extends ItemState {
  final String fieldId;
  final Map<String, dynamic>? itemDetails;
  ItemSelected(this.fieldId, [this.itemDetails]);
}

class SlipNoLoaded extends ItemState {
  final String slipNo;
  SlipNoLoaded(this.slipNo);
}

class ItemSubmitted extends ItemState {
  final bool success;
  final String message;
  ItemSubmitted(this.success, this.message);
}

class ItemBloc extends Bloc<ItemEvent, ItemState> {
  List<Map<String, dynamic>> _cachedItems = [];
  static const int _maxDisplayItems = 10;
  static const int _initialLoadLimit = 50;
  bool _isFullDataLoaded = false;
  String _slipNo = '';
  String get slipNo => _slipNo;

  ItemBloc() : super(ItemInitial()) {
    on<FetchInitialItems>(_fetchInitialItems);
    on<SearchItems>(_searchItems);
    on<SelectItem>(_selectItem);
    on<FetchSlipNo>(_fetchSlipNo);
    on<SubmitItem>(_submitItem);
    _loadFullDataInBackground();
  }

  Future<void> _fetchInitialItems(FetchInitialItems event, Emitter<ItemState> emit) async {
    if (_cachedItems.isNotEmpty && _cachedItems.length <= _initialLoadLimit) {
      emit(ItemLoaded(_cachedItems.take(_maxDisplayItems).toList()));
      return;
    }
    emit(ItemLoading());
    try {
      print('LOG: Fetching initial items...');
      final response = await http.get(Uri.parse(
          'http://localhost/Bestapi/get_item.php?CompanyCode=101&CallFrom=Direct&limit=$_initialLoadLimit'));
      print('LOG: Initial items response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          _cachedItems = List<Map<String, dynamic>>.from(jsonData['data']);
          print('LOG: Initial items loaded: ${_cachedItems.length} items');
          emit(ItemLoaded(_cachedItems.take(_maxDisplayItems).toList()));
        } else {
          emit(ItemError('Failed to load initial items'));
          print('LOG: Initial items load failed: ${jsonData['message']}');
        }
      } else {
        emit(ItemError('Failed to connect to the server'));
        print('LOG: Server connection failed for initial items');
      }
    } catch (e) {
      emit(ItemError('Error fetching initial items: $e'));
      print('LOG: Exception fetching initial items: $e');
    }
  }

  Future<void> _loadFullDataInBackground() async {
    if (_isFullDataLoaded) return;
    try {
      print('LOG: Starting background full data load...');
      final response = await http.get(Uri.parse(
          'http://localhost/Bestapi/get_item.php?CompanyCode=101&CallFrom=Direct'));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          _cachedItems = List<Map<String, dynamic>>.from(jsonData['data']);
          _isFullDataLoaded = true;
          print('LOG: Full data loaded in background: ${_cachedItems.length} items');
        }
      }
    } catch (e) {
      print('LOG: Background load error: $e');
    }
  }

  Future<void> _fetchSlipNo(FetchSlipNo event, Emitter<ItemState> emit) async {
    try {
      print('LOG: Fetching slip number...');
      final response = await http.get(Uri.parse(
          'http://localhost/Bestapi/get_slip.php?CompanyCode=101&NoOfDigit=0'));
      print('LOG: Slip number response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'].isNotEmpty) {
          _slipNo = jsonData['data'][0]['NextCode'] ?? '';
          emit(SlipNoLoaded(_slipNo));
          print('LOG: Slip number loaded: $_slipNo');
        } else {
          emit(ItemError('Failed to load slip number'));
          print('LOG: Slip number load failed: ${jsonData['message']}');
        }
      } else {
        emit(ItemError('Failed to connect to the server for slip number'));
        print('LOG: Server connection failed for slip number');
      }
    } catch (e) {
      emit(ItemError('Error fetching slip number: $e'));
      print('LOG: Exception fetching slip number: $e');
    }
  }

  Future<void> _searchItems(SearchItems event, Emitter<ItemState> emit) async {
    if (event.query.length < 3) {
      emit(ItemSearchResults(_cachedItems.take(_maxDisplayItems).toList()));
      return;
    }
    emit(ItemLoading());
    try {
      print('LOG: Searching items for query: ${event.query}');
      if (_isFullDataLoaded) {
        _performLocalSearch(event.query, emit);
      } else if (_cachedItems.isNotEmpty) {
        _performLocalSearch(event.query, emit);
        await _performApiSearch(event.query, emit);
      } else {
        await _performApiSearch(event.query, emit);
      }
    } catch (e) {
      emit(ItemError('Search failed: $e'));
      print('LOG: Exception during search: $e');
    }
  }

  void _performLocalSearch(String query, Emitter<ItemState> emit) {
    print('LOG: Performing local search for: $query');
    final results = _cachedItems
        .where((item) =>
    item['FieldName']
        .toString()
        .toLowerCase()
        .contains(query.toLowerCase()) ||
        item['FieldID']
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase()))
        .take(_maxDisplayItems)
        .toList();
    emit(ItemSearchResults(results));
    print('LOG: Local search results: ${results.length} items');
  }

  Future<void> _performApiSearch(String query, Emitter<ItemState> emit) async {
    try {
      print('LOG: Performing API search for: $query');
      final response = await http.get(Uri.parse(
          'http://localhost/Bestapi/get_item.php?CompanyCode=101&CallFrom=Direct&search=$query'));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          final items = List<Map<String, dynamic>>.from(jsonData['data']);
          if (!_isFullDataLoaded) _cachedItems = items;
          emit(ItemSearchResults(items.take(_maxDisplayItems).toList()));
          print('LOG: API search results: ${items.length} items');
        } else {
          emit(ItemError('Search failed'));
          print('LOG: API search failed: ${jsonData['message']}');
        }
      } else {
        emit(ItemError('Failed to connect to the server'));
        print('LOG: Server connection failed for API search');
      }
    } catch (e) {
      emit(ItemError('API search error: $e'));
      print('LOG: Exception during API search: $e');
    }
  }

  void _selectItem(SelectItem event, Emitter<ItemState> emit) {
    print('LOG: Selecting item with FieldID: ${event.fieldId}');
    final selectedItem = _cachedItems.firstWhere(
          (item) => item['FieldID'] == event.fieldId,
      orElse: () => <String, dynamic>{},
    );
    emit(ItemSelected(event.fieldId, selectedItem));
    print('LOG: Item selected: ${selectedItem['FieldName']}');
  }

  Future<void> _submitItem(SubmitItem event, Emitter<ItemState> emit) async {
    emit(ItemLoading());
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
      print('LOG: Request body being sent: ${json.encode(requestBody)}');
      final response = await http.post(
        Uri.parse('http://localhost/Bestapi/post_save.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );
      print('LOG: Submit response status: ${response.statusCode}');
      print('LOG: Submit response body: ${response.body}');
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          emit(ItemSubmitted(true, 'Item submitted successfully'));
          print('LOG: Item submitted successfully');
        } else {
          emit(ItemSubmitted(false, 'Failed to submit item: ${jsonData['message']}'));
          print('LOG: Submit failed: ${jsonData['message']}');
        }
      } else {
        emit(ItemSubmitted(false, 'Failed to connect to the server'));
        print('LOG: Server connection failed for submit');
      }
    } catch (e) {
      emit(ItemSubmitted(false, 'Error submitting item: $e'));
      print('LOG: Exception submitting item: $e');
    }
  }
}

// SparePartDetailScreen UI