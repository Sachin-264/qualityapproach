import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

// Global export lock to prevent multiple exports
class ExportLock {
  static bool _isExportingGlobally = false;

  static bool get isExporting => _isExportingGlobally;

  static void startExport() {
    _isExportingGlobally = true;
  }

  static void endExport() {
    _isExportingGlobally = false;
  }
}

// Simple debouncer class
class Debouncer {
  final Duration duration;
  Debouncer(this.duration);

  bool _isScheduled = false;

  Future<void> debounce(VoidCallback callback) async {
    if (_isScheduled) {
      print('Debouncer: Ignoring callback, already scheduled');
      return;
    }

    _isScheduled = true;
    await Future.delayed(duration);
    callback();
    _isScheduled = false;
  }
}

// Global tracker for downloads
class DownloadTracker {
  static int _downloadCount = 0;
  static void trackDownload(String fileName, String url, String exportId) {
    _downloadCount++;
    print('DownloadTracker: Download #$_downloadCount: $fileName, URL: $url, ExportID: $exportId');
  }
}

class ExportWidget extends StatefulWidget {
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
  _ExportWidgetState createState() => _ExportWidgetState();
}

class _ExportWidgetState extends State<ExportWidget> {
  bool _isExporting = false;
  int _clickCount = 0;
  final _csvDebouncer = Debouncer(Duration(milliseconds: 1000));
  final _pdfDebouncer = Debouncer(Duration(milliseconds: 1000));
  final _emailDebouncer = Debouncer(Duration(milliseconds: 1000));
  String _exportId = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    print('ExportWidget: Initialized with exportId=$_exportId, fileName=${widget
        .fileName}');
  }

  @override
  Widget build(BuildContext context) {
    print('ExportWidget: Building with exportId=$_exportId, dataLength=${widget
        .data.length}');
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: widget.data.isNotEmpty && !_isExporting &&
                !ExportLock.isExporting
                ? () async {
              print(
                  'ExportWidget: CSV button clicked, clickCount=${++_clickCount}, exportId=$_exportId, stack: ${StackTrace
                      .current}');
              await _csvDebouncer.debounce(() => _exportToCSV(context));
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.data.isNotEmpty && !_isExporting &&
                  !ExportLock.isExporting ? Colors.green : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Export to Excel',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: widget.data.isNotEmpty && !ExportLock.isExporting
                ? () =>
                _pdfDebouncer.debounce(() {
                  print(
                      'ExportWidget: PDF button clicked, exportId=$_exportId, stack: ${StackTrace
                          .current}');
                  _exportToPDFWithLoading(context);
                })
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.data.isNotEmpty && !ExportLock.isExporting
                  ? Colors.red
                  : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Export to PDF',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: widget.data.isNotEmpty && !ExportLock.isExporting
                ? () =>
                _emailDebouncer.debounce(() {
                  print(
                      'ExportWidget: Email button clicked, exportId=$_exportId, stack: ${StackTrace
                          .current}');
                  _sendToEmail(context);
                })
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.data.isNotEmpty && !ExportLock.isExporting
                  ? Colors.blue
                  : Colors.grey,
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

  Future<void> _exportToCSV(BuildContext context) async {
    print(
        'ExportToCSV: Starting CSV export, exportId=$_exportId, stack: ${StackTrace
            .current}');
    final startTime = DateTime.now();

    try {
      if (widget.data.isEmpty) {
        print('ExportToCSV: No data to export, exportId=$_exportId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export!')),
        );
        return;
      }

      if (_isExporting || ExportLock.isExporting) {
        print(
            'ExportToCSV: Export already in progress (local or global), ignoring request, exportId=$_exportId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export already in progress!')),
        );
        return;
      }

      print(
          'ExportToCSV: Setting _isExporting to true and acquiring global lock, exportId=$_exportId');
      setState(() {
        _isExporting = true;
      });
      ExportLock.startExport();

      print('ExportToCSV: Showing loading dialog, exportId=$_exportId');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      print('ExportToCSV: Generating CSV file, exportId=$_exportId');
      final csvStartTime = DateTime.now();
      final csvBytes = await compute(_generateCSV, {
        'data': widget.data,
        'headerMap': widget.headerMap,
        'exportId': _exportId,
      });
      final csvEndTime = DateTime.now();
      print('ExportToCSV: CSV generation took ${csvEndTime
          .difference(csvStartTime)
          .inMilliseconds} ms, exportId=$_exportId');
      print('ExportToCSV: Generated CSV file size: ${csvBytes
          .length} bytes, exportId=$_exportId');

      if (kIsWeb) {
        print(
            'ExportToCSV: Saving CSV file using file_saver, exportId=$_exportId');
        final fileName = '${widget.fileName}.csv';
        final result = await FileSaver.instance.saveFile(
          name: fileName,
          bytes: csvBytes,
          mimeType: MimeType.csv,
        );
        print(
            'ExportToCSV: File saved with result: $result, fileName: $fileName, exportId=$_exportId');
        DownloadTracker.trackDownload(fileName, 'file_saver', _exportId);
      } else {
        print(
            'ExportToCSV: Platform is not web, showing not implemented message, exportId=$_exportId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('CSV export not implemented for this platform!')),
        );
      }

      print('ExportToCSV: Closing loading dialog, exportId=$_exportId');
      Navigator.of(context).pop();

      print('ExportToCSV: Showing success message, exportId=$_exportId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported to CSV successfully!')),
      );
    } catch (e) {
      print('ExportToCSV: Exception caught: $e, exportId=$_exportId');
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to CSV: $e')),
      );
    } finally {
      print(
          'ExportToCSV: Resetting _isExporting to false and releasing global lock, exportId=$_exportId');
      setState(() {
        _isExporting = false;
      });
      ExportLock.endExport();
    }

    final endTime = DateTime.now();
    print('ExportToCSV: Total export time: ${endTime
        .difference(startTime)
        .inMilliseconds} ms, exportId=$_exportId');
  }

  static Uint8List _generateCSV(Map<String, dynamic> params) {
    final exportId = params['exportId'] as String;
    print('GenerateCSV: Starting CSV generation, exportId=$exportId');
    final data = params['data'] as List<Map<String, dynamic>>;
    final headerMap = params['headerMap'] as Map<String, String>?;

    if (data.isEmpty) {
      print(
          'GenerateCSV: Empty data provided, returning empty CSV, exportId=$exportId');
      return Uint8List.fromList(''.codeUnits);
    }

    print('GenerateCSV: Validating data consistency, exportId=$exportId');
    final headers = headerMap != null ? headerMap.keys.toList() : data.first
        .keys.toList();
    for (var row in data) {
      if (row.keys
          .toSet()
          .intersection(headers.toSet())
          .isEmpty) {
        print(
            'GenerateCSV: Warning: Row has no matching headers, exportId=$exportId');
      }
    }

    print('GenerateCSV: Generating CSV content, exportId=$exportId');
    final csvStartTime = DateTime.now();
    final csvLines = <String>[];

    // Add header row
    final headerRow = headers.map((header) => '"${header.replaceAll(
        '"', '""')}"').join(',');
    csvLines.add(headerRow);
    print('GenerateCSV: Added header row: $headerRow, exportId=$exportId');

    // Add data rows
    for (var row in data) {
      final rowValues = headers.map((header) {
        final key = headerMap != null ? headerMap[header] ?? header : header;
        final value = row[key]?.toString() ?? 'N/A';
        return '"${value.replaceAll('"', '""')}"';
      }).join(',');
      csvLines.add(rowValues);
    }
    print('GenerateCSV: Added ${data.length} data rows, exportId=$exportId');

    // Combine lines and encode to bytes
    final csvContent = csvLines.join('\n');
    final csvBytes = Uint8List.fromList(csvContent.codeUnits);
    final csvEndTime = DateTime.now();
    print('GenerateCSV: CSV generation took ${csvEndTime
        .difference(csvStartTime)
        .inMilliseconds} ms, exportId=$exportId');
    print('GenerateCSV: Generated CSV bytes: ${csvBytes
        .length} bytes, exportId=$exportId');

    return csvBytes;
  }

  Future<void> _exportToPDFWithLoading(BuildContext context) async {
    print('ExportToPDF: Starting PDF export, exportId=$_exportId');
    final startTime = DateTime.now();

    try {
      if (widget.data.isEmpty) {
        print('ExportToPDF: No data to export, exportId=$_exportId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export!')),
        );
        return;
      }

      print('ExportToPDF: Data length: ${widget.data
          .length} rows, exportId=$_exportId');
      if (widget.data.length > 500) {
        print(
            'ExportToPDF: Data exceeds 500 rows, prompting user, exportId=$_exportId');
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) =>
              AlertDialog(
                title: const Text('Large Data Warning'),
                content: Text(
                  'The dataset contains ${widget.data
                      .length} rows, which may take a long time to export to PDF or fail. Do you want to proceed with the first 500 rows only?',
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
          print(
              'ExportToPDF: User cancelled due to large data, exportId=$_exportId');
          return;
        }
        print(
            'ExportToPDF: Proceeding with first 500 rows, exportId=$_exportId');
      }

      print('ExportToPDF: Acquiring global lock, exportId=$_exportId');
      ExportLock.startExport();

      print('ExportToPDF: Showing loading dialog, exportId=$_exportId');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      print(
          'ExportToPDF: Calling compute to generate PDF, exportId=$_exportId');
      final pdfStartTime = DateTime.now();
      final pdfBytes = await compute(_generatePDF, {
        'data': widget.data.length > 500 ? widget.data.sublist(0, 500) : widget
            .data,
        'fileName': widget.fileName,
        'headerMap': widget.headerMap,
        'exportId': _exportId,
      });
      final pdfEndTime = DateTime.now();
      print('ExportToPDF: PDF generation took ${pdfEndTime
          .difference(pdfStartTime)
          .inMilliseconds} ms, exportId=$_exportId');

      if (kIsWeb) {
        print(
            'ExportToPDF: Saving PDF file using file_saver, exportId=$_exportId');
        final fileName = '${widget.fileName}.pdf';
        final result = await FileSaver.instance.saveFile(
          name: fileName,
          bytes: pdfBytes,
          mimeType: MimeType.pdf,
        );
        print(
            'ExportToPDF: File saved with result: $result, fileName: $fileName, exportId=$_exportId');
        DownloadTracker.trackDownload(fileName, 'file_saver', _exportId);
      } else {
        print(
            'ExportToPDF: Platform is not web, showing not implemented message, exportId=$_exportId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('PDF export not implemented for this platform!')),
        );
      }

      print('ExportToPDF: Closing loading dialog, exportId=$_exportId');
      Navigator.of(context).pop();
      print(
          'ExportToPDF: PDF export completed successfully, exportId=$_exportId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported to PDF successfully!')),
      );
    } catch (e) {
      print('ExportToPDF: Error during PDF export: $e, exportId=$_exportId');
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to PDF: $e')),
      );
    } finally {
      print('ExportToPDF: Releasing global lock, exportId=$_exportId');
      ExportLock.endExport();
    }

    final endTime = DateTime.now();
    print('ExportToPDF: Total PDF export time: ${endTime
        .difference(startTime)
        .inMilliseconds} ms, exportId=$_exportId');
  }

  Future<void> _sendToEmail(BuildContext context) async {
    print('SendToEmail: Starting email sending process, exportId=$_exportId');
    try {
      if (widget.data.isEmpty) {
        print('SendToEmail: No data to send, exportId=$_exportId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to send!')),
        );
        return;
      }

      print('SendToEmail: Showing email input dialog, exportId=$_exportId');
      final emailController = TextEditingController();
      final shouldSend = await showDialog<bool>(
        context: context,
        builder: (context) =>
            AlertDialog(
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
                    print(
                        'SendToEmail: User pressed Cancel in email dialog, exportId=$_exportId');
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    print(
                        'SendToEmail: User pressed Send with email: ${emailController
                            .text}, exportId=$_exportId');
                    if (emailController.text.isNotEmpty &&
                        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(
                            emailController.text)) {
                      print(
                          'SendToEmail: Email is valid, proceeding, exportId=$_exportId');
                      Navigator.of(context).pop(true);
                    } else {
                      print(
                          'SendToEmail: Invalid email address entered, exportId=$_exportId');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(
                            'Please enter a valid email address!')),
                      );
                    }
                  },
                  child: const Text('Send'),
                ),
              ],
            ),
      );

      print(
          'SendToEmail: Dialog result: shouldSend=$shouldSend, exportId=$_exportId');
      if (shouldSend != true) {
        print(
            'SendToEmail: Email sending cancelled by user, exportId=$_exportId');
        return;
      }

      print('SendToEmail: Acquiring global lock, exportId=$_exportId');
      ExportLock.startExport();

      print('SendToEmail: Showing loading dialog, exportId=$_exportId');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      print('SendToEmail: Generating CSV file, exportId=$_exportId');
      final csvStartTime = DateTime.now();
      final csvBytes = await compute(_generateCSV, {
        'data': widget.data,
        'headerMap': widget.headerMap,
        'exportId': _exportId,
      });
      final csvEndTime = DateTime.now();
      print('SendToEmail: CSV generation took ${csvEndTime
          .difference(csvStartTime)
          .inMilliseconds} ms, exportId=$_exportId');

      print('SendToEmail: Generating PDF file, exportId=$_exportId');
      final pdfStartTime = DateTime.now();
      final pdfBytes = await compute(_generatePDF, {
        'data': widget.data.length > 500 ? widget.data.sublist(0, 500) : widget
            .data,
        'fileName': widget.fileName,
        'headerMap': widget.headerMap,
        'exportId': _exportId,
      });
      final pdfEndTime = DateTime.now();
      print('SendToEmail: PDF generation took ${pdfEndTime
          .difference(pdfStartTime)
          .inMilliseconds} ms, exportId=$_exportId');

      print(
          'SendToEmail: Preparing multipart HTTP request, exportId=$_exportId');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost/sendmail.php'),
      );

      request.fields['email'] = emailController.text;
      print('SendToEmail: Added email field: ${emailController
          .text}, exportId=$_exportId');

      request.files.add(http.MultipartFile.fromBytes(
        'csv',
        csvBytes,
        filename: '${widget.fileName}.csv',
      ));
      print('SendToEmail: Added CSV file: ${widget
          .fileName}.csv, exportId=$_exportId');

      request.files.add(http.MultipartFile.fromBytes(
        'pdf',
        pdfBytes,
        filename: '${widget.fileName}.pdf',
      ));
      print('SendToEmail: Added PDF file: ${widget
          .fileName}.pdf, exportId=$_exportId');

      print(
          'SendToEmail: Sending HTTP request to http://localhost/sendmail.php, exportId=$_exportId');
      final response = await request.send();
      print('SendToEmail: HTTP response status code: ${response
          .statusCode}, exportId=$_exportId');
      final responseString = await response.stream.bytesToString();
      print(
          'SendToEmail: HTTP response body: $responseString, exportId=$_exportId');

      print('SendToEmail: Closing loading dialog, exportId=$_exportId');
      Navigator.of(context).pop();

      if (response.statusCode == 200 && responseString == 'Success') {
        print(
            'SendToEmail: Files sent to email successfully, exportId=$_exportId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Files sent to email successfully!')),
        );
      } else {
        print('SendToEmail: Failed to send email. Status: ${response
            .statusCode}, Response: $responseString, exportId=$_exportId');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send email: $responseString')),
        );
      }
    } catch (e) {
      print('SendToEmail: Exception caught: $e, exportId=$_exportId');
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send email: $e')),
      );
    } finally {
      print('SendToEmail: Releasing global lock, exportId=$_exportId');
      ExportLock.endExport();
    }
  }

  static Future<Uint8List> _generatePDF(Map<String, dynamic> params) async {
    final exportId = params['exportId'] as String;
    print(
        'GeneratePDF: Starting PDF generation in isolate, exportId=$exportId');
    final data = params['data'] as List<Map<String, dynamic>>;
    final fileName = params['fileName'] as String;
    final headerMap = params['headerMap'] as Map<String, String>?;

    // Validate data
    if (data.isEmpty) {
      print(
          'GeneratePDF: Empty data provided, returning empty PDF, exportId=$exportId');
      final pdf = pw.Document();
      return await pdf.save();
    }

    print('GeneratePDF: Data length: ${data.length} rows, exportId=$exportId');
    final headers = headerMap != null ? headerMap.keys.toList() : data.first
        .keys.toList();
    print('GeneratePDF: Headers (count: ${headers
        .length}): $headers, exportId=$exportId');

    final pdf = pw.Document();

    // Load font with error handling
    print('GeneratePDF: Loading font, exportId=$exportId');
    final fontStartTime = DateTime.now();
    late pw.Font font;
    try {
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      font = pw.Font.ttf(fontData);
    } catch (e) {
      print('GeneratePDF: Failed to load font: $e, exportId=$exportId');
      throw Exception('Failed to load font: $e');
    }
    final fontEndTime = DateTime.now();
    print('GeneratePDF: Font loading took ${fontEndTime
        .difference(fontStartTime)
        .inMilliseconds} ms, exportId=$exportId');

    // Configure layout based on data size
    final bool useNormalSize = data.length < 15;
    final double fontSize = useNormalSize ? 10.0 : 4.0;
    final pageFormat = PdfPageFormat.a4.landscape;
    final double availableWidth = pageFormat.width -
        20; // Account for left and right margins
    final double columnWidth = useNormalSize
        ? availableWidth / headers.length
        : availableWidth / headers.length;
    final int rowsPerPage = useNormalSize ? 50 : 20;
    print('GeneratePDF: Using ${useNormalSize
        ? "normal"
        : "small"} size - Font size: $fontSize pt, Rows per page: $rowsPerPage, exportId=$exportId');

    // Split data into pages
    print('GeneratePDF: Splitting data into pages, exportId=$exportId');
    final List<List<Map<String, dynamic>>> pages = [];
    for (var i = 0; i < data.length; i += rowsPerPage) {
      final end = (i + rowsPerPage < data.length) ? i + rowsPerPage : data
          .length;
      pages.add(data.sublist(i, end));
    }
    print('GeneratePDF: Number of pages created: ${pages
        .length}, exportId=$exportId');

    // Add pages to PDF
    print('GeneratePDF: Adding pages to PDF, exportId=$exportId');
    final pageStartTime = DateTime.now();
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final pageData = pages[pageIndex];
      print('GeneratePDF: Adding page ${pageIndex + 1} with ${pageData
          .length} rows, exportId=$exportId');
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat.copyWith(
            marginLeft: 10,
            marginRight: 10,
            marginTop: 10,
            marginBottom: 10,
          ),
          build: (pw.Context context) {
            print('GeneratePDF: Building page ${pageIndex +
                1} content, exportId=$exportId');
            final tableData = pageData.map((row) {
              return headers.map((header) {
                final key = headerMap != null
                    ? headerMap[header] ?? header
                    : header;
                final value = row[key]?.toString() ?? 'N/A';
                return useNormalSize
                    ? value
                    : value.length > 30
                    ? value.substring(0, 30) + '...'
                    : value;
              }).toList();
            }).toList();
            print(
                'GeneratePDF: Table data for page ${pageIndex + 1}: ${tableData
                    .length} rows, exportId=$exportId');

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
    print('GeneratePDF: Page building took ${pageEndTime
        .difference(pageStartTime)
        .inMilliseconds} ms, exportId=$exportId');

    // Save PDF
    print('GeneratePDF: Saving PDF, exportId=$exportId');
    final saveStartTime = DateTime.now();
    final pdfBytes = await pdf.save();
    final saveEndTime = DateTime.now();
    print('GeneratePDF: PDF save took ${saveEndTime
        .difference(saveStartTime)
        .inMilliseconds} ms, exportId=$exportId');
    print('GeneratePDF: PDF generation completed, returning bytes (${pdfBytes
        .length} bytes), exportId=$exportId');

    return pdfBytes;
  }
}