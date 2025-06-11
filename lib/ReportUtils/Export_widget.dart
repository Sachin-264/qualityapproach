// lib/ReportDynamic/exportpdf.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pluto_grid/pluto_grid.dart';

// Global export lock to prevent multiple exports
class ExportLock {
  static bool _isExportingGlobally = false;

  static bool get isExporting => _isExportingGlobally;

  static void startExport() {
    _isExportingGlobally = true;
    print('ExportLock: Global lock acquired.');
  }

  static void endExport() {
    _isExportingGlobally = false;
    print('ExportLock: Global lock released.');
  }
}

// Simple debouncer class to prevent rapid clicks
class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer(this.duration);

  Future<void> debounce(FutureOr<void> Function() callback) async {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }
    _timer = Timer(duration, () async {
      await callback();
    });
  }
}

// Global tracker for downloads (not directly related to the current issues, but kept for context)
class DownloadTracker {
  static int _downloadCount = 0;
  static void trackDownload(String fileName, String url, String exportId) {
    _downloadCount++;
    print('DownloadTracker: Download #$_downloadCount: $fileName, URL: $url, ExportID: $exportId');
  }
}

class ExportWidget extends StatefulWidget {
  final List<PlutoColumn> columns;
  final List<PlutoRow> plutoRows;
  final String fileName;
  final List<Map<String, dynamic>>? fieldConfigs;
  final String reportLabel;
  final Map<String, String> parameterValues;
  final Map<String, String> displayParameterValues; // Already filtered by ReportUI for visible & non-empty
  final List<Map<String, dynamic>>? apiParameters; // Full parameter definitions from demo_table
  final Map<String, List<Map<String, String>>>? pickerOptions;
  final String companyName; // NEW: Add companyName to ExportWidget constructor

  const ExportWidget({
    required this.columns,
    required this.plutoRows,
    required this.fileName,
    this.fieldConfigs,
    required this.reportLabel,
    required this.parameterValues,
    required this.displayParameterValues,
    this.apiParameters,
    this.pickerOptions,
    required this.companyName, // NEW: Make companyName required
    super.key,
  });

  @override
  _ExportWidgetState createState() => _ExportWidgetState();
}

class _ExportWidgetState extends State<ExportWidget> {
  final _excelDebouncer = Debouncer(const Duration(milliseconds: 500));
  final _pdfDebouncer = Debouncer(const Duration(milliseconds: 500));
  final _emailDebouncer = Debouncer(const Duration(milliseconds: 500));
  final _printDebouncer = Debouncer(const Duration(milliseconds: 500));
  final String _exportId = UniqueKey().toString(); // Unique ID for each widget instance/export lifecycle

  static const String _pdfApiBaseUrl = 'http://localhost:3000'; // <<-- YOUR NODE.JS API BASE URL

  @override
  void initState() {
    super.initState();
    print('ExportWidget: Initialized with exportId=$_exportId, fileName=${widget.fileName}');
  }

  // MODIFIED: Helper to get the company name for the header, considering 'show' and 'display_value_cache'
  String? get _companyNameForHeader {
    // Prioritize the companyName passed directly to ExportWidget (from ReportMainUI/TableMainUI)
    if (widget.companyName.isNotEmpty) {
      print('ExportWidget: Company name (from passed prop) found: ${widget.companyName}');
      return widget.companyName;
    }

    // Fallback logic: If companyName was not directly passed or is empty, try to derive it from apiParameters.
    // This is useful if the `companyName` field was not explicitly populated in the higher-level UI
    // or if this widget is used in a context where `companyName` isn't directly computed by its parent.
    if (widget.apiParameters != null) {
      for (var param in widget.apiParameters!) {
        if (param['is_company_name_field'] == true) {
          final paramName = param['name'].toString();

          // Case 1: Parameter is shown in UI (show: true). Use the value from displayParameterValues.
          if (param['show'] == true) {
            final companyDisplayName = widget.displayParameterValues[paramName];
            if (companyDisplayName != null && companyDisplayName.isNotEmpty) {
              print('ExportWidget: Company name (from UI/visible param in fallback) found: $companyDisplayName');
              return companyDisplayName;
            }
          }
          // Case 2: Parameter is NOT shown in UI (show: false). Use display_value_cache.
          else if (param['display_value_cache'] != null && param['display_value_cache'].toString().isNotEmpty) {
            final companyDisplayName = param['display_value_cache'].toString();
            print('ExportWidget: Company name (from display_value_cache in fallback) found: $companyDisplayName');
            return companyDisplayName;
          }
        }
      }
    }
    print('ExportWidget: No company name found for header (after fallback).');
    return null;
  }


  @override
  Widget build(BuildContext context) {
    // Determine if export buttons should be enabled: data must not be empty AND no global export in progress.
    final bool canExport = widget.plutoRows.isNotEmpty && !ExportLock.isExporting;

    print('ExportWidget: Building with exportId=$_exportId, dataLength=${widget.plutoRows.length}, ExportLock.isExporting=${ExportLock.isExporting}');
    print('ExportWidget: Derived company name for header: ${_companyNameForHeader ?? 'N/A'}');


    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: canExport
                ? () async {
              print('ExportWidget: Excel button clicked, exportId=$_exportId');
              await _excelDebouncer.debounce(() async {
                await _exportToExcel(context);
              });
            }
                : null, // Button disabled if canExport is false
            style: ElevatedButton.styleFrom(
              backgroundColor: canExport ? Colors.green : Colors.grey, // Visual feedback for disabled state
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Export to Excel',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: canExport
                ? () async {
              print('ExportWidget: PDF button clicked, exportId=$_exportId');
              await _pdfDebouncer.debounce(() async {
                await _exportToPDF(context); // This will download the PDF
              });
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canExport ? Colors.red : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Export to PDF',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: canExport
                ? () async {
              print('ExportWidget: Email button clicked, exportId=$_exportId');
              await _emailDebouncer.debounce(() async {
                await _sendToEmail(context);
              });
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canExport ? Colors.blue : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Send to Email',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: canExport
                ? () async {
              print('ExportWidget: Print button clicked, exportId=$_exportId');
              // No debouncer for Print because it's usually a direct action to a system dialog
              await _printDocument(context); // This will trigger the print dialog
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canExport ? Colors.deepPurple : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Print',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeExportTask(BuildContext context, Future<void> Function() task, String taskName) async {
    print('$taskName: Starting export task, exportId=$_exportId');
    final startTime = DateTime.now();

    if (widget.plutoRows.isEmpty) {
      print('$taskName: No data to export, exportId=$_exportId');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export!')),
        );
      }
      return;
    }

    if (ExportLock.isExporting) {
      print('$taskName: Export already in progress (global lock active), ignoring request, exportId=$_exportId');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export already in progress!')),
        );
      }
      return;
    }

    ExportLock.startExport(); // Acquire global lock FIRST
    if (context.mounted) {
      setState(() {}); // Rebuild widget to gray out buttons IMMEDIATELY
    }

    bool dialogShown = false;
    if (context.mounted) {
      Future.delayed(Duration.zero, () {
        // Use Duration.zero to schedule after current frame
        if (context.mounted && ExportLock.isExporting) {
          // Double check if still exporting and context is valid
          print('$taskName: Showing loader dialog, exportId=$_exportId');
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );
          dialogShown = true;
        }
      });
    }

    try {
      await task(); // Execute the specific export task
    } catch (e) {
      print('$taskName: Exception caught: $e, exportId=$_exportId');
      String errorMessage = 'Failed to $taskName. Please try again.';
      // More specific error messages for PDF API errors
      if (e.toString().contains('Failed to generate PDF on server')) {
        errorMessage = 'PDF generation failed on server. Server response: ${e.toString().split("Server response:").last.trim()}';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage = 'Could not connect to PDF server. Is it running?';
      } else {
        errorMessage = 'Failed to $taskName: $e';
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (dialogShown && context.mounted && Navigator.of(context).canPop()) {
        print('$taskName: Dismissing loader dialog, exportId=$_exportId');
        Navigator.of(context).pop();
      }
      ExportLock.endExport(); // Release global lock
      if (context.mounted) {
        setState(() {}); // Rebuild widget to re-enable buttons
      }
      print('$taskName: Resetting state and releasing global lock, exportId=$_exportId');
    }

    final endTime = DateTime.now();
    print('$taskName: Total export time: ${endTime.difference(startTime).inMilliseconds} ms, exportId=$_exportId');
  }

  // --- Helper to call Node.js PDF Generation API ---
  Future<Uint8List> _callPdfGenerationApi() async {
    print('Calling Node.js PDF API, exportId=$_exportId');

    // Use widget.displayParameterValues directly (already filtered by ReportUI for visible & non-empty)
    final Map<String, String> visibleAndFormattedParameters = widget.displayParameterValues;

    // Prepare serializable data for HTTP request
    final List<Map<String, dynamic>> serializableColumns = widget.columns.map((col) => {
      'field': col.field,
      'title': col.title,
      'type': col.type.runtimeType.toString(), // Simple type representation (e.g., PlutoColumnType.text)
      'width': col.width,
    }).toList();

    final List<Map<String, dynamic>> serializableRows = widget.plutoRows.map((row) => {
      'cells': row.cells.map((key, value) => MapEntry(key, value.value)),
      '__isSubtotal__': row.cells.containsKey('__isSubtotal__') ? row.cells['__isSubtotal__']!.value : false,
    }).toList();

    // Calculate total configured width to help Node.js with proportional column sizing
    double totalPlutoConfiguredWidth = 0.0;
    for (var col in widget.columns) {
      // Exclude the __actions__ column from width calculation for content columns
      if (col.field != '__actions__') {
        totalPlutoConfiguredWidth += (col.width ?? 100.0);
      }
    }
    // Fallback if no columns with widths or all are actions
    if (totalPlutoConfiguredWidth == 0 && widget.columns.where((col) => col.field != '__actions__').isNotEmpty) {
      totalPlutoConfiguredWidth = widget.columns.where((col) => col.field != '__actions__').length * 100.0;
    } else if (totalPlutoConfiguredWidth == 0) {
      totalPlutoConfiguredWidth = 1.0; // Avoid division by zero if there are no content columns at all
    }

    final Map<String, dynamic> requestBody = {
      'columns': serializableColumns,
      'rows': serializableRows,
      'fileName': widget.fileName,
      'exportId': _exportId, // Pass for server-side logging/tracking if needed
      'fieldConfigs': widget.fieldConfigs, // These are crucial for server-side formatting
      'reportLabel': widget.reportLabel,
      'visibleAndFormattedParameters': visibleAndFormattedParameters, // Already formatted and filtered by ReportUI
      'companyNameForHeader': _companyNameForHeader, // Pass the company name
      // 'totalPlutoConfiguredWidth': totalPlutoConfiguredWidth, // Node.js now calculates this dynamically
    };

    try {
      final response = await http.post(
        Uri.parse('$_pdfApiBaseUrl/generate-pdf'), // <<-- USING THE DEFINED API URL
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        print('Node.js PDF API responded successfully, exportId=$_exportId. File size: ${response.bodyBytes.length} bytes.');
        return response.bodyBytes;
      } else {
        final errorMessage = 'Failed to generate PDF on server: ${response.statusCode} - ${response.body}';
        print(errorMessage);
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error calling Node.js PDF API: $e, exportId=$_exportId');
      rethrow; // Re-throw to be caught by _executeExportTask
    }
  }

  // --- Export to Excel --- (Modified to pass more params to isolate)
  Future<void> _exportToExcel(BuildContext context) async {
    await _executeExportTask(context, () async {
      final List<Map<String, dynamic>> serializableColumns = widget.columns.map((col) => {
        'field': col.field,
        'title': col.title,
        'type': col.type.runtimeType.toString(),
        'width': col.width,
      }).toList();

      final List<Map<String, dynamic>> serializableRows = widget.plutoRows.map((row) => {
        'cells': row.cells.map((key, value) => MapEntry(key, value.value)),
        '__isSubtotal__': row.cells.containsKey('__isSubtotal__') ? row.cells['__isSubtotal__']!.value : false,
      }).toList();

      print('ExportToExcel: Calling compute to generate Excel, exportId=$_exportId');
      final excelBytes = await compute(_generateExcel, {
        'columns': serializableColumns,
        'rows': serializableRows,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'displayParameterValues': widget.displayParameterValues, // Already formatted and filtered
        'companyNameForHeader': _companyNameForHeader, // Pass the company name
      });

      print('ExportToExcel: Saving Excel file using FileSaver, exportId=$_exportId');
      final fileName = '${widget.fileName}.xlsx';
      final result = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: excelBytes,
        mimeType: MimeType.microsoftExcel,
      );
      print('ExportToExcel: File saved with result: $result, fileName: $fileName, exportId=$_exportId');
      DownloadTracker.trackDownload(fileName, 'file_saver', _exportId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exported to Excel successfully!')),
        );
      }
    }, 'Export to Excel');
  }

  // --- Export to PDF (Download) --- (MODIFIED to use API)
  Future<void> _exportToPDF(BuildContext context) async {
    await _executeExportTask(context, () async {
      print('ExportToPDF: Calling Node.js API to generate PDF, exportId=$_exportId');
      final pdfBytes = await _callPdfGenerationApi(); // <<-- CALLS THE API HERE

      print('ExportToPDF: Saving PDF file using FileSaver, exportId=$_exportId');
      final fileName = '${widget.fileName}.pdf';
      final result = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: pdfBytes,
        mimeType: MimeType.pdf,
      );
      print('ExportToPDF: File saved with result: $result, fileName: $fileName, exportId=$_exportId');
      DownloadTracker.trackDownload(fileName, 'file_saver', _exportId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exported to PDF successfully!')),
        );
      }
    }, 'Export to PDF');
  }

  // --- Print Document --- (MODIFIED to use API)
  Future<void> _printDocument(BuildContext context) async {
    await _executeExportTask(context, () async {
      print('PrintDocument: Calling Node.js API to generate PDF for printing, exportId=$_exportId');
      final pdfBytes = await _callPdfGenerationApi(); // <<-- CALLS THE API HERE

      if (kIsWeb) {
        print('PrintDocument: Platform is web. Using Printing.layoutPdf for direct browser print dialog, exportId=$_exportId');
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: '${widget.fileName}_Print.pdf',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Browser print dialog opened.')),
          );
        }
      } else {
        print('PrintDocument: Platform is not web. Using Printing.sharePdf to trigger system print/share dialog, exportId=$_exportId');
        await Printing.sharePdf(bytes: pdfBytes, filename: '${widget.fileName}_Print.pdf');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF prepared. Select a printer from the system dialog.')),
          );
        }
      }
    }, 'Print Document');
  }

  // --- Send to Email --- (MODIFIED to use API for PDF, and pass updated params to Excel isolate)
  Future<void> _sendToEmail(BuildContext context) async {
    await _executeExportTask(context, () async {
      print('SendToEmail: Showing email input dialog, exportId=$_exportId');
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
                print('SendToEmail: User pressed Cancel in email dialog, exportId=$_exportId');
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                print('SendToEmail: User pressed Send with email: ${emailController.text}, exportId=$_exportId');
                if (emailController.text.isNotEmpty &&
                    RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text)) {
                  print('SendToEmail: Email is valid, proceeding, exportId=$_exportId');
                  Navigator.of(context).pop(true);
                } else {
                  print('SendToEmail: Invalid email address entered, exportId=$_exportId');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid email address!')),
                    );
                  }
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      );

      print('SendToEmail: Dialog result: shouldSend=$shouldSend, exportId=$_exportId');
      if (shouldSend != true) {
        print('SendToEmail: Email sending cancelled by user, exportId=$_exportId');
        throw Exception('Email sending cancelled by user.');
      }

      // Generate Excel file (still client-side via compute)
      print('SendToEmail: Generating Excel file for email attachment, exportId=$_exportId');
      final List<Map<String, dynamic>> serializableColumnsForExcel = widget.columns.map((col) => {
        'field': col.field,
        'title': col.title,
        'type': col.type.runtimeType.toString(),
        'width': col.width,
      }).toList();
      final List<Map<String, dynamic>> serializableRowsForExcel = widget.plutoRows.map((row) => {
        'cells': row.cells.map((key, value) => MapEntry(key, value.value)),
        '__isSubtotal__': row.cells.containsKey('__isSubtotal__') ? row.cells['__isSubtotal__']!.value : false,
      }).toList();

      final excelBytes = await compute(_generateExcel, {
        'columns': serializableColumnsForExcel,
        'rows': serializableRowsForExcel,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'displayParameterValues': widget.displayParameterValues, // Already formatted and filtered
        'companyNameForHeader': _companyNameForHeader, // Pass the company name
      });

      // Generate PDF file (now via API)
      print('SendToEmail: Generating PDF file for email attachment via API, exportId=$_exportId');
      final pdfBytes = await _callPdfGenerationApi(); // <<-- CALLS THE API HERE

      print('SendToEmail: Preparing multipart HTTP request, exportId=$_exportId');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost/sendmail.php'), // <<-- THIS IS YOUR BACKEND EMAIL API. UPDATE IF NEEDED.
      );

      request.fields['email'] = emailController.text;

      request.files.add(http.MultipartFile.fromBytes(
        'excel',
        excelBytes,
        filename: '${widget.fileName}.xlsx',
        contentType: MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      ));

      request.files.add(http.MultipartFile.fromBytes(
        'pdf',
        pdfBytes,
        filename: '${widget.fileName}.pdf',
        contentType: MediaType('application', 'pdf'),
      ));

      print('SendToEmail: Sending HTTP request to backend, exportId=$_exportId');
      final response = await request.send();
      final responseString = await response.stream.bytesToString();
      print('SendToEmail: HTTP response status code: ${response.statusCode}, Response: $responseString, exportId=$_exportId');

      if (response.statusCode == 200 && responseString.contains('Success')) {
        print('SendToEmail: Files sent to email successfully, exportId=$_exportId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Files sent to email successfully!')),
          );
        }
      } else {
        print('SendToEmail: Failed to send email. Status: ${response.statusCode}, Response: $responseString, exportId=$_exportId');
        throw Exception('Server failed to send email: ${responseString.isNotEmpty ? responseString : 'Unknown error'}');
      }
    }, 'Send to Email');
  }

  // --- Static Helper for Number Formatting (Used by Excel only now, but kept for consistency if needed elsewhere) ---
  static String _formatNumber(double number, int decimalPoints, {bool indianFormat = false}) {
    String pattern = '##,##,##0';
    if (decimalPoints > 0) {
      pattern += '.${'0' * decimalPoints}';
    }

    final NumberFormat formatter = NumberFormat(
      pattern,
      indianFormat ? 'en_IN' : 'en_US',
    );
    return formatter.format(number);
  }

  // --- _generateExcel function (static for compute) --- (MODIFIED for company name)
  static Uint8List _generateExcel(Map<String, dynamic> params) {
    final exportId = params['exportId'] as String;
    print('GenerateExcel: Starting Excel generation in isolate, exportId=$exportId');
    final columns = params['columns'] as List<Map<String, dynamic>>;
    final rows = params['rows'] as List<Map<String, dynamic>>;
    final fieldConfigs = params['fieldConfigs'] as List<Map<String, dynamic>>?;
    final reportLabel = params['reportLabel'] as String;
    final displayParameterValues = params['displayParameterValues'] as Map<String, String>; // Already filtered
    final companyNameForHeader = params['companyNameForHeader'] as String?; // NEW

    var excel = Excel.createExcel();
    var sheet = excel['Sheet1'];

    final List<String> fieldNames = [];
    final List<String> headerLabels = [];
    for (var col in columns) {
      if (col['field'] != '__actions__') {
        fieldNames.add(col['field'].toString());
        headerLabels.add(col['title'].toString());
      }
    }

    int maxCols = headerLabels.length;

    // NEW: Add Company Name if available
    if (companyNameForHeader != null && companyNameForHeader.isNotEmpty) {
      sheet.appendRow([TextCellValue(companyNameForHeader)]);
      // Merge cells for the company name header
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1),
          CellIndex.indexByColumnRow(columnIndex: maxCols - 1, rowIndex: sheet.maxRows - 1));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle = CellStyle(
        fontFamily: 'Calibri',
        fontSize: 14, // Slightly smaller than report label
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      sheet.appendRow([]); // Empty row for spacing
    }

    // Add Report Label
    sheet.appendRow([TextCellValue(reportLabel)]);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1),
        CellIndex.indexByColumnRow(columnIndex: maxCols - 1, rowIndex: sheet.maxRows - 1));
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle = CellStyle(
      fontFamily: 'Calibri',
      fontSize: 18,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    sheet.appendRow([]); // Empty row for spacing

    // Use the already filtered displayParameterValues (only non-empty, visible params)
    if (displayParameterValues.isNotEmpty) {
      for (var entry in displayParameterValues.entries) {
        // No additional check for entry.value.isNotEmpty needed here as ReportUI already ensures it
        sheet.appendRow([TextCellValue('${entry.key}: ${entry.value}')]);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle = CellStyle(
          fontFamily: 'Calibri',
          fontSize: 10,
        );
      }
      sheet.appendRow([]); // Empty row for spacing after parameters
    }

    if (rows.isEmpty) {
      print('GenerateExcel: Empty rows provided, returning Excel with headers and title, exportId=$exportId');
      sheet.appendRow([TextCellValue('No data available')]);
      return Uint8List.fromList(excel.encode() ?? []);
    }

    print('GenerateExcel: Populating Excel data, exportId=$exportId');
    final excelContentStartTime = DateTime.now();

    sheet.appendRow(headerLabels.map((header) => TextCellValue(header)).toList());
    final headerRowIndex = sheet.maxRows - 1;
    for (int i = 0; i < headerLabels.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRowIndex)).cellStyle = CellStyle(
        fontFamily: 'Calibri',
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    final Map<String, Map<String, dynamic>> fieldConfigMap = {
      for (var config in (fieldConfigs ?? [])) config['Field_name']?.toString() ?? '': config
    };

    List<Map<String, dynamic>> dataRowsForGrandTotal = [];
    for (var rowData in rows) {
      final isSubtotalRow = rowData.containsKey('__isSubtotal__') ? rowData['__isSubtotal__'] : false;

      final rowValues = fieldNames.map((fieldName) {
        final rawValue = rowData['cells'][fieldName];
        final config = fieldConfigMap[fieldName];

        final isNumeric = [
          'VQ_GrandTotal',
          'Qty',
          'Rate',
          'NetRate',
          'GrandTotal',
          'Value',
          'Amount',
          'Excise',
          'Cess',
          'HSCess',
          'Freight',
          'TCS',
          'CGST',
          'SGST',
          'IGST'
        ].contains(fieldName) ||
            (config?['data_type']?.toString().toLowerCase() == 'number');
        final decimalPoints = int.tryParse(config?['decimal_points']?.toString() ?? '0') ?? 0;
        final indianFormat = config?['indian_format']?.toString() == '1';

        if (isSubtotalRow && fieldName == fieldNames[0]) {
          return TextCellValue(rawValue?.toString() ?? 'Subtotal');
        } else if (isNumeric && rawValue != null) {
          final doubleValue = double.tryParse(rawValue.toString()) ?? 0.0;
          return TextCellValue(_formatNumber(doubleValue, decimalPoints, indianFormat: indianFormat));
        } else if (config?['image']?.toString() == '1' &&
            rawValue != null &&
            (rawValue.toString().startsWith('http://') || rawValue.toString().startsWith('https://'))) {
          // For Excel, just put the URL or a placeholder text
          return TextCellValue('Image Link: ${rawValue.toString()}');
        }
        return TextCellValue(rawValue?.toString() ?? '');
      }).toList();
      sheet.appendRow(rowValues);

      final dataRowIndex = sheet.maxRows - 1;
      for (int i = 0; i < fieldNames.length; i++) {
        final fieldName = fieldNames[i];
        final config = fieldConfigMap[fieldName];
        final alignment = config?['num_alignment']?.toString().toLowerCase() ?? 'left';
        final isNumeric = [
          'VQ_GrandTotal',
          'Qty',
          'Rate',
          'NetRate',
          'GrandTotal',
          'Value',
          'Amount',
          'Excise',
          'Cess',
          'HSCess',
          'Freight',
          'TCS',
          'CGST',
          'SGST',
          'IGST'
        ].contains(fieldName) ||
            (config?['data_type']?.toString().toLowerCase() == 'number');

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: dataRowIndex)).cellStyle = CellStyle(
          horizontalAlign: isNumeric
              ? (alignment == 'center' ? HorizontalAlign.Center : HorizontalAlign.Right)
              : HorizontalAlign.Left,
          bold: isSubtotalRow,
          fontFamily: 'Calibri',
        );
      }

      if (!isSubtotalRow) {
        dataRowsForGrandTotal.add(rowData);
      }
    }

    if (fieldConfigs != null && fieldConfigs.any((config) => config['Total']?.toString() == '1')) {
      final totalRowValues = fieldNames.map((fieldName) {
        final config = fieldConfigMap[fieldName];
        final total = config?['Total']?.toString() == '1';
        final isNumeric = [
          'VQ_GrandTotal',
          'Qty',
          'Rate',
          'NetRate',
          'GrandTotal',
          'Value',
          'Amount',
          'Excise',
          'Cess',
          'HSCess',
          'Freight',
          'TCS',
          'CGST',
          'SGST',
          'IGST'
        ].contains(fieldName) ||
            (config?['data_type']?.toString().toLowerCase() == 'number');
        final decimalPoints = int.tryParse(config?['decimal_points']?.toString() ?? '0') ?? 0;
        final indianFormat = config?['indian_format']?.toString() == '1';

        if (fieldNames.indexOf(fieldName) == 0) {
          return TextCellValue('Grand Total');
        } else if (total && isNumeric) {
          final sum = dataRowsForGrandTotal.fold<double>(0.0, (sum, row) {
            final value = row['cells'][fieldName];
            return sum + (double.tryParse(value?.toString() ?? '0') ?? 0.0);
          });
          return TextCellValue(_formatNumber(sum, decimalPoints, indianFormat: indianFormat));
        }
        return TextCellValue('');
      }).toList();
      sheet.appendRow(totalRowValues);

      final totalRowIndex = sheet.maxRows - 1;
      for (int i = 0; i < fieldNames.length; i++) {
        final fieldName = fieldNames[i];
        final config = fieldConfigMap[fieldName];
        final total = config?['Total']?.toString() == '1';
        final isNumeric = [
          'VQ_GrandTotal',
          'Qty',
          'Rate',
          'NetRate',
          'GrandTotal',
          'Value',
          'Amount',
          'Excise',
          'Cess',
          'HSCess',
          'Freight',
          'TCS',
          'CGST',
          'SGST',
          'IGST'
        ].contains(fieldName) ||
            (config?['data_type']?.toString().toLowerCase() == 'number');
        final alignment = config?['num_alignment']?.toString().toLowerCase() ?? 'left';

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: totalRowIndex)).cellStyle = CellStyle(
          fontFamily: 'Calibri',
          bold: true,
          horizontalAlign: i == 0
              ? HorizontalAlign.Left
              : (total && isNumeric
              ? (alignment == 'center' ? HorizontalAlign.Center : HorizontalAlign.Right)
              : HorizontalAlign.Left),
        );
      }
    }

    for (var i = 0; i < fieldNames.length; i++) {
      final fieldName = fieldNames[i];
      final config = fieldConfigMap[fieldName];
      final width = double.tryParse(config?['width']?.toString() ?? '100') ?? 100.0;
      sheet.setColumnWidth(i, width / 6);
    }

    final excelBytes = Uint8List.fromList(excel.encode() ?? []);
    final excelContentEndTime = DateTime.now();
    print('GenerateExcel: Excel content generation and encoding took ${excelContentEndTime.difference(excelContentStartTime).inMilliseconds} ms, exportId=$exportId');
    print('GenerateExcel: Excel generation completed, returning bytes, exportId=$exportId');

    return excelBytes;
  }
}