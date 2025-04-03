import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'global.dart';

void main() {
  runApp(const MaterialApp(home: SparePartDetailScreen(selectedPart: {})));
}

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
class SparePartDetailScreen extends StatelessWidget {
  final Map<String, dynamic> selectedPart;

  const SparePartDetailScreen({super.key, required this.selectedPart});

  @override
  Widget build(BuildContext context) {
    final currentDate = DateTime.now().toString().split(' ')[0];
    return BlocProvider(
      create: (_) => ItemBloc()
        ..add(FetchInitialItems())
        ..add(FetchSlipNo()),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Spare Part Details',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRequestInfoCard(context, currentDate),
                const SizedBox(height: 24),
                SparePartForm(initialPart: selectedPart, currentDate: currentDate),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestInfoCard(BuildContext context, String currentDate) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Information',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildDateField(currentDate),
                const SizedBox(width: 16),
                BlocBuilder<ItemBloc, ItemState>(
                  builder: (context, state) {
                    final bloc = context.read<ItemBloc>();
                    String slipNo = bloc.slipNo;
                    if (state is ItemLoading && slipNo.isEmpty) {
                      return Expanded(
                        child: TextFormField(
                          decoration: _inputDecoration('Slip No', Icons.confirmation_number).copyWith(
                            suffixIcon: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          readOnly: true,
                        ),
                      );
                    } else if (state is SlipNoLoaded) {
                      slipNo = state.slipNo;
                    }
                    return _buildSlipNoField(slipNo);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildInfoField(
                    label: 'Complaint No',
                    value: GlobalData.selectedComplaintNo ?? '',
                    icon: Icons.receipt,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoField(
                    label: 'Mobile No',
                    value: GlobalData.selectedMobileNo ?? '',
                    icon: Icons.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoField(
              label: 'Customer Name',
              value: GlobalData.selectedCustomerName ?? '',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),
            _buildInfoField(
              label: 'Address',
              value: GlobalData.selectedAddress ?? '',
              icon: Icons.location_on,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(String date) => Expanded(
    child: TextFormField(
      initialValue: date,
      decoration: _inputDecoration('Current Date', Icons.calendar_today),
      readOnly: true,
    ),
  );

  Widget _buildSlipNoField(String slipNo) => Expanded(
    child: TextFormField(
      controller: TextEditingController(text: slipNo),
      decoration: _inputDecoration('Slip No', Icons.confirmation_number),
      readOnly: true,
    ),
  );

  Widget _buildInfoField(
      {required String label, required String value, required IconData icon}) =>
      TextFormField(
        initialValue: value,
        decoration: _inputDecoration(label, icon),
        readOnly: true,
      );

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
    prefixIcon: Icon(icon, size: 20, color: Colors.blue.shade600),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

class SparePartForm extends StatefulWidget {
  final Map<String, dynamic> initialPart;
  final String currentDate;

  const SparePartForm({super.key, required this.initialPart, required this.currentDate});

  @override
  _SparePartFormState createState() => _SparePartFormState();
}

class _SparePartFormState extends State<SparePartForm> {
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _rateController = TextEditingController();
  final _amountController = TextEditingController();
  final _gstPercentController = TextEditingController();
  final _gstAmountController = TextEditingController();
  final _totalController = TextEditingController();
  Timer? _debounce;
  Map<String, dynamic>? _selectedItem;
  bool _isDropdownVisible = false;
  List<Map<String, dynamic>> _addedItems = [];

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_calculateTotal);
    _rateController.addListener(_calculateTotal);
    _gstPercentController.addListener(_calculateTotal);
    if (widget.initialPart.isNotEmpty) _initializeWithPart(widget.initialPart);
  }

  void _initializeWithPart(Map<String, dynamic> part) {
    setState(() {
      _selectedItem = part;
      _searchController.text = part['FieldName'] ?? '';
      _rateController.text = part['Rate']?.toString() ?? '';
      _quantityController.text = _quantityController.text.isEmpty ? '1' : _quantityController.text;
      _gstPercentController.text = part['GST']?.toString() ?? '18';
      _isDropdownVisible = false;
      _calculateTotal();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    _amountController.dispose();
    _gstPercentController.dispose();
    _gstAmountController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;
    final gstPercent = double.tryParse(_gstPercentController.text) ?? 0;
    final amount = quantity * rate;
    final gstAmount = amount * (gstPercent / 100);
    final total = amount + gstAmount;
    _amountController.text = amount.toStringAsFixed(2);
    _gstAmountController.text = gstAmount.toStringAsFixed(2);
    _totalController.text = total.toStringAsFixed(2);
  }

  void _onSearchChanged(String query) {
    setState(() => _isDropdownVisible = query.length >= 3);
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      context.read<ItemBloc>().add(SearchItems(query));
    });
  }

  void _addItem() {
    if (_selectedItem != null) {
      setState(() {
        _addedItems.add({
          'FieldID': _selectedItem!['FieldID'],
          'FieldName': _selectedItem!['FieldName'],
          'Qty': _quantityController.text,
          'Rate': _rateController.text,
          'Amount': _amountController.text,
          'GSTPer': _gstPercentController.text,
          'GSTAmt': _gstAmountController.text,
          'Total': _totalController.text,
        });
        _clearForm();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an item first')),
      );
    }
  }

  void _editItem(int index) {
    final item = _addedItems[index];
    setState(() {
      _selectedItem = item;
      _searchController.text = item['FieldName'];
      _quantityController.text = item['Qty'];
      _rateController.text = item['Rate'];
      _amountController.text = item['Amount'];
      _gstPercentController.text = item['GSTPer'];
      _gstAmountController.text = item['GSTAmt'];
      _totalController.text = item['Total'];
      _addedItems.removeAt(index);
    });
  }

  void _deleteItem(int index) {
    setState(() {
      _addedItems.removeAt(index);
    });
  }

  void _clearForm() {
    _selectedItem = null;
    _searchController.clear();
    _quantityController.clear();
    _rateController.clear();
    _amountController.clear();
    _gstPercentController.clear();
    _gstAmountController.clear();
    _totalController.clear();
    _isDropdownVisible = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ItemBloc, ItemState>(
      listener: (context, state) {
        if (state is ItemError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        } else if (state is ItemSubmitted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: state.success ? Colors.green : Colors.red,
            ),
          );
          if (state.success) {
            setState(() {
              _addedItems.clear();
              _clearForm();
            });
            context.read<ItemBloc>().add(FetchSlipNo());
          }
        }
      },
      child: Card(
        elevation: 4,
        color: Colors.white, // Explicitly set the background color to white
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spare Part Details',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 20),
              _buildSearchField(context),
              if (_isDropdownVisible) _buildDropdown(context),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildNumberInputField(
                        'Quantity', Icons.format_list_numbered, _quantityController),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child:
                    _buildNumberInputField('Rate', Icons.attach_money, _rateController),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildNumberInputField(
                        'Amount', Icons.calculate, _amountController,
                        readOnly: true),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNumberInputField(
                        'GST %', Icons.percent, _gstPercentController),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildNumberInputField(
                        'GST Amount', Icons.money, _gstAmountController,
                        readOnly: true),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNumberInputField(
                        'Total', Icons.summarize, _totalController,
                        readOnly: true),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: _buildActionButton(
                  icon: Icons.add,
                  label: 'Add Item',
                  color: Colors.blue.shade600,
                  onPressed: _addItem,
                ),
              ),
              const SizedBox(height: 20),
              if (_addedItems.isNotEmpty) _buildItemsTable(),
              const SizedBox(height: 24),
              if (_addedItems.isNotEmpty) _buildSubmitResetButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) => TextFormField(
    controller: _searchController,
    decoration: InputDecoration(
      labelText: 'Search by Name or ID (min 3 chars)',
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      prefixIcon: Icon(Icons.search, size: 20, color: Colors.blue.shade600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    onChanged: _onSearchChanged,
  );

  Widget _buildDropdown(BuildContext context) => BlocBuilder<ItemBloc, ItemState>(
    builder: (context, state) {
      if (state is ItemLoading) {
        return Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: _ShimmerLoader(),
        );
      } else if (state is ItemSearchResults && state.items.isNotEmpty) {
        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return ListTile(
                title: Text(
                  '${item['FieldName']} (ID: ${item['FieldID']})',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                dense: true,
                onTap: () {
                  setState(() {
                    _selectedItem = item;
                    _searchController.text = item['FieldName'];
                    _rateController.text = item['Rate']?.toString() ?? '';
                    _quantityController.text =
                    _quantityController.text.isEmpty ? '1' : _quantityController.text;
                    _gstPercentController.text = item['GST']?.toString() ?? '18';
                    _isDropdownVisible = false;
                    _calculateTotal();
                  });
                  context.read<ItemBloc>().add(SelectItem(item['FieldID']));
                },
              );
            },
          ),
        );
      } else if (state is ItemLoaded) {
        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return ListTile(
                title: Text(
                  '${item['FieldName']} (ID: ${item['FieldID']})',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                dense: true,
                onTap: () {
                  setState(() {
                    _selectedItem = item;
                    _searchController.text = item['FieldName'];
                    _rateController.text = item['Rate']?.toString() ?? '';
                    _quantityController.text =
                    _quantityController.text.isEmpty ? '1' : _quantityController.text;
                    _gstPercentController.text = item['GST']?.toString() ?? '18';
                    _isDropdownVisible = false;
                    _calculateTotal();
                  });
                  context.read<ItemBloc>().add(SelectItem(item['FieldID']));
                },
              );
            },
          ),
        );
      }
      return const SizedBox.shrink();
    },
  );

  Widget _buildNumberInputField(String label, IconData icon, TextEditingController controller,
      {bool readOnly = false}) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          prefixIcon: Icon(icon, size: 20, color: Colors.blue.shade600),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );

  Widget _buildItemsTable() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Added Items',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.blue.shade800,
        ),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          columns: [
            DataColumn(
                label: Text('Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Qty', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Rate', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Amount', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('GST %', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('GST Amt', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Actions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          ],
          rows: _addedItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return DataRow(cells: [
              DataCell(Text(item['FieldName'], style: GoogleFonts.poppins())),
              DataCell(Text(item['Qty'], style: GoogleFonts.poppins())),
              DataCell(Text(item['Rate'], style: GoogleFonts.poppins())),
              DataCell(Text(item['Amount'], style: GoogleFonts.poppins())),
              DataCell(Text(item['GSTPer'], style: GoogleFonts.poppins())),
              DataCell(Text(item['GSTAmt'], style: GoogleFonts.poppins())),
              DataCell(Text(item['Total'], style: GoogleFonts.poppins())),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editItem(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteItem(index),
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    ],
  );

  Widget _buildSubmitResetButtons(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _buildActionButton(
        icon: Icons.check,
        label: 'Submit All',
        color: Colors.green.shade600,
        onPressed: () {
          if (_addedItems.isNotEmpty) {
            final bloc = context.read<ItemBloc>();
            final slipNo = bloc.slipNo;
            String itemDetails = _addedItems.map((item) {
              return "<Item>"
                  "<ItemNo>${item['FieldID']}</ItemNo>"
                  "<OurItemNo>${item['FieldID']}</OurItemNo>"
                  "<ItemName>${item['FieldName']}</ItemName>"
                  "<Qty>${item['Qty']}</Qty>"
                  "<Rate>${item['Rate']}</Rate>"
                  "<Amount>${item['Amount']}</Amount>"
                  "<GSTPer>${item['GSTPer']}</GSTPer>"
                  "<GSTAmt>${item['GSTAmt']}</GSTAmt>"
                  "<Total>${item['Total']}</Total>"
                  "</Item>";
            }).join();
            context.read<ItemBloc>().add(
              SubmitItem(
                userCode: "1",
                companyCode: "101",
                recNo: 1,
                complaintRecNo:
                (double.tryParse(GlobalData.selectedComplaintNo ?? '0')?.toInt()) ?? 0,
                date: widget.currentDate,
                slipNo: slipNo,
                grandTotal:
                _addedItems.fold(0.0, (sum, item) => sum + (double.tryParse(item['Total']) ?? 0)),
                itemDetails: "<Items>$itemDetails</Items>",
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No items to submit')),
            );
          }
        },
      ),
      const SizedBox(width: 16),
      _buildActionButton(
        icon: Icons.refresh,
        label: 'Reset All',
        color: Colors.red.shade600,
        onPressed: () {
          setState(() {
            _addedItems.clear();
            _clearForm();
          });
          context.read<ItemBloc>().add(FetchInitialItems());
        },
      ),
    ],
  );

  Widget _buildActionButton(
      {required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onPressed}) =>
      ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}

class _ShimmerLoader extends StatefulWidget {
  @override
  __ShimmerLoaderState createState() => __ShimmerLoaderState();
}

class __ShimmerLoaderState extends State<_ShimmerLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.2, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade200,
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => FractionallySizedBox(
          widthFactor: _animation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.blue.shade600.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }
}