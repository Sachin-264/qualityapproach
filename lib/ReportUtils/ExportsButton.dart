import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:universal_html/html.dart' as html;
import 'package:flutter/services.dart' show rootBundle;

class ExportButtons extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String fileName;
  final Map<String, String>? headerMap;
  static const int _rowsPerPage = 50; // Limit rows per page

  const ExportButtons({
    required this.data,
    required this.fileName,
    this.headerMap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: data.isNotEmpty ? () => _exportToCSV(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: data.isNotEmpty ? Colors.green : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Export to Excel',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: data.isNotEmpty ? () => _exportToPDFWithLoading(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: data.isNotEmpty ? Colors.red : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Export to PDF',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToCSV(BuildContext context) async {
    print('Starting CSV export...');
    final startTime = DateTime.now();

    try {
      if (data.isEmpty) {
        print('No data to export.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export!')),
        );
        return;
      }

      print('Showing loading dialog...');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      print('Calling compute to generate CSV...');
      final csvStartTime = DateTime.now();
      final csvBytes = await compute(_generateCSV, {
        'data': data,
        'headerMap': headerMap,
      });
      final csvEndTime = DateTime.now();
      print('CSV generation took ${csvEndTime.difference(csvStartTime).inMilliseconds} ms');

      print('Creating Blob and triggering download...');
      final blob = html.Blob([csvBytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "$fileName.csv")
        ..click();
      html.Url.revokeObjectUrl(url);

      print('Closing loading dialog...');
      Navigator.of(context).pop();
      print('CSV export completed successfully.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported to CSV successfully!')),
      );
    } catch (e) {
      print('Error during CSV export: $e');
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to CSV: $e')),
      );
    }

    final endTime = DateTime.now();
    print('Total CSV export time: ${endTime.difference(startTime).inMilliseconds} ms');
  }

  static Uint8List _generateCSV(Map<String, dynamic> params) {
    print('Starting _generateCSV in isolate...');
    final data = params['data'] as List<Map<String, dynamic>>;
    final headerMap = params['headerMap'] as Map<String, String>?;

    if (data.isEmpty) {
      print('Empty data provided, returning empty CSV.');
      return Uint8List.fromList(''.codeUnits);
    }

    print('Data length in _generateCSV: ${data.length} rows');
    final headers = headerMap != null ? headerMap.keys.toList() : data.first.keys.toList();
    print('Headers (count: ${headers.length}): $headers');

    final csvLines = <String>[];

    // Add header row
    final headerRow = headers.map((header) => '"${header.replaceAll('"', '""')}"').join(',');
    csvLines.add(headerRow);
    print('Added header row: $headerRow');

    // Add data rows
    for (var row in data) {
      final rowValues = headers.map((header) {
        final key = headerMap != null ? headerMap[header] ?? header : header;
        final value = row[key]?.toString() ?? 'N/A';
        return '"${value.replaceAll('"', '""')}"';
      }).join(',');
      csvLines.add(rowValues);
    }
    print('Added ${data.length} data rows');

    // Combine lines and encode to bytes
    final csvContent = csvLines.join('\n');
    final csvBytes = Uint8List.fromList(csvContent.codeUnits);
    print('Generated CSV bytes: ${csvBytes.length} bytes');

    return csvBytes;
  }

  Future<void> _exportToPDFWithLoading(BuildContext context) async {
    print('Starting PDF export...');
    final startTime = DateTime.now();

    try {
      if (data.isEmpty) {
        print('No data to export.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export!')),
        );
        return;
      }

      print('Data length: ${data.length} rows');
      if (data.length > 500) {
        print('Data exceeds 500 rows, prompting user...');
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Large Data Warning'),
            content: Text(
              'The dataset contains ${data.length} rows, which may take a long time to export to PDF or fail. Do you want to proceed with the first 500 rows only?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Proceed'),
              ),
            ],
          ),
        );
        if (shouldProceed != true) {
          print('User cancelled due to large data.');
          return;
        }
        print('Proceeding with first 500 rows.');
      }

      print('Showing loading dialog...');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      print('Calling compute to generate PDF...');
      final pdfStartTime = DateTime.now();
      final pdfBytes = await compute(_generatePDF, {
        'data': data.length > 500 ? data.sublist(0, 500) : data,
        'fileName': fileName,
        'headerMap': headerMap,
      });
      final pdfEndTime = DateTime.now();
      print('PDF generation took ${pdfEndTime.difference(pdfStartTime).inMilliseconds} ms');

      print('Creating Blob and triggering download...');
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "$fileName.pdf")
        ..click();
      html.Url.revokeObjectUrl(url);

      print('Closing loading dialog...');
      Navigator.of(context).pop();
      print('PDF export completed successfully.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported to PDF successfully!')),
      );
    } catch (e) {
      print('Error during PDF export: $e');
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to PDF: $e')),
      );
    }

    final endTime = DateTime.now();
    print('Total PDF export time: ${endTime.difference(startTime).inMilliseconds} ms');
  }

  static Future<Uint8List> _generatePDF(Map<String, dynamic> params) async {
    print('Starting _generatePDF in isolate...');
    final data = params['data'] as List<Map<String, dynamic>>;
    final fileName = params['fileName'] as String;
    final headerMap = params['headerMap'] as Map<String, String>?;

    // Validate data
    if (data.isEmpty) {
      print('Empty data provided, returning empty PDF.');
      final pdf = pw.Document();
      return await pdf.save();
    }

    print('Data length in _generatePDF: ${data.length} rows');
    final headers = headerMap != null ? headerMap.keys.toList() : data.first.keys.toList();
    print('Headers (count: ${headers.length}): $headers');

    final pdf = pw.Document();

    // Load font with error handling
    print('Loading font...');
    final fontStartTime = DateTime.now();
    late pw.Font font;
    try {
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      font = pw.Font.ttf(fontData);
    } catch (e) {
      print('Failed to load font: $e');
      throw Exception('Failed to load font: $e');
    }
    final fontEndTime = DateTime.now();
    print('Font loading took ${fontEndTime.difference(fontStartTime).inMilliseconds} ms');

    // Configure layout based on data size
    final bool useNormalSize = data.length < 15;
    final double fontSize = useNormalSize ? 10.0 : 4.0;
    final pageFormat = PdfPageFormat.a4.landscape;
    final double availableWidth = pageFormat.width - 20; // Account for left and right margins
    final double columnWidth = useNormalSize ? availableWidth / headers.length : availableWidth / headers.length;
    final int rowsPerPage = useNormalSize ? 50 : 20;
    print('Using ${useNormalSize ? "normal" : "small"} size - Font size: $fontSize pt, Rows per page: $rowsPerPage');

    // Split data into pages
    print('Splitting data into pages...');
    final List<List<Map<String, dynamic>>> pages = [];
    for (var i = 0; i < data.length; i += rowsPerPage) {
      final end = (i + rowsPerPage < data.length) ? i + rowsPerPage : data.length;
      pages.add(data.sublist(i, end));
    }
    print('Number of pages created: ${pages.length}');

    // Add pages to PDF
    print('Adding pages to PDF...');
    final pageStartTime = DateTime.now();
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final pageData = pages[pageIndex];
      print('Adding page ${pageIndex + 1} with ${pageData.length} rows');
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat.copyWith(
            marginLeft: 10,
            marginRight: 10,
            marginTop: 10,
            marginBottom: 10,
          ),
          build: (pw.Context context) {
            print('Building page ${pageIndex + 1} content...');
            final tableData = pageData.map((row) {
              return headers.map((header) {
                final key = headerMap != null ? headerMap[header] ?? header : header;
                final value = row[key]?.toString() ?? 'N/A';
                return useNormalSize
                    ? value
                    : value.length > 30 ? value.substring(0, 30) + '...' : value;
              }).toList();
            }).toList();
            print('Table data for page ${pageIndex + 1}: ${tableData.length} rows');

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (pageIndex == 0)
                  pw.Text(
                    fileName,
                    style: pw.TextStyle(
                      fontSize: useNormalSize ? 16 : 12,
                      font: font,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                pw.Text(
                  'Page ${pageIndex + 1} of ${pages.length}',
                  style: pw.TextStyle(font: font, fontSize: fontSize),
                ),
                pw.Table.fromTextArray(
                  headers: headers,
                  headerStyle: pw.TextStyle(
                    font: font,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: fontSize,
                  ),
                  cellStyle: pw.TextStyle(font: font, fontSize: fontSize),
                  data: tableData,
                  columnWidths: {
                    for (var i = 0; i < headers.length; i++)
                      i: pw.FixedColumnWidth(columnWidth),
                  },
                  cellPadding: pw.EdgeInsets.all(useNormalSize ? 4 : 1),
                ),
              ],
            );
          },
        ),
      );
    }
    final pageEndTime = DateTime.now();
    print('Page building took ${pageEndTime.difference(pageStartTime).inMilliseconds} ms');

    // Save PDF
    print('Saving PDF...');
    final saveStartTime = DateTime.now();
    final pdfBytes = await pdf.save();
    final saveEndTime = DateTime.now();
    print('PDF save took ${saveEndTime.difference(saveStartTime).inMilliseconds} ms');
    print('PDF generation completed, returning bytes (${pdfBytes.length} bytes)');

    return pdfBytes;
  }
}