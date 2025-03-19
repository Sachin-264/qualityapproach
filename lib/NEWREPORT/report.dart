import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'report_bloc.dart';

class ReportPage extends StatefulWidget {
  final String userCode = '1';
  final String companyCode = '101';
  final String recNo = '0';

  const ReportPage({Key? key}) : super(key: key);

  @override
  _ReportPageState createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TextEditingController _reportNameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<TextEditingController> _nameControllers;

  @override
  void initState() {
    super.initState();
    _nameControllers = [];
    context.read<ReportBloc>().add(FetchReportData(widget.userCode, widget.companyCode, widget.recNo));
  }

  @override
  void dispose() {
    _reportNameController.dispose();
    _scrollController.dispose();
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900,
        elevation: 6,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Report Page',
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4, // Reverted to original elevation
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Reverted to original radius
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Report Name:',
                      style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87), // Reverted to original weight
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _reportNameController,
                        decoration: InputDecoration(
                          hintText: 'Enter report name',
                          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue.shade700),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: GoogleFonts.roboto(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Card(
                elevation: 10,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BlocConsumer<ReportBloc, ReportState>(
                    listener: (context, state) {
                      if (state.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(state.error!), backgroundColor: Colors.redAccent),
                        );
                      }
                      if (state.columns.isNotEmpty && _nameControllers.isEmpty) {
                        _nameControllers = state.columns
                            .map((column) => TextEditingController(text: column.columnHeading))
                            .toList();
                      }
                    },
                    builder: (context, state) {
                      if (state.isLoading) {
                        return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)));
                      }
                      if (state.error != null) {
                        return Center(child: Text(state.error!, style: GoogleFonts.roboto(color: Colors.red, fontSize: 16)));
                      }
                      if (state.columns.isEmpty) {
                        return Center(child: Text('No data to display', style: GoogleFonts.roboto(fontSize: 16)));
                      }
                      return Column(
                        children: [
                          Expanded(
                            child: Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                scrollDirection: Axis.vertical,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: DataTable(
                                    columnSpacing: 40,
                                    dataRowHeight: 70,
                                    headingRowHeight: 64,
                                    headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                                    border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1)),
                                    columns: [
                                      DataColumn(label: Text('Name', style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey))),
                                      DataColumn(label: Text('Show Menu', style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey))),
                                    ],
                                    rows: List.generate(
                                      state.columns.length,
                                          (index) => DataRow(
                                        cells: [
                                          DataCell(
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.grey.withOpacity(0.15),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: TextField(
                                                controller: _nameControllers[index],
                                                decoration: InputDecoration(
                                                  hintText: 'Column Name',
                                                  hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    borderSide: BorderSide(color: Colors.blue.shade900, width: 1.5),
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.grey.shade100,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                ),
                                                style: GoogleFonts.roboto(fontSize: 14, color: Colors.black87),
                                                onChanged: (value) {
                                                  context.read<ReportBloc>().add(UpdateColumnName(index, value));
                                                },
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Checkbox(
                                              value: state.columns[index].isVisible == 'Y',
                                              onChanged: (value) {
                                                context.read<ReportBloc>().add(UpdateColumnVisibility(index, value!));
                                              },
                                              activeColor: Colors.blue.shade900,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  final reportName = _reportNameController.text.trim();
                                  if (reportName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Please enter a report name'), backgroundColor: Colors.redAccent),
                                    );
                                    return;
                                  }
                                  context.read<ReportBloc>().add(SubmitReport(reportName, widget.userCode, widget.companyCode, widget.recNo));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Report submitted successfully'), backgroundColor: Colors.green),
                                  );
                                },
                                icon: Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                label: Text('Submit', style: GoogleFonts.roboto(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade900,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 6,
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Resetting report...'), duration: Duration(milliseconds: 800), backgroundColor: Colors.blue.shade900),
                                  );
                                  context.read<ReportBloc>().add(ResetReport());
                                  for (var i = 0; i < _nameControllers.length; i++) {
                                    _nameControllers[i].text = state.columns[i].columnHeading;
                                  }
                                },
                                icon: Icon(Icons.refresh, color: Colors.white, size: 20),
                                label: Text('Reset', style: GoogleFonts.roboto(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 6,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}