// lib/ReportUtils/Export_widget.dart
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
import 'package:collection/collection.dart'; // Import for firstWhereOrNull


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
  final List<PlutoRow> plutoRows; // This now only contains data rows and subtotals. Grand total is in UI footer.
  final String fileName;
  final List<Map<String, dynamic>>? fieldConfigs;
  final String reportLabel;
  final Map<String, String> parameterValues;
  final Map<String, String> displayParameterValues; // Already filtered by ReportUI for visible & non-empty
  final List<Map<String, dynamic>>? apiParameters; // Full parameter definitions from demo_table
  final Map<String, List<Map<String, String>>>? pickerOptions;
  final String companyName;
  final bool includePdfFooterDateTime; // NEW: Added includePdfFooterDateTime

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
    required this.companyName,
    this.includePdfFooterDateTime=false , // NEW: Make required
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
  final String _exportId = UniqueKey().toString();

  static const String _pdfApiBaseUrl = 'https://pdf-node-kbfu8swqw-vishal-jains-projects-b322eb37.vercel.app/api/generate-pdf'; // Make sure this is your Node.js server URL

  @override
  void initState() {
    super.initState();
    print('ExportWidget: Initialized with exportId=$_exportId, fileName=${widget.fileName}');
  }

  String? get _companyNameForHeader {
    if (widget.companyName.isNotEmpty) {
      print('ExportWidget: Company name (from passed prop) found: ${widget.companyName}');
      return widget.companyName;
    }
    if (widget.apiParameters != null) {
      for (var param in widget.apiParameters!) {
        if (param['is_company_name_field'] == true) {
          final paramName = param['name'].toString();
          if (param['show'] == true) {
            final companyDisplayName = widget.displayParameterValues[paramName];
            if (companyDisplayName != null && companyDisplayName.isNotEmpty) {
              print('ExportWidget: Company name (from UI/visible param in fallback) found: $companyDisplayName');
              return companyDisplayName;
            }
          } else if (param['display_value_cache'] != null && param['display_value_cache'].toString().isNotEmpty) {
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
    final bool canExport = widget.plutoRows.isNotEmpty && !ExportLock.isExporting;
    print('ExportWidget: Building with exportId=$_exportId, dataLength=${widget.plutoRows.length}, ExportLock.isExporting=${ExportLock.isExporting}');
    print('ExportWidget: Derived company name for header: ${_companyNameForHeader ?? 'N/A'}');
    print('ExportWidget: includePdfFooterDateTime for PDF exports: ${widget.includePdfFooterDateTime}'); // NEW: Log for ExportWidget

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
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canExport ? Colors.green : Colors.grey,
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
                await _exportToPDF(context);
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
              await _printDebouncer.debounce(() async { // Using debouncer for print too
                await _printDocument(context);
              });
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

  // MODIFIED: _executeExportTask now accepts showLoaderDialog and initialMessage
  Future<void> _executeExportTask(
      BuildContext context,
      Future<void> Function() task,
      String taskName, {
        bool showLoaderDialog = true, // Default to true for blocking dialog
        String initialMessage = 'Processing...', // Default message for loader
      }) async {
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

    ExportLock.startExport();

    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? snackBarController;
    bool dialogShown = false;

    if (context.mounted) {
      // Show initial feedback (SnackBar for background, Dialog for blocking)
      if (!showLoaderDialog) {
        // Non-blocking SnackBar for background tasks (like PDF download)
        snackBarController = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(width: 16),
                Text(initialMessage, style: const TextStyle(color: Colors.white)),
              ],
            ),
            duration: const Duration(minutes: 5), // Long duration if not dismissed manually
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction( // ADDED: "Hide" action
              label: 'Hide',
              textColor: Colors.white,
              onPressed: () {
                // Manually dismiss the snackbar
                snackBarController?.close();
                print('$taskName: User manually hid the progress snackbar, exportId=$_exportId');
                // The background task will continue running.
              },
            ),
          ),
        );
        print('$taskName: Showing non-blocking SnackBar: "$initialMessage", exportId=$_exportId');
      } else {
        // Existing blocking Dialog for other tasks
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && ExportLock.isExporting) {
            print('$taskName: Showing loader dialog, exportId=$_exportId');
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(initialMessage, style: GoogleFonts.poppins(color: Colors.white)), // Now dialog also shows message
                  ],
                ),
              ),
            );
            dialogShown = true;
          }
        });
      }
    }


    try {
      await task(); // Execute the actual export task

      // After task completes successfully, if snackbar was shown, dismiss it and show success.
      if (context.mounted) {
        if (!showLoaderDialog && snackBarController != null) {
          snackBarController.close(); // Explicitly close the initial progress snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$taskName successful!')), // Show success message
          );
          print('$taskName: Successfully completed, showed success snackbar, exportId=$_exportId');
        }
      }
    } catch (e) {
      // Only show error message if the error is not a user cancellation
      if (!e.toString().contains('Email sending cancelled by user.')) { // Check for cancellation message
        print('$taskName: Exception caught: $e, exportId=$_exportId');
        String errorMessage = 'Failed to $taskName. Please try again.';
        if (e.toString().contains('Failed to generate PDF on server')) {
          errorMessage = 'PDF generation failed on server. Server response: ${e.toString().split("Server response:").last.trim()}';
        } else if (e.toString().contains('Connection refused')) {
          errorMessage = 'Could not connect to PDF server. Is it running?';
        } else if (e.toString().contains('Server failed to send email')) {
          errorMessage = 'Email sending failed. ${e.toString().split("Details:").last.trim()}';
        } else {
          errorMessage = 'Failed to $taskName: $e';
        }

        if (context.mounted) {
          if (!showLoaderDialog && snackBarController != null) {
            snackBarController.close(); // Explicitly close the initial progress snackbar on error
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } finally {
      // Always dismiss blocking dialog if it was shown
      if (dialogShown && context.mounted && Navigator.of(context).canPop()) {
        print('$taskName: Dismissing loader dialog, exportId=$_exportId');
        Navigator.of(context).pop();
      }
      // If we used a non-blocking snackbar, it's handled by `snackBarController.close()` above.

      ExportLock.endExport(); // Release global lock
      if (context.mounted) {
        setState(() {}); // Re-enable buttons, trigger rebuild if needed
      }
      print('$taskName: Resetting state and releasing global lock, exportId=$_exportId');
    }

    final endTime = DateTime.now();
    print('$taskName: Total export time: ${endTime.difference(startTime).inMilliseconds} ms, exportId=$_exportId');
  }

  // Helper to calculate grand totals from provided PlutoRows
  Map<String, dynamic>? _calculateGrandTotals(
      List<PlutoColumn> columns,
      List<PlutoRow> plutoRows,
      List<Map<String, dynamic>>? fieldConfigs,
      ) {
    bool hasGrandTotals = false;
    if (fieldConfigs != null) {
      hasGrandTotals = fieldConfigs.any((config) => config['Total']?.toString() == '1');
    }

    if (!hasGrandTotals) {
      print('CalculateGrandTotals: No columns marked for Total. Returning null.');
      return null;
    }

    final Map<String, dynamic> grandTotals = {};
    final Map<String, Map<String, dynamic>> fieldConfigMap = {
      for (var config in (fieldConfigs ?? [])) config['Field_name']?.toString() ?? '': config
    };

    // Use filtered columns for PDF export (which also affects what fields are considered for total)
    final List<String> relevantFieldNames = columns
        .where((col) => col.field != '__actions__' && col.field != '__raw_data__')
        .map((col) => col.field)
        .toList();

    for (var fieldName in relevantFieldNames) {
      final config = fieldConfigMap[fieldName];
      final isTotalColumn = config?['Total']?.toString() == '1';

      // Replicate the isNumeric logic from TableMainUI/ReportMainUI
      bool isNumericField = (config?['data_type']?.toString().toLowerCase() == 'number') ||
          (['VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount',
            'Excise', 'Cess', 'HSCess', 'Freight', 'TCS', 'CGST', 'SGST', 'IGST'].contains(fieldName.toLowerCase()));
      // Crucial: If Total or SubTotal is marked, it IS numeric for aggregation purposes.
      if (config?['Total']?.toString() == '1' || config?['SubTotal']?.toString() == '1') {
        isNumericField = true;
      }

      if (isTotalColumn && isNumericField) {
        double sum = 0.0;
        for (var row in plutoRows) {
          // Exclude subtotal rows from grand total calculation
          if (row.cells.containsKey('__isSubtotal__') && row.cells['__isSubtotal__']!.value == true) {
            continue;
          }
          final cellValue = row.cells[fieldName]?.value;
          final parsedValue = double.tryParse(cellValue.toString()) ?? 0.0;
          sum += parsedValue;
        }
        grandTotals[fieldName] = sum;
        print('CalculateGrandTotals: Total for $fieldName: $sum');
      } else if (relevantFieldNames.indexOf(fieldName) == 0) {
        grandTotals[fieldName] = 'Grand Total'; // Label for the first column
      } else {
        grandTotals[fieldName] = ''; // Empty for other non-total columns
      }
    }
    print('CalculateGrandTotals: Final grand totals: $grandTotals');
    return grandTotals;
  }

  // --- Helper to call Node.js PDF Generation API ---
  Future<Uint8List> _callPdfGenerationApi() async {
    print('Calling Node.js PDF API, exportId=$_exportId');

    final Map<String, String> visibleAndFormattedParameters = widget.displayParameterValues;

    final List<Map<String, dynamic>> serializableColumns = widget.columns
        .where((col) => col.field != '__actions__' && col.field != '__raw_data__')
        .map((col) => {
      'field': col.field,
      'title': col.title,
      'type': col.type.runtimeType.toString(),
      'width': col.width,
      // Add other relevant column properties from fieldConfigs if needed by Node.js
      // e.g., 'decimal_points', 'indian_format', 'num_alignment'
      'decimal_points': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['decimal_points'],
      'indian_format': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['indian_format'],
      'num_alignment': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['num_alignment'],
      'Total': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['Total'],
      'SubTotal': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['SubTotal'],
      'Breakpoint': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['Breakpoint'],
      'data_type': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['data_type'],
      'image': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['image'],
      'time': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['time'],
    }).toList();
    print('ExportWidget: PDF Export Columns (filtered): ${serializableColumns.map((c) => c['field']).toList()}');

    final List<Map<String, dynamic>> serializableRows = widget.plutoRows.map((row) {
      final Map<String, dynamic> serializableRowCells = {};
      for (var col in widget.columns) {
        if (col.field != '__actions__' && col.field != '__raw_data__') {
          serializableRowCells[col.field] = row.cells[col.field]?.value;
        }
      }
      final Map<String, dynamic> rowDataForApi = {
        'cells': serializableRowCells,
      };
      if (row.cells.containsKey('__isSubtotal__')) {
        rowDataForApi['__isSubtotal__'] = row.cells['__isSubtotal__']!.value;
      }
      return rowDataForApi;
    }).toList();
    print('ExportWidget: Number of rows for PDF: ${serializableRows.length}');

    final Map<String, dynamic>? grandTotalData = _calculateGrandTotals(
        widget.columns, widget.plutoRows, widget.fieldConfigs);
    print('ExportWidget: Grand Total data for PDF: $grandTotalData');


    double totalPdfConfiguredWidth = 0.0;
    for (var col in serializableColumns) {
      totalPdfConfiguredWidth += (col['width'] ?? 100.0);
    }
    if (totalPdfConfiguredWidth == 0 && serializableColumns.isNotEmpty) {
      totalPdfConfiguredWidth = serializableColumns.length * 100.0;
    } else if (totalPdfConfiguredWidth == 0) {
      totalPdfConfiguredWidth = 1.0;
    }
    print('ExportWidget: Total configured width for PDF (filtered columns): $totalPdfConfiguredWidth');


    final Map<String, dynamic> requestBody = {
      'columns': serializableColumns,
      'rows': serializableRows,
      'fileName': widget.fileName,
      'exportId': _exportId,
      'fieldConfigs': widget.fieldConfigs, // Also send full fieldConfigs for more granular control on Node.js side
      'reportLabel': widget.reportLabel,
      'visibleAndFormattedParameters': visibleAndFormattedParameters,
      'companyNameForHeader': _companyNameForHeader,
      'totalPlutoConfiguredWidth': totalPdfConfiguredWidth,
      'grandTotalData': grandTotalData, // NEW: Send grand total separately
      'includePdfFooterDateTime': widget.includePdfFooterDateTime, // NEW: Pass the footer flag to Node.js
    };
    print('ExportWidget: Request body size for PDF: ${jsonEncode(requestBody).length} bytes');


    try {
      final response = await http.post(
        Uri.parse('$_pdfApiBaseUrl'),
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
      rethrow;
    }
  }

  // --- Export to Excel ---
  Future<void> _exportToExcel(BuildContext context) async {
    await _executeExportTask(context, () async {
      final List<Map<String, dynamic>> serializableColumns = widget.columns
          .where((col) => col.field != '__raw_data__')
          .map((col) => {
        'field': col.field,
        'title': col.title,
        'type': col.type.runtimeType.toString(),
        'width': col.width,
      }).toList();

      final List<Map<String, dynamic>> serializableRows = widget.plutoRows.map((row) {
        final Map<String, dynamic> cellsMap = {};
        for (var col in widget.columns) {
          cellsMap[col.field] = row.cells[col.field]?.value;
        }
        if (row.cells.containsKey('__isSubtotal__')) {
          cellsMap['__isSubtotal__'] = row.cells['__isSubtotal__']!.value;
        }
        return cellsMap;
      }).toList();

      final Map<String, dynamic>? grandTotalData = _calculateGrandTotals(
          widget.columns, widget.plutoRows, widget.fieldConfigs);
      print('ExportWidget: Grand Total data for Excel: $grandTotalData');


      print('ExportToExcel: Calling compute to generate Excel, exportId=$_exportId');
      final excelBytes = await compute(_generateExcel, {
        'columns': serializableColumns,
        'rows': serializableRows, // These are the PlutoRows as-is, including subtotal flags
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'displayParameterValues': widget.displayParameterValues,
        'companyNameForHeader': _companyNameForHeader,
        'grandTotalData': grandTotalData, // NEW: Send grand total separately to Excel
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

      // SnackBar is handled by _executeExportTask for success
    }, 'Export to Excel', initialMessage: 'Generating Excel...'); // Provide initial message
  }

  // --- Export to PDF (Download) ---
  Future<void> _exportToPDF(BuildContext context) async {
    await _executeExportTask(context, () async {
      print('ExportToPDF: Calling Node.js API to generate PDF, exportId=$_exportId');
      final pdfBytes = await _callPdfGenerationApi();

      print('ExportToPDF: Saving PDF file using FileSaver, exportId=$_exportId');
      final fileName = '${widget.fileName}.pdf';
      final result = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: pdfBytes,
        mimeType: MimeType.pdf,
      );
      print('ExportToPDF: File saved with result: $result, fileName: $fileName, exportId=$_exportId');
      DownloadTracker.trackDownload(fileName, 'file_saver', _exportId);

      // SnackBar is handled by _executeExportTask for success
    }, 'Export to PDF', showLoaderDialog: false, initialMessage: 'Downloading PDF...'); // MODIFIED for background download feedback
  }

  // --- Print Document ---
  Future<void> _printDocument(BuildContext context) async {
    await _executeExportTask(context, () async {
      print('PrintDocument: Calling Node.js API to generate PDF for printing, exportId=$_exportId');
      final pdfBytes = await _callPdfGenerationApi();

      if (kIsWeb) {
        print('PrintDocument: Platform is web. Using Printing.layoutPdf for direct browser print dialog, exportId=$_exportId');
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: '${widget.fileName}_Print.pdf',
        );
        // SnackBar for web print is specific and handled here, not by general success
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Browser print dialog opened.')),
          );
        }
      } else {
        print('PrintDocument: Platform is not web. Using Printing.sharePdf to trigger system print/share dialog, exportId=$_exportId');
        await Printing.sharePdf(bytes: pdfBytes, filename: '${widget.fileName}_Print.pdf');
        // SnackBar for non-web print is specific and handled here, not by general success
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF prepared. Select a printer from the system dialog.')),
          );
        }
      }
    }, 'Print Document', initialMessage: 'Preparing document for print...'); // Provide initial message
  }

  // --- Send to Email ---
  Future<void> _sendToEmail(BuildContext context) async {
    print('SendToEmail: Showing email input dialog, exportId=$_exportId');
    final emailController = TextEditingController();
    final shouldSend = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Ensure user must make a choice
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
      // If the user cancels, gracefully exit the task. No loader needed.
      return;
    }

    // --- User confirmed email, now start the actual processing with the loader ---
    await _executeExportTask(context, () async {
      print('SendToEmail: Generating Excel file for email attachment, exportId=$_exportId');
      final List<Map<String, dynamic>> serializableColumnsForExcel = widget.columns
          .where((col) => col.field != '__raw_data__')
          .map((col) => {
        'field': col.field,
        'title': col.title,
        'type': col.type.runtimeType.toString(),
        'width': col.width,
      }).toList();

      final List<Map<String, dynamic>> serializableRowsForExcel = widget.plutoRows.map((row) {
        final Map<String, dynamic> cellsMap = {};
        for (var col in widget.columns) {
          cellsMap[col.field] = row.cells[col.field]?.value;
        }
        if (row.cells.containsKey('__isSubtotal__')) {
          cellsMap['__isSubtotal__'] = row.cells['__isSubtotal__']!.value;
        }
        return cellsMap;
      }).toList();

      final Map<String, dynamic>? grandTotalData = _calculateGrandTotals(
          widget.columns, widget.plutoRows, widget.fieldConfigs);
      print('SendToEmail: Grand Total data for Excel: $grandTotalData');


      final excelBytes = await compute(_generateExcel, {
        'columns': serializableColumnsForExcel,
        'rows': serializableRowsForExcel,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'displayParameterValues': widget.displayParameterValues,
        'companyNameForHeader': _companyNameForHeader,
        'grandTotalData': grandTotalData,
      });
      print('SendToEmail: Excel file generated. Size: ${excelBytes.length} bytes, exportId=$_exportId');


      print('SendToEmail: Generating PDF file for email attachment via API, exportId=$_exportId');
      final pdfBytes = await _callPdfGenerationApi(); // This method already uses widget.includePdfFooterDateTime
      print('SendToEmail: PDF file generated. Size: ${pdfBytes.length} bytes, exportId=$_exportId');


      print('SendToEmail: Preparing multipart HTTP request, exportId=$_exportId');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://aquare.co.in/mobileAPI/sachin/reportBuilder/sendmail.php'),
      );

      request.fields['email'] = emailController.text;
      print('SendToEmail: Adding email field: ${emailController.text}, exportId=$_exportId');

      request.files.add(http.MultipartFile.fromBytes(
        'excel',
        excelBytes,
        filename: '${widget.fileName}.xlsx',
        contentType: MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      ));
      print('SendToEmail: Added Excel attachment: ${widget.fileName}.xlsx, size: ${excelBytes.length} bytes, exportId=$_exportId');


      request.files.add(http.MultipartFile.fromBytes(
        'pdf',
        pdfBytes,
        filename: '${widget.fileName}.pdf',
        contentType: MediaType('application', 'pdf'),
      ));
      print('SendToEmail: Added PDF attachment: ${widget.fileName}.pdf, size: ${pdfBytes.length} bytes, exportId=$_exportId');


      print('SendToEmail: Sending HTTP request to backend, exportId=$_exportId');
      try {
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        final responseString = response.body;
        print('SendToEmail: HTTP response status code: ${response.statusCode}, Response: "$responseString", exportId=$_exportId');

        // Changed condition: Rely on 200 status code for success
        if (response.statusCode == 200) {
          print('SendToEmail: Files sent to email successfully (server returned 200 OK), exportId=$_exportId');
          // SnackBar is handled by _executeExportTask for success
        } else {
          print('SendToEmail: Failed to send email. Status: ${response.statusCode}, Response: "$responseString", exportId=$_exportId');
          // Provide a more descriptive error message to the user
          String errorDetail = responseString.isNotEmpty ? responseString : 'No response body from server.';
          throw Exception('Server failed to send email. Status Code: ${response.statusCode}. Details: $errorDetail');
        }
      } catch (e) {
        print('SendToEmail: Exception during HTTP request: $e, exportId=$_exportId');
        rethrow; // Rethrow to be caught by _executeExportTask
      }
    }, 'Send to Email Processing', initialMessage: 'Preparing email and attachments...'); // New task name for the processing part
  }

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
    final displayParameterValues = params['displayParameterValues'] as Map<String, String>;
    final companyNameForHeader = params['companyNameForHeader'] as String?;
    final grandTotalData = params['grandTotalData'] as Map<String, dynamic>?; // NEW: Receive grand total

    var excel = Excel.createExcel();
    var sheet = excel['Sheet1'];

    final List<String> fieldNames = [];
    final List<String> headerLabels = [];
    for (var col in columns) {
      if (col['field'] != '__actions__' && col['field'] != '__raw_data__') {
        fieldNames.add(col['field'].toString());
        headerLabels.add(col['title'].toString());
      }
    }
    print('GenerateExcel: Excel field names (filtered): $fieldNames');


    int maxCols = headerLabels.length;

    if (companyNameForHeader != null && companyNameForHeader.isNotEmpty) {
      sheet.appendRow([TextCellValue(companyNameForHeader)]);
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1),
          CellIndex.indexByColumnRow(columnIndex: maxCols - 1, rowIndex: sheet.maxRows - 1));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle = CellStyle(
        fontFamily: 'Calibri',
        fontSize: 14,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      sheet.appendRow([]);
    }

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

    if (displayParameterValues.isNotEmpty) {
      for (var entry in displayParameterValues.entries) {
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

    for (var rowData in rows) {
      final isSubtotalRow = rowData.containsKey('__isSubtotal__') ? rowData['__isSubtotal__'] : false;

      final rowValues = fieldNames.map((fieldName) {
        final rawValue = rowData[fieldName];
        final config = fieldConfigMap[fieldName];

        bool isNumeric = (config?['data_type']?.toString().toLowerCase() == 'number') ||
            (['VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount',
              'Excise', 'Cess', 'HSCess', 'Freight', 'TCS', 'CGST', 'SGST', 'IGST'].contains(fieldName.toLowerCase()));
        if (config?['Total']?.toString() == '1' || config?['SubTotal']?.toString() == '1') {
          isNumeric = true;
        }

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

        bool isNumeric = (config?['data_type']?.toString().toLowerCase() == 'number') ||
            (['VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount',
              'Excise', 'Cess', 'HSCess', 'Freight', 'TCS', 'CGST', 'SGST', 'IGST'].contains(fieldName.toLowerCase()));
        if (config?['Total']?.toString() == '1' || config?['SubTotal']?.toString() == '1') {
          isNumeric = true;
        }

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: dataRowIndex)).cellStyle = CellStyle(
          horizontalAlign: isNumeric
              ? (alignment == 'center' ? HorizontalAlign.Center : HorizontalAlign.Right)
              : HorizontalAlign.Left,
          bold: isSubtotalRow,
          fontFamily: 'Calibri',
        );
      }
    }

    // NEW: Add Grand Total row if grandTotalData is provided
    if (grandTotalData != null) {
      final totalRowValues = fieldNames.map((fieldName) {
        final config = fieldConfigMap[fieldName];
        final total = config?['Total']?.toString() == '1';

        // Replicate the isNumeric logic for the grand total row as well
        bool isNumeric = (config?['data_type']?.toString().toLowerCase() == 'number') ||
            (['VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount',
              'Excise', 'Cess', 'HSCess', 'Freight', 'TCS', 'CGST', 'SGST', 'IGST'].contains(fieldName.toLowerCase()));
        if (config?['Total']?.toString() == '1' || config?['SubTotal']?.toString() == '1') {
          isNumeric = true;
        }

        final decimalPoints = int.tryParse(config?['decimal_points']?.toString() ?? '0') ?? 0;
        final indianFormat = config?['indian_format']?.toString() == '1';

        if (fieldName == fieldNames[0]) {
          return TextCellValue(grandTotalData[fieldName]?.toString() ?? 'Grand Total'); // Get label from grandTotalData
        } else if (total && isNumeric && grandTotalData.containsKey(fieldName)) {
          final double sum = grandTotalData[fieldName] as double;
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
        final alignment = config?['num_alignment']?.toString().toLowerCase() ?? 'left';

        bool isNumeric = (config?['data_type']?.toString().toLowerCase() == 'number') ||
            (['VQ_GrandTotal', 'Qty', 'Rate', 'NetRate', 'GrandTotal', 'Value', 'Amount',
              'Excise', 'Cess', 'HSCess', 'Freight', 'TCS', 'CGST', 'SGST', 'IGST'].contains(fieldName.toLowerCase()));
        if (config?['Total']?.toString() == '1' || config?['SubTotal']?.toString() == '1') {
          isNumeric = true;
        }

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