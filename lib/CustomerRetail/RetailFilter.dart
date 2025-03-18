import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:intl/intl.dart';

import 'RetailBloc.dart';

class RetailCustomerPage extends StatefulWidget {
  @override
  _RetailCustomerPageState createState() => _RetailCustomerPageState();
}

class _RetailCustomerPageState extends State<RetailCustomerPage> {
  String UserCode ='1';
  String CompanyCode ='101';
  String str = 'eTFKdGFqMG5ibWN0NGJ4ekIxUG8zbzRrNXZFbGQxaW96dHpteFFQdEdWREN5L1FKTW5NNXN3c3l3dDRiNXczOGVBMmhDb3kxUjJRT1RTdmhyV2Y2clE9PQ==';
  DateTime? fromDate;
  DateTime? toDate;
  final DateFormat formatter = DateFormat('dd-MMM-yyyy');
  late RetailCustomerBloc _bloc;

  final List<PlutoColumn> columns = [
    PlutoColumn(title: 'Customer Name', field: 'CustomerName', type: PlutoColumnType.text(), width: 300),
    PlutoColumn(title: 'Contact Person', field: 'ContactPerson', type: PlutoColumnType.text(), width: 170),
    PlutoColumn(title: 'Mobile No', field: 'CustomerMobileNo', type: PlutoColumnType.text(), width: 130),
    PlutoColumn(title: 'Email', field: 'CustomerEmailID', type: PlutoColumnType.text(), width: 200),
    PlutoColumn(title: 'Address', field: 'CustomerAddress', type: PlutoColumnType.text(), width: 300),
    PlutoColumn(title: 'State', field: 'StateName', type: PlutoColumnType.text(), width: 120),
    PlutoColumn(title: 'City', field: 'CityName', type: PlutoColumnType.text(), width: 120),
    PlutoColumn(title: 'Pin Code', field: 'PinCode', type: PlutoColumnType.text(), width: 150),
  ];

  @override
  void initState() {
    super.initState();
    _bloc = RetailCustomerBloc();
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2026),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
    }
  }

  void _resetDates() {
    setState(() {
      fromDate = null;
      toDate = null;
    });
    _bloc.add(ClearRetailCustomers()); // Add an event to clear the data
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Customer Report',
            style: TextStyle(color: Colors.white),
          ),
          elevation: 2,
          backgroundColor: Colors.blue, // Changed AppBar color to blue
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filter Card
              Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'From Date',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                suffixIcon: Icon(Icons.calendar_today, color: Colors.blue),
                                filled: true,
                                fillColor: Colors.blue[50],
                              ),
                              controller: TextEditingController(
                                text: fromDate != null ? formatter.format(fromDate!) : '',
                              ),
                              onTap: () => _selectDate(context, true),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'To Date',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                suffixIcon: Icon(Icons.calendar_today, color: Colors.blue),
                                filled: true,
                                fillColor: Colors.blue[50],
                              ),
                              controller: TextEditingController(
                                text: toDate != null ? formatter.format(toDate!) : '',
                              ),
                              onTap: () => _selectDate(context, false),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Centered Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            ),
                            onPressed: () {
                              if (fromDate != null && toDate != null) {
                                final fromDateStr = formatter.format(fromDate!);
                                final toDateStr = formatter.format(toDate!);
                                _bloc.add(FetchRetailCustomers(UserCode,CompanyCode,str,fromDateStr, toDateStr));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Please select both dates')),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Icon(Icons.arrow_forward, color: Colors.white), // Added icon
                                SizedBox(width: 8),
                                Text(
                                  'Show',
                                  style: TextStyle(fontSize: 16, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            ),
                            onPressed: _resetDates,
                            child: Row(
                              children: [
                                Icon(Icons.close, color: Colors.white), // Reset icon
                                SizedBox(width: 8),
                                Text(
                                  'Reset',
                                  style: TextStyle(fontSize: 16, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              // Report Card
              Expanded(
                child: Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: BlocConsumer<RetailCustomerBloc, RetailCustomerState>(
                      bloc: _bloc,
                      listener: (context, state) {
                        if (state is RetailCustomerError) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(state.message)),
                          );
                        }
                      },
                      builder: (context, state) {
                        if (state is RetailCustomerLoading) {
                          return Center(child: CircularProgressIndicator());
                        } else if (state is RetailCustomerLoaded) {
                          return PlutoGrid(
                            columns: columns,
                            rows: state.customers.map((customer) {
                              return PlutoRow(
                                cells: {
                                  'CustomerName': PlutoCell(value: customer['CustomerName'] ?? ''),
                                  'ContactPerson': PlutoCell(value: customer['ContactPerson'] ?? ''),
                                  'CustomerMobileNo': PlutoCell(value: customer['CustomerMobileNo'] ?? ''),
                                  'CustomerEmailID': PlutoCell(value: customer['CustomerEmailID'] ?? ''),
                                  'CustomerAddress': PlutoCell(value: customer['CustomerAddress'] ?? ''),
                                  'StateName': PlutoCell(value: customer['StateName'] ?? ''),
                                  'CityName': PlutoCell(value: customer['CityName'] ?? ''),
                                  'PinCode': PlutoCell(value: customer['PinCode'] ?? ''),
                                },
                              );
                            }).toList(),
                            configuration: PlutoGridConfiguration(
                              style: PlutoGridStyleConfig(
                                gridBorderRadius: BorderRadius.circular(12),
                                gridBackgroundColor: Colors.white,
                                cellTextStyle: TextStyle(color: Colors.blueGrey[900]),
                                columnTextStyle: TextStyle(color: Colors.blueGrey[900]),
                              ),
                            ),
                          );
                        }  else if (state is RetailCustomerNoData) {
                          return Center(child: Text('No data found')); // Display no data message
                        }else if (state is RetailCustomerError) {
                          return Center(child: Text(state.message));
                        }
                        return Center(child: Text('Select dates to view report'));
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }
}