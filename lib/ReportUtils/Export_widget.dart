import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:universal_html/html.dart' as html;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

class ExportWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String fileName;
  final Map<String, String>? headerMap;
  static const int _rowsPerPage = 50;

  const ExportWidget({
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
            onPressed: data.isNotEmpty ? () => _exportToExcel(context) : null,
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
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: data.isNotEmpty ? () => _sendToEmail(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: data.isNotEmpty ? Colors.blue : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Send to Email',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel(BuildContext context) async {
    try {
      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export!')),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final excelBytes = await compute(_generateExcel, {
        'data': data,
        'headerMap': headerMap,
      });

      final blob = html.Blob([excelBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "$fileName.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported to Excel successfully!')),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to Excel: $e')),
      );
    }
  }

  static Uint8List _generateExcel(Map<String, dynamic> params) {
    final data = params['data'] as List<Map<String, dynamic>>;
    final headerMap = params['headerMap'] as Map<String, String>?;

    var excel = Excel.createExcel();
    excel.delete('flutter');
    var sheet = excel['Sheet1'];

    final headers = headerMap != null ? headerMap!.keys.toList() : data.first.keys.toList();
    sheet.appendRow(headers.map((header) => TextCellValue(header)).toList());

    for (var row in data) {
      final rowValues = headers.map((header) {
        final key = headerMap != null ? headerMap![header] : header;
        return TextCellValue(row[key]?.toString() ?? 'N/A');
      }).toList();
      sheet.appendRow(rowValues);
    }

    final excelBytes = excel.save();
    return Uint8List.fromList(excelBytes!);
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
      print('PDF generation took ${pdfEndTime.difference(pdfStartTime).inSeconds} seconds');

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
    print('Total PDF export time: ${endTime.difference(startTime).inSeconds} seconds');
  }

  Future<void> _sendToEmail(BuildContext context) async {
    print('SendToEmail: Starting email sending process...');
    try {
      if (data.isEmpty) {
        print('SendToEmail: No data to send.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to send!')),
        );
        return;
      }

      print('SendToEmail: Showing email input dialog...');
      // Prompt user for email address
      final emailController = TextEditingController();
      final shouldSend = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send to Email'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Recipient Email',
              hintText: 'Enter email address',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('SendToEmail: User pressed Cancel in email dialog.');
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                print('SendToEmail: User pressed Send with email: ${emailController.text}');
                if (emailController.text.isNotEmpty &&
                    RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text)) {
                  print('SendToEmail: Email is valid, proceeding...');
                  Navigator.of(context).pop(true);
                } else {
                  print('SendToEmail: Invalid email address entered.');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid email address!')),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      );

      print('SendToEmail: Dialog result: shouldSend=$shouldSend');
      if (shouldSend != true) {
        print('SendToEmail: Email sending cancelled by user.');
        return;
      }

      print('SendToEmail: Showing loading dialog...');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      print('SendToEmail: Generating Excel file...');
      // Generate Excel file
      final excelStartTime = DateTime.now();
      final excelBytes = await compute(_generateExcel, {
        'data': data,
        'headerMap': headerMap,
      });
      final excelEndTime = DateTime.now();
      print('SendToEmail: Excel generation took ${excelEndTime.difference(excelStartTime).inSeconds} seconds');

      print('SendToEmail: Generating PDF file...');
      // Generate PDF file
      final pdfStartTime = DateTime.now();
      final pdfBytes = await compute(_generatePDF, {
        'data': data.length > 500 ? data.sublist(0, 500) : data,
        'fileName': fileName,
        'headerMap': headerMap,
      });
      final pdfEndTime = DateTime.now();
      print('SendToEmail: PDF generation took ${pdfEndTime.difference(pdfStartTime).inSeconds} seconds');

      print('SendToEmail: Preparing multipart HTTP request...');
      // Prepare multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost/sendmail.php'),
      );

      // Add email field
      request.fields['email'] = emailController.text;
      print('SendToEmail: Added email field: ${emailController.text}');

      // Add Excel file
      request.files.add(http.MultipartFile.fromBytes(
        'excel',
        excelBytes,
        filename: '$fileName.xlsx',
      ));
      print('SendToEmail: Added Excel file: $fileName.xlsx');

      // Add PDF file
      request.files.add(http.MultipartFile.fromBytes(
        'pdf',
        pdfBytes,
        filename: '$fileName.pdf',
      ));
      print('SendToEmail: Added PDF file: $fileName.pdf');

      print('SendToEmail: Sending HTTP request to http://localhost/sendmail.php...');
      // Send request
      final response = await request.send();
      print('SendToEmail: HTTP response status code: ${response.statusCode}');
      final responseString = await response.stream.bytesToString();
      print('SendToEmail: HTTP response body: $responseString');

      print('SendToEmail: Closing loading dialog...');
      Navigator.of(context).pop();

      if (response.statusCode == 200 && responseString == 'Success') {
        print('SendToEmail: Files sent to email successfully!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Files sent to email successfully!')),
        );
      } else {
        print('SendToEmail: Failed to send email. Status: ${response.statusCode}, Response: $responseString');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send email: $responseString')),
        );
      }
    } catch (e) {
      print('SendToEmail: Exception caught: $e');
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send email: $e')),
      );
    }
  }

  static Future<Uint8List> _generatePDF(Map<String, dynamic> params) async {
    print('Starting _generatePDF in isolate...');
    final data = params['data'] as List<Map<String, dynamic>>;
    final fileName = params['fileName'] as String;
    final headerMap = params['headerMap'] as Map<String, String>?;

    print('Data length in _generatePDF: ${data.length} rows');
    final headers = headerMap != null ? headerMap!.keys.toList() : data.first.keys.toList();
    print('Headers (full count: ${headers.length}): $headers');

    final pdf = pw.Document();

    print('Loading font...');
    final fontStartTime = DateTime.now();
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    final fontEndTime = DateTime.now();
    print('Font loading took ${fontEndTime.difference(fontStartTime).inMilliseconds} ms');

    final bool useNormalSize = data.length < 15;
    final double fontSize = useNormalSize ? 10.0 : 4.0;
    final double columnWidth = useNormalSize
        ? (841.89 - 20) / headers.length
        : 841.89 / headers.length;
    final int rowsPerPage = useNormalSize ? 50 : 20;
    print('Using ${useNormalSize ? "normal" : "small"} size - Font size: $fontSize pt, Rows per page: $rowsPerPage');

    print('Splitting data into pages...');
    final List<List<Map<String, dynamic>>> pages = [];
    for (var i = 0; i < data.length; i += rowsPerPage) {
      final end = (i + rowsPerPage < data.length) ? i + rowsPerPage : data.length;
      pages.add(data.sublist(i, end));
    }
    print('Number of pages created: ${pages.length}');

    print('Adding pages to PDF...');
    final pageStartTime = DateTime.now();
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final pageData = pages[pageIndex];
      print('Adding page ${pageIndex + 1} with ${pageData.length} rows');
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape.copyWith(
            marginLeft: 10,
            marginRight: 10,
            marginTop: 10,
            marginBottom: 10,
          ),
          build: (pw.Context context) {
            print('Building page ${pageIndex + 1} content...');
            final tableData = pageData.map((row) {
              return headers.map((header) {
                final key = headerMap != null ? headerMap![header] : header;
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
                  headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: fontSize),
                  cellStyle: pw.TextStyle(font: font, fontSize: fontSize),
                  data: tableData,
                  columnWidths: {for (var i in headers) headers.indexOf(i): pw.FixedColumnWidth(columnWidth)},
                  cellPadding: pw.EdgeInsets.all(useNormalSize ? 4 : 1),
                ),
              ],
            );
          },
        ),
      );
    }
    final pageEndTime = DateTime.now();
    print('Page building took ${pageEndTime.difference(pageStartTime).inSeconds} seconds');

    print('Saving PDF...');
    final saveStartTime = DateTime.now();
    final pdfBytes = await pdf.save();
    final saveEndTime = DateTime.now();
    print('PDF save took ${saveEndTime.difference(saveStartTime).inSeconds} seconds');
    print('PDF generation completed, returning bytes (${pdfBytes.length} bytes).');

    return pdfBytes;
  }
}