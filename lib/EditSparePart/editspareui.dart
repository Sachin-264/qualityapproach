import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:developer' as developer;

import 'package:qualityapproach/SparePart/SpareDetail_UI.dart';
import '../ReportUtils/Appbar.dart';
import '../ReportUtils/subtleloader.dart';
import '../SparePart/global.dart';
import 'editsparebloc.dart';
import 'editsparedetailUI.dart';

class EditSpareScreen extends StatefulWidget {
  const EditSpareScreen({super.key});

  @override
  _EditSpareScreenState createState() => _EditSpareScreenState();
}

class _EditSpareScreenState extends State<EditSpareScreen> {
  final EditSpareBloc _EditSpareBloc = EditSpareBloc();
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now().subtract(const Duration(days: 7));
    _toDate = DateTime.now();
    _fromDateController.text = DateFormat('dd-MMM-yyyy').format(_fromDate!);
    _toDateController.text = DateFormat('dd-MMM-yyyy').format(_toDate!);
    developer.log('EditSpareScreen initialized', name: 'EditSpareScreen');
  }

  @override
  void dispose() {
    _EditSpareBloc.close();
    _fromDateController.dispose();
    _toDateController.dispose();
    developer.log('EditSpareScreen disposed', name: 'EditSpareScreen');
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    developer.log('Date selection initiated (isFromDate: $isFromDate)',
        name: 'EditSpareScreen');

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate! : _toDate!,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          _fromDateController.text = DateFormat('dd-MMM-yyyy').format(picked);
          developer.log('From date updated to: ${_fromDateController.text}',
              name: 'EditSpareScreen');
        } else {
          _toDate = picked;
          _toDateController.text = DateFormat('dd-MMM-yyyy').format(picked);
          developer.log('To date updated to: ${_toDateController.text}',
              name: 'EditSpareScreen');
        }
      });
    }
  }

  void _resetDates() {
    developer.log('Resetting dates to default', name: 'EditSpareScreen');
    setState(() {
      _fromDate = DateTime.now().subtract(const Duration(days: 7));
      _toDate = DateTime.now();
      _fromDateController.text = DateFormat('dd-MMM-yyyy').format(_fromDate!);
      _toDateController.text = DateFormat('dd-MMM-yyyy').format(_toDate!);
    });
  }

  void _submit() {
    if (_fromDate != null && _toDate != null) {
      developer.log('Submitting search with dates: ${_fromDateController.text} to ${_toDateController.text}',
          name: 'EditSpareScreen');
      _EditSpareBloc.add(LoadEditSpares(
        userCode: '1',
        companyCode: '101',
        fromDate: _fromDateController.text,
        toDate: _toDateController.text,
      ));
    } else {
      developer.log('Submit attempted with null dates', name: 'EditSpareScreen');
    }
  }

  void _deleteEditSpare(String recNo) {
    developer.log('Initiating delete for record: $recNo', name: 'EditSpareScreen');

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete', style: GoogleFonts.poppins()),
          content: Text('Are you sure you want to delete this spare part?',
              style: GoogleFonts.poppins()),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.blue.shade700)),
              onPressed: () {
                developer.log('Delete operation cancelled by user', name: 'EditSpareScreen');
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
              onPressed: () {
                developer.log('User confirmed delete for record: $recNo', name: 'EditSpareScreen');
                Navigator.of(context).pop();
                _EditSpareBloc.add(DeleteEditSpare(
                  userCode: '1',
                  companyCode: '101',
                  recNo: recNo,
                ));
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToDetailScreen(Map<String, dynamic> selectedPart) {
    developer.log('Navigating to detail screen for record: ${selectedPart['RecNo']}',
        name: 'EditSpareScreen');

    GlobalData.selectedCustomerName = selectedPart['CustomerName'] ?? '';
    GlobalData.selectedAddress = selectedPart['CustomerAddress'] ?? '';
    GlobalData.selectedMobileNo = selectedPart['CustomerMobileNo'] ?? '';
    GlobalData.selectedComplaintNo = selectedPart['ComplaintNo']?.toString() ?? '';
    GlobalData.selectedRecNo = selectedPart['RecNo']?.toString() ?? '';

    developer.log('Global data updated for navigation', name: 'EditSpareScreen');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSparePartDetailScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBarWidget(
        title: 'Edit Spare Parts',
        onBackPress: () => Navigator.pop(context),
      ),
      body: BlocProvider(
        create: (context) => _EditSpareBloc,
        child: BlocListener<EditSpareBloc, EditSpareState>(
          listener: (context, state) {
            if (state is EditSpareDeleted) {
              developer.log('Spare part deleted successfully', name: 'EditSpareScreen');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Spare part deleted successfully',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
              _submit();
            } else if (state is EditSpareError) {
              developer.log('Error occurred: ${state.message}', name: 'EditSpareScreen');
            }
          },
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFiltersCard(),
                  const SizedBox(height: 20),
                  _buildTableCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context, true),
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _fromDateController,
                        decoration: InputDecoration(
                          labelText: 'From Date',
                          labelStyle:
                          GoogleFonts.poppins(color: Colors.blue.shade700),
                          prefixIcon: Icon(Icons.calendar_today,
                              color: Colors.blue.shade700),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context, false),
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _toDateController,
                        decoration: InputDecoration(
                          labelText: 'To Date',
                          labelStyle:
                          GoogleFonts.poppins(color: Colors.blue.shade700),
                          prefixIcon: Icon(Icons.calendar_today,
                              color: Colors.blue.shade700),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _resetDates,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Reset',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Search',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: BlocBuilder<EditSpareBloc, EditSpareState>(
          builder: (context, state) {
            if (state is EditSpareLoading) {
              return const Center(child: SubtleLoader());
            } else if (state is EditSpareError) {
              return Center(
                child: Text(
                  state.message,
                  style: GoogleFonts.poppins(
                      color: Colors.red.shade700, fontSize: 16),
                ),
              );
            } else if (state is EditSpareLoaded) {
              return _buildEditSparesTable(state.EditSpares);
            }
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.grey.shade400, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Select date range and click Search',
                    style: GoogleFonts.poppins(
                        color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEditSparesTable(List<dynamic> EditSpares) {
    developer.log('Building table with ${EditSpares.length} items', name: 'EditSpareScreen');

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
              dataRowColor: MaterialStateProperty.all(Colors.white),
              columnSpacing: 20,
              horizontalMargin: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              columns: [
                DataColumn(
                  label: Text(
                    'S.No',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Complaint RecNo',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Customer Name',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                  ),
                ),
              ],
              rows: EditSpares.map((part) {
                return DataRow(
                  cells: [
                    DataCell(Text(part['SNo'] ?? '',
                        style: GoogleFonts.poppins())),
                    DataCell(Text(part['RecNo']?.toString() ?? '',
                        style: GoogleFonts.poppins())),
                    DataCell(Text(part['CustomerName'] ?? '',
                        style: GoogleFonts.poppins())),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: 'Edit',
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _navigateToDetailScreen(part),
                            ),
                          ),
                          Tooltip(
                            message: 'Delete',
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                developer.log('Delete button pressed for record: ${part['RecNo']}',
                                    name: 'EditSpareScreen');
                                _deleteEditSpare(part['RecNo']?.toString() ?? '');
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}