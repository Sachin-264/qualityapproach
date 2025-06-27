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
import 'package:excel/excel.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:pdf/pdf.dart' as pdf_lib;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:collection/collection.dart';
import 'package:image/image.dart' as img_lib;
import 'package:archive/archive.dart'; // Import for zipping
import 'package:archive/archive_io.dart'; // For ZipEncoder

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

  // Define the number of rows to process per chunk for isolate communication
  // For multi-part PDFs, this also defines how many rows go into each PDF file.
  static const int _pdfRowsPerFile = 1000; // Example: 1000 rows per PDF file

  static const String _pdfApiBaseUrl = 'https://pdf-node-kbfu8swqw-vishal-jains-projects-b322eb37.vercel.app/api/generate-pdf';

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
          ElevatedButton(
            onPressed: canExport
                ? () async {
              await _printDebouncer.debounce(() async {
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
          ...widget.topLevelActions,
        ],
      ),
    );
  }

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
      Future<void> Function() task,
      String taskName, {
        bool showLoaderDialog = true,
        String initialMessage = 'Processing...',
        Function(String)? onProgressUpdate, // Callback for progress messages
      }) async {
    if (widget.plutoRows.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export!')),
        );
      }
      return;
    }

    if (ExportLock.isExporting) {
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

    // Use a ValueNotifier to update the message dynamically in the UI
    final ValueNotifier<String> currentMessage = ValueNotifier(initialMessage);

    if (context.mounted) {
      if (!showLoaderDialog) {
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
            duration: const Duration(minutes: 5), // Keep it long, as progress updates will manage visibility
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Hide',
              textColor: Colors.white,
              onPressed: () => snackBarController?.close(),
            ),
          ),
        );
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && ExportLock.isExporting) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => PopScope( // Use PopScope for better control on back button
                canPop: false, // Prevent dialog dismissal by back button
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
          }
        });
      }
    }

    // Set the progress update callback - this will update the ValueNotifier used by the UI
    Function(String)? internalProgressUpdater = (msg) => currentMessage.value = msg;
    if (onProgressUpdate != null) {
      Function(String originalMsg) externalOnProgress = onProgressUpdate;
      internalProgressUpdater = (msg) {
        currentMessage.value = msg;
        externalOnProgress(msg);
      };
    }

    try {
      await task(); // Execute the main task
      internalProgressUpdater('Task completed successfully!'); // Final success message

      if (context.mounted) {
        if (!showLoaderDialog && snackBarController != null) {
          snackBarController.close();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$taskName successful!')),
          );
        }
      }
    } catch (e) {
      if (!e.toString().contains('Email sending cancelled by user.')) {
        String errorMessage = 'Failed to $taskName: $e';
        debugPrint('Error during $taskName: $e');
        if (context.mounted) {
          if (!showLoaderDialog && snackBarController != null) {
            snackBarController.close();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } finally {
      if (dialogShown && context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ExportLock.endExport();
      if (context.mounted) {
        setState(() {}); // Rebuild to re-enable buttons
      }
    }
  }

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

  // Isolate function to process rows and fetch/encode images
  static Future<Map<String, dynamic>> _processRowsInIsolate(Map<String, dynamic> params) async {
    debugPrint("Isolate: Starting _processRowsInIsolate");
    final List<Map<String, dynamic>> rawPlutoRowsJson = params['plutoRowsJson'] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> fieldConfigs = params['fieldConfigs'] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> serializableColumns = params['serializableColumns'] as List<Map<String, dynamic>>;

    final Map<String, String?> isolateBase64ImageCache = {};

    Future<String?> _isolateFetchImageAndEncodeBase64(String imageUrl) async {
      if (isolateBase64ImageCache.containsKey(imageUrl)) {
        // debugPrint("Isolate: Cache hit for image: $imageUrl");
        return isolateBase64ImageCache[imageUrl];
      }
      if (!imageUrl.startsWith('http')) {
        // debugPrint("Isolate: Not an http image URL: $imageUrl");
        isolateBase64ImageCache[imageUrl] = null;
        return null;
      }

      try {
        // debugPrint("Isolate: Fetching image from: $imageUrl");
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
            // Fallback: If image package can't decode, just base64 encode raw bytes if they are not empty
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
          const String mimeType = 'image/jpeg';
          final String base64String = base64Encode(Uint8List.fromList(resizedBytes));
          final String dataUrl = 'data:$mimeType;base64,$base64String';
          isolateBase64ImageCache[imageUrl] = dataUrl;
          // debugPrint("Isolate: Image processed and cached for: $imageUrl");
          return dataUrl;
        } else {
          debugPrint("Isolate: Failed to fetch image (Status ${response.statusCode}) from: $imageUrl. Response body: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}");
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

  // New helper function to generate PDF for a specific chunk of PlutoRows, with images handled locally
  Future<Uint8List> _generatePdfWithImagesLocallyForChunk(List<PlutoRow> rowsChunk) async {
    debugPrint("Local PDF generation for chunk: Starting local PDF generation with images.");
    final doc = pw.Document();

    final poppinsRegular = await PdfGoogleFonts.poppinsRegular();
    final poppinsBold = await PdfGoogleFonts.poppinsBold();
    debugPrint("Local PDF generation for chunk: Fonts loaded.");

    final List<Map<String, dynamic>> serializableColumns = widget.columns
        .where((col) => col.field != '__actions__' && col.field != '__raw_data__')
        .map((col) => {'field': col.field, 'title': col.title, 'width': col.width})
        .toList();
    debugPrint("Local PDF generation for chunk: Serializable columns prepared. Count: ${serializableColumns.length}");

    final List<Map<String, dynamic>> allPlutoRowsJsonForCompute = [];
    for (var row in rowsChunk) { // Iterate only over the provided chunk
      final Map<String, dynamic> flattenedRowData = {};

      for (var col in serializableColumns) {
        final fieldName = col['field'] as String;
        if (row.cells.containsKey(fieldName)) {
          flattenedRowData[fieldName] = row.cells[fieldName]?.value;
        } else {
          flattenedRowData[fieldName] = null;
        }
      }
      flattenedRowData['__isSubtotal__'] = row.cells.containsKey('__isSubtotal__')
          ? (row.cells['__isSubtotal__']!.value is bool ? row.cells['__isSubtotal__']!.value : false)
          : false;
      allPlutoRowsJsonForCompute.add(flattenedRowData);
    }
    debugPrint("Local PDF generation for chunk: ${allPlutoRowsJsonForCompute.length} rows flattened for single compute call.");

    List<Map<String, dynamic>> allProcessedSerializableRows = [];
    try {
      final preProcessResult = await compute(_processRowsInIsolate, {
        'plutoRowsJson': allPlutoRowsJsonForCompute,
        'fieldConfigs': widget.fieldConfigs ?? [],
        'serializableColumns': serializableColumns,
      });
      debugPrint("Local PDF generation for chunk: Isolate processing complete. Result received.");
      allProcessedSerializableRows = preProcessResult['serializableRows'];
    } catch (e, stack) {
      debugPrint("Local PDF generation ERROR for chunk: Failed during compute call: $e\n$stack");
      rethrow;
    }

    final Map<String, dynamic>? grandTotalData = _calculateGrandTotals(widget.columns, rowsChunk, widget.fieldConfigs);
    debugPrint("Local PDF generation for chunk: Calculated grand totals: $grandTotalData");


    doc.addPage(
      pw.MultiPage(
        pageFormat: pdf_lib.PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildPdfHeader(poppinsRegular, poppinsBold),
        footer: (context) => _buildPdfFooter(context, poppinsRegular),
        build: (context) => [
          _buildPdfContentTable(serializableColumns, allProcessedSerializableRows, grandTotalData, poppinsRegular, poppinsBold),
        ],
      ),
    );
    debugPrint("Local PDF generation for chunk: PDF document built. Saving...");
    return doc.save();
  }

  pw.Widget _buildPdfHeader(pw.Font regularFont, pw.Font boldFont) {
    // debugPrint("PDF Header: Building header."); // Too verbose if called for every page
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

  pw.Widget _buildPdfFooter(pw.Context context, pw.Font font) {
    // debugPrint("PDF Footer: Building footer."); // Too verbose
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
    // debugPrint("PDF Table: Headers prepared. Count: ${headers.length}"); // Too verbose

    final data = rows.map<List<pw.Widget>>((row) {
      bool isSubtotal = row.containsKey('__isSubtotal__') && row['__isSubtotal__'] == true;
      if (!row.containsKey('cells') || row['cells'] is! Map<String, dynamic>) {
        debugPrint("PDF Table ERROR: Skipping malformed row, 'cells' is missing or not a Map: $row");
        return columns.map((col) => pw.Container(alignment: pw.Alignment.center, child: pw.Text('Data Error', style: pw.TextStyle(font: regularFont, fontSize: 8)))).toList();
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

        if (config?['image']?.toString() == '1' && rawValue is String && rawValue.startsWith('data:image')) {
          try {
            final imageData = base64Decode(rawValue.split(',').last);
            return pw.Container(
              width: 50,
              height: 50,
              alignment: pw.Alignment.center,
              child: pw.Image(pw.MemoryImage(imageData), fit: pw.BoxFit.contain),
            );
          } catch (e) {
            debugPrint('PDF Table Cell ERROR: Error decoding image data for field $fieldName: $e');
            return pw.Container(alignment: alignment, child: pw.Text('Invalid Image', style: pw.TextStyle(font: regularFont, fontSize: 8)));
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

  // New helper function to generate PDF for a specific chunk of PlutoRows, via API
  Future<Uint8List> _callPdfGenerationApiForChunk(List<PlutoRow> rowsChunk) async {
    debugPrint("API PDF generation for chunk: Preparing data for API call.");
    final List<Map<String, dynamic>> serializableColumns = widget.columns
        .where((col) => col.field != '__actions__' && col.field != '__raw_data__')
        .map((col) => {
      'field': col.field,
      'title': col.title,
      'width': col.width,
      'decimal_points': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['decimal_points'],
      'indian_format': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['indian_format'],
      'num_alignment': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['num_alignment'],
      'Total': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['Total'],
      'SubTotal': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['SubTotal'],
      'Breakpoint': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['Breakpoint'],
      'data_type': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['data_type'],
      'image': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['image'],
      'time': widget.fieldConfigs?.firstWhereOrNull((fc) => fc['Field_name'] == col.field)?['time'],
    })
        .toList();
    debugPrint("API PDF generation for chunk: Serializable columns prepared. Count: ${serializableColumns.length}");

    final List<Map<String, dynamic>> plutoRowsJsonForApi = [];
    for (var row in rowsChunk) { // Iterate only over the provided chunk
      final Map<String, dynamic> flattenedRowData = {};
      for (var col in serializableColumns) {
        final fieldName = col['field'] as String;
        if (row.cells.containsKey(fieldName)) {
          flattenedRowData[fieldName] = row.cells[fieldName]?.value;
        } else {
          flattenedRowData[fieldName] = null;
        }
      }
      flattenedRowData['__isSubtotal__'] = row.cells.containsKey('__isSubtotal__')
          ? (row.cells['__isSubtotal__']!.value is bool ? row.cells['__isSubtotal__']!.value : false)
          : false;
      plutoRowsJsonForApi.add(flattenedRowData);
    }
    debugPrint("API PDF generation for chunk: ${plutoRowsJsonForApi.length} rows flattened for API payload.");

    final Map<String, dynamic>? grandTotalData = _calculateGrandTotals(widget.columns, rowsChunk, widget.fieldConfigs);
    debugPrint("API PDF generation for chunk: Calculated grand totals: $grandTotalData");

    final Map<String, dynamic> requestBody = {
      'columns': serializableColumns,
      'rows': plutoRowsJsonForApi,
      'fileName': widget.fileName,
      'exportId': _exportId,
      'fieldConfigs': widget.fieldConfigs,
      'reportLabel': widget.reportLabel,
      'visibleAndFormattedParameters': widget.displayParameterValues,
      'companyNameForHeader': _companyNameForHeader,
      'grandTotalData': grandTotalData,
      'includePdfFooterDateTime': widget.includePdfFooterDateTime,
    };
    debugPrint("API PDF generation for chunk: Sending request to PDF API.");
    try {
      final response = await http.post(
        Uri.parse(_pdfApiBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        debugPrint("API PDF generation for chunk: PDF generated successfully by API.");
        return response.bodyBytes;
      } else {
        debugPrint("API PDF generation for chunk: Failed to generate PDF on server: ${response.statusCode} - ${response.body}");
        throw Exception('Failed to generate PDF on server: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API PDF generation for chunk: Error calling PDF API: $e');
      rethrow;
    }
  }

  // Modified _exportToPDF to generate multiple PDFs and zip them
  Future<void> _exportToPDF(BuildContext context) async {
    await _executeExportTask(context, () async {
      debugPrint('PDF export: Initiating multi-part PDF generation.');

      final List<({String fileName, Uint8List bytes})> pdfParts = [];
      final totalRows = widget.plutoRows.length;
      final numParts = (totalRows / _pdfRowsPerFile).ceil();

      for (int i = 0; i < numParts; i++) {
        final int startRow = i * _pdfRowsPerFile;
        final int endRow = (startRow + _pdfRowsPerFile > totalRows) ? totalRows : startRow + _pdfRowsPerFile;
        final List<PlutoRow> currentRowsChunk = widget.plutoRows.sublist(startRow, endRow);

        String partFileName = widget.fileName;
        if (numParts > 1) { // Only append part number if there are multiple parts
          partFileName = '${widget.fileName}_Part${i + 1}';
        }

        // Update UI progress for current part
        // Note: _executeExportTask manages the single UI loader/snackbar.
        // We're updating its internal message via its 'onProgressUpdate' callback.
        if (context.mounted) {
          final message = 'Generating PDF part ${i + 1} of $numParts (${startRow + 1} - $endRow rows)...';
          // This calls the internalProgressUpdater of the parent _executeExportTask
          // by passing a dummy async function to its 'task' parameter, and then
          // directly calling 'onProgressUpdate'. This is a bit of a hack to
          // update the message from an inner loop without spawning new _executeExportTask.
          // A better design might be to pass the ValueNotifier directly.
          if (ModalRoute.of(context)?.isCurrent == true) { // Check if context is still valid
            // Re-invoke _executeExportTask to update its message. This is still not ideal.
            // The ideal way to update the existing _executeExportTask's message is via a direct callback.
            // Let's assume _executeExportTask's onProgressUpdate is the way.
            (context as Element).visitAncestorElements((element) {
              if (element.widget is _ExportWidgetState && (element.state as _ExportWidgetState)._isExportingGlobally) {
                // This is a direct hack to access the internal message notifier.
                // In a real app, you'd pass a callback or a notifier more cleanly.
                (element.state as _ExportWidgetState)._executeExportTask(
                    element.context, () async {}, 'Export to PDF', // Dummy task
                    showLoaderDialog: false, // Don't show new dialog
                    initialMessage: message // Update message
                );
                return false; // Stop visiting ancestors
              }
              return true; // Continue visiting
            });
          }
        }


        Uint8List pdfBytes;
        if (_hasImageColumns()) {
          pdfBytes = await _generatePdfWithImagesLocallyForChunk(currentRowsChunk);
        } else {
          pdfBytes = await _callPdfGenerationApiForChunk(currentRowsChunk);
        }
        pdfParts.add((fileName: '$partFileName.pdf', bytes: pdfBytes));
        debugPrint('PDF part ${i + 1} generated: $partFileName.pdf');
      }

      // If there's only one part, just save it directly (no need to zip)
      if (pdfParts.length == 1) {
        final firstPart = pdfParts.first;
        final result = await FileSaver.instance.saveFile(
          name: firstPart.fileName,
          bytes: firstPart.bytes,
          mimeType: MimeType.pdf,
        );
        DownloadTracker.trackDownload(firstPart.fileName, result, _exportId);
        debugPrint('Single PDF export successful: ${firstPart.fileName} at $result');
      } else {
        // If multiple parts, create a ZIP file
        final archive = Archive();
        for (var part in pdfParts) {
          archive.addFile(ArchiveFile(part.fileName, part.bytes.length, part.bytes));
        }
        final zipBytes = ZipEncoder().encode(archive);
        if (zipBytes == null) {
          throw Exception('Failed to create ZIP archive. Resulting bytes were null.');
        }

        final zipFileName = '${widget.fileName}_Parts.zip';
        final result = await FileSaver.instance.saveFile(
          name: zipFileName,
          bytes: Uint8List.fromList(zipBytes),
          mimeType: MimeType.zip,
        );
        DownloadTracker.trackDownload(zipFileName, result, _exportId);
        debugPrint('Multi-part PDF export successful (zipped): $zipFileName at $result');
      }

    }, 'Export to PDF', showLoaderDialog: false, initialMessage: 'Preparing PDF exports...');
  }


  Future<void> _printDocument(BuildContext context) async {
    // For printing, we usually want one continuous document.
    // So, we'll revert to generating one large PDF for print, using the combined logic.
    await _executeExportTask(context, () async {
      debugPrint('Print document: Initiating PDF byte generation for a single document.');

      // Consolidate all rows for the print operation
      final List<Map<String, dynamic>> serializableColumns = widget.columns
          .where((col) => col.field != '__actions__' && col.field != '__raw_data__')
          .map((col) => {'field': col.field, 'title': col.title, 'width': col.width})
          .toList();

      final List<Map<String, dynamic>> allPlutoRowsJsonForCompute = [];
      for (var row in widget.plutoRows) {
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

      final Map<String, dynamic>? grandTotalData = _calculateGrandTotals(widget.columns, widget.plutoRows, widget.fieldConfigs);

      Uint8List pdfBytes;
      if (_hasImageColumns()) {
        debugPrint("Print: Image columns detected. Generating PDF locally for print.");
        final doc = pw.Document();
        final poppinsRegular = await PdfGoogleFonts.poppinsRegular();
        final poppinsBold = await PdfGoogleFonts.poppinsBold();

        List<Map<String, dynamic>> allProcessedSerializableRows = [];
        try {
          final preProcessResult = await compute(_processRowsInIsolate, {
            'plutoRowsJson': allPlutoRowsJsonForCompute,
            'fieldConfigs': widget.fieldConfigs ?? [],
            'serializableColumns': serializableColumns,
          });
          allProcessedSerializableRows = preProcessResult['serializableRows'];
        } catch (e, stack) {
          debugPrint("Print ERROR: Failed during compute call: $e\n$stack");
          rethrow;
        }

        doc.addPage(
          pw.MultiPage(
            pageFormat: pdf_lib.PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(30),
            header: (context) => _buildPdfHeader(poppinsRegular, poppinsBold),
            footer: (context) => _buildPdfFooter(context, poppinsRegular),
            build: (context) => [
              _buildPdfContentTable(serializableColumns, allProcessedSerializableRows, grandTotalData, poppinsRegular, poppinsBold),
            ],
          ),
        );
        pdfBytes = await doc.save();

      } else {
        debugPrint("Print: No image columns. Calling PDF generation API for print.");
        final Map<String, dynamic> requestBody = {
          'columns': serializableColumns,
          'rows': allPlutoRowsJsonForCompute,
          'fileName': widget.fileName,
          'exportId': _exportId,
          'fieldConfigs': widget.fieldConfigs,
          'reportLabel': widget.reportLabel,
          'visibleAndFormattedParameters': widget.displayParameterValues,
          'companyNameForHeader': _companyNameForHeader,
          'grandTotalData': grandTotalData,
          'includePdfFooterDateTime': widget.includePdfFooterDateTime,
        };
        try {
          final response = await http.post(
            Uri.parse(_pdfApiBaseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          );

          if (response.statusCode == 200) {
            pdfBytes = response.bodyBytes;
          } else {
            throw Exception('Failed to generate PDF on server for print: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          debugPrint('Print: Error calling PDF API: $e');
          rethrow;
        }
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
    }, 'Print Document', initialMessage: 'Preparing document for print...');
  }

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
              if (emailController.text.isNotEmpty && RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text)) {
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
      return;
    }

    await _executeExportTask(context, () async {
      final serializableColumnsForExcel = widget.columns
          .where((col) => col.field != '__raw_data__')
          .map((col) => {'field': col.field, 'title': col.title, 'width': col.width})
          .toList();

      final serializableRowsForExcel = widget.plutoRows.map((row) {
        final cellsMap = <String, dynamic>{};
        for (var col in widget.columns) {
          cellsMap[col.field] = row.cells[col.field]?.value;
        }
        if (row.cells.containsKey('__isSubtotal__')) {
          cellsMap['__isSubtotal__'] = row.cells['__isSubtotal__']!.value;
        }
        return cellsMap;
      }).toList();

      final grandTotalDataExcel = _calculateGrandTotals(widget.columns, widget.plutoRows, widget.fieldConfigs);

      debugPrint('Email: Generating Excel for attachment...');
      final excelBytes = await compute(_generateExcel, {
        'columns': serializableColumnsForExcel,
        'rows': serializableRowsForExcel,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'displayParameterValues': widget.displayParameterValues,
        'companyNameForHeader': _companyNameForHeader,
        'grandTotalData': grandTotalDataExcel,
      });
      debugPrint('Email: Excel generated successfully for attachment.');

      // For email, we generally want to attach a single PDF for convenience.
      // So, this will also generate one large PDF, similar to print.
      debugPrint('Email: Generating single PDF for attachment...');

      // Consolidate all rows for the PDF attachment
      final List<Map<String, dynamic>> serializableColumnsForPdf = widget.columns
          .where((col) => col.field != '__actions__' && col.field != '__raw_data__')
          .map((col) => {'field': col.field, 'title': col.title, 'width': col.width})
          .toList();

      final List<Map<String, dynamic>> allPlutoRowsJsonForPdf = [];
      for (var row in widget.plutoRows) {
        final Map<String, dynamic> flattenedRowData = {};
        for (var col in serializableColumnsForPdf) {
          final fieldName = col['field'] as String;
          flattenedRowData[fieldName] = row.cells.containsKey(fieldName) ? row.cells[fieldName]?.value : null;
        }
        flattenedRowData['__isSubtotal__'] = row.cells.containsKey('__isSubtotal__')
            ? (row.cells['__isSubtotal__']!.value is bool ? row.cells['__isSubtotal__']!.value : false)
            : false;
        allPlutoRowsJsonForPdf.add(flattenedRowData);
      }

      final Map<String, dynamic>? grandTotalDataPdf = _calculateGrandTotals(widget.columns, widget.plutoRows, widget.fieldConfigs);

      Uint8List pdfBytes;
      if (_hasImageColumns()) {
        debugPrint("Email: Image columns detected. Generating PDF locally for email attachment.");
        final doc = pw.Document();
        final poppinsRegular = await PdfGoogleFonts.poppinsRegular();
        final poppinsBold = await PdfGoogleFonts.poppinsBold();

        List<Map<String, dynamic>> allProcessedSerializableRows = [];
        try {
          final preProcessResult = await compute(_processRowsInIsolate, {
            'plutoRowsJson': allPlutoRowsJsonForPdf,
            'fieldConfigs': widget.fieldConfigs ?? [],
            'serializableColumns': serializableColumnsForPdf,
          });
          allProcessedSerializableRows = preProcessResult['serializableRows'];
        } catch (e, stack) {
          debugPrint("Email PDF ERROR: Failed during compute call: $e\n$stack");
          rethrow;
        }

        doc.addPage(
          pw.MultiPage(
            pageFormat: pdf_lib.PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(30),
            header: (context) => _buildPdfHeader(poppinsRegular, poppinsBold),
            footer: (context) => _buildPdfFooter(context, poppinsRegular),
            build: (context) => [
              _buildPdfContentTable(serializableColumnsForPdf, allProcessedSerializableRows, grandTotalDataPdf, poppinsRegular, poppinsBold),
            ],
          ),
        );
        pdfBytes = await doc.save();

      } else {
        debugPrint("Email: No image columns. Calling PDF generation API for email attachment.");
        final Map<String, dynamic> requestBody = {
          'columns': serializableColumnsForPdf,
          'rows': allPlutoRowsJsonForPdf,
          'fileName': widget.fileName,
          'exportId': _exportId,
          'fieldConfigs': widget.fieldConfigs,
          'reportLabel': widget.reportLabel,
          'visibleAndFormattedParameters': widget.displayParameterValues,
          'companyNameForHeader': _companyNameForHeader,
          'grandTotalData': grandTotalDataPdf,
          'includePdfFooterDateTime': widget.includePdfFooterDateTime,
        };
        try {
          final response = await http.post(
            Uri.parse(_pdfApiBaseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          );

          if (response.statusCode == 200) {
            pdfBytes = response.bodyBytes;
          } else {
            throw Exception('Failed to generate PDF on server for email: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          debugPrint('Email PDF: Error calling PDF API: $e');
          rethrow;
        }
      }

      debugPrint('Email: PDF generated successfully for attachment.');

      final request = http.MultipartRequest('POST', Uri.parse('https://aquare.co.in/mobileAPI/sachin/reportBuilder/sendmail.php'));
      request.fields['email'] = emailController.text;
      request.files.add(http.MultipartFile.fromBytes('excel', excelBytes,
          filename: '${widget.fileName}.xlsx', contentType: MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet')));
      request.files.add(http.MultipartFile.fromBytes('pdf', pdfBytes,
          filename: '${widget.fileName}.pdf', contentType: MediaType('application', 'pdf')));

      debugPrint('Email: Sending email with attachments to ${emailController.text}...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        debugPrint('Email: Email sent successfully. Response: ${response.body}');
      } else {
        debugPrint('Email: Failed to send email. Status: ${response.statusCode}. Details: ${response.body}');
        throw Exception('Server failed to send email. Status: ${response.statusCode}. Details: ${response.body}');
      }
    }, 'Send to Email Processing', initialMessage: 'Preparing email and attachments...');
  }

  static String _formatNumber(double number, int decimalPoints, {bool indianFormat = false}) {
    String pattern = '##,##,##0';
    if (decimalPoints > 0) {
      pattern += '.${'0' * decimalPoints}';
    }
    return NumberFormat(pattern, indianFormat ? 'en_IN' : 'en_US').format(number);
  }

  static Uint8List _generateExcel(Map<String, dynamic> params) {
    debugPrint('Excel Isolate: Starting Excel generation.');
    final columns = params['columns'] as List<Map<String, dynamic>>;
    final rows = params['rows'] as List<Map<String, dynamic>>;
    final fieldConfigs = params['fieldConfigs'] as List<Map<String, dynamic>>?;
    final reportLabel = params['reportLabel'] as String;
    final displayParameterValues = params['displayParameterValues'] as Map<String, String>;
    final companyNameForHeader = params['companyNameForHeader'] as String?;
    final grandTotalData = params['grandTotalData'] as Map<String, dynamic>?;

    var excel = Excel.createExcel();
    var sheet = excel['Sheet1'];

    final fieldNames = columns
        .where((col) => col['field'] != '__actions__' && col['field'] != '__raw_data__')
        .map<String>((col) => col['field'].toString())
        .toList();
    final headerLabels = columns
        .where((col) => col['field'] != '__actions__' && col['field'] != '__raw_data__')
        .map<String>((col) => col['title'].toString())
        .toList();

    int maxCols = headerLabels.length;
    debugPrint('Excel Isolate: Max Columns = $maxCols');

    if (companyNameForHeader != null && companyNameForHeader.isNotEmpty) {
      sheet.appendRow([TextCellValue(companyNameForHeader)]);
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1),
          CellIndex.indexByColumnRow(columnIndex: maxCols - 1, rowIndex: sheet.maxRows - 1));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle =
          CellStyle(fontFamily: 'Calibri', fontSize: 14, bold: true, horizontalAlign: HorizontalAlign.Center);
      sheet.appendRow([]);
      debugPrint('Excel Isolate: Added company name header.');
    }

    sheet.appendRow([TextCellValue(reportLabel)]);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1),
        CellIndex.indexByColumnRow(columnIndex: maxCols - 1, rowIndex: sheet.maxRows - 1));
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle =
        CellStyle(fontFamily: 'Calibri', fontSize: 18, bold: true, horizontalAlign: HorizontalAlign.Center);
    sheet.appendRow([]);
    debugPrint('Excel Isolate: Added report label header.');

    if (displayParameterValues.isNotEmpty) {
      for (var entry in displayParameterValues.entries) {
        sheet.appendRow([TextCellValue('${entry.key}: ${entry.value}')]);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle =
            CellStyle(fontFamily: 'Calibri', fontSize: 10);
      }
      sheet.appendRow([]);
      debugPrint('Excel Isolate: Added parameters.');
    }

    if (rows.isEmpty) {
      sheet.appendRow([TextCellValue('No data available')]);
      debugPrint('Excel Isolate: No data to export.');
      return Uint8List.fromList(excel.encode() ?? []);
    }

    sheet.appendRow(headerLabels.map((h) => TextCellValue(h)).toList());
    final headerRowIndex = sheet.maxRows - 1;
    for (int i = 0; i < headerLabels.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRowIndex)).cellStyle =
          CellStyle(fontFamily: 'Calibri', bold: true, horizontalAlign: HorizontalAlign.Center);
    }
    debugPrint('Excel Isolate: Added column headers.');

    final fieldConfigMap = {for (var config in (fieldConfigs ?? [])) config['Field_name']?.toString() ?? '': config};

    for (var rowData in rows) {
      final isSubtotalRow = rowData['__isSubtotal__'] == true;
      final rowValues = fieldNames.map((fieldName) {
        final rawValue = rowData[fieldName];
        final config = fieldConfigMap[fieldName];
        bool isNumeric = (config?['data_type']?.toString().toLowerCase() == 'number') ||
            config?['Total']?.toString() == '1' ||
            config?['SubTotal']?.toString() == '1';
        final decimalPoints = int.tryParse(config?['decimal_points']?.toString() ?? '0') ?? 0;
        final indianFormat = config?['indian_format']?.toString() == '1';

        if (isSubtotalRow && fieldName == fieldNames[0]) {
          return TextCellValue(rawValue?.toString() ?? 'Subtotal');
        } else if (isNumeric && rawValue != null) {
          final doubleValue = double.tryParse(rawValue.toString()) ?? 0.0;
          return TextCellValue(_formatNumber(doubleValue, decimalPoints, indianFormat: indianFormat));
        } else if (config?['image']?.toString() == '1' && rawValue != null) {
          return TextCellValue('Image Data (Link/Base64)');
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
            config?['Total']?.toString() == '1' ||
            config?['SubTotal']?.toString() == '1';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: dataRowIndex)).cellStyle = CellStyle(
          horizontalAlign: isNumeric ? (alignment == 'center' ? HorizontalAlign.Center : HorizontalAlign.Right) : HorizontalAlign.Left,
          bold: isSubtotalRow,
          fontFamily: 'Calibri',
        );
      }
    }
    debugPrint('Excel Isolate: Added data rows.');

    if (grandTotalData != null) {
      final totalRowValues = fieldNames.map((fieldName) {
        final config = fieldConfigMap[fieldName];
        final isTotalCol = config?['Total']?.toString() == '1';
        bool isNumeric = (config?['data_type']?.toString().toLowerCase() == 'number') || isTotalCol;
        final decimalPoints = int.tryParse(config?['decimal_points']?.toString() ?? '0') ?? 0;
        final indianFormat = config?['indian_format']?.toString() == '1';
        if (fieldName == fieldNames[0]) {
          return TextCellValue(grandTotalData[fieldName]?.toString() ?? 'Grand Total');
        } else if (isTotalCol && isNumeric && grandTotalData.containsKey(fieldName)) {
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
        final isTotalCol = config?['Total']?.toString() == '1';
        final alignment = config?['num_alignment']?.toString().toLowerCase() ?? 'left';
        bool isNumeric = (config?['data_type']?.toString().toLowerCase() == 'number') || isTotalCol;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: totalRowIndex)).cellStyle = CellStyle(
          fontFamily: 'Calibri',
          bold: true,
          horizontalAlign: i == 0 ? HorizontalAlign.Left : (isNumeric ? (alignment == 'center' ? HorizontalAlign.Center : HorizontalAlign.Right) : HorizontalAlign.Left),
        );
      }
    }
    debugPrint('Excel Isolate: Added grand total row.');

    for (var i = 0; i < fieldNames.length; i++) {
      final fieldName = fieldNames[i];
      final config = fieldConfigMap[fieldName];
      final width = double.tryParse(config?['width']?.toString() ?? '100') ?? 100.0;
      sheet.setColumnWidth(i, width / 6);
    }
    debugPrint('Excel Isolate: Set column widths.');
    debugPrint('Excel Isolate: Excel generation complete.');
    return Uint8List.fromList(excel.encode() ?? []);
  }
}