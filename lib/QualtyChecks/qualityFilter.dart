import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:qualityapproach/QualtyChecks/MRNpage.dart';
import 'package:qualityapproach/QualtyChecks/qualityFilterbloc.dart';

class QualityFilterPage extends StatefulWidget {
  @override
  _QualityFilterPageState createState() => _QualityFilterPageState();
}

class _QualityFilterPageState extends State<QualityFilterPage> {
  Branch? selectedBranch;
  String BranchCode = '';
  DateTime fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime toDate = DateTime.now();
  String status = "Y"; // "Y" for Pending, "N" for Complete

  @override
  void initState() {
    super.initState();
    BlocProvider.of<BranchBloc>(context).add(FetchBranches());
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    DateTime initialDate = isFromDate ? fromDate : toDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Quality Filter", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: () {
              // Handle + icon action
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branch Dropdown
            Text("Select Branch",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            BlocBuilder<BranchBloc, BranchState>(
              builder: (context, state) {
                if (state is BranchLoading) {
                  return Center(child: CircularProgressIndicator());
                } else if (state is BranchLoaded) {
                  if (selectedBranch == null ||
                      !state.branches.contains(selectedBranch)) {
                    selectedBranch =
                        state.branches.isNotEmpty ? state.branches.first : null;
                  }

                  return DropdownButton<Branch>(
                    isExpanded: true,
                    value: selectedBranch, // Ensure this is in the list
                    items: state.branches.map((Branch branch) {
                      return DropdownMenuItem<Branch>(
                        value: branch,
                        child: Text(branch.fieldName),
                      );
                    }).toList(),
                    onChanged: (Branch? newValue) {
                      setState(() {
                        selectedBranch = newValue;
                      });
                    },
                  );
                } else {
                  return Text("Failed to load branches");
                }
              },
            ),

            SizedBox(height: 20),

            // From Date & To Date
            // From Date & To Date
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("From Date",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey, width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(DateFormat('dd-MMM-yyyy').format(fromDate),
                                  style: TextStyle(fontSize: 16)),
                              Spacer(),
                              Icon(Icons.calendar_today,
                                  size: 20, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("To Date",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey, width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(DateFormat('dd-MMM-yyyy').format(toDate),
                                  style: TextStyle(fontSize: 16)),
                              Spacer(),
                              Icon(Icons.calendar_today,
                                  size: 20, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Radio Buttons for Pending/Complete
            Row(
              children: [
                Radio(
                  value: "Y",
                  groupValue: status,
                  onChanged: (value) {
                    setState(() {
                      status = value.toString();
                    });
                  },
                ),
                Text("Pending"),
                SizedBox(width: 20),
                Radio(
                  value: "N",
                  groupValue: status,
                  onChanged: (value) {
                    setState(() {
                      status = value.toString();
                    });
                  },
                ),
                Text("Complete"),
              ],
            ),

            SizedBox(height: 20),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    setState(() {
                      selectedBranch = null;
                      fromDate = DateTime(
                          DateTime.now().year, DateTime.now().month, 1);
                      toDate = DateTime.now();
                      status = "Y";
                    });
                  },
                  child: Row(
                    children: [
                      Icon(Icons.close,
                          color: Colors.white, size: 20), // Cross icon
                      SizedBox(width: 8), // Spacing between icon and text
                      Text("Reset", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () {
                    // Navigate to next screen
                    log('Branch Code: ${selectedBranch?.fieldID}');
                    log('From Date: ${DateFormat('y-MM-dd').format(fromDate)}');
                    log('To Date: ${DateFormat('yyyy-MM-dd').format(toDate)}');
                    log('Status: $status');

                    // If you want to stay on the current page, you can skip navigation
                    // Otherwise, if you still want to navigate to a new page, use the code below

                    // Uncomment the following if you still want to navigate to another page
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => MRNReportPage(
                                  branchCode: selectedBranch!.fieldID,
                                  fromDate:
                                      DateFormat('dd-MM-yyyy').format(fromDate),
                                  toDate:
                                      DateFormat('dd-MM-yyyy').format(toDate),
                                  pending: status,
                                )));
                  },
                  child: Row(
                    children: [
                      Icon(Icons.arrow_forward,
                          color: Colors.white, size: 20), // Cross icon
                      SizedBox(width: 8), // Spacing between icon and text
                      Text("Show", style: TextStyle(color: Colors.white)),
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
}
