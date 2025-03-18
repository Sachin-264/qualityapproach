import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'report_bloc.dart';

class ReportPage extends StatelessWidget {
  final String userCode = '1';
  final String companyCode = '101';
  final String recNo = '0';

  ReportPage({Key? key}) : super(key: key);

  final TextEditingController _reportNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportBloc()
        ..add(FetchReportData(userCode, companyCode, recNo)),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          elevation: 4,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Report Page',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.white,
            ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Report Name:',
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _reportNameController,
                          decoration: InputDecoration(
                            hintText: 'Enter report name',
                            hintStyle: GoogleFonts.roboto(
                              color: Colors.grey.shade600,
                            ),
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: GoogleFonts.roboto(fontSize: 16),
                          onChanged: (value) {
                            // Add logic to store in BLoC if needed
                          },
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: BlocBuilder<ReportBloc, ReportState>(
                      builder: (context, state) {
                        if (state.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          );
                        }
                        if (state.error != null) {
                          return Center(
                            child: Text(
                              state.error!,
                              style: GoogleFonts.roboto(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }
                        return Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                columnSpacing: 40,
                                dataRowHeight: 60,
                                headingRowHeight: 64,
                                headingRowColor: MaterialStateProperty.all(
                                  Colors.blue.shade50,
                                ),
                                border: TableBorder(
                                  horizontalInside: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'Name',
                                      style: GoogleFonts.roboto(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Show Menu',
                                      style: GoogleFonts.roboto(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: List.generate(
                                  state.columns.length,
                                      (index) => DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          state.columns[index].columnHeading,
                                          style: GoogleFonts.roboto(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Checkbox(
                                          value: state.columns[index].isVisible,
                                          onChanged: (value) {
                                            context.read<ReportBloc>().add(
                                              UpdateColumnVisibility(
                                                  index, value!),
                                            );
                                          },
                                          activeColor: Colors.blue.shade700,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
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
                      // Add submit logic here
                    },
                    icon: Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    label: Text(
                      'Submit',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Show brief loading indicator
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Resetting report...'),
                          duration: Duration(milliseconds: 800),
                          backgroundColor: Colors.blue.shade700,
                        ),
                      );

                      // Navigate with a fade transition after a short delay
                      Future.delayed(Duration(milliseconds: 300), () {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => ReportPage(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            transitionDuration: Duration(milliseconds: 500),
                          ),
                        );
                      });
                    },
                    icon: Icon(Icons.refresh, color: Colors.white, size: 20),
                    label: Text(
                      'Reset',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}