import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:printing/printing.dart';
import 'dart:html' as html;

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
  final String fileName; // Base filename for the exported file
  final Map<String, String>? headerMap; // Field label to field name map
  final List<Map<String, dynamic>>? fieldConfigs; // Detailed field configurations
  final String reportLabel; // Actual report label for display
  final Map<String, String> parameterValues; // Selected parameter values
  final List<Map<String, dynamic>>? apiParameters; // API parameter configurations for filtering
  final Map<String, List<Map<String, String>>>? pickerOptions; // Picker options for display labels

  const ExportWidget({
    required this.data,
    required this.fileName,
    this.headerMap,
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
  bool _isExporting = false;
  int _clickCount = 0;
  final _excelDebouncer = Debouncer(const Duration(milliseconds: 1000));
  final _pdfDebouncer = Debouncer(const Duration(milliseconds: 1000));
  final _emailDebouncer = Debouncer(const Duration(milliseconds: 1000));
  final _printDebouncer = Debouncer(const Duration(milliseconds: 1000));
  String _exportId = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    print('ExportWidget: Initialized with exportId=$_exportId, fileName=${widget.fileName}');
  }

  @override
  Widget build(BuildContext context) {
    print('ExportWidget: Building with exportId=$_exportId, dataLength=${widget.data.length}');
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: widget.data.isNotEmpty && !_isExporting && !ExportLock.isExporting
                ? () async {
              print('ExportWidget: Excel button clicked, clickCount=${++_clickCount}, exportId=$_exportId, stack: ${StackTrace.current}');
              await _excelDebouncer.debounce(() async {
                await _exportToExcel(context);
              });
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.data.isNotEmpty && !_isExporting && !ExportLock.isExporting ? Colors.green : Colors.grey,
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
                ? () async {
              print('ExportWidget: PDF button clicked, exportId=$_exportId, stack: ${StackTrace.current}');
              await _pdfDebouncer.debounce(() async {
                await _exportToPDFWithLoading(context);
              });
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.data.isNotEmpty && !ExportLock.isExporting ? Colors.red : Colors.grey,
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
                ? () async {
              print('ExportWidget: Email button clicked, exportId=$_exportId, stack: ${StackTrace.current}');
              await _emailDebouncer.debounce(() async {
                await _sendToEmail(context);
              });
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.data.isNotEmpty && !ExportLock.isExporting ? Colors.blue : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Send to Email',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: widget.data.isNotEmpty && !ExportLock.isExporting
                ? () async {
              print('ExportWidget: Print button clicked, exportId=$_exportId, stack: ${StackTrace.current}');
              await _printDebouncer.debounce(() async {
                await _printDocument(context);
              });
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.data.isNotEmpty && !ExportLock.isExporting ? Colors.deepPurple : Colors.grey,
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

  Future<void> _exportToExcel(BuildContext context) async {
    print('ExportToExcel: Starting Excel export, exportId=$_exportId, stack: ${StackTrace.current}');
    final startTime = DateTime.now();

    try {
      if (widget.data.isEmpty) {
        print('ExportToExcel: No data to export, exportId=$_exportId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export!')),
          );
        }
        return;
      }

      if (_isExporting || ExportLock.isExporting) {
        print('ExportToExcel: Export already in progress (local or global), ignoring request, exportId=$_exportId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export already in progress!')),
          );
        }
        return;
      }

      print('ExportToExcel: Setting _isExporting to true and acquiring global lock, exportId=$_exportId');
      setState(() {
        _isExporting = true;
      });
      ExportLock.startExport();

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      print('ExportToExcel: Generating Excel file, exportId=$_exportId');
      final excelStartTime = DateTime.now();
      final excelBytes = await compute(_generateExcel, {
        'data': widget.data,
        'headerMap': widget.headerMap,
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

      if (kIsWeb) {
        print('ExportToExcel: Saving Excel file using file_saver, exportId=$_exportId');
        final fileName = '${widget.fileName}.xlsx';
        final result = await FileSaver.instance.saveFile(
          name: fileName,
          bytes: excelBytes,
          mimeType: MimeType.microsoftExcel,
        );
        print('ExportToExcel: File saved with result: $result, fileName: $fileName, exportId=$_exportId');
        DownloadTracker.trackDownload(fileName, 'file_saver', _exportId);
      } else {
        print('ExportToExcel: Platform is not web, showing not implemented message, exportId=$_exportId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel export not implemented for this platform!')),
          );
        }
      }

      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exported to Excel successfully!')),
        );
      }
    } catch (e) {
      print('ExportToExcel: Exception caught: $e, exportId=$_exportId');
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export to Excel: $e')),
        );
      }
    } finally {
      print('ExportToExcel: Resetting _isExporting to false and releasing global lock, exportId=$_exportId');
      setState(() {
        _isExporting = false;
      });
      ExportLock.endExport();
    }

    final endTime = DateTime.now();
    print('ExportToExcel: Total export time: ${endTime.difference(startTime).inMilliseconds} ms, exportId=$_exportId');
  }

  // --- Static Helper for Number Formatting (Used by Excel and PDF) ---
  static String _formatNumber(double number, int decimalPoints, {bool indianFormat = false}) {
    String numStr = number.toStringAsFixed(decimalPoints);
    List<String> parts = numStr.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    bool isNegative = integerPart.startsWith('-');
    if (isNegative) {
      integerPart = integerPart.substring(1);
    }

    if (indianFormat) {
      if (integerPart.length <= 3) {
        String result = integerPart;
        if (decimalPoints > 0 && decimalPart.isNotEmpty) {
          result += '.$decimalPart';
        }
        return isNegative ? '-$result' : result;
      }

      String lastThree = integerPart.substring(integerPart.length - 3);
      String remaining = integerPart.substring(0, integerPart.length - 3);

      String formattedRemaining = '';
      for (int i = remaining.length; i > 0; i -= 2) {
        int start = (i - 2 < 0) ? 0 : i - 2;
        String chunk = remaining.substring(start, i);
        if (formattedRemaining.isEmpty) {
          formattedRemaining = chunk;
        } else {
          formattedRemaining = '$chunk,$formattedRemaining';
        }
      }
      String result = '$formattedRemaining,$lastThree';
      if (decimalPoints > 0 && decimalPart.isNotEmpty) {
        result += '.$decimalPart';
      }
      return isNegative ? '-$result' : result;
    } else {
      final formatter = NumberFormat.currency(
        locale: 'en_US',
        symbol: '',
        decimalDigits: decimalPoints,
      );
      return formatter.format(number).trim();
    }
  }

  // --- _generateExcel function (static for compute) ---
  static Uint8List _generateExcel(Map<String, dynamic> params) {
    final exportId = params['exportId'] as String;
    final data = params['data'] as List<Map<String, dynamic>>;
    final headerMap = params['headerMap'] as Map<String, String>?;
    final fieldConfigs = params['fieldConfigs'] as List<Map<String, dynamic>>?;
    final reportLabel = params['reportLabel'] as String;
    final parameterValues = params['parameterValues'] as Map<String, String>;
    final apiParameters = params['apiParameters'] as List<Map<String, dynamic>>?;
    final pickerOptions = params['pickerOptions'] as Map<String, List<Map<String, String>>>?;

    print('GenerateExcel: Starting Excel generation, exportId=$exportId');
    var excel = Excel.createExcel();
    var sheet = excel['Sheet1'];

    int maxCols = 0;
    if (headerMap != null && headerMap.isNotEmpty) {
      maxCols = headerMap.length;
    } else if (data.isNotEmpty) {
      maxCols = data.first.keys.length;
    } else {
      maxCols = 1;
    }
    maxCols = maxCols > 0 ? maxCols : 1;

    // Add Report Label as a heading
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

    // Add Parameters (FILTERED and with display labels, NO "Report Parameters:" heading)
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
      // Fallback if apiParameters not provided, show all as they are (raw values)
      visibleAndFormattedParameters.addAll(parameterValues);
    }

    if (visibleAndFormattedParameters.isNotEmpty) {
      // Removed: sheet.appendRow([TextCellValue('Report Parameters:')]);
      // Removed: sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle = ...;
      for (var entry in visibleAndFormattedParameters.entries) {
        sheet.appendRow([TextCellValue('${entry.key}: ${entry.value}')]);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle = CellStyle(
          fontFamily: 'Calibri',
          fontSize: 10,
        );
      }
      sheet.appendRow([]); // Empty row for spacing
    }

    if (data.isEmpty) {
      print('GenerateExcel: Empty data provided, returning Excel with headers and title, exportId=$exportId');
      sheet.appendRow([TextCellValue('No data available')]);
      return Uint8List.fromList(excel.encode() ?? []);
    }

    print('GenerateExcel: Validating data consistency, exportId=$exportId');
    final headers = headerMap != null ? headerMap.keys.toList() : data.first.keys.toList();

    print('GenerateExcel: Generating Excel content, exportId=$exportId');
    final excelStartTime = DateTime.now();

    // Add header row
    sheet.appendRow(headers.map((header) => TextCellValue(header)).toList());
    print('GenerateExcel: Added header row: $headers, exportId=$exportId');

    // Apply header style (bold)
    final headerRowIndex = sheet.maxRows - 1;
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRowIndex)).cellStyle = CellStyle(
        fontFamily: 'Calibri',
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    // Add data rows with formatting
    for (var row in data) {
      final rowValues = headers.map((header) {
        final fieldName = headerMap != null ? headerMap[header] ?? header : header;
        final config = fieldConfigs?.firstWhere(
              (cfg) => cfg['Field_name']?.toString() == fieldName,
          orElse: () => {},
        );
        final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'GrandTotal', 'Value', 'Amount'].contains(fieldName) ||
            (config?['data_type']?.toString().toLowerCase() == 'number');
        final decimalPoints = int.tryParse(config?['decimal_points']?.toString() ?? '0') ?? 0;
        final indianFormat = config?['indian_format']?.toString() == '1';

        final rawValue = row[fieldName];
        if (isNumeric && rawValue != null && rawValue.toString().isNotEmpty) {
          final doubleValue = double.tryParse(rawValue.toString()) ?? 0.0;
          return TextCellValue(_formatNumber(doubleValue, decimalPoints, indianFormat: indianFormat));
        } else {
          return TextCellValue(rawValue?.toString() ?? '');
        }
      }).toList();
      sheet.appendRow(rowValues);

      // Apply cell styles for data rows (align numbers right)
      final dataRowIndex = sheet.maxRows - 1;
      for (int i = 0; i < headers.length; i++) {
        final fieldName = headerMap != null ? headerMap[headers[i]] ?? headers[i] : headers[i];
        final config = fieldConfigs?.firstWhere(
              (cfg) => cfg['Field_name']?.toString() == fieldName,
          orElse: () => {},
        );
        final alignment = config?['num_alignment']?.toString().toLowerCase() ?? 'left';
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: dataRowIndex)).cellStyle = CellStyle(
          horizontalAlign: alignment == 'center'
              ? HorizontalAlign.Center
              : alignment == 'right'
              ? HorizontalAlign.Right
              : HorizontalAlign.Left,
        );
      }
    }

    // Add total row if fieldConfigs is provided and contains totals
    if (fieldConfigs != null && fieldConfigs.any((config) => config['Total']?.toString() == '1')) {
      final totalRowValues = headers.map((header) {
        final fieldName = headerMap != null ? headerMap[header] ?? header : header;
        final config = fieldConfigs.firstWhere(
              (cfg) => cfg['Field_name']?.toString() == fieldName,
          orElse: () => {},
        );
        final total = config['Total']?.toString() == '1';
        final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'GrandTotal', 'Value', 'Amount'].contains(fieldName) ||
            (config['data_type']?.toString().toLowerCase() == 'number');
        final decimalPoints = int.tryParse(config['decimal_points']?.toString() ?? '0') ?? 0;
        final indianFormat = config['indian_format']?.toString() == '1';

        if (headers.indexOf(header) == 0) {
          return TextCellValue('Total');
        } else if (total && isNumeric) {
          final sum = data.fold<double>(0.0, (sum, row) {
            final value = row[fieldName]?.toString() ?? '0';
            return sum + (double.tryParse(value) ?? 0.0);
          });
          return TextCellValue(_formatNumber(sum, decimalPoints, indianFormat: indianFormat));
        }
        return TextCellValue('');
      }).toList();
      sheet.appendRow(totalRowValues);
      print('GenerateExcel: Added total row: $totalRowValues, exportId=$exportId');

      // Apply style to total row
      final totalRowIndex = sheet.maxRows - 1;
      for (int i = 0; i < headers.length; i++) {
        final fieldName = headerMap != null ? headerMap[headers[i]] ?? headers[i] : headers[i];
        final config = fieldConfigs.firstWhere(
              (cfg) => cfg['Field_name']?.toString() == fieldName,
          orElse: () => {},
        );
        final total = config['Total']?.toString() == '1';
        final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'GrandTotal', 'Value', 'Amount'].contains(fieldName) ||
            (config['data_type']?.toString().toLowerCase() == 'number');
        final alignment = config['num_alignment']?.toString().toLowerCase() ?? 'left';

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

    // Set column widths
    for (var i = 0; i < headers.length; i++) {
      final fieldName = headerMap != null ? headerMap[headers[i]] ?? headers[i] : headers[i];
      final config = fieldConfigs?.firstWhere(
            (cfg) => cfg['Field_name']?.toString() == fieldName,
        orElse: () => {},
      );
      final width = double.tryParse(config?['width']?.toString() ?? '15') ?? 15.0;
      sheet.setColumnWidth(i, width / 6);
    }

    final excelBytes = Uint8List.fromList(excel.encode() ?? []);
    final excelEndTime = DateTime.now();
    print('GenerateExcel: Excel generation took ${excelEndTime.difference(excelStartTime).inMilliseconds} ms, exportId=$exportId');
    print('GenerateExcel: Generated Excel bytes: ${excelBytes.length} bytes, exportId=$exportId');

    return excelBytes;
  }

  Future<void> _exportToPDFWithLoading(BuildContext context) async {
    print('ExportToPDF: Starting PDF export, exportId=$_exportId');
    final startTime = DateTime.now();

    try {
      if (widget.data.isEmpty) {
        print('ExportToPDF: No data to export, exportId=$_exportId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export!')),
          );
        }
        return;
      }

      print('ExportToPDF: Acquiring global lock, exportId=$_exportId');
      ExportLock.startExport();

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      print('ExportToPDF: Calling compute to generate PDF, exportId=$_exportId');
      final pdfStartTime = DateTime.now();
      final pdfBytes = await compute(_generatePDF, {
        'data': widget.data, // Export all data, no truncation
        'fileName': widget.fileName,
        'headerMap': widget.headerMap,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'parameterValues': widget.parameterValues,
        'apiParameters': widget.apiParameters,
        'pickerOptions': widget.pickerOptions,
      });
      final pdfEndTime = DateTime.now();
      print('ExportToPDF: PDF generation took ${pdfEndTime.difference(pdfStartTime).inMilliseconds} ms, exportId=$_exportId');

      if (kIsWeb) {
        print('ExportToPDF: Saving PDF file using file_saver, exportId=$_exportId');
        final fileName = '${widget.fileName}.pdf';
        final result = await FileSaver.instance.saveFile(
          name: fileName,
          bytes: pdfBytes,
          mimeType: MimeType.pdf,
        );
        print('ExportToPDF: File saved with result: $result, fileName: $fileName, exportId=$_exportId');
        DownloadTracker.trackDownload(fileName, 'file_saver', _exportId);
      } else {
        print('ExportToPDF: Platform is not web, showing not implemented message, exportId=$_exportId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF export not implemented for this platform!')),
          );
        }
      }

      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      print('ExportToPDF: PDF export completed successfully, exportId=$_exportId');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exported to PDF successfully!')),
        );
      }
    } catch (e) {
      print('ExportToPDF: Error during PDF export: $e, exportId=$_exportId');
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export to PDF: $e')),
        );
      }
    } finally {
      print('ExportToPDF: Releasing global lock, exportId=$_exportId');
      ExportLock.endExport();
    }

    final endTime = DateTime.now();
    print('ExportToPDF: Total PDF export time: ${endTime.difference(startTime).inMilliseconds} ms, exportId=$_exportId');
  }

  // --- _generatePDF function (static for compute) ---
  static Future<Uint8List> _generatePDF(Map<String, dynamic> params) async {
    final exportId = params['exportId'] as String;
    print('GeneratePDF: Starting PDF generation in isolate, exportId=$exportId');
    final data = params['data'] as List<Map<String, dynamic>>;
    final fileName = params['fileName'] as String; // Not directly used in PDF content, but good to keep
    final headerMap = params['headerMap'] as Map<String, String>?;
    final fieldConfigs = params['fieldConfigs'] as List<Map<String, dynamic>>?;
    final reportLabel = params['reportLabel'] as String;
    final parameterValues = params['parameterValues'] as Map<String, String>;
    final apiParameters = params['apiParameters'] as List<Map<String, dynamic>>?;
    final pickerOptions = params['pickerOptions'] as Map<String, List<Map<String, String>>>?;

    // Validate data
    if (data.isEmpty) {
      print('GeneratePDF: Empty data provided, returning empty PDF, exportId=$exportId');
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Text(
            'No data available',
            style: pw.TextStyle(fontSize: 12),
          ),
        ),
      );
      return await pdf.save();
    }

    print('GeneratePDF: Data length: ${data.length} rows, exportId=$exportId');
    final headers = headerMap != null ? headerMap.keys.toList() : data.first.keys.toList();
    print('GeneratePDF: Headers (count: ${headers.length}): $headers, exportId=$exportId');

    final pdf = pw.Document();
    const fontSize = 8.0;
    const headerFontSize = 10.0;
    const reportLabelFontSize = 14.0;
    const rowsPerPage = 20; // This is a pagination setting, not a hard limit for export

    // Load font
    print('GeneratePDF: Loading font, exportId=$exportId');
    pw.Font font;
    try {
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      font = pw.Font.ttf(fontData);
    } catch (e) {
      print('GeneratePDF: Failed to load font: $e, exportId=$exportId');
      font = pw.Font.helvetica(); // Fallback to built-in font
    }

    // Create a map for quick lookup of field configurations by field name
    final Map<String, Map<String, dynamic>> fieldConfigMap = {
      for (var config in (fieldConfigs ?? [])) config['Field_name']?.toString() ?? '': config
    };

    // Calculate column widths (dynamic based on PlutoGrid config width)
    double totalConfiguredWidth = 0.0;
    for (var headerLabel in headers) {
      final fieldName = headerMap != null ? headerMap[headerLabel] ?? headerLabel : headerLabel;
      final config = fieldConfigMap[fieldName];
      totalConfiguredWidth += double.tryParse(config?['width']?.toString() ?? '100') ?? 100.0;
    }

    if (totalConfiguredWidth == 0 && headers.isNotEmpty) {
      totalConfiguredWidth = headers.length * 100.0;
    }
    totalConfiguredWidth = totalConfiguredWidth > 0 ? totalConfiguredWidth : (headers.isNotEmpty ? headers.length * 100.0 : 100.0);


    final Map<int, pw.TableColumnWidth> columnWidths = {};
    for (int i = 0; i < headers.length; i++) {
      final headerLabel = headers[i];
      final fieldName = headerMap != null ? headerMap[headerLabel] ?? headerLabel : headerLabel;
      final config = fieldConfigMap[fieldName];
      final width = double.tryParse(config?['width']?.toString() ?? '100') ?? 100.0;
      columnWidths[i] = pw.FlexColumnWidth(width / totalConfiguredWidth);
    }

    // Calculate total row
    final List<String>? totalRowValues = fieldConfigs != null && fieldConfigs.any((config) => config['Total']?.toString() == '1')
        ? headers.map((header) {
      final fieldName = headerMap != null ? headerMap[header] ?? header : header;
      final config = fieldConfigMap[fieldName];
      final total = config?['Total']?.toString() == '1';
      final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'GrandTotal', 'Value', 'Amount'].contains(fieldName) ||
          (config?['data_type']?.toString().toLowerCase() == 'number');
      final decimalPoints = int.tryParse(config?['decimal_points']?.toString() ?? '0') ?? 0;
      final indianFormat = config?['indian_format']?.toString() == '1';

      if (headers.indexOf(header) == 0) {
        return 'Total';
      } else if (total && isNumeric) {
        final sum = data.fold<double>(0.0, (sum, row) {
          final value = row[fieldName]?.toString() ?? '0';
          return sum + (double.tryParse(value) ?? 0.0);
        });
        return _formatNumber(sum, decimalPoints, indianFormat: indianFormat);
      }
      return '';
    }).toList()
        : null;
    if (totalRowValues != null) {
      print('GeneratePDF: Total row: $totalRowValues, exportId=$exportId');
    }

    // Add Parameters (FILTERED and with display labels)
    final Map<String, String> visibleAndFormattedParameters = <String, String>{};
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

    // Split data into pages
    print('GeneratePDF: Splitting data into pages, exportId=$exportId');
    final List<List<Map<String, dynamic>>> pages = [];
    for (var i = 0; i < data.length; i += rowsPerPage) {
      final end = (i + rowsPerPage < data.length) ? i + rowsPerPage : data.length;
      pages.add(data.sublist(i, end));
    }
    print('GeneratePDF: Number of pages created: ${pages.length}, exportId=$exportId');

    // Add pages
    print('GeneratePDF: Adding pages to PDF, exportId=$exportId');
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final pageData = pages[pageIndex];
      print('GeneratePDF: Adding page ${pageIndex + 1} with ${pageData.length} rows, exportId=$exportId');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape.copyWith(
            marginLeft: 20,
            marginRight: 20,
            marginTop: 20,
            marginBottom: 20,
          ),
          build: (pw.Context context) {
            print('GeneratePDF: Building page ${pageIndex + 1} content, exportId=$exportId');

            final children = <pw.Widget>[
              // Report Label
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
              // Parameters
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
                  'Page ${pageIndex + 1} of ${pages.length}',
                  style: pw.TextStyle(font: font, fontSize: fontSize),
                ),
              ),
              pw.SizedBox(height: 10),
              // Main data table
              pw.Table(
                columnWidths: columnWidths,
                border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey500),
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey100,
                    ),
                    children: headers.map((headerLabel) {
                      final fieldName = headerMap != null ? headerMap[headerLabel] ?? headerLabel : headerLabel;
                      final config = fieldConfigMap[fieldName];
                      final alignment = config?['num_alignment']?.toString().toLowerCase();

                      pw.TextAlign headerTextAlign = pw.TextAlign.center; // Default for headers
                      if (alignment == 'left') {
                        headerTextAlign = pw.TextAlign.left;
                      } else if (alignment == 'right') {
                        headerTextAlign = pw.TextAlign.right;
                      }

                      return pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        alignment: pw.Alignment.center, // Visually center the header text within its cell
                        child: pw.Text(
                          headerLabel,
                          style: pw.TextStyle(
                            font: font,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: headerFontSize,
                          ),
                          textAlign: headerTextAlign, // Apply alignment to header text
                        ),
                      );
                    }).toList(),
                  ),
                  // Data Rows
                  ...pageData.map((row) {
                    return pw.TableRow(
                      children: headers.map((headerLabel) {
                        final fieldName = headerMap != null ? headerMap[headerLabel] ?? headerLabel : headerLabel;
                        final config = fieldConfigMap[fieldName];

                        final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'GrandTotal', 'Value', 'Amount'].contains(fieldName) ||
                            (config?['data_type']?.toString().toLowerCase() == 'number');
                        final decimalPoints = int.tryParse(config?['decimal_points']?.toString() ?? '0') ?? 0;
                        final indianFormat = config?['indian_format']?.toString() == '1';
                        final alignment = config?['num_alignment']?.toString().toLowerCase();

                        final rawValue = row[fieldName];
                        String displayValue = rawValue?.toString() ?? '';

                        if (isNumeric && rawValue != null && rawValue.toString().isNotEmpty) {
                          final doubleValue = double.tryParse(rawValue.toString()) ?? 0.0;
                          displayValue = _formatNumber(doubleValue, decimalPoints, indianFormat: indianFormat);
                        } else {
                          // No truncation for text fields either, let PDF library handle wrapping
                          // displayValue = value.length > 100 ? '${value.substring(0, 100)}...' : value; // REMOVED
                        }

                        pw.TextAlign cellTextAlign = pw.TextAlign.left; // Default for data cells
                        if (alignment == 'center') {
                          cellTextAlign = pw.TextAlign.center;
                        } else if (alignment == 'right') {
                          cellTextAlign = pw.TextAlign.right;
                        }

                        return pw.Container(
                          padding: const pw.EdgeInsets.all(2),
                          alignment: (cellTextAlign == pw.TextAlign.left) ? pw.Alignment.centerLeft :
                          (cellTextAlign == pw.TextAlign.right) ? pw.Alignment.centerRight :
                          pw.Alignment.center,
                          child: pw.Text(
                            displayValue,
                            style: pw.TextStyle(font: font, fontSize: fontSize),
                            textAlign: cellTextAlign,
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ],
              ),
            ];

            if (totalRowValues != null && pageIndex == pages.length - 1) {
              children.addAll([
                pw.SizedBox(height: 10),
                pw.Table(
                  columnWidths: columnWidths,
                  border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey500),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blueGrey50,
                      ),
                      children: totalRowValues.asMap().entries.map((entry) {
                        final i = entry.key;
                        final value = entry.value;

                        final headerLabel = headers[i];
                        final fieldName = headerMap != null ? headerMap[headerLabel] ?? headerLabel : headerLabel;
                        final config = fieldConfigMap[fieldName];
                        final isNumeric = ['VQ_GrandTotal', 'Qty', 'Rate', 'GrandTotal', 'Value', 'Amount'].contains(fieldName) ||
                            (config?['data_type']?.toString().toLowerCase() == 'number');
                        final alignment = config?['num_alignment']?.toString().toLowerCase();

                        pw.TextAlign totalTextAlign = pw.TextAlign.left; // Default for total row
                        if (i == 0) { // First column "Total" label
                          totalTextAlign = pw.TextAlign.left;
                        } else if (isNumeric && alignment == 'center') {
                          totalTextAlign = pw.TextAlign.center;
                        } else if (isNumeric && alignment == 'right') {
                          totalTextAlign = pw.TextAlign.right;
                        } else if (isNumeric) { // Default for numeric totals if alignment is not specified
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
                              fontSize: headerFontSize, // Use header font size for totals
                            ),
                            textAlign: totalTextAlign,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ]);
              print('GeneratePDF: Added total row table to page ${pageIndex + 1}: $totalRowValues, exportId=$exportId');
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            );
          },
        ),
      );
    }

    print('GeneratePDF: Saving PDF, exportId=$exportId');
    final pdfBytes = await pdf.save();
    print('GeneratePDF: PDF generation completed, returning bytes (${pdfBytes.length} bytes), exportId=$exportId');

    return pdfBytes;
  }

  // NEW: _printDocument method
  Future<void> _printDocument(BuildContext context) async {
    print('PrintDocument: Starting print process, exportId=$_exportId');
    final startTime = DateTime.now();

    try {
      if (widget.data.isEmpty) {
        print('PrintDocument: No data to print, exportId=$_exportId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to print!')),
          );
        }
        return;
      }

      print('PrintDocument: Acquiring global lock, exportId=$_exportId');
      ExportLock.startExport();

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      print('PrintDocument: Calling compute to generate PDF, exportId=$_exportId');
      final pdfStartTime = DateTime.now();
      final pdfBytes = await compute(_generatePDF, {
        'data': widget.data, // Print all data, no truncation
        'fileName': widget.fileName,
        'headerMap': widget.headerMap,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'parameterValues': widget.parameterValues,
        'apiParameters': widget.apiParameters,
        'pickerOptions': widget.pickerOptions,
      });
      final pdfEndTime = DateTime.now();
      print('PrintDocument: PDF generation took ${pdfEndTime.difference(pdfStartTime).inMilliseconds} ms, exportId=$_exportId');

      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(url, '_blank');
        html.Url.revokeObjectUrl(url);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF opened in new tab. Use browser print options.')),
          );
        }
      } else {
        print('PrintDocument: Platform is not web. Using printing package to share/print PDF, exportId=$_exportId');
        await Printing.sharePdf(bytes: pdfBytes, filename: '${widget.fileName}_Print.pdf');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF prepared for printing. Select a printer from the system dialog.')),
          );
        }
      }

      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      print('PrintDocument: Print process completed successfully, exportId=$_exportId');
    } catch (e) {
      print('PrintDocument: Error during print process: $e, exportId=$_exportId');
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare document for printing: $e')),
        );
      }
    } finally {
      print('PrintDocument: Releasing global lock, exportId=$_exportId');
      ExportLock.endExport();
    }

    final endTime = DateTime.now();
    print('PrintDocument: Total print process time: ${endTime.difference(startTime).inMilliseconds} ms, exportId=$_exportId');
  }

  Future<void> _sendToEmail(BuildContext context) async {
    print('SendToEmail: Starting email sending process, exportId=$_exportId');
    try {
      if (widget.data.isEmpty) {
        print('SendToEmail: No data to send, exportId=$_exportId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to send!')),
          );
        }
        return;
      }

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
        return;
      }

      print('SendToEmail: Acquiring global lock, exportId=$_exportId');
      ExportLock.startExport();

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Generate Excel file
      print('SendToEmail: Generating Excel file, exportId=$_exportId');
      final excelBytes = await compute(_generateExcel, {
        'data': widget.data,
        'headerMap': widget.headerMap,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'parameterValues': widget.parameterValues,
        'apiParameters': widget.apiParameters,
        'pickerOptions': widget.pickerOptions,
      });

      // Generate PDF file (now generates all data)
      print('SendToEmail: Generating PDF file, exportId=$_exportId');
      final pdfBytes = await compute(_generatePDF, {
        'data': widget.data, // All data for PDF
        'fileName': widget.fileName,
        'headerMap': widget.headerMap,
        'exportId': _exportId,
        'fieldConfigs': widget.fieldConfigs,
        'reportLabel': widget.reportLabel,
        'parameterValues': widget.parameterValues,
        'apiParameters': widget.apiParameters,
        'pickerOptions': widget.pickerOptions,
      });

      print('SendToEmail: Preparing multipart HTTP request, exportId=$_exportId');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost/sendmail.php'), // Placeholder
      );

      request.fields['email'] = emailController.text;
      print('SendToEmail: Added email field: ${emailController.text}, exportId=$_exportId');

      request.files.add(http.MultipartFile.fromBytes(
        'excel',
        excelBytes,
        filename: '${widget.fileName}.xlsx',
        contentType: MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      ));
      print('SendToEmail: Added Excel file: ${widget.fileName}.xlsx, exportId=$_exportId');

      request.files.add(http.MultipartFile.fromBytes(
        'pdf',
        pdfBytes,
        filename: '${widget.fileName}.pdf',
        contentType: MediaType('application', 'pdf'),
      ));
      print('SendToEmail: Added PDF file: ${widget.fileName}.pdf, exportId=$_exportId');

      print('SendToEmail: Sending HTTP request to backend, exportId=$_exportId');
      final response = await request.send();
      print('SendToEmail: HTTP response status code: ${response.statusCode}, exportId=$_exportId');
      final responseString = await response.stream.bytesToString();
      print('SendToEmail: HTTP response body: $responseString, exportId=$_exportId');

      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (response.statusCode == 200 && responseString.contains('Success')) {
        print('SendToEmail: Files sent to email successfully, exportId=$_exportId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Files sent to email successfully!')),
          );
        }
      } else {
        print('SendToEmail: Failed to send email. Status: ${response.statusCode}, Response: $responseString, exportId=$_exportId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send email: ${responseString.isNotEmpty ? responseString : 'Unknown error'}')),
          );
        }
      }
    } catch (e) {
      print('SendToEmail: Exception caught: $e, exportId=$_exportId');
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send email: $e')),
        );
      }
    } finally {
      print('SendToEmail: Releasing global lock, exportId=$_exportId');
      ExportLock.endExport();
    }
  }
}