import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qualityapproach/SparePart/global.dart';
import 'dart:async';
import '../ReportUtils/subtleloader.dart';
import 'editsparedetailbloc.dart';
import 'dart:developer' as developer;

class EditSparePartDetailScreen extends StatelessWidget {
  const EditSparePartDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EditSparePartBloc()..add(FetchSparePartDetails()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Edit Spare Part Details',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<EditSparePartBloc>().add(FetchSparePartDetails()),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: BlocBuilder<EditSparePartBloc, EditSparePartState>(
            builder: (context, state) {
              developer.log('Main BlocBuilder state: ${state.runtimeType}');
              if (state is EditSparePartInitial || state is EditSparePartLoading) {
                return const Center(child: SubtleLoader());
              } else if (state is EditSparePartLoaded || state is EditSparePartSearchLoading) {
                final loadedState = state is EditSparePartLoaded
                    ? state
                    : EditSparePartLoaded(headerData: {}, items: [], slipNo: '');
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRequestInfoCard(context, loadedState.headerData),
                      const SizedBox(height: 24),
                      EditSparePartForm(
                        initialItems: loadedState.items,
                        currentDate: loadedState.headerData['EntryDate'] ?? 'N/A',
                        slipNo: loadedState.slipNo,
                      ),
                    ],
                  ),
                );
              } else if (state is EditSparePartError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(state.message),
                      ElevatedButton(
                        onPressed: () => context.read<EditSparePartBloc>().add(FetchSparePartDetails()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              } else if (state is EditSparePartSubmitted) {
                // Handle submission state without reloading UI
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (state.success) {
                    Navigator.pop(context); // Pop back to previous page on success
                  }
                });
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRequestInfoCard(context, state.headerData),
                      const SizedBox(height: 24),
                      EditSparePartForm(
                        initialItems: state.items,
                        currentDate: state.headerData['EntryDate'] ?? 'N/A',
                        slipNo: state.slipNo,
                      ),
                    ],
                  ),
                );
              }
              return const Center(child: Text('Unexpected state, please try again'));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRequestInfoCard(BuildContext context, Map<String, dynamic> headerData) {
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
                _buildDateField(headerData['EntryDate'] ?? 'N/A'),
                const SizedBox(width: 16),
                _buildSlipNoField(headerData['SlipNo'] ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildInfoField(
                    label: 'Complaint No',
                    value: headerData['ComplaintNo'] ?? '',
                    icon: Icons.receipt,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoField(
                    label: 'Mobile No',
                    value: headerData['CustomerMobileNo'] ?? '',
                    icon: Icons.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoField(
              label: 'Customer Name',
              value: headerData['CustomerName'] ?? '',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),
            _buildInfoField(
              label: 'Address',
              value: headerData['CustomerAddress'] ?? '',
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
      initialValue: slipNo,
      decoration: _inputDecoration('Slip No', Icons.confirmation_number),
      readOnly: true,
    ),
  );

  Widget _buildInfoField({required String label, required String value, required IconData icon}) =>
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

class EditSparePartForm extends StatefulWidget {
  final List<Map<String, dynamic>> initialItems;
  final String currentDate;
  final String slipNo;

  const EditSparePartForm({
    super.key,
    required this.initialItems,
    required this.currentDate,
    required this.slipNo,
  });

  @override
  _EditSparePartFormState createState() => _EditSparePartFormState();
}

class _EditSparePartFormState extends State<EditSparePartForm> with SingleTickerProviderStateMixin {
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
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _currentlyEditingIndex;

  @override
  void initState() {
    super.initState();
    _addedItems = List.from(widget.initialItems);
    _quantityController.addListener(_calculateTotal);
    _rateController.addListener(_calculateTotal);
    _gstPercentController.addListener(_calculateTotal);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
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
    _controller.dispose();
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
    developer.log('Search query changed: $query');
    setState(() => _isDropdownVisible = query.length >= 3);
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.length >= 3) {
        developer.log('Triggering search for query: $query');
        context.read<EditSparePartBloc>().add(SearchItems(query));
      } else {
        setState(() => _isDropdownVisible = false);
        if (_selectedItem != null) {
          _searchController.text = _selectedItem!['ItemName']?.toString() ?? '';
        }
        developer.log('Query too short, hiding dropdown');
      }
    });
  }

  void _updateItem() {
    if (_selectedItem != null) {
      setState(() {
        final newItem = {
          'ItemNo': _selectedItem!['ItemNo']?.toString() ?? _selectedItem!['FieldID']?.toString() ?? '',
          'ItemName': _selectedItem!['ItemName']?.toString() ?? _selectedItem!['FieldName']?.toString() ?? '',
          'OurItemNo': _selectedItem!['OurItemNo']?.toString() ?? '',
          'Qty': _quantityController.text.isNotEmpty ? _quantityController.text : _selectedItem!['Qty']?.toString() ?? '1',
          'Rate': _rateController.text.isNotEmpty ? _rateController.text : _selectedItem!['Rate']?.toString() ?? '0',
          'Amount': _amountController.text.isNotEmpty ? _amountController.text : _selectedItem!['Amount']?.toString() ?? '0',
          'GSTPer': _gstPercentController.text.isNotEmpty ? _gstPercentController.text : _selectedItem!['GSTPer']?.toString() ?? '18',
          'GSTAmt': _gstAmountController.text.isNotEmpty ? _gstAmountController.text : _selectedItem!['GSTAmt']?.toString() ?? '0',
          'Total': _totalController.text.isNotEmpty ? _totalController.text : _selectedItem!['Total']?.toString() ?? '0',
        };

        if (_currentlyEditingIndex != null) {
          developer.log('Before update - Item at index $_currentlyEditingIndex: ${_addedItems[_currentlyEditingIndex!]['ItemName']}');
          _addedItems[_currentlyEditingIndex!] = newItem;
          developer.log('Updated item at index $_currentlyEditingIndex: ${newItem['ItemName']}');
        } else {
          _addedItems.add(newItem);
          developer.log('Added new item: ${newItem['ItemName']}');
        }
        _clearForm();
        _currentlyEditingIndex = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an item first')),
      );
      developer.log('Attempted to update/add item with no selection');
    }
  }

  void _editItem(int index) {
    setState(() {
      final item = Map<String, dynamic>.from(_addedItems[index]);
      _selectedItem = item;
      _searchController.text = item['ItemName'] ?? '';
      _quantityController.text = item['Qty']?.toString() ?? '';
      _rateController.text = item['Rate']?.toString() ?? '';
      _amountController.text = item['Amount']?.toString() ?? '';
      _gstPercentController.text = item['GSTPer']?.toString() ?? '';
      _gstAmountController.text = item['GSTAmt']?.toString() ?? '';
      _totalController.text = item['Total']?.toString() ?? '';
      _currentlyEditingIndex = index;
      _isDropdownVisible = false;
      developer.log('Editing item at index $index: ${item['ItemName']}');
    });
  }

  void _deleteItem(int index) {
    setState(() {
      final item = _addedItems[index];
      _addedItems.removeAt(index);
      if (_currentlyEditingIndex == index) {
        _clearForm();
        _currentlyEditingIndex = null;
      }
      developer.log('Deleted item at index $index: ${item['ItemName']}');
    });
  }

  void _cancelEdit() {
    setState(() {
      _clearForm();
      _currentlyEditingIndex = null;
      developer.log('Cancelled editing');
    });
  }

  void _clearForm() {
    Future.delayed(const Duration(milliseconds: 50), () {
      _searchController.clear();
      _quantityController.clear();
      _rateController.clear();
      _amountController.clear();
      _gstPercentController.clear();
      _gstAmountController.clear();
      _totalController.clear();
      setState(() {
        _isDropdownVisible = false;
        _selectedItem = null;
      });
      developer.log('Form cleared');
    });
  }

  double _calculateGrandTotal() {
    return _addedItems.fold(0.0, (sum, item) => sum + (double.tryParse(item['Total'] ?? '0') ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EditSparePartBloc, EditSparePartState>(
      listener: (context, state) {
        developer.log('BlocListener state: ${state.runtimeType}');
        if (state is EditSparePartSubmitted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: state.success ? Colors.green : Colors.red,
                duration: const Duration(seconds: 2),
            ),
          );
          // Navigate back only on success after showing SnackBar
          if (state.success) {
            Future.delayed(const Duration(seconds: 2), () {
              Navigator.pop(context); // Navigate back after SnackBar
            });
          }
        }
      },
      child: BlocBuilder<EditSparePartBloc, EditSparePartState>(
        builder: (context, state) {
          final isItemsLoaded = state is EditSparePartLoaded && state.allItems.isNotEmpty;
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
                    'Edit Spare Part Details',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  isItemsLoaded
                      ? _buildSearchField(context)
                      : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SubtleLoader(),
                        const SizedBox(width: 16),
                        Text(
                          'Loading data...',
                          style: GoogleFonts.poppins(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (_isDropdownVisible && isItemsLoaded) _buildDropdown(context),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberInputField(
                            'Quantity', Icons.format_list_numbered, _quantityController),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildNumberInputField('Rate', Icons.currency_rupee, _rateController),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildActionButton(
                        icon: _currentlyEditingIndex != null ? Icons.update : Icons.add,
                        label: _currentlyEditingIndex != null ? 'Update Item' : 'Add Item',
                        color: Colors.blue.shade600,
                        onPressed: _updateItem,
                      ),
                      if (_currentlyEditingIndex != null) ...[
                        const SizedBox(width: 16),
                        _buildActionButton(
                          icon: Icons.cancel,
                          label: 'Cancel',
                          color: Colors.grey.shade600,
                          onPressed: _cancelEdit,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_addedItems.isNotEmpty) _buildItemsTable(),
                  const SizedBox(height: 24),
                  if (_addedItems.isNotEmpty) _buildSubmitResetButtons(context),
                ],
              ),
            ),
          );
        },
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
      suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
        icon: Icon(Icons.clear, size: 20, color: Colors.grey.shade600),
        onPressed: () {
          _searchController.clear();
          setState(() => _isDropdownVisible = false);
          if (_selectedItem != null) {
            _searchController.text = _selectedItem!['ItemName']?.toString() ?? '';
          }
          developer.log('Search cleared');
        },
      )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    onChanged: _onSearchChanged,
  );

  Widget _buildDropdown(BuildContext context) => BlocBuilder<EditSparePartBloc, EditSparePartState>(
    builder: (context, state) {
      developer.log('Dropdown BlocBuilder state: ${state.runtimeType}');
      if (state is EditSparePartSearchLoading) {
        developer.log('Showing search loading shimmer');
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: _ShimmerLoader(),
        );
      } else if (state is EditSparePartLoaded) {
        final searchResults = state.searchResults;
        if (searchResults.isNotEmpty) {
          developer.log('Showing ${searchResults.length} search results');
          return Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 8.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: searchResults.length > 10 ? 10 : searchResults.length,
              itemBuilder: (context, index) {
                final item = searchResults[index];
                final fieldName = item['FieldName']?.toString() ?? 'Unnamed Item';
                final fieldId = item['FieldID']?.toString() ?? 'N/A';
                final ourItemNo = item['OurItemNo']?.toString() ?? 'N/A';
                final rate = item['Rate']?.toString() ?? 'N/A';
                return ListTile(
                  title: Text(
                    '$fieldName (ID: $fieldId)',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  subtitle: Text(
                    'OurItemNo: $ourItemNo | Rate: $rate',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  dense: true,
                  onTap: () {
                    setState(() {
                      _selectedItem = Map.from(item);
                      _searchController.text = fieldName;
                      _rateController.text = rate != 'N/A' ? rate : '';
                      _quantityController.text =
                      _quantityController.text.isEmpty ? '1' : _quantityController.text;
                      _gstPercentController.text = item['GST']?.toString() ?? '18';
                      _selectedItem!['OurItemNo'] = ourItemNo;
                      _isDropdownVisible = false;
                      _calculateTotal();
                      developer.log('Selected item: $fieldName');
                    });
                  },
                );
              },
            ),
          );
        } else {
          developer.log('No search results');
          return const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text('No results found', style: TextStyle(color: Colors.grey)),
          );
        }
      }
      developer.log('Dropdown default case');
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
                label:
                Text('GST Amt', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
            DataColumn(
                label:
                Text('Actions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          ],
          rows: [
            ..._addedItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              developer.log('Table item at index $index: ItemName = ${item['ItemName']}');
              return DataRow(cells: [
                DataCell(Text(item['ItemName'] ?? 'N/A', style: GoogleFonts.poppins())),
                DataCell(Text(
                    (double.tryParse(item['Qty'] ?? '0') ?? 0).toStringAsFixed(2),
                    style: GoogleFonts.poppins())),
                DataCell(Text(
                    (double.tryParse(item['Rate'] ?? '0') ?? 0).toStringAsFixed(2),
                    style: GoogleFonts.poppins())),
                DataCell(Text(
                    (double.tryParse(item['Amount'] ?? '0') ?? 0).toStringAsFixed(2),
                    style: GoogleFonts.poppins())),
                DataCell(Text(
                    (double.tryParse(item['GSTPer'] ?? '0') ?? 0).toStringAsFixed(2),
                    style: GoogleFonts.poppins())),
                DataCell(Text(
                    (double.tryParse(item['GSTAmt'] ?? '0') ?? 0).toStringAsFixed(2),
                    style: GoogleFonts.poppins())),
                DataCell(Text(
                    (double.tryParse(item['Total'] ?? '0') ?? 0).toStringAsFixed(2),
                    style: GoogleFonts.poppins())),
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
            DataRow(cells: [
              DataCell(
                  Text('Grand Total', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text(_calculateGrandTotal().toStringAsFixed(2),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
              DataCell(Text('')),
            ]),
          ],
        ),
      ),
    ],
  );

  Widget _buildSubmitResetButtons(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _buildActionButton(
        icon: Icons.check,
        label: 'Update All',
        color: Colors.green.shade600,
        onPressed: () {
          if (_addedItems.isNotEmpty) {
            String itemDetails = _addedItems.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              return "<InsertLine>"
                  "<SNo>$index</SNo>"
                  "<ItemNo>${item['ItemNo']}</ItemNo>"
                  "<OurItemNo>${item['OurItemNo']}</OurItemNo>"
                  "<ItemName>${item['ItemName']}</ItemName>"
                  "<Qty>${item['Qty']}</Qty>"
                  "<Rate>${item['Rate']}</Rate>"
                  "<Amount>${item['Amount']}</Amount>"
                  "<GSTPer>${item['GSTPer']}</GSTPer>"
                  "<GSTAmt>${item['GSTAmt']}</GSTAmt>"
                  "<Total>${item['Total']}</Total>"
                  "</InsertLine>";
            }).join();

            final recNoStr = GlobalData.selectedRecNo ?? '2';
            final recNo = double.tryParse(recNoStr)?.toInt() ?? int.parse(recNoStr.split('.')[0]);
            final complaintRecNoStr = GlobalData.selectedComplaintNo ?? '0';
            final complaintRecNo =
                double.tryParse(complaintRecNoStr)?.toInt() ?? int.parse(complaintRecNoStr.split('.')[0]);

            context.read<EditSparePartBloc>().add(
              SubmitEditedSparePart(
                userCode: "1",
                companyCode: "101",
                recNo: recNo,
                complaintRecNo: complaintRecNo,
                date: widget.currentDate,
                slipNo: widget.slipNo,
                grandTotal: _calculateGrandTotal(),
                itemDetails: "<ROOT>$itemDetails</ROOT>",
              ),
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
            _currentlyEditingIndex = null;
          });
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
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}

class _ShimmerLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Colors.grey.shade200,
      ),
      child: AnimatedBuilder(
        animation: AnimationController(
          duration: const Duration(milliseconds: 800),
          vsync: Navigator.of(context),
        )..repeat(reverse: true),
        builder: (context, child) => FractionallySizedBox(
          widthFactor: Tween<double>(begin: 0.3, end: 0.7)
              .animate(CurvedAnimation(
            parent: AnimationController(
              duration: const Duration(milliseconds: 800),
              vsync: Navigator.of(context),
            )..repeat(reverse: true),
            curve: Curves.easeInOut,
          ))
              .value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: Colors.blue.shade400.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }
}