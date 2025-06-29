// lib/ReportUtils/Export_widget.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
// import 'package:excel/excel.dart'; // No longer needed
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:pdf/pdf.dart' as pdf_lib;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:collection/collection.dart';
import 'dart:io';
import 'dart:math'; // For min function
import 'package:image/image.dart' as img_lib;


class ExportLock {
  static bool _isExportingGlobally = false;
  static bool get isExporting => _isExportingGlobally;

  static void startExport() {
    _isExportingGlobally = true;
    debugPrint("ExportLock: Lock acquired.");
  }

  static void endExport() {
    _isExportingGlobally = false;
    debugPrint("ExportLock: Lock released.");
  }
}

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

class DownloadTracker {
  static int _downloadCount = 0;
  static void trackDownload(String fileName, String url, String exportId) {
    _downloadCount++;
    debugPrint("DownloadTracker: Downloaded #$_downloadCount: $fileName (URL: $url)");
  }
}

class ExportWidget extends StatefulWidget {
  final List<PlutoColumn> columns;
  final List<PlutoRow> plutoRows;
  final String fileName;
  final List<Map<String, dynamic>>? fieldConfigs;
  final String reportLabel;
  final Map<String, String> parameterValues;
  final Map<String, String> displayParameterValues;
  final List<Map<String, dynamic>>? apiParameters;
  final Map<String, List<Map<String, String>>>? pickerOptions;
  final String companyName;
  final bool includePdfFooterDateTime;
  final List<Widget> topLevelActions;

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
    this.includePdfFooterDateTime = false,
    this.topLevelActions = const [],
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

  // State for iterative PDF download
  int _currentPdfPartIndex = 0;
  int _totalPdfParts = 0;
  bool _downloadingAllRemainingPdf = false; // Flag for automatic PDF download

  // State for iterative Excel download (NEW)
  int _currentExcelPartIndex = 0;
  int _totalExcelParts = 0;
  bool _downloadingAllRemainingExcel = false; // Flag for automatic Excel download

  // Define the number of rows per file part
  static const int _rowsPerFilePart = 50; // Use a common chunk size for both PDF and Excel

  // IMPORTANT: Updated Vercel API URLs
  static const String _pdfApiBaseUrl = 'https://pdf-node-pq4yewm18-vishal-jains-projects-b322eb37.vercel.app/api/generate-pdf';
  static const String _excelApiBaseUrl = 'https://pdf-node-pq4yewm18-vishal-jains-projects-b322eb37.vercel.app/api/generate-excel';


  String? get _companyNameForHeader {
    if (widget.companyName.isNotEmpty) {
      return widget.companyName;
    }
    if (widget.apiParameters != null) {
      for (var param in widget.apiParameters!) {
        if (param['is_company_name_field'] == true) {
          final paramName = param['name'].toString();
          if (param['show'] == true) {
            final companyDisplayName = widget.displayParameterValues[paramName];
            if (companyDisplayName != null && companyDisplayName.isNotEmpty) {
              return companyDisplayName;
            }
          } else if (param['display_value_cache'] != null && param['display_value_cache'].toString().isNotEmpty) {
            return param['display_value_cache'].toString();
          }
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Buttons are disabled if no rows or if an export is globally in progress.
    final bool canExport = widget.plutoRows.isNotEmpty && !ExportLock.isExporting;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 12.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton(
            onPressed: canExport
                ? () async {
              await _excelDebouncer.debounce(() async {
                if (ExportLock.isExporting) {
                  _showExportInProgressSnackbar(); return;
                }
                // _exportToExcel will now handle ExportLock.startExport() and ExportLock.endExport()
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
          ElevatedButton(
            onPressed: canExport
                ? () async {
              await _pdfDebouncer.debounce(() async {
                if (ExportLock.isExporting) {
                  _showExportInProgressSnackbar(); return;
                }
                // _exportToPDF will handle ExportLock.startExport() and ExportLock.endExport()
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
          ElevatedButton(
            onPressed: canExport
                ? () async {
              await _emailDebouncer.debounce(() async {
                if (ExportLock.isExporting) {
                  _showExportInProgressSnackbar(); return;
                }
                ExportLock.startExport(); // Acquire global lock for this operation (single email attachment)
                try {
                  await _sendToEmail(context);
                } finally {
                  ExportLock.endExport(); // Release global lock
                  if (context.mounted) setState(() {}); // Rebuild to re-enable buttons
                }
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
          ElevatedButton(
            onPressed: canExport
                ? () async {
              await _printDebouncer.debounce(() async {
                if (ExportLock.isExporting) {
                  _showExportInProgressSnackbar(); return;
                }
                ExportLock.startExport(); // Acquire global lock for this operation (single print job)
                try {
                  await _printDocument(context);
                } finally {
                  ExportLock.endExport(); // Release global lock
                  if (context.mounted) setState(() {}); // Rebuild to re-enable buttons
                }
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
          ...widget.topLevelActions,
        ],
      ),
    );
  }

  void _showExportInProgressSnackbar() {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export already in progress! Please wait.')),
      );
    }
  }

  // Helper to check if any column is configured as an image column
  bool _hasImageColumns() {
    if (widget.fieldConfigs == null || widget.fieldConfigs!.isEmpty) {
      return false;
    }
    return widget.columns.any((col) {
      final config = widget.fieldConfigs!.firstWhereOrNull((fc) => fc['Field_name'] == col.field);
      return config != null && config['image']?.toString() == '1';
    });
  }

  Future<void> _executeExportTask(
      BuildContext context,
      String taskName,
      Future<void> Function(Function(String) progressUpdater) task,
      {
        bool showLoaderDialog = true, // true for blocking dialog, false for snackbar
        String initialMessage = 'Processing...',
        bool dismissUIAtEnd = true, // Control UI dismissal at the end of this _executeExportTask call
      }) async {

    // Check for empty rows, though top-level callers should also do this.
    if (widget.plutoRows.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export!')),
        );
      }
      return;
    }

    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? snackBarController;
    bool dialogShown = false; // Flag to track if the blocking dialog was shown by THIS call

    final ValueNotifier<String> currentMessage = ValueNotifier(initialMessage);

    void updateProgress(String message) {
      currentMessage.value = message;
      debugPrint("Progress for $taskName: $message");
    }

    if (context.mounted) {
      if (showLoaderDialog) {
        // Use AlertDialog for blocking initial progress (e.g., first chunk, single file export)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) { // Only show if widget is still mounted
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => PopScope(
                canPop: false, // Prevent dismissal by back button
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<String>(
                        valueListenable: currentMessage,
                        builder: (context, msg, child) {
                          return Text(msg, style: GoogleFonts.poppins(color: Colors.white));
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
            dialogShown = true;
            debugPrint("Dialog UI shown for $taskName.");
          }
        });
      } else {
        // Use SnackBar for non-blocking progress updates (e.g., subsequent chunks)
        snackBarController = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(width: 16),
                ValueListenableBuilder<String>(
                  valueListenable: currentMessage,
                  builder: (context, msg, child) {
                    return Text(msg, style: const TextStyle(color: Colors.white));
                  },
                ),
              ],
            ),
            duration: const Duration(minutes: 5), // Keep visible for a long time
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Hide',
              textColor: Colors.white,
              onPressed: () => snackBarController?.close(),
            ),
          ),
        );
        debugPrint("Snackbar UI shown for $taskName.");
      }
    }

    try {
      await task(updateProgress); // Execute the actual export task
    } catch (e) {
      String errorMessage = 'Failed to $taskName: $e';
      debugPrint('Error during $taskName: $e');

      if (e is http.ClientException) {
        errorMessage = 'Network Error: Please check your internet connection or server URL. Details: ${e.message}';
      } else if (e is SocketException) {
        errorMessage = 'Connection Error: Could not connect to the server. Check network or server status. Details: ${e.message}';
      } else if (e.toString().contains('Email sending cancelled by user.')) {
        return; // Suppress snackbar for user-cancelled email
      } else if (e.toString().contains('Failed to generate PDF on server') || e.toString().contains('Failed to generate Excel on server')) {
        errorMessage = 'Server Generation Error: ${e.toString().replaceFirst('Exception: ', '')}';
      }

      if (context.mounted) {
        // Close any active snackbar (from previous parts or current) before showing error
        if (snackBarController != null) {
          snackBarController.close();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      // Dismiss the initial blocking dialog if it was shown by *this* call
      if (dialogShown && context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        debugPrint("Dialog UI dismissed for $taskName.");
      }

      // Close the snackbar if it was shown by *this* call AND it's supposed to be dismissed.
      // If `dismissUIAtEnd` is false (for intermediate chunks), the snackbar *remains open*.
      if (!showLoaderDialog && snackBarController != null && dismissUIAtEnd) {
        snackBarController.close();
        debugPrint("Snackbar UI dismissed for $taskName.");
      }
      // Note: Global lock is NOT released here. That's handled by the top-level calling function/sequence.
    }
  }

  // Calculates grand totals based on field configurations.
  Map<String, dynamic>? _calculateGrandTotals(
      List<PlutoColumn> columns,
      List<PlutoRow> plutoRows,
      List<Map<String, dynamic>>? fieldConfigs,
      ) {
    bool hasGrandTotals = fieldConfigs?.any((config) => config['Total']?.toString() == '1') ?? false;
    if (!hasGrandTotals) return null;

    final Map<String, dynamic> grandTotals = {};
    final Map<String, Map<String, dynamic>> fieldConfigMap = {
      for (var config in (fieldConfigs ?? [])) config['Field_name']?.toString() ?? '': config
    };

    final List<String> relevantFieldNames = columns
        .where((col) => col.field != '__actions__' && col.field != '__raw_data__')
        .map((col) => col.field)
        .toList();

    for (var fieldName in relevantFieldNames) {
      final config = fieldConfigMap[fieldName];
      final isTotalColumn = config?['Total']?.toString() == '1';

      bool isNumericField = (config?['data_type']?.toString().toLowerCase() == 'number') ||
          config?['Total']?.toString() == '1' ||
          config?['SubTotal']?.toString() == '1';

      if (isTotalColumn && isNumericField) {
        double sum = 0.0;
        for (var row in plutoRows) {
          // Exclude subtotal rows from grand total calculation if they exist
          if (row.cells['__isSubtotal__']?.value != true) {
            sum += double.tryParse(row.cells[fieldName]?.value.toString() ?? '0.0') ?? 0.0;
          }
        }
        grandTotals[fieldName] = sum;
      } else if (relevantFieldNames.indexOf(fieldName) == 0) {
        grandTotals[fieldName] = 'Grand Total';
      } else {
        grandTotals[fieldName] = '';
      }
    }
    return grandTotals;
  }

  // Isolate function to process rows and fetch/encode images (used by LOCAL PDF generation for Print/Email)
  static Future<Map<String, dynamic>> _processRowsInIsolate(Map<String, dynamic> params) async {
    debugPrint("Isolate: Starting _processRowsInIsolate");
    final List<Map<String, dynamic>> rawPlutoRowsJson = params['plutoRowsJson'] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> fieldConfigs = params['fieldConfigs'] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> serializableColumns = params['serializableColumns'] as List<Map<String, dynamic>>;

    // Simple in-isolate cache to avoid refetching same image URLs multiple times
    final Map<String, String?> isolateBase64ImageCache = {};

    Future<String?> _isolateFetchImageAndEncodeBase64(String imageUrl) async {
      if (isolateBase64ImageCache.containsKey(imageUrl)) {
        return isolateBase64ImageCache[imageUrl];
      }
      if (!imageUrl.startsWith('http')) {
        isolateBase64ImageCache[imageUrl] = null;
        return null;
      }

      try {
        final response = await http.get(Uri.parse(imageUrl));

        if (response.statusCode == 200) {
          if (response.bodyBytes.isEmpty) {
            debugPrint("Isolate: Fetched image bytes are empty for: $imageUrl. Skipping.");
            isolateBase64ImageCache[imageUrl] = null;
            return null;
          }

          img_lib.Image? image;
          try {
            image = img_lib.decodeImage(response.bodyBytes);
          } catch (e) {
            debugPrint("Isolate: Error decoding image bytes with img_lib for $imageUrl: $e. Attempting raw base64 encode.");
          }

          if (image == null) {
            // Fallback: If image package can't decode, just base64 encode raw bytes
            if (response.bodyBytes.isNotEmpty) {
              final String base64String = base64Encode(response.bodyBytes);
              String mimeType = response.headers['content-type']?.split(';')[0] ?? 'application/octet-stream';
              final String dataUrl = 'data:$mimeType;base64,$base64String';
              isolateBase64ImageCache[imageUrl] = dataUrl;
              return dataUrl;
            } else {
              debugPrint("Isolate: Raw image bytes also empty/invalid after decode failure for $imageUrl.");
              isolateBase64ImageCache[imageUrl] = null;
              return null;
            }
          }

          const int targetHeightPx = 100; // Define a target height for images
          image = img_lib.copyResize(image, height: targetHeightPx, interpolation: img_lib.Interpolation.average);

          final List<int> resizedBytes = img_lib.encodeJpg(image, quality: 75);
          const String mimeType = 'image/jpeg'; // Assuming JPEG for optimized size
          final String base64String = base64Encode(Uint8List.fromList(resizedBytes));
          final String dataUrl = 'data:$mimeType;base64,$base64String';
          isolateBase64ImageCache[imageUrl] = dataUrl;
          return dataUrl;
        } else {
          debugPrint(
              "Isolate: Failed to fetch image (Status ${response.statusCode}) from: $imageUrl. Response body: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}");
          isolateBase64ImageCache[imageUrl] = null;
          return null;
        }
      } catch (e, stack) {
        debugPrint("Isolate: Error during image fetching/processing from $imageUrl: $e\n$stack");
        isolateBase64ImageCache[imageUrl] = null;
        return null;
      }
    }

    final List<String> imageFieldNames = serializableColumns
        .where((col) => fieldConfigs.firstWhereOrNull((fc) => fc['Field_name'] == col['field'])?['image'] == '1')
        .map((col) => col['field'] as String)
        .toList();
    debugPrint("Isolate: Image field names detected: $imageFieldNames");

    final List<Map<String, dynamic>> finalSerializableRows = [];
    int rowIndex = 0;
    for (var rowData in rawPlutoRowsJson) {
      final Map<String, dynamic> serializableRowCells = {};
      bool isCurrentRowSubtotal = false;

      for (var colConfig in serializableColumns) {
        final fieldName = colConfig['field'] as String;

        if (!rowData.containsKey(fieldName)) {
          serializableRowCells[fieldName] = null;
          continue;
        }

        final rawValue = rowData[fieldName];

        if (imageFieldNames.contains(fieldName) &&
            rawValue is String &&
            (rawValue.startsWith('http://') || rawValue.startsWith('https://'))) {
          serializableRowCells[fieldName] = await _isolateFetchImageAndEncodeBase64(rawValue);
        } else {
          serializableRowCells[fieldName] = rawValue;
        }
      }

      if (rowData.containsKey('__isSubtotal__') && rowData['__isSubtotal__'] is bool) {
        isCurrentRowSubtotal = rowData['__isSubtotal__'] as bool;
      }

      final Map<String, dynamic> processedRowData = {
        'cells': serializableRowCells,
        '__isSubtotal__': isCurrentRowSubtotal,
      };

      finalSerializableRows.add(processedRowData);
      rowIndex++;
    }
    debugPrint("Isolate: Finished processing rows. Total processed: ${finalSerializableRows.length}");
    return {'serializableRows': finalSerializableRows};
  }

  // --- LOCAL PDF GENERATION (Using pdf package) ---
  // Primarily used for Print and Email functionalities when images are present,
  // as the Puppeteer API handles the main PDF export for non-image or chunked image PDFs.
  Future<Uint8List> _generatePdfLocally({
    required List<PlutoRow> rowsToProcess,
    required Map<String, dynamic>? grandTotalData,
  }) async {
    debugPrint("Local PDF generation: Starting local PDF generation.");
    final doc = pw.Document();

    final poppinsRegular = await PdfGoogleFonts.poppinsRegular();
    final poppinsBold = await PdfGoogleFonts.poppinsBold();
    debugPrint("Local PDF generation: Fonts loaded.");

    final List<Map<String, dynamic>> serializableColumns = widget.columns
        .where((col) => col.field != '__actions__' && col.field != '__raw_data__')
        .map((col) => {'field': col.field, 'title': col.title, 'width': col.width})
        .toList();
    debugPrint("Local PDF generation: Serializable columns prepared. Count: ${serializableColumns.length}");

    // Convert PlutoRows to a serializable JSON format for the isolate
    final List<Map<String, dynamic>> allPlutoRowsJsonForCompute = [];
    for (var row in rowsToProcess) {
      final Map<String, dynamic> flattenedRowData = {};
      for (var col in serializableColumns) {
        final fieldName = col['field'] as String;
        flattenedRowData[fieldName] = row.cells.containsKey(fieldName) ? row.cells[fieldName]?.value : null;
      }
      flattenedRowData['__isSubtotal__'] = row.cells.containsKey('__isSubtotal__')
          ? (row.cells['__isSubtotal__']!.value is bool ? row.cells['__isSubtotal__']!.value : false)
          : false;
      allPlutoRowsJsonForCompute.add(flattenedRowData);
    }
    debugPrint("Local PDF generation: ${allPlutoRowsJsonForCompute.length} rows flattened for single compute call.");

    List<Map<String, dynamic>> allProcessedSerializableRows = [];
    try {
      final preProcessResult = await compute(_processRowsInIsolate, {
        'plutoRowsJson': allPlutoRowsJsonForCompute,
        'fieldConfigs': widget.fieldConfigs ?? [],
        'serializableColumns': serializableColumns,
      });
      debugPrint("Local PDF generation: Isolate processing complete. Result received.");
      allProcessedSerializableRows = preProcessResult['serializableRows'];
    } catch (e, stack) {
      debugPrint("Local PDF generation ERROR: Failed during compute call: $e\n$stack");
      rethrow;
    }

    debugPrint("Local PDF generation: Using grand totals: $grandTotalData");

    doc.addPage(
      pw.MultiPage(
        pageFormat: pdf_lib.PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildPdfHeader(poppinsRegular, poppinsBold),
        footer: (context) => _buildPdfFooter(context, poppinsRegular),
        build: (context) => [
          _buildPdfContentTable(
              serializableColumns, allProcessedSerializableRows, grandTotalData, poppinsRegular, poppinsBold),

        ],
      ),
    );
    debugPrint("Local PDF generation: PDF document built. Saving...");
    return doc.save();
  }

  // Builds the header for the PDF document.
  pw.Widget _buildPdfHeader(pw.Font regularFont, pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (_companyNameForHeader != null && _companyNameForHeader!.isNotEmpty)
          pw.Text(_companyNameForHeader!, style: pw.TextStyle(font: boldFont, fontSize: 14)),
        pw.SizedBox(height: 5),
        pw.Text(widget.reportLabel, style: pw.TextStyle(font: boldFont, fontSize: 18)),
        pw.SizedBox(height: 5),
        if (widget.displayParameterValues.isNotEmpty)
          pw.Text(
            widget.displayParameterValues.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
            style: pw.TextStyle(font: regularFont, fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        pw.SizedBox(height: 15),
      ],
    );
  }

  // Builds the footer for the PDF document.
  pw.Widget _buildPdfFooter(pw.Context context, pw.Font font) {
    String footerText = 'Page ${context.pageNumber} of ${context.pagesCount}';
    if (widget.includePdfFooterDateTime) {
      final formattedDateTime = DateFormat('dd-MM-yyyy hh:mm:ss a').format(DateTime.now());
      footerText += '  |  Generated on: $formattedDateTime';
    }

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10.0),
      child: pw.Text(
        footerText,
        style: pw.TextStyle(font: font, fontSize: 8, color: pdf_lib.PdfColors.grey),
      ),
    );
  }

  // Builds the main content table for the PDF document.
  pw.Widget _buildPdfContentTable(
      List<Map<String, dynamic>> columns,
      List<Map<String, dynamic>> rows,
      Map<String, dynamic>? grandTotals,
      pw.Font regularFont,
      pw.Font boldFont,
      ) {
    debugPrint("PDF Table: Building content table for ${rows.length} rows.");
    final fieldConfigMap = {for (var config in (widget.fieldConfigs ?? [])) config['Field_name']?.toString() ?? '': config};

    final headers = columns.map((col) => pw.Text(col['title'], style: pw.TextStyle(font: boldFont))).toList();

    final data = rows.map<List<pw.Widget>>((row) {
      bool isSubtotal = row.containsKey('__isSubtotal__') && row['__isSubtotal__'] == true;
      if (!row.containsKey('cells') || row['cells'] is! Map<String, dynamic>) {
        debugPrint("PDF Table ERROR: Skipping malformed row, 'cells' is missing or not a Map: $row");
        return columns
            .map((col) => pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Text('Data Error', style: pw.TextStyle(font: regularFont, fontSize: 8))))
            .toList();
      }
      final Map<String, dynamic> rowCells = row['cells'] as Map<String, dynamic>;

      return columns.map<pw.Widget>((col) {
        final fieldName = col['field'];
        final config = fieldConfigMap[fieldName];

        final rawValue = rowCells.containsKey(fieldName) ? rowCells[fieldName] : null;

        final alignmentStr = config?['num_alignment']?.toString().toLowerCase() ?? 'left';
        final isNumeric = config?['data_type']?.toString().toLowerCase() == 'number' ||
            config?['Total']?.toString() == '1' ||
            config?['SubTotal']?.toString() == '1';

        pw.Alignment alignment = isNumeric
            ? (alignmentStr == 'center' ? pw.Alignment.center : pw.Alignment.centerRight)
            : pw.Alignment.centerLeft;

        // Image handling for PDF
        if (config?['image']?.toString() == '1' && rawValue is String && rawValue.startsWith('data:image')) {
          try {
            final imageData = base64Decode(rawValue.split(',').last);
            return pw.Container(
              width: 50, // Fixed width for image cell in PDF
              height: 50, // Fixed height for image cell in PDF
              alignment: pw.Alignment.center,
              child: pw.Image(pw.MemoryImage(imageData), fit: pw.BoxFit.contain),
            );
          } catch (e) {
            debugPrint('PDF Table Cell ERROR: Error decoding image data for field $fieldName: $e');
            return pw.Container(
                alignment: alignment,
                child: pw.Text('Invalid Image', style: pw.TextStyle(font: regularFont, fontSize: 8)));
          }
        }

        return pw.Container(
          alignment: alignment,
          padding: const pw.EdgeInsets.all(2),
          child: pw.Text(
            rawValue?.toString() ?? '',
            style: pw.TextStyle(font: isSubtotal ? boldFont : regularFont, fontSize: 8),
          ),
        );
      }).toList();
    }).toList();

    if (grandTotals != null) {
      debugPrint("PDF Table: Adding grand total row.");
      final totalRow = columns.map<pw.Widget>((col) {
        final fieldName = col['field'];
        final config = fieldConfigMap[fieldName];
        final alignmentStr = config?['num_alignment']?.toString().toLowerCase() ?? 'left';
        final isNumeric = config?['data_type']?.toString().toLowerCase() == 'number' || config?['Total']?.toString() == '1';

        pw.Alignment alignment = isNumeric
            ? (alignmentStr == 'center' ? pw.Alignment.center : pw.Alignment.centerRight)
            : pw.Alignment.centerLeft;

        return pw.Container(
            alignment: alignment,
            padding: const pw.EdgeInsets.all(2),
            child: pw.Text(grandTotals[fieldName]?.toString() ?? '', style: pw.TextStyle(font: boldFont, fontSize: 9)));
      }).toList();
      data.add(totalRow);
      debugPrint("PDF Table: Grand total row added.");
    }

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: pdf_lib.PdfColors.grey600),
      headerStyle: pw.TextStyle(font: boldFont, fontSize: 9, color: pdf_lib.PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: pdf_lib.PdfColors.grey800),
      cellHeight: 0,
      cellAlignments: {
        for (var i = 0; i < columns.length; i++) i: pw.Alignment.centerLeft,
      },
      cellPadding: const pw.EdgeInsets.all(4),
    );
  }

  // --- API PDF GENERATION (Using Node.js Puppeteer API) ---
  Future<Uint8List> _callPdfGenerationApiForChunk({
    required List<PlutoRow> rowsChunk,
    required Map<String, dynamic>? chunkGrandTotals,
  }) async {
    debugPrint("API PDF generation: Preparing data for API call.");
    final List<Map<String, dynamic>> serializableColumns = widget.columns
        .where((col) => col.field != '__actions__' && col.field != '__raw_data__')
        .map((col) => {
      'field': col.field,
      'title': col.title,
      'width': col.width,
      'decimal_points':
      widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['decimal_points'],
      'indian_format':
      widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['indian_format'],
      'num_alignment':
      widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['num_alignment'],
      'Total': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['Total'],
      'SubTotal': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['SubTotal'],
      'Breakpoint':
      widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['Breakpoint'],
      'data_type': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['data_type'],
      'image': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['image'],
      'time': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['time'],
    })
        .toList();
    debugPrint("API PDF generation: Serializable columns prepared. Count: ${serializableColumns.length}");

    final List<Map<String, dynamic>> plutoRowsJsonForApi = [];
    final List<String> imageFieldNames = serializableColumns
        .where((col) => widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col['field'])?['image'] == '1')
        .map((col) => col['field'] as String)
        .toList();
    debugPrint("API PDF generation: Image field names detected: $imageFieldNames");

    // Process rows to include base64 images if applicable, before sending to API
    for (var row in rowsChunk) {
      final Map<String, dynamic> flattenedRowData = {};
      for (var col in serializableColumns) {
        final fieldName = col['field'] as String;
        final rawValue = row.cells.containsKey(fieldName) ? row.cells[fieldName]?.value : null;

        if (imageFieldNames.contains(fieldName) &&
            rawValue is String &&
            (rawValue.startsWith('http://') || rawValue.startsWith('https://'))) {
          // Fetch and encode image for API payload
          final String? base64Image = await _fetchImageAndEncodeBase64(rawValue);
          flattenedRowData[fieldName] = base64Image;
        } else {
          flattenedRowData[fieldName] = rawValue;
        }
      }
      flattenedRowData['__isSubtotal__'] = row.cells.containsKey('__isSubtotal__')
          ? (row.cells['__isSubtotal__']!.value is bool ? row.cells['__isSubtotal__']!.value : false)
          : false;
      plutoRowsJsonForApi.add(flattenedRowData);
    }
    debugPrint("API PDF generation: ${plutoRowsJsonForApi.length} rows flattened (with images as base64) for API payload.");

    debugPrint("API PDF generation: Using grand totals: $chunkGrandTotals");

    final Map<String, dynamic> requestBody = {
      'columns': serializableColumns,
      'rows': plutoRowsJsonForApi,
      'fileName': widget.fileName,
      'exportId': _exportId,
      'fieldConfigs': widget.fieldConfigs,
      'reportLabel': widget.reportLabel,
      'visibleAndFormattedParameters': widget.displayParameterValues,
      'companyNameForHeader': _companyNameForHeader,
      'grandTotalData': chunkGrandTotals, // Pass chunk's grand total
      'includePdfFooterDateTime': widget.includePdfFooterDateTime,
    };
    debugPrint("API PDF generation: Sending request to PDF API.");

    // Instantiate http.Client to apply timeout
    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse(_pdfApiBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 90)); // Apply timeout here

      if (response.statusCode == 200) {
        debugPrint("API PDF generation: PDF generated successfully by API.");
        return response.bodyBytes;
      } else {
        // Log API response body for detailed server-side error
        final String apiResponseBody = response.body.isNotEmpty ? response.body : 'No response body';
        debugPrint("API PDF generation: Server responded with Status ${response.statusCode}. Body: $apiResponseBody");
        throw Exception('Failed to generate PDF on server: Status ${response.statusCode} - $apiResponseBody');
      }
    } on TimeoutException catch (e) {
      debugPrint("API PDF generation: Timeout Exception: ${e.message}");
      throw Exception('PDF generation API request timed out. Please try again or check server.');
    } on SocketException catch (e) {
      debugPrint("API PDF generation: Socket Exception: ${e.message}");
      throw Exception('Network connection issue with PDF API. Check your internet or API URL.');
    } finally {
      client.close(); // Close the client to release resources
    }
  }

  // --- API Excel GENERATION (New helper function to avoid code duplication) ---
  Future<Uint8List> _callExcelGenerationApi({
    required List<PlutoRow> rowsToProcess,
    required Map<String, dynamic>? grandTotalData,
  }) async {
    debugPrint("API Excel generation: Preparing data for API call.");
    final List<Map<String, dynamic>> serializableColumns = widget.columns
        .where((col) => col.field != '__raw_data__')
        .map((col) => {
      'field': col.field,
      'title': col.title,
      'width': col.width,
      'decimal_points':
      widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['decimal_points'],
      'indian_format':
      widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['indian_format'],
      'num_alignment':
      widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['num_alignment'],
      'Total': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['Total'],
      'SubTotal': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['SubTotal'],
      'Breakpoint':
      widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['Breakpoint'],
      'data_type': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['data_type'],
      'image': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['image'],
      'time': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['time'],
    })
        .toList();
    debugPrint("API Excel generation: Serializable columns prepared. Count: ${serializableColumns.length}");

    final List<Map<String, dynamic>> plutoRowsJsonForApi = [];
    final List<String> imageFieldNames = serializableColumns
        .where((col) => widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col['field'])?['image'] == '1')
        .map((col) => col['field'] as String)
        .toList();
    debugPrint("API Excel generation: Image field names detected: $imageFieldNames");

    for (var row in rowsToProcess) {
      final Map<String, dynamic> flattenedRowData = {};
      for (var col in serializableColumns) {
        final fieldName = col['field'] as String;
        final rawValue = row.cells.containsKey(fieldName) ? row.cells[fieldName]?.value : null;

        if (imageFieldNames.contains(fieldName) &&
            rawValue is String &&
            (rawValue.startsWith('http://') || rawValue.startsWith('https://'))) {
          final String? base64Image = await _fetchImageAndEncodeBase64(rawValue);
          flattenedRowData[fieldName] = base64Image;
        } else {
          flattenedRowData[fieldName] = rawValue;
        }
      }
      flattenedRowData['__isSubtotal__'] = row.cells.containsKey('__isSubtotal__')
          ? (row.cells['__isSubtotal__']!.value is bool ? row.cells['__isSubtotal__']!.value : false)
          : false;
      plutoRowsJsonForApi.add(flattenedRowData);
    }
    debugPrint("API Excel generation: ${plutoRowsJsonForApi.length} rows flattened (with images as base64) for API payload.");

    debugPrint("API Excel generation: Using grand totals: $grandTotalData");

    final client = http.Client();
    try {
      final excelResponse = await client.post(
        Uri.parse(_excelApiBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'columns': serializableColumns,
          'rows': plutoRowsJsonForApi,
          'exportId': _exportId,
          'fieldConfigs': widget.fieldConfigs,
          'reportLabel': widget.reportLabel,
          'displayParameterValues': widget.displayParameterValues,
          'companyNameForHeader': _companyNameForHeader,
          'grandTotalData': grandTotalData,
        }),
      ).timeout(const Duration(seconds: 60));

      if (excelResponse.statusCode == 200) {
        debugPrint('API Excel generation: Excel generated successfully by API.');
        return excelResponse.bodyBytes;
      } else {
        final String apiResponseBody = excelResponse.body.isNotEmpty ? excelResponse.body : 'No response body';
        debugPrint("API Excel generation: Excel API responded with Status ${excelResponse.statusCode}. Body: $apiResponseBody");
        throw Exception('Failed to generate Excel on server: Status ${excelResponse.statusCode} - $apiResponseBody');
      }
    } on TimeoutException catch (e) {
      debugPrint("API Excel generation: Timeout Exception: ${e.message}");
      throw Exception('Excel generation API request timed out. Please try again or check server.');
    } on SocketException catch (e) {
      debugPrint("API Excel generation: Socket Exception: ${e.message}");
      throw Exception('Network connection issue with Excel API. Check your internet or API URL.');
    } finally {
      client.close();
    }
  }


  // Helper function to fetch and encode image to Base64 (for API payload)
  Future<String?> _fetchImageAndEncodeBase64(String imageUrl) async {
    // This is run on the main thread when preparing API payload.
    if (!imageUrl.startsWith('http')) {
      return null; // Not a valid URL to fetch
    }
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        if (response.bodyBytes.isEmpty) return null;

        img_lib.Image? image;
        try {
          image = img_lib.decodeImage(response.bodyBytes);
        } catch (e) {
          debugPrint("Main Thread Image Fetch: Error decoding image bytes with img_lib for $imageUrl: $e. Using raw base64.");
        }

        if (image == null) {
          // Fallback: If image package can't decode, just base64 encode raw bytes
          if (response.bodyBytes.isNotEmpty) {
            final String base64String = base64Encode(response.bodyBytes);
            String mimeType = response.headers['content-type']?.split(';')[0] ?? 'application/octet-stream';
            return 'data:$mimeType;base64,$base64String';
          }
          return null;
        }

        const int targetHeightPx = 100;
        image = img_lib.copyResize(image, height: targetHeightPx, interpolation: img_lib.Interpolation.average);
        final List<int> resizedBytes = img_lib.encodeJpg(image, quality: 75);
        const String mimeType = 'image/jpeg';
        final String base64String = base64Encode(Uint8List.fromList(resizedBytes));
        return 'data:$mimeType;base64,$base64String';
      } else {
        debugPrint("Main Thread Image Fetch: Failed to fetch image (Status ${response.statusCode}) from: $imageUrl");
        return null;
      }
    } catch (e) {
      debugPrint("Main Thread Image Fetch: Error during image fetching/processing from $imageUrl: $e");
      return null;
    }
  }

  // Handles the iterative PDF export and download for chunked PDFs.
  Future<void> _exportNextPdfPart(BuildContext context, {bool initialCall = false}) async {
    final int currentPartNumberForDisplay = _currentPdfPartIndex + 1;

    // Check if all parts are done. This is the exit condition for the recursive calls.
    if (_currentPdfPartIndex >= _totalPdfParts) {
      debugPrint('PDF export: All parts exported. Releasing lock and updating UI.');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All PDF parts downloaded!')),
        );
      }
      ExportLock.endExport(); // Global lock released for the PDF sequence
      if (context.mounted) {
        setState(() {}); // Rebuild to re-enable buttons
      }
      return;
    }

    await _executeExportTask(
      context,
      'Export to PDF (Part $currentPartNumberForDisplay)',
          (progressUpdater) async {
        final int startRow = _currentPdfPartIndex * _rowsPerFilePart;
        final int endRow = min(startRow + _rowsPerFilePart, widget.plutoRows.length);
        final List<PlutoRow> currentRowsChunk = widget.plutoRows.sublist(startRow, endRow);

        final String partFileName = '${widget.fileName}_Part$currentPartNumberForDisplay.pdf';

        progressUpdater('Generating PDF part $currentPartNumberForDisplay of $_totalPdfParts (${startRow + 1} - $endRow rows)...');
        debugPrint('PDF export: Generating part $currentPartNumberForDisplay of $_totalPdfParts.');

        // Calculate grand totals once for the entire dataset (passed only to the last chunk)
        final Map<String, dynamic>? fullGrandTotalData = _calculateGrandTotals(widget.columns, widget.plutoRows, widget.fieldConfigs);

        // Pass grand totals only to the *last* chunk of the PDF
        final Map<String, dynamic>? currentChunkGrandTotals = (currentPartNumberForDisplay == _totalPdfParts) ? fullGrandTotalData : null;

        Uint8List pdfBytes = await _callPdfGenerationApiForChunk(
          rowsChunk: currentRowsChunk,
          chunkGrandTotals: currentChunkGrandTotals,
        );

        final result = await FileSaver.instance.saveFile(
          name: partFileName,
          bytes: pdfBytes,
          mimeType: MimeType.pdf,
        );
        DownloadTracker.trackDownload(partFileName, result, _exportId);
        debugPrint('PDF part $currentPartNumberForDisplay downloaded: $partFileName at $result');

        _currentPdfPartIndex++; // Increment part index for next iteration
      },
      showLoaderDialog: initialCall, // Show blocking dialog only for the initial call
      dismissUIAtEnd: false, // UI is NOT dismissed after an intermediate part download
      initialMessage: 'Downloading PDF part $currentPartNumberForDisplay of $_totalPdfParts...',
    );

    // After a part is downloaded and its _executeExportTask completes:
    if (_currentPdfPartIndex < _totalPdfParts) {
      if (_downloadingAllRemainingPdf) { // Check the PDF-specific flag
        debugPrint('PDF export: Auto-downloading next part...');
        Future.microtask(() => _exportNextPdfPart(context));
      } else {
        if (context.mounted) {
          final bool? shouldContinue = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text('Part $currentPartNumberForDisplay Downloaded!'),
              content: Text('Do you want to download Part ${_currentPdfPartIndex + 1} of $_totalPdfParts?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // User clicked Cancel
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true); // User clicked Download Next Part
                  },
                  child: const Text('Download Next Part'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    setState(() {
                      _downloadingAllRemainingPdf = true; // Set PDF-specific flag to auto-download
                    });
                  },
                  child: const Text('Download All Remaining'),
                ),
              ],
            ),
          );

          if (shouldContinue == true) {
            _exportNextPdfPart(context);
          } else {
            debugPrint('PDF download cancelled by user. Releasing lock and updating UI.');
            ExportLock.endExport(); // Explicitly release lock if user cancels
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF download cancelled.')),
              );
              setState(() {});
            }
          }
        }
      }
    } else {
      debugPrint('PDF export: All parts processed. Final step will trigger lock release.');
    }
  }


  // The main function for "Export to PDF" button.
  Future<void> _exportToPDF(BuildContext context) async {
    if (widget.plutoRows.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export!')),
        );
      }
      ExportLock.endExport();
      if (context.mounted) setState(() {});
      return;
    }

    final bool hasImages = _hasImageColumns();

    if (hasImages) {
      // CHUNKED PDF APPROACH (for images)
      setState(() {
        _currentPdfPartIndex = 0;
        _totalPdfParts = (widget.plutoRows.length / _rowsPerFilePart).ceil();
        if (_totalPdfParts == 0 && widget.plutoRows.isNotEmpty) {
          _totalPdfParts = 1;
        } else if (widget.plutoRows.isEmpty) {
          _totalPdfParts = 0;
        }
        _downloadingAllRemainingPdf = false; // Reset PDF-specific auto-download flag
      });

      if (_totalPdfParts == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export!')),
          );
        }
        ExportLock.endExport();
        if (context.mounted) setState(() {});
        return;
      }
      ExportLock.startExport(); // Acquired for the multi-part PDF process
      await _exportNextPdfPart(context, initialCall: true);
    } else {
      // SINGLE PDF FILE APPROACH (no images)
      ExportLock.startExport(); // Acquire global lock for this single operation
      try {
        await _executeExportTask(context, 'Export to PDF', (progressUpdater) async {
          progressUpdater('Generating PDF...');
          debugPrint('PDF export: No image columns detected. Generating single PDF via API.');

          final Map<String, dynamic>? grandTotalData =
          _calculateGrandTotals(widget.columns, widget.plutoRows, widget.fieldConfigs);

          Uint8List pdfBytes = await _callPdfGenerationApiForChunk(
            rowsChunk: widget.plutoRows, // All rows
            chunkGrandTotals: grandTotalData,
          );

          final fileName = '${widget.fileName}.pdf';
          final result = await FileSaver.instance.saveFile(
            name: fileName,
            bytes: pdfBytes,
            mimeType: MimeType.pdf,
          );
          DownloadTracker.trackDownload(fileName, result, _exportId);
          debugPrint('Single PDF export successful: $fileName at $result');

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$fileName downloaded successfully!')),
            );
          }
        }, initialMessage: 'Generating PDF...', dismissUIAtEnd: true);
      } finally {
        ExportLock.endExport(); // Release lock for this single operation
        if (context.mounted) setState(() {});
      }
    }
  }

  // --- NEW: Handle iterative Excel export and download for chunked Excel files ---
  Future<void> _exportNextExcelPart(BuildContext context, {bool initialCall = false}) async {
    final int currentPartNumberForDisplay = _currentExcelPartIndex + 1;

    // Check if all parts are done.
    if (_currentExcelPartIndex >= _totalExcelParts) {
      debugPrint('Excel export: All parts exported. Releasing lock and updating UI.');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All Excel parts downloaded!')),
        );
      }
      ExportLock.endExport(); // Global lock released for the Excel sequence
      if (context.mounted) {
        setState(() {}); // Rebuild to re-enable buttons
      }
      return;
    }

    await _executeExportTask(
      context,
      'Export to Excel (Part $currentPartNumberForDisplay)',
          (progressUpdater) async {
        final int startRow = _currentExcelPartIndex * _rowsPerFilePart;
        final int endRow = min(startRow + _rowsPerFilePart, widget.plutoRows.length);
        final List<PlutoRow> currentRowsChunk = widget.plutoRows.sublist(startRow, endRow);

        final String partFileName = '${widget.fileName}_Part$currentPartNumberForDisplay.xlsx';

        progressUpdater('Generating Excel part $currentPartNumberForDisplay of $_totalExcelParts (${startRow + 1} - $endRow rows)...');
        debugPrint('Excel export: Generating part $currentPartNumberForDisplay of $_totalExcelParts.');

        // Calculate grand totals once for the entire dataset (passed only to the last chunk)
        final Map<String, dynamic>? fullGrandTotalData = _calculateGrandTotals(widget.columns, widget.plutoRows, widget.fieldConfigs);
        // Pass grand totals only to the *last* chunk of the Excel file
        final Map<String, dynamic>? currentChunkGrandTotals = (currentPartNumberForDisplay == _totalExcelParts) ? fullGrandTotalData : null;

        Uint8List excelBytes = await _callExcelGenerationApi(
          rowsToProcess: currentRowsChunk,
          grandTotalData: currentChunkGrandTotals,
        );

        final result = await FileSaver.instance.saveFile(
          name: partFileName,
          bytes: excelBytes,
          mimeType: MimeType.microsoftExcel,
        );
        DownloadTracker.trackDownload(partFileName, result, _exportId);
        debugPrint('Excel part $currentPartNumberForDisplay downloaded: $partFileName at $result');

        _currentExcelPartIndex++; // Increment part index
      },
      showLoaderDialog: initialCall,
      dismissUIAtEnd: false, // Crucial: UI is NOT dismissed after an intermediate part download
      initialMessage: 'Downloading Excel part $currentPartNumberForDisplay of $_totalExcelParts...',
    );

    // After a part is downloaded:
    if (_currentExcelPartIndex < _totalExcelParts) {
      if (_downloadingAllRemainingExcel) { // Check the Excel-specific flag
        debugPrint('Excel export: Auto-downloading next part...');
        Future.microtask(() => _exportNextExcelPart(context));
      } else {
        if (context.mounted) {
          final bool? shouldContinue = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text('Part $currentPartNumberForDisplay Downloaded!'),
              content: Text('Do you want to download Part ${_currentExcelPartIndex + 1} of $_totalExcelParts?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Download Next Part'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    setState(() {
                      _downloadingAllRemainingExcel = true; // Set Excel-specific flag to auto-download
                    });
                  },
                  child: const Text('Download All Remaining'),
                ),
              ],
            ),
          );

          if (shouldContinue == true) {
            _exportNextExcelPart(context);
          } else {
            debugPrint('Excel download cancelled by user. Releasing lock and updating UI.');
            ExportLock.endExport(); // Explicitly release lock if user cancels
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Excel download cancelled.')),
              );
              setState(() {});
            }
          }
        }
      }
    } else {
      debugPrint('Excel export: All parts processed. Final step will trigger lock release.');
    }
  }


  // The main function for "Export to Excel" button.
  Future<void> _exportToExcel(BuildContext context) async {
    if (widget.plutoRows.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export!')),
        );
      }
      ExportLock.endExport();
      if (context.mounted) setState(() {});
      return;
    }

    final bool hasImages = _hasImageColumns();

    if (hasImages) {
      // CHUNKED EXCEL APPROACH (for images)
      setState(() {
        _currentExcelPartIndex = 0;
        _totalExcelParts = (widget.plutoRows.length / _rowsPerFilePart).ceil();
        if (_totalExcelParts == 0 && widget.plutoRows.isNotEmpty) {
          _totalExcelParts = 1;
        } else if (widget.plutoRows.isEmpty) {
          _totalExcelParts = 0;
        }
        _downloadingAllRemainingExcel = false; // Reset Excel-specific auto-download flag
      });

      if (_totalExcelParts == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export!')),
          );
        }
        ExportLock.endExport();
        if (context.mounted) setState(() {});
        return;
      }
      ExportLock.startExport(); // Acquire global lock for the multi-part Excel process
      await _exportNextExcelPart(context, initialCall: true);
    } else {
      // SINGLE EXCEL FILE APPROACH (no images)
      ExportLock.startExport(); // Acquire global lock for this single operation
      try {
        await _executeExportTask(context, 'Export to Excel', (progressUpdater) async {
          progressUpdater('Generating Excel...');
          debugPrint('Excel export: No image columns detected. Generating single Excel via API.');

          final Map<String, dynamic>? grandTotalData =
          _calculateGrandTotals(widget.columns, widget.plutoRows, widget.fieldConfigs);

          Uint8List excelBytes = await _callExcelGenerationApi(
            rowsToProcess: widget.plutoRows, // All rows
            grandTotalData: grandTotalData,
          );

          final fileName = '${widget.fileName}.xlsx';
          final result = await FileSaver.instance.saveFile(
            name: fileName,
            bytes: excelBytes,
            mimeType: MimeType.microsoftExcel,
          );
          DownloadTracker.trackDownload(fileName, result, _exportId);
          debugPrint('Single Excel export successful: $fileName at $result');

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$fileName downloaded successfully!')),
            );
          }
        }, initialMessage: 'Generating Excel...', dismissUIAtEnd: true);
      } finally {
        ExportLock.endExport(); // Release lock for this single operation
        if (context.mounted) setState(() {});
      }
    }
  }


  // Handles the "Print" functionality. Always generates a single PDF.
  Future<void> _printDocument(BuildContext context) async {
    if (widget.plutoRows.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to print!')),
        );
      }
      return; // Lock already handled by debouncer's finally
    }

    // For printing, we usually want one continuous document.
    await _executeExportTask(context, 'Print Document', (progressUpdater) async {
      progressUpdater('Generating document for print...');
      debugPrint('Print document: Initiating PDF byte generation for a single document.');

      final Map<String, dynamic>? grandTotalData = _calculateGrandTotals(widget.columns, widget.plutoRows, widget.fieldConfigs);

      Uint8List pdfBytes;
      if (_hasImageColumns()) {
        debugPrint("Print: Image columns detected. Generating PDF locally for print.");
        // Local generation still uses compute for image processing
        pdfBytes = await _generatePdfLocally(rowsToProcess: widget.plutoRows, grandTotalData: grandTotalData);
      } else {
        debugPrint("Print: No image columns. Calling PDF generation API for print.");
        // Use the API for a single large chunk
        pdfBytes = await _callPdfGenerationApiForChunk(
          rowsChunk: widget.plutoRows,
          chunkGrandTotals: grandTotalData,
        );
      }

      debugPrint('Print document: PDF bytes generated. Sending to printer.');
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: '${widget.fileName}_Print.pdf',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Browser print dialog opened.')),
        );
      }
      debugPrint('Print job initiated for ${widget.fileName}.pdf');
    }, initialMessage: 'Preparing document for print...', dismissUIAtEnd: true);
  }

  // Handles the "Send to Email" functionality. Attaches both Excel and PDF.
  // This will still generate a SINGLE Excel file and a SINGLE PDF file for attachments.
  Future<void> _sendToEmail(BuildContext context) async {
    final emailController = TextEditingController();
    final shouldSend = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Send to Email'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Recipient Email', hintText: 'Enter email address'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (emailController.text.isNotEmpty &&
                  RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text)) {
                Navigator.of(context).pop(true);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email address!')));
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (shouldSend != true) {
      debugPrint('Email sending cancelled by user.');
      return; // Lock already handled by debouncer's finally
    }

    if (widget.plutoRows.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to email!')),
        );
      }
      return; // Lock already handled by debouncer's finally
    }

    await _executeExportTask(context, 'Send to Email Processing', (progressUpdater) async {
      // For email, we ALWAYS want a single, complete Excel file.
      progressUpdater('Generating Excel for attachment...');
      debugPrint('Email: Generating Excel for attachment via API (single file).');

      final Map<String, dynamic>? grandTotalDataExcel = _calculateGrandTotals(widget.columns, widget.plutoRows, widget.fieldConfigs);

      Uint8List excelBytes = await _callExcelGenerationApi(
        rowsToProcess: widget.plutoRows, // ALL rows for email attachment
        grandTotalData: grandTotalDataExcel,
      );
      debugPrint('Email: Excel generated successfully by API.');

      // For email, we ALWAYS want a single, complete PDF.
      progressUpdater('Generating single PDF for attachment...');
      debugPrint('Email: Generating single PDF for attachment.');

      final Map<String, dynamic>? grandTotalDataPdf =
      _calculateGrandTotals(widget.columns, widget.plutoRows, widget.fieldConfigs);

      Uint8List pdfBytes;
      if (_hasImageColumns()) {
        debugPrint("Email: Image columns detected. Generating PDF locally for email attachment.");
        pdfBytes = await _generatePdfLocally(rowsToProcess: widget.plutoRows, grandTotalData: grandTotalDataPdf);
      } else {
        debugPrint("Email: No image columns. Calling PDF generation API for email attachment.");
        // Use the API for a single large chunk
        pdfBytes = await _callPdfGenerationApiForChunk(
          rowsChunk: widget.plutoRows,
          chunkGrandTotals: grandTotalDataPdf,
        );
      }

      debugPrint('Email: PDF generated successfully for attachment.');

      // Ensure 'archive' and 'http_parser' packages are in your pubspec.yaml for MultipartRequest
      final request = http.MultipartRequest('POST', Uri.parse('https://aquare.co.in/mobileAPI/sachin/reportBuilder/sendmail.php'));
      request.fields['email'] = emailController.text;
      request.files.add(http.MultipartFile.fromBytes('excel', excelBytes,
          filename: '${widget.fileName}.xlsx', contentType: MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet')));
      request.files.add(http.MultipartFile.fromBytes('pdf', pdfBytes,
          filename: '${widget.fileName}.pdf', contentType: MediaType('application', 'pdf')));

      progressUpdater('Sending email with attachments to ${emailController.text}...');
      debugPrint('Email: Sending email with attachments to ${emailController.text}...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        debugPrint('Email: Email sent successfully. Response: ${response.body}');
      } else {
        debugPrint('Email: Failed to send email. Status: ${response.statusCode}. Details: ${response.body}');
        throw Exception('Server failed to send email. Status: ${response.statusCode}. Details: ${response.body}');
      }
    }, initialMessage: 'Preparing email and attachments...', dismissUIAtEnd: true);
  }
}