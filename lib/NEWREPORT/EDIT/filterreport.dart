import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qualityapproach/NEWREPORT/EDIT/Mainreport.dart';
import '../../ReportUtils/subtleloader.dart';
import 'filterreportbloc.dart';

class FilterUI extends StatefulWidget {
  const FilterUI({super.key});

  @override
  State<FilterUI> createState() => _FilterUIState();
}

class _FilterUIState extends State<FilterUI> {
  DateTime? fromDate = DateTime(DateTime.now().year, 1, 1);
  DateTime? toDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? selectedReportId;
  String? selectedReportName;

  void _navigateToMainReport(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MainReport(
          fromDate: fromDate?.toString() ?? DateTime.now().toString(),
          toDate: toDate?.toString() ?? DateTime.now().toString(),
          fieldId: selectedReportId?.toString() ?? '',
          reportName: selectedReportName?.toString() ?? '', // Added report name
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FilterBloc()..add(FetchReportsEvent()),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue[800],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Custom Report',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 2,
        ),
        body: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey[100]!, Colors.white],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildReportDropdown(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      'From Date',
                      fromDate,
                          (date) => setState(() => fromDate = date),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildDateField(
                      'To Date',
                      toDate,
                          (date) => setState(() => toDate = date),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        fromDate = DateTime(DateTime.now().year, 1, 1);
                        toDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
                        selectedReportId = null;
                        selectedReportName = null;
                      });
                      context.read<FilterBloc>().add(ResetFilterEvent());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('Reset', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      context.read<FilterBloc>().add(SubmitFilterEvent(fromDate, toDate, selectedReportId));
                      _navigateToMainReport(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('Submit', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? selectedDate, Function(DateTime) onDateSelected) {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.blue[800]!,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onDateSelected(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 2, blurRadius: 5),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedDate != null ? DateFormat('dd-MMM-yyyy').format(selectedDate) : label,
              style: GoogleFonts.poppins(
                color: selectedDate != null ? Colors.black : Colors.grey[600],
                fontSize: 16,
              ),
            ),
            Icon(Icons.calendar_today, color: Colors.blue[800]),
          ],
        ),
      ),
    );
  }

  Widget _buildReportDropdown() {
    return BlocBuilder<FilterBloc, FilterState>(
      builder: (context, state) {
        if (state is FilterLoading) {
          return const SubtleLoader();
        } else if (state is FilterLoaded) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButton<String>(
              value: selectedReportId,
              isExpanded: true,
              hint: Text('Select Report', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16)),
              items: state.reports.map((report) {
                return DropdownMenuItem<String>(
                  value: report['FieldID'],
                  child: Text(
                    report['FieldName']!,
                    style: GoogleFonts.poppins(color: Colors.black, fontSize: 16),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedReportId = value;
                  // Find and set the selected report name
                  final selectedReport = state.reports.firstWhere(
                        (report) => report['FieldID'] == value,
                    orElse: () => {'FieldName': ''},
                  );
                  selectedReportName = selectedReport['FieldName'] as String?;
                });
              },
              underline: const SizedBox(),
              style: GoogleFonts.poppins(color: Colors.black, fontSize: 16),
              icon: Icon(Icons.arrow_drop_down, color: Colors.blue[800]),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 4,
            ),
          );
        } else if (state is FilterError) {
          return Text('Error: ${state.message}', style: GoogleFonts.poppins(color: Colors.red));
        }
        return const SizedBox();
      },
    );
  }
}