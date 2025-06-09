import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:file_saver/file_saver.dart'; // FileSaver supports web and non-web platforms for saving files
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:printing/printing.dart'; // Handles printing (web and non-web)
import 'dart:html' as html; // Only available for web; used for specific web print/download behaviors if needed
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
  final List<Map<String, dynamic>>? apiParameters;
  final Map<String, List<Map<String, String>>>? pickerOptions;

  const ExportWidget({
    required this.columns,
    required this.plutoRows,
    required this.fileName,
    this.fieldConfigs,
    required this.reportLabel,
    required this.parameterValues,
    this.apiParameters,
    this.pickerOptions,
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

  @override
  void initState() {
    super.initState();
    print('ExportWidget: Initialized with exportId=$_exportId, fileName=${widget.fileName}');
  }

  @override
  Widget build(BuildContext context) {
    // Determine if export buttons should be enabled: data must not be empty AND no global export in progress.
    final bool canExport = widget.plutoRows.isNotEmpty && !ExportLock.isExporting;

    print('ExportWidget: Building with exportId=$_exportId, dataLength=${widget.plutoRows.length}, ExportLock.isExporting=${ExportLock.isExporting}');

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

  // --- Common Export Logic Wrapper ---
  // This helper function centralizes the lock management and loader display
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

    // Show loader right after the UI update to disabled buttons
    // Using a Future.delayed ensures the UI has a moment to redraw before dialog appears
    // This reduces the 'lag' perception for very fast operations
    bool dialogShown = false;
    if (context.mounted) {
      Future.delayed(Duration.zero, () { // Use Duration.zero to schedule after current frame
        if (context.mounted && ExportLock.isExporting) { // Double check if still exporting and context is valid
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
      // Provide more specific error messages for PDF if possible
      if (taskName.contains('PDF') && e.toString().contains('TooManyPagesException')) {
        errorMessage = 'PDF export failed: The report is too large to render. Please try filtering data or contact support.';
      } else if (taskName.contains('PDF') && e.toString().contains('Memory')) { // Generic memory error
        errorMessage = 'PDF export failed due to insufficient memory for a very large report. Try reducing data or contact support.';
      }
      else {
        errorMessage = 'Failed to $taskName: $e';
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      // Only pop the dialog if it was successfully shown.
      // This prevents "Navigator.pop called on a null route" errors
      // if the export finished before the dialog even had a chance to render.
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

  // --- Export to Excel ---
  Future<void> _exportToExcel(BuildContext context) async {
    await _executeExportTask(context, () async {
      // Prepare serializable data for compute
      final List<Map<String, dynamic>> serializableColumns = widget.columns.map((col) => {
        'field': col.field,
        'title': col.title,
        'type': col.type.runtimeType.toString(), // Simple type representation
        'width': col.width,
      }).toList();

      final List<Map<String, dynamic>> serializableRows = widget.plutoRows.map((row) => {
        'cells': row.cells.map((key, value) => MapEntry(key, value.value)),
        '__isSubtotal__': row.cells.containsKey('__isSubtotal__') ? row.cells['__isSubtotal__']!.value : false,
      }).toList();

      print('ExportToExcel: Calling compute to generate Excel, exportId=$_exportId');
      final excelStartTime = DateTime.now();
      final excelBytes = await compute(_generateExcel, {
        'columns': serializableColumns,
        'rows': serializableRows,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'parameterValues': widget.parameterValues,
        'apiParameters': widget.apiParameters,
        'pickerOptions': widget.pickerOptions,
      });
      final excelEndTime = DateTime.now();
      print('ExportToExcel: Excel generation took ${excelEndTime.difference(excelStartTime).inMilliseconds} ms, exportId=$_exportId');
      print('ExportToExcel: Generated Excel file size: ${excelBytes.length} bytes, exportId=$_exportId');

      // Use FileSaver for both web and non-web platforms to download the file
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

  // --- Export to PDF (Download) ---
  Future<void> _exportToPDF(BuildContext context) async {
    await _executeExportTask(context, () async {
      // Collect parameters into a map for compute
      final Map<String, String> visibleAndFormattedParameters = _getVisibleAndFormattedParameters();

      // Prepare serializable data for compute
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

      print('ExportToPDF: Calling compute to generate PDF, exportId=$_exportId');
      final pdfStartTime = DateTime.now();
      final pdfBytes = await compute(_generatePDF, {
        'columns': serializableColumns,
        'rows': serializableRows,
        'fileName': widget.fileName,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'parameterValues': widget.parameterValues,
        'apiParameters': widget.apiParameters,
        'pickerOptions': widget.pickerOptions,
        'visibleAndFormattedParameters': visibleAndFormattedParameters,
      });
      final pdfEndTime = DateTime.now();
      print('ExportToPDF: PDF generation took ${pdfEndTime.difference(pdfStartTime).inMilliseconds} ms, exportId=$_exportId');

      // Use FileSaver for both web and non-web platforms to download the file
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

  // --- Print Document ---
  Future<void> _printDocument(BuildContext context) async {
    await _executeExportTask(context, () async {
      final Map<String, String> visibleAndFormattedParameters = _getVisibleAndFormattedParameters();

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

      print('PrintDocument: Calling compute to generate PDF for printing, exportId=$_exportId');
      final pdfStartTime = DateTime.now();
      final pdfBytes = await compute(_generatePDF, {
        'columns': serializableColumns,
        'rows': serializableRows,
        'fileName': widget.fileName,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'parameterValues': widget.parameterValues,
        'apiParameters': widget.apiParameters,
        'pickerOptions': widget.pickerOptions,
        'visibleAndFormattedParameters': visibleAndFormattedParameters,
      });
      final pdfEndTime = DateTime.now();
      print('PrintDocument: PDF generation for print took ${pdfEndTime.difference(pdfStartTime).inMilliseconds} ms, exportId=$_exportId');

      if (kIsWeb) {
        print('PrintDocument: Platform is web. Using Printing.layoutPdf for direct browser print dialog, exportId=$_exportId');
        // On web, this directly opens the browser's print preview/dialog.
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
        // On non-web (mobile/desktop), Printing.sharePdf opens the native share sheet,
        // which typically includes a "Print" option among others. This gives the user control.
        await Printing.sharePdf(bytes: pdfBytes, filename: '${widget.fileName}_Print.pdf');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF prepared. Select a printer from the system dialog.')),
          );
        }
      }
    }, 'Print Document');
  }

  // --- Send to Email ---
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
        throw Exception('Email sending cancelled by user.'); // Throw to enter finally block of _executeExportTask
      }

      final Map<String, String> visibleAndFormattedParameters = _getVisibleAndFormattedParameters();

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

      // Generate Excel file
      print('SendToEmail: Generating Excel file for email attachment, exportId=$_exportId');
      final excelBytes = await compute(_generateExcel, {
        'columns': serializableColumns,
        'rows': serializableRows,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'parameterValues': widget.parameterValues,
        'apiParameters': widget.apiParameters,
        'pickerOptions': widget.pickerOptions,
      });

      // Generate PDF file
      print('SendToEmail: Generating PDF file for email attachment, exportId=$_exportId');
      final pdfBytes = await compute(_generatePDF, {
        'columns': serializableColumns,
        'rows': serializableRows,
        'fileName': widget.fileName,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'parameterValues': widget.parameterValues,
        'apiParameters': widget.apiParameters,
        'pickerOptions': widget.pickerOptions,
        'visibleAndFormattedParameters': visibleAndFormattedParameters,
      });

      print('SendToEmail: Preparing multipart HTTP request, exportId=$_exportId');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost/sendmail.php'), // Placeholder: Replace with your actual backend endpoint
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

  // Helper method to format parameters for display in PDF/Excel header
  Map<String, String> _getVisibleAndFormattedParameters() {
    final Map<String, String> formattedParams = <String, String>{};
    if (widget.apiParameters != null) {
      for (var param in widget.apiParameters!) {
        final paramName = param['name']?.toString();
        if (paramName != null && param['show'] == true && widget.parameterValues.containsKey(paramName)) {
          final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : paramName;
          final String rawValue = widget.parameterValues[paramName]!;

          String displayValue = rawValue;

          final isPickerField = param['master_table'] != null && param['master_table'].toString().isNotEmpty &&
              param['master_field'] != null && param['master_field'].toString().isNotEmpty &&
              param['display_field'] != null && param['display_field'].toString().isNotEmpty;

          if (isPickerField && widget.pickerOptions != null && widget.pickerOptions!.containsKey(paramName)) {
            final foundOption = widget.pickerOptions![paramName]?.firstWhere(
                  (opt) => opt['value'] == rawValue,
              orElse: () => {'label': rawValue, 'value': rawValue},
            );
            displayValue = foundOption!['label']!;
          } else if ((param['type']?.toString().toLowerCase() == 'date') && rawValue.isNotEmpty) {
            try {
              final DateTime parsedDate = DateTime.parse(rawValue);
              displayValue = DateFormat('dd-MMM-yyyy').format(parsedDate);
            } catch (e) {
              // If parsing fails, use the rawValue as is
            }
          }
          formattedParams[paramLabel] = displayValue;
        }
      }
    } else {
      formattedParams.addAll(widget.parameterValues);
    }
    return formattedParams;
  }

  // --- Static Helper for Number Formatting (Used by Excel and PDF) ---
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

  // --- _generateExcel function (static for compute) ---
  static Uint8List _generateExcel(Map<String, dynamic> params) {
    final exportId = params['exportId'] as String;
    print('GenerateExcel: Starting Excel generation in isolate, exportId=$exportId');
    final columns = params['columns'] as List<Map<String, dynamic>>;
    final rows = params['rows'] as List<Map<String, dynamic>>;
    final fieldConfigs = params['fieldConfigs'] as List<Map<String, dynamic>>?;
    final reportLabel = params['reportLabel'] as String;
    final parameterValues = params['parameterValues'] as Map<String, String>;
    final apiParameters = params['apiParameters'] as List<Map<String, dynamic>>?;
    final pickerOptions = params['pickerOptions'] as Map<String, List<Map<String, String>>>?;

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
    sheet.appendRow([]);

    final Map<String, String> visibleAndFormattedParameters = {};
    if (apiParameters != null) {
      for (var param in apiParameters) {
        final paramName = param['name']?.toString();
        if (paramName != null && param['show'] == true && parameterValues.containsKey(paramName)) {
          final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : paramName;
          final String rawValue = parameterValues[paramName]!;
          String displayValue = rawValue;

          final isPickerField = param['master_table'] != null && param['master_table'].toString().isNotEmpty &&
              param['master_field'] != null && param['master_field'].toString().isNotEmpty &&
              param['display_field'] != null && param['display_field'].toString().isNotEmpty;

          if (isPickerField && pickerOptions != null && pickerOptions.containsKey(paramName)) {
            final foundOption = pickerOptions[paramName]?.firstWhere(
                  (opt) => opt['value'] == rawValue,
              orElse: () => {'label': rawValue, 'value': rawValue},
            );
            displayValue = foundOption!['label']!;
          } else if ((param['type']?.toString().toLowerCase() == 'date') && rawValue.isNotEmpty) {
            try {
              final DateTime parsedDate = DateTime.parse(rawValue);
              displayValue = DateFormat('dd-MMM-yyyy').format(parsedDate);
            } catch (e) {
              // If parsing fails, use the rawValue as is
            }
          }
          visibleAndFormattedParameters[paramLabel] = displayValue;
        }
      }
    } else {
      visibleAndFormattedParameters.addAll(parameterValues);
    }

    if (visibleAndFormattedParameters.isNotEmpty) {
      for (var entry in visibleAndFormattedParameters.entries) {
        sheet.appendRow([TextCellValue('${entry.key}: ${entry.value}')]);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle = CellStyle(
          fontFamily: 'Calibri',
          fontSize: 10,
        );
      }
      sheet.appendRow([]);
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

        final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount', 'Excise', 'Cess', 'HSCess', 'Freight', 'TCS'].contains(fieldName) ||
            (config?['data_type']?.toString().toLowerCase() == 'number');
        final decimalPoints = int.tryParse(config?['decimal_points']?.toString() ?? '0') ?? 0;
        final indianFormat = config?['indian_format']?.toString() == '1';

        if (isSubtotalRow && fieldName == fieldNames[0]) {
          return TextCellValue(rawValue?.toString() ?? 'Subtotal');
        } else if (isNumeric && rawValue != null) {
          final doubleValue = double.tryParse(rawValue.toString()) ?? 0.0;
          return TextCellValue(_formatNumber(doubleValue, decimalPoints, indianFormat: indianFormat));
        } else if (config?['image']?.toString() == '1' && rawValue != null && (rawValue.toString().startsWith('http://') || rawValue.toString().startsWith('https://'))) {
          return TextCellValue(rawValue.toString());
        }
        return TextCellValue(rawValue?.toString() ?? '');
      }).toList();
      sheet.appendRow(rowValues);

      final dataRowIndex = sheet.maxRows - 1;
      for (int i = 0; i < fieldNames.length; i++) {
        final fieldName = fieldNames[i];
        final config = fieldConfigMap[fieldName];
        final alignment = config?['num_alignment']?.toString().toLowerCase() ?? 'left';
        final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount', 'Excise', 'Cess', 'HSCess', 'Freight', 'TCS'].contains(fieldName) ||
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
        final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount', 'Excise', 'Cess', 'HSCess', 'Freight', 'TCS'].contains(fieldName) ||
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
        final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount', 'Excise', 'Cess', 'HSCess', 'Freight', 'TCS'].contains(fieldName) ||
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

  // --- _generatePDF function (static for compute) ---
  static Future<Uint8List> _generatePDF(Map<String, dynamic> params) async {
    final exportId = params['exportId'] as String;
    print('GeneratePDF: Starting PDF generation in isolate, exportId=$exportId');
    final columns = params['columns'] as List<Map<String, dynamic>>;
    final rows = params['rows'] as List<Map<String, dynamic>>;
    final fieldConfigs = params['fieldConfigs'] as List<Map<String, dynamic>>?;
    final reportLabel = params['reportLabel'] as String;
    final visibleAndFormattedParameters = params['visibleAndFormattedParameters'] as Map<String, String>;

    if (rows.isEmpty) {
      print('GeneratePDF: Empty rows provided, returning empty PDF, exportId=$exportId');
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Text(
              'No data available',
              style: pw.TextStyle(fontSize: 12),
            ),
          ),
        ),
      );
      return await pdf.save();
    }

    print('GeneratePDF: Rows length: ${rows.length} rows, exportId=$exportId');
    final List<String> originalFieldNames = columns.map((col) => col['field'].toString()).toList();
    final List<String> originalHeaderLabels = columns.map((col) => col['title'].toString()).toList();

    final List<String> fieldNames = [];
    final List<String> headerLabels = [];
    for(int i = 0; i < originalFieldNames.length; i++) {
      if (originalFieldNames[i] != '__actions__') {
        fieldNames.add(originalFieldNames[i]);
        headerLabels.add(originalHeaderLabels[i]);
      }
    }
    print('GeneratePDF: Filtered headers (count: ${headerLabels.length}): $headerLabels, exportId=$exportId');

    final pdf = pw.Document();
    const fontSize = 8.0;
    const headerFontSize = 10.0;
    const reportLabelFontSize = 14.0;

    print('GeneratePDF: Loading font, exportId=$exportId');
    pw.Font font;
    try {
      // Only load once
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      font = pw.Font.ttf(fontData);
      print('GeneratePDF: Font loaded successfully, exportId=$exportId');
    } catch (e) {
      print('GeneratePDF: Failed to load font: $e, using Helvetica fallback, exportId=$exportId');
      font = pw.Font.helvetica();
    }

    final Map<String, Map<String, dynamic>> fieldConfigMap = {
      for (var config in (fieldConfigs ?? [])) config['Field_name']?.toString() ?? '': config
    };

    double totalPlutoConfiguredWidth = 0.0;
    for (var col in columns) {
      if (col['field'] != '__actions__') {
        totalPlutoConfiguredWidth += (col['width'] as double? ?? 100.0);
      }
    }
    if (totalPlutoConfiguredWidth == 0) {
      totalPlutoConfiguredWidth = fieldNames.length * 100.0;
    }

    final Map<int, pw.TableColumnWidth> columnWidths = {};
    for (int i = 0; i < fieldNames.length; i++) {
      final fieldName = fieldNames[i];
      final originalCol = columns.firstWhere((col) => col['field'] == fieldName);
      columnWidths[i] = pw.FlexColumnWidth((originalCol['width'] as double? ?? 100.0) / totalPlutoConfiguredWidth);
    }
    print('GeneratePDF: Calculated column widths for PDF table, exportId=$exportId');

    final List<pw.TableRow> tableRows = [];

    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColors.blueGrey100,
        ),
        children: headerLabels.map((headerLabel) {
          final fieldName = fieldNames[headerLabels.indexOf(headerLabel)];
          final config = fieldConfigMap[fieldName];
          final alignment = config?['num_alignment']?.toString().toLowerCase();

          pw.TextAlign headerTextAlign = pw.TextAlign.center;
          if (alignment == 'left') {
            headerTextAlign = pw.TextAlign.left;
          } else if (alignment == 'right') {
            headerTextAlign = pw.TextAlign.right;
          }

          return pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.center,
            child: pw.Text(
              headerLabel,
              style: pw.TextStyle(
                font: font,
                fontWeight: pw.FontWeight.bold,
                fontSize: headerFontSize,
              ),
              textAlign: headerTextAlign,
            ),
          );
        }).toList(),
      ),
    );
    print('GeneratePDF: Added header row to PDF tableRows, exportId=$exportId');

    List<Map<String, dynamic>> dataRowsForGrandTotal = [];
    print('GeneratePDF: Starting to add data rows to PDF tableRows, exportId=$exportId');
    final dataRowsStartTime = DateTime.now();
    for (var rowData in rows) {
      final isSubtotalRow = rowData.containsKey('__isSubtotal__') ? rowData['__isSubtotal__'] : false;

      tableRows.add(
        pw.TableRow(
          decoration: isSubtotalRow
              ? const pw.BoxDecoration(color: PdfColors.grey200)
              : (rows.indexOf(rowData) % 2 == 0
              ? const pw.BoxDecoration(color: PdfColors.white)
              : const pw.BoxDecoration(color: PdfColors.grey50)),
          children: fieldNames.map((fieldName) {
            final rawValue = rowData['cells'][fieldName];
            final config = fieldConfigMap[fieldName];

            final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount', 'Excise', 'Cess', 'HSCess', 'Freight', 'TCS'].contains(fieldName) ||
                (config?['data_type']?.toString().toLowerCase() == 'number');
            final decimalPoints = int.tryParse(config?['decimal_points']?.toString() ?? '0') ?? 0;
            final indianFormat = config?['indian_format']?.toString() == '1';
            final alignment = config?['num_alignment']?.toString().toLowerCase();
            final isImageColumn = config?['image']?.toString() == '1';

            String displayValue = rawValue?.toString() ?? '';

            pw.Widget cellContent;

            if (isImageColumn && displayValue.isNotEmpty && (displayValue.startsWith('http://') || displayValue.startsWith('https://'))) {
              // OPTIMIZATION: For print/PDF, large number of images from URLs can cause memory issues.
              // Instead of attempting to load/embed, display a placeholder or the URL.
              cellContent = pw.Text(
                '[Image]', // Or displayValue if you prefer the URL text
                style: pw.TextStyle(font: font, fontSize: fontSize, color: PdfColors.blue, decoration: pw.TextDecoration.underline),
                overflow: pw.TextOverflow.clip,
                maxLines: 1,
              );
            } else if (isNumeric && rawValue != null) {
              final doubleValue = double.tryParse(rawValue.toString()) ?? 0.0;
              displayValue = _formatNumber(doubleValue, decimalPoints, indianFormat: indianFormat);
              cellContent = pw.Text(
                displayValue,
                style: pw.TextStyle(
                  font: font,
                  fontSize: fontSize,
                  fontWeight: isSubtotalRow ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
                textAlign: alignment == 'center'
                    ? pw.TextAlign.center
                    : alignment == 'right'
                    ? pw.TextAlign.right
                    : pw.TextAlign.left,
              );
            } else {
              cellContent = pw.Text(
                displayValue,
                style: pw.TextStyle(
                  font: font,
                  fontSize: fontSize,
                  fontWeight: isSubtotalRow ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
                textAlign: isSubtotalRow && fieldName == fieldNames[0]
                    ? pw.TextAlign.left
                    : alignment == 'center'
                    ? pw.TextAlign.center
                    : alignment == 'right'
                    ? pw.TextAlign.right
                    : pw.TextAlign.left,
              );
            }
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              alignment: (alignment == 'center') ? pw.Alignment.center :
              (alignment == 'right') ? pw.Alignment.centerRight :
              pw.Alignment.centerLeft,
              child: cellContent,
            );
          }).toList(),
        ),
      );
      if (!isSubtotalRow) {
        dataRowsForGrandTotal.add(rowData);
      }
    }
    final dataRowsEndTime = DateTime.now();
    print('GeneratePDF: Added all data rows (including subtotals) to PDF tableRows in ${dataRowsEndTime.difference(dataRowsStartTime).inMilliseconds} ms, exportId=$exportId');

    final bool hasGrandTotals = fieldConfigs != null && fieldConfigs.any((config) => config['Total']?.toString() == '1');
    if (hasGrandTotals) {
      print('GeneratePDF: Calculating and adding grand total row, exportId=$exportId');
      final List<String> grandTotalValues = fieldNames.map((fieldName) {
        final config = fieldConfigMap[fieldName];
        final total = config?['Total']?.toString() == '1';
        final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount', 'Excise', 'Cess', 'HSCess', 'Freight', 'TCS'].contains(fieldName) ||
            (config?['data_type']?.toString().toLowerCase() == 'number');
        final decimalPoints = int.tryParse(config?['decimal_points']?.toString() ?? '0') ?? 0;
        final indianFormat = config?['indian_format']?.toString() == '1';

        if (fieldNames.indexOf(fieldName) == 0) {
          return 'Grand Total';
        } else if (total && isNumeric) {
          final sum = dataRowsForGrandTotal.fold<double>(0.0, (sum, row) {
            final value = row['cells'][fieldName];
            return sum + (double.tryParse(value?.toString() ?? '0') ?? 0.0);
          });
          return _formatNumber(sum, decimalPoints, indianFormat: indianFormat);
        }
        return '';
      }).toList();
      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.blueGrey50,
          ),
          children: grandTotalValues.asMap().entries.map((entry) {
            final i = entry.key;
            final value = entry.value;

            final fieldName = fieldNames[i];
            final config = fieldConfigMap[fieldName];
            final total = config?['Total']?.toString() == '1';
            final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount', 'Excise', 'Cess', 'HSCess', 'Freight', 'TCS'].contains(fieldName) ||
                (config?['data_type']?.toString().toLowerCase() == 'number');
            final alignment = config?['num_alignment']?.toString().toLowerCase();

            pw.TextAlign totalTextAlign = pw.TextAlign.left;
            if (i == 0) {
              totalTextAlign = pw.TextAlign.left;
            } else if (isNumeric && alignment == 'center') {
              totalTextAlign = pw.TextAlign.center;
            } else if (isNumeric && alignment == 'right') {
              totalTextAlign = pw.TextAlign.right;
            } else if (isNumeric) {
              totalTextAlign = pw.TextAlign.right;
            }

            return pw.Container(
              padding: const pw.EdgeInsets.all(4),
              alignment: (totalTextAlign == pw.TextAlign.left) ? pw.Alignment.centerLeft :
              (totalTextAlign == pw.TextAlign.right) ? pw.Alignment.centerRight :
              pw.Alignment.center,
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  font: font,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: headerFontSize,
                ),
                textAlign: totalTextAlign,
              ),
            );
          }).toList(),
        ),
      );
      print('GeneratePDF: Added grand total row to PDF tableRows, exportId=$exportId');
    }

    print('GeneratePDF: Adding page to PDF document, exportId=$exportId');
    final pdfBuildStartTime = DateTime.now();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape.copyWith(
          marginLeft: 20,
          marginRight: 20,
          marginTop: 20,
          marginBottom: 20,
        ),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Center(
                child: pw.Text(
                  reportLabel,
                  style: pw.TextStyle(
                    fontSize: reportLabelFontSize,
                    font: font,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              if (visibleAndFormattedParameters.isNotEmpty) ...[
                for (var entry in visibleAndFormattedParameters.entries)
                  pw.Text(
                    '${entry.key}: ${entry.value}',
                    style: pw.TextStyle(font: font, fontSize: fontSize),
                  ),
                pw.SizedBox(height: 10),
              ],
              pw.Align(
                alignment: pw.Alignment.topRight,
                child: pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(font: font, fontSize: fontSize),
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
        build: (pw.Context context) => [
          pw.Table(
            columnWidths: columnWidths,
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey500),
            children: tableRows,
          ),
        ],
      ),
    );
    final pdfBuildEndTime = DateTime.now();
    print('GeneratePDF: PDF page building took ${pdfBuildEndTime.difference(pdfBuildStartTime).inMilliseconds} ms, exportId=$exportId');

    print('GeneratePDF: Saving PDF, exportId=$exportId');
    final pdfSaveStartTime = DateTime.now();
    Uint8List pdfBytes;
    try {
      pdfBytes = await pdf.save(); // This is the final step where memory or serialization could be an issue
    } catch (e) {
      print('GeneratePDF: ERROR during pdf.save(): $e, exportId=$exportId');
      // Re-throw with more specific info if possible, or a custom exception
      throw Exception('PDF Save Error: $e'); // This will be caught by _executeExportTask
    }

    final pdfSaveEndTime = DateTime.now();
    print('GeneratePDF: PDF saving took ${pdfSaveEndTime.difference(pdfSaveStartTime).inMilliseconds} ms, exportId=$exportId');
    print('GeneratePDF: PDF generation completed, returning bytes (${pdfBytes.length} bytes), exportId=$exportId');

    return pdfBytes;
  }
}