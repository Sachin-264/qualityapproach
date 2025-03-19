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

  @override
  void initState() {
    super.initState();
    context.read<ReportBloc>().add(FetchReportData(widget.userCode, widget.companyCode, widget.recNo));
  }

  @override
  void dispose() {
    _reportNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        elevation: 4,
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
              elevation: 4,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Report Name:',
                      style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
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
                elevation: 6,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BlocConsumer<ReportBloc, ReportState>(
                    listener: (context, state) {
                      if (state.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(state.error!), backgroundColor: Colors.redAccent),
                        );
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
                      return Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.vertical,
                          child: SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              columnSpacing: 40,
                              dataRowHeight: 60,
                              headingRowHeight: 64,
                              headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                              border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade300, width: 1)),
                              columns: [
                                DataColumn(label: Text('Name', style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey))),
                                DataColumn(label: Text('Show Menu', style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey))),
                              ],
                              rows: List.generate(
                                state.columns.length,
                                    (index) => DataRow(
                                  cells: [
                                    DataCell(Text(state.columns[index].columnHeading, style: GoogleFonts.roboto(fontSize: 14, color: Colors.black87))),
                                    DataCell(
                                      Checkbox(
                                        value: state.columns[index].isVisible == 'Y',
                                        onChanged: (value) {
                                          context.read<ReportBloc>().add(UpdateColumnVisibility(index, value!));
                                        },
                                        activeColor: Colors.blue.shade700,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
                    // Show success message only after successful submission
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Report submitted successfully'), backgroundColor: Colors.green),
                    );
                  },
                  icon: Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  label: Text('Submit', style: GoogleFonts.roboto(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Resetting report...'), duration: Duration(milliseconds: 800), backgroundColor: Colors.blue.shade700),
                    );
                    context.read<ReportBloc>().add(ResetReport());
                  },
                  icon: Icon(Icons.refresh, color: Colors.white, size: 20),
                  label: Text('Reset', style: GoogleFonts.roboto(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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