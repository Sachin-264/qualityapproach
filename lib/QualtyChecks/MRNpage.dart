import 'dart:developer'; // For logging

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:excel/excel.dart'; // For Excel export
import 'package:pdf/pdf.dart'; // For PDF export
import 'package:pdf/widgets.dart' as pw; // For PDF export
import 'package:path_provider/path_provider.dart'; // For file storage
import 'package:qualityapproach/QualtyChecks/MRNDetail.dart';
import 'dart:io'; // For file operations
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

import 'package:qualityapproach/QualtyChecks/MRNbloc.dart'; // For HTML operations

class MRNReportPage extends StatelessWidget {
  final String branchCode;
  final String fromDate;
  final String toDate;
  final String pending;

  const MRNReportPage({
    required this.branchCode,
    required this.fromDate,
    required this.toDate,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MRNReportBloc()
        ..add(FetchMRNReport(
          branchCode: branchCode,
          fromDate: fromDate,
          toDate: toDate,
          pending: pending,
        )),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'MRN Report Filter',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.blue,
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Row(
                children: [
                  Icon(Icons.arrow_back_ios, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Back',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Export buttons
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BlocBuilder<MRNReportBloc, MRNReportState>(
                    builder: (context, state) {
                      return ElevatedButton(
                        onPressed: state is MRNReportLoaded
                            ? () => _exportToExcel(context, state.reports)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: state is MRNReportLoaded
                              ? Colors.green
                              : Colors.grey,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                        child: const Text(
                          'Export to Excel',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  BlocBuilder<MRNReportBloc, MRNReportState>(
                    builder: (context, state) {
                      return ElevatedButton(
                        onPressed: state is MRNReportLoaded
                            ? () => _exportToPDF(context, state.reports)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: state is MRNReportLoaded
                              ? Colors.red
                              : Colors.grey,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                        child: const Text(
                          'Export to PDF',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: MRNReportGrid(
                  branchCode: branchCode), // This will take the remaining space
            ),
          ],
        ),
      ),
    );
  }

  // Export to Excel logic
  Future<void> _exportToExcel(
      BuildContext context, List<Map<String, dynamic>> reports) async {
    try {
      var excel = Excel.createExcel();
      excel.delete('flutter'); // Remove the default "flutter" sheet
      var sheet = excel['Sheet1'];

      // Add headers
      sheet.appendRow([
        'MRN No',
        'MRN Date',
        'Vendor Name',
        'Our Item Code',
        'Item Name',
        'Quantity',
        'Status',
      ].map((header) => TextCellValue(header)).toList());

      // Add data rows
      for (var report in reports) {
        sheet.appendRow([
          report['MRN No']?.toString() ?? 'N/A',
          report['MRN Date']?.toString() ?? 'N/A',
          report['Vendor Name']?.toString() ?? 'N/A',
          report['Our Item Code']?.toString() ?? 'N/A',
          report['Item Name']?.toString() ?? 'N/A',
          report['Quantity']?.toString() ?? 'N/A',
          report['status']?.toString() ?? 'N/A',
        ].map((value) => TextCellValue(value)).toList());
      }

      // Save the file
      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/MRN_report.xlsx');
        await file.writeAsBytes(fileBytes);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exported to Excel successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to Excel: $e')),
      );
    }
  }

  // Export to PDF logic
  Future<void> _exportToPDF(
      BuildContext context, List<Map<String, dynamic>> reports) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Text(
                  'MRN Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: [
                    'MRN No',
                    'MRN Date',
                    'Vendor Name',
                    'Our Item Code',
                    'Item Name',
                    'Quantity',
                    'Status',
                  ],
                  data: reports.map((report) {
                    return [
                      report['MRN No']?.toString() ?? 'N/A',
                      report['MRN Date']?.toString() ?? 'N/A',
                      report['Vendor Name']?.toString() ?? 'N/A',
                      report['Our Item Code']?.toString() ?? 'N/A',
                      report['Item Name']?.toString() ?? 'N/A',
                      report['Quantity']?.toString() ?? 'N/A',
                      report['status']?.toString() ?? 'N/A',
                    ];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();

      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "MRN_report.pdf")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = io.File('${directory.path}/MRN_report.pdf');
        await file.writeAsBytes(pdfBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF saved successfully!')),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported to PDF successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to PDF: $e')),
      );
    }
  }
}

class MRNReportGrid extends StatelessWidget {
  final String branchCode;

  const MRNReportGrid({required this.branchCode, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MRNReportBloc, MRNReportState>(
      builder: (context, state) {
        log('Current state in MRNReportGrid: $state');
        if (state is MRNReportLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is MRNReportError) {
          return Center(child: Text(state.message));
        } else if (state is MRNReportLoaded) {
          log('Reports data in MRNReportGrid: ${state.reports}');

          return PlutoGrid(
            columns: _buildColumns(context),
            rows: _buildRows(state.reports),
            configuration: PlutoGridConfiguration(
              columnFilter: PlutoGridColumnFilterConfig(
                filters: const [
                  ...FilterHelper.defaultFilters,
                ],
              ),
            ),
            onLoaded: (PlutoGridOnLoadedEvent event) {
              event.stateManager.setShowColumnFilter(true);
            },
          );
        }
        return const Center(child: Text('No data available'));
      },
    );
  }

  // Define columns for PlutoGrid
  List<PlutoColumn> _buildColumns(BuildContext context) {
    return [
      PlutoColumn(
        title: 'MRN No',
        field: 'MRN No',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'MRN Date',
        field: 'MRN Date',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Vendor Name',
        field: 'Vendor Name',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Our Item Code',
        field: 'Our Item Code',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Item Name',
        field: 'Item Name',
        type: PlutoColumnType.text(),
        width: 350,
      ),
      PlutoColumn(
        title: 'Quantity',
        field: 'Quantity',
        type: PlutoColumnType.text(),
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Status',
        field: 'status',
        type: PlutoColumnType.text(),
        renderer: (rendererContext) {
          return InkWell(
            onTap: () {
              _navigateToMRNDetails(
                context,
                branchCode,
                rendererContext.row.cells['MRN No']?.value.toString() ?? 'N/A',
                rendererContext.row.cells['MRN Date']?.value.toString() ??
                    'N/A',
                rendererContext.row.cells['Vendor Name']?.value.toString() ??
                    'N/A',
                rendererContext.row.cells['Item Name']?.value.toString() ??
                    'N/A',
                rendererContext.row.cells['ItemNo']?.value.toString() ?? 'N/A',
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text(
                  'View Details',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ];
  }

  // Convert API data to PlutoRow format
  List<PlutoRow> _buildRows(List<Map<String, dynamic>> reports) {
    return reports.map((report) {
      return PlutoRow(
        cells: {
          'MRN No': PlutoCell(value: report['MRNNO'] ?? 'N/A'),
          'MRN Date': PlutoCell(value: report['MRNDATE'] ?? 'N/A'),
          'Vendor Name': PlutoCell(value: report['AccountName'] ?? 'N/A'),
          'Our Item Code': PlutoCell(value: report['OurItemNo'] ?? 'N/A'),
          'Item Name': PlutoCell(value: report['ItemName'] ?? 'N/A'),
          'Quantity': PlutoCell(value: report['SNo'] ?? 'N/A'),
          'ItemNo': PlutoCell(value: report['ItemNo'] ?? 'N/A'),
          'status': PlutoCell(value: 'Select'),
        },
      );
    }).toList();
  }

  void _navigateToMRNDetails(
    BuildContext context,
    String branchCode,
    String mrnNo,
    String mrnDate,
    String vendorName,
    String itemName,
    String itemNo,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MRNDetailsPage(
          branchCode: branchCode,
          mrnNo: mrnNo,
          mrnDate: mrnDate,
          vendorName: vendorName,
          itemName: itemName,
          itemNo: itemNo,
        ),
      ),
    );
  }
}
