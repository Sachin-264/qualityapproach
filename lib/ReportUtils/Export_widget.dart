
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
final List<Map<String, dynamic>>? fieldConfigs;
static const int _rowsPerPage = 20;

const ExportWidget({
required this.data,
required this.fileName,
this.headerMap,
this.fieldConfigs,
super.key,
});

@override
_ExportWidgetState createState() => _ExportWidgetState();
}

class _ExportWidgetState extends State<ExportWidget> {
bool _isExporting = false;
int _clickCount = 0;
final _excelDebouncer = Debouncer(Duration(milliseconds: 1000));
final _pdfDebouncer = Debouncer(Duration(milliseconds: 1000));
final _emailDebouncer = Debouncer(Duration(milliseconds: 1000));
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
await _excelDebouncer.debounce(() => _exportToExcel(context));
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
? () => _pdfDebouncer.debounce(() {
print('ExportWidget: PDF button clicked, exportId=$_exportId, stack: ${StackTrace.current}');
_exportToPDFWithLoading(context);
})
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
? () => _emailDebouncer.debounce(() {
print('ExportWidget: Email button clicked, exportId=$_exportId, stack: ${StackTrace.current}');
_sendToEmail(context);
})
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
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('No data to export!')),
);
return;
}

if (_isExporting || ExportLock.isExporting) {
print('ExportToExcel: Export already in progress (local or global), ignoring request, exportId=$_exportId');
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Export already in progress!')),
);
return;
}

print('ExportToExcel: Setting _isExporting to true and acquiring global lock, exportId=$_exportId');
setState(() {
_isExporting = true;
});
ExportLock.startExport();

print('ExportToExcel: Showing loading dialog, exportId=$_exportId');
showDialog(
context: context,
barrierDismissible: false,
builder: (context) => const Center(child: CircularProgressIndicator()),
);

print('ExportToExcel: Generating Excel file, exportId=$_exportId');
final excelStartTime = DateTime.now();
final excelBytes = await compute(_generateExcel, {
'data': widget.data,
'headerMap': widget.headerMap,
'exportId': _exportId,
'fieldConfigs': widget.fieldConfigs,
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
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Excel export not implemented for this platform!')),
);
}

print('ExportToExcel: Closing loading dialog, exportId=$_exportId');
Navigator.of(context).pop();

print('ExportToExcel: Showing success message, exportId=$_exportId');
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Exported to Excel successfully!')),
);
} catch (e) {
print('ExportToExcel: Exception caught: $e, exportId=$_exportId');
Navigator.of(context).pop();
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Failed to export to Excel: $e')),
);
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

static Uint8List _generateExcel(Map<String, dynamic> params) {
final exportId = params['exportId'] as String;
final data = params['data'] as List<Map<String, dynamic>>;
final headerMap = params['headerMap'] as Map<String, String>?;
final fieldConfigs = params['fieldConfigs'] as List<Map<String, dynamic>>?;

print('GenerateExcel: Starting Excel generation, exportId=$exportId');
if (data.isEmpty) {
print('GenerateExcel: Empty data provided, returning empty Excel, exportId=$exportId');
var excel = Excel.createExcel();
return Uint8List.fromList(excel.encode() ?? []);
}

print('GenerateExcel: Validating data consistency, exportId=$exportId');
final headers = headerMap != null ? headerMap.keys.toList() : data.first.keys.toList();
for (var row in data) {
if (row.keys.toSet().intersection(headers.toSet()).isEmpty) {
print('GenerateExcel: Warning: Row has no matching headers, exportId=$exportId');
}
}

print('GenerateExcel: Generating Excel content, exportId=$exportId');
final excelStartTime = DateTime.now();
var excel = Excel.createExcel();
var sheet = excel['Sheet1'];

// Add header row
sheet.appendRow(headers.map((header) => TextCellValue(header)).toList());
print('GenerateExcel: Added header row: $headers, exportId=$exportId');

// Add data rows
for (var row in data) {
final rowValues = headers.map((header) {
final key = headerMap != null ? headerMap[header] ?? header : header;
return TextCellValue(row[key]?.toString() ?? 'N/A');
}).toList();
sheet.appendRow(rowValues);
}
print('GenerateExcel: Added ${data.length} data rows, exportId=$exportId');

// Add total row if fieldConfigs is provided and contains totals
if (fieldConfigs != null && fieldConfigs.any((config) => config['Total']?.toString() == '1')) {
final totalRow = headers.map((header) {
final key = headerMap != null ? headerMap[header] ?? header : header;
final config = fieldConfigs.firstWhere(
(config) => config['Field_name']?.toString() == key,
orElse: () => {},
);
final total = config['Total']?.toString() == '1';
final indianFormat = config['indian_format']?.toString() == '1';
final decimalPoints = int.tryParse(config['decimal_points']?.toString() ?? '0') ?? 0;

if (total) {
final sum = data.fold<double>(0.0, (sum, row) {
final value = row[key]?.toString() ?? '0';
return sum + (double.tryParse(value) ?? 0.0);
});
final formatter = NumberFormat.currency(
locale: indianFormat ? 'en_IN' : 'en_US',
symbol: '',
decimalDigits: decimalPoints,
);
return TextCellValue(formatter.format(sum));
}
return TextCellValue(headers.indexOf(header) == 0 ? 'Total' : '');
}).toList();
sheet.appendRow(totalRow);
print('GenerateExcel: Added total row: $totalRow, exportId=$exportId');
}

// Set column widths
for (var i = 0; i < headers.length; i++) {
final key = headerMap != null ? headerMap[headers[i]] ?? headers[i] : headers[i];
final config = fieldConfigs?.firstWhere(
(config) => config['Field_name']?.toString() == key,
orElse: () => {},
);
final total = config?['Total']?.toString() == '1';
sheet.setColumnWidth(i, total ? 30.0 : 15.0); // Wider for total columns
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
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('No data to export!')),
);
return;
}

print('ExportToPDF: Data length: ${widget.data.length} rows, exportId=$_exportId');
if (widget.data.length > 500) {
print('ExportToPDF: Data exceeds 500 rows, prompting user, exportId=$_exportId');
final shouldProceed = await showDialog<bool>(
context: context,
builder: (context) => AlertDialog(
title: const Text('Large Data Warning'),
content: Text(
'The dataset contains ${widget.data.length} rows, which may take a long time to export to PDF or fail. Do you want to proceed with the first 500 rows only?',
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
print('ExportToPDF: User cancelled due to large data, exportId=$_exportId');
return;
}
print('ExportToPDF: Proceeding with first 500 rows, exportId=$_exportId');
}

print('ExportToPDF: Acquiring global lock, exportId=$_exportId');
ExportLock.startExport();

print('ExportToPDF: Showing loading dialog, exportId=$_exportId');
showDialog(
context: context,
barrierDismissible: false,
builder: (context) => const Center(child: CircularProgressIndicator()),
);

print('ExportToPDF: Calling compute to generate PDF, exportId=$_exportId');
final pdfStartTime = DateTime.now();
final pdfBytes = await compute(_generatePDF, {
'data': widget.data.length > 500 ? widget.data.sublist(0, 500) : widget.data,
'fileName': widget.fileName,
'headerMap': widget.headerMap,
'exportId': _exportId,
'fieldConfigs': widget.fieldConfigs,
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
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('PDF export not implemented for this platform!')),
);
}

print('ExportToPDF: Closing loading dialog, exportId=$_exportId');
Navigator.of(context).pop();
print('ExportToPDF: PDF export completed successfully, exportId=$_exportId');
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
print('ExportToPDF: Total PDF export time: ${endTime.difference(startTime).inMilliseconds} ms, exportId=$_exportId');
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

print('SendToEmail: Dialog result: shouldSend=$shouldSend, exportId=$_exportId');
if (shouldSend != true) {
print('SendToEmail: Email sending cancelled by user, exportId=$_exportId');
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

print('SendToEmail: Generating Excel file, exportId=$_exportId');
final excelStartTime = DateTime.now();
final excelBytes = await compute(_generateExcel, {
'data': widget.data,
'headerMap': widget.headerMap,
'exportId': _exportId,
'fieldConfigs': widget.fieldConfigs,
});
final excelEndTime = DateTime.now();
print('SendToEmail: Excel generation took ${excelEndTime.difference(excelStartTime).inMilliseconds} ms, exportId=$_exportId');

print('SendToEmail: Generating PDF file, exportId=$_exportId');
final pdfStartTime = DateTime.now();
final pdfBytes = await compute(_generatePDF, {
'data': widget.data.length > 500 ? widget.data.sublist(0, 500) : widget.data,
'fileName': widget.fileName,
'headerMap': widget.headerMap,
'exportId': _exportId,
'fieldConfigs': widget.fieldConfigs,
});
final pdfEndTime = DateTime.now();
print('SendToEmail: PDF generation took ${pdfEndTime.difference(pdfStartTime).inMilliseconds} ms, exportId=$_exportId');

print('SendToEmail: Preparing multipart HTTP request, exportId=$_exportId');
final request = http.MultipartRequest(
'POST',
Uri.parse('http://localhost/sendmail.php'),
);

request.fields['email'] = emailController.text;
print('SendToEmail: Added email field: ${emailController.text}, exportId=$_exportId');

request.files.add(http.MultipartFile.fromBytes(
'excel',
excelBytes,
filename: '${widget.fileName}.xlsx',
));
print('SendToEmail: Added Excel file: ${widget.fileName}.xlsx, exportId=$_exportId');

request.files.add(http.MultipartFile.fromBytes(
'pdf',
pdfBytes,
filename: '${widget.fileName}.pdf',
));
print('SendToEmail: Added PDF file: ${widget.fileName}.pdf, exportId=$_exportId');

print('SendToEmail: Sending HTTP request to http://localhost/sendmail.php, exportId=$_exportId');
final response = await request.send();
print('SendToEmail: HTTP response status code: ${response.statusCode}, exportId=$_exportId');
final responseString = await response.stream.bytesToString();
print('SendToEmail: HTTP response body: $responseString, exportId=$_exportId');

print('SendToEmail: Closing loading dialog, exportId=$_exportId');
Navigator.of(context).pop();

if (response.statusCode == 200 && responseString == 'Success') {
print('SendToEmail: Files sent to email successfully, exportId=$_exportId');
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Files sent to email successfully!')),
);
} else {
print('SendToEmail: Failed to send email. Status: ${response.statusCode}, Response: $responseString, exportId=$_exportId');
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
print('GeneratePDF: Starting PDF generation in isolate, exportId=$exportId');
final data = params['data'] as List<Map<String, dynamic>>;
final fileName = params['fileName'] as String;
final headerMap = params['headerMap'] as Map<String, String>?;
final fieldConfigs = params['fieldConfigs'] as List<Map<String, dynamic>>?;

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
const fontSize = 6.0;
const rowsPerPage = 20;
final pageFormat = PdfPageFormat.a4.landscape;

// Load font
print('GeneratePDF: Loading font, exportId=$exportId');
final fontStartTime = DateTime.now();
late pw.Font font;
try {
final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
font = pw.Font.ttf(fontData);
} catch (e) {
print('GeneratePDF: Failed to load font: $e, exportId=$exportId');
font = pw.Font.helvetica(); // Fallback to built-in font
}
final fontEndTime = DateTime.now();
print('GeneratePDF: Font loading took ${fontEndTime.difference(fontStartTime).inMilliseconds} ms, exportId=$exportId');

// Calculate column widths (equal for simplicity)
final availableWidth = pageFormat.width - 40; // 20pt margins on each side
final columnWidth = availableWidth / headers.length;
final columnWidths = <int, pw.TableColumnWidth>{
for (var i = 0; i < headers.length; i++) i: pw.FixedColumnWidth(columnWidth),
};

// Calculate total row
final totalRow = fieldConfigs != null && fieldConfigs.any((config) => config['Total']?.toString() == '1')
? headers.map((header) {
final key = headerMap != null ? headerMap[header] ?? header : header;
final config = fieldConfigs.firstWhere(
(config) => config['Field_name']?.toString() == key,
orElse: () => {},
);
final total = config['Total']?.toString() == '1';
final indianFormat = config['indian_format']?.toString() == '1';
final decimalPoints = int.tryParse(config['decimal_points']?.toString() ?? '0') ?? 0;

if (total) {
final sum = data.fold<double>(0.0, (sum, row) {
final value = row[key]?.toString() ?? '0';
return sum + (double.tryParse(value) ?? 0.0);
});
final formatter = NumberFormat.currency(
locale: indianFormat ? 'en_IN' : 'en_US',
symbol: '',
decimalDigits: decimalPoints,
);
return formatter.format(sum);
}
return headers.indexOf(header) == 0 ? 'Total' : '';
}).toList()
    : null;
if (totalRow != null) {
print('GeneratePDF: Total row: $totalRow, exportId=$exportId');
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
final pageStartTime = DateTime.now();
for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
final pageData = pages[pageIndex];
print('GeneratePDF: Adding page ${pageIndex + 1} with ${pageData.length} rows, exportId=$exportId');

// Prepare table data
final tableData = pageData.map((row) {
final rowValues = headers.map((header) {
final key = headerMap != null ? headerMap[header] ?? header : header;
final value = row[key]?.toString() ?? 'N/A';
// Truncate long values to prevent rendering issues
return value.length > 50 ? value.substring(0, 50) + '...' : value;
}).toList();
print('GeneratePDF: Row data for page ${pageIndex + 1}: $rowValues, exportId=$exportId');
return rowValues;
}).toList();

pdf.addPage(
pw.Page(
pageFormat: pageFormat.copyWith(
marginLeft: 20,
marginRight: 20,
marginTop: 20,
marginBottom: 20,
),
build: (pw.Context context) {
print('GeneratePDF: Building page ${pageIndex + 1} content, exportId=$exportId');
print('GeneratePDF: Table data for page ${pageIndex + 1}: ${tableData.length} rows, exportId=$exportId');

final children = <pw.Widget>[
// Header
if (pageIndex == 0)
pw.Text(
fileName,
style: pw.TextStyle(
fontSize: 12,
font: font,
fontWeight: pw.FontWeight.bold,
),
),
pw.Text(
'Page ${pageIndex + 1} of ${pages.length}',
style: pw.TextStyle(font: font, fontSize: fontSize),
),
pw.SizedBox(height: 10),
// Main data table
pw.Table.fromTextArray(
headers: headers,
data: tableData,
headerStyle: pw.TextStyle(
font: font,
fontWeight: pw.FontWeight.bold,
fontSize: fontSize,
),
cellStyle: pw.TextStyle(font: font, fontSize: fontSize),
columnWidths: columnWidths,
cellPadding: pw.EdgeInsets.all(2),
cellAlignment: pw.Alignment.centerLeft,
border: pw.TableBorder.all(width: 0.5),
),
];

// Add total row as a separate table on the last page
if (totalRow != null && pageIndex == pages.length - 1) {
children.addAll([
pw.SizedBox(height: 10),
pw.Table.fromTextArray(
data: [totalRow],
headerStyle: pw.TextStyle(
font: font,
fontWeight: pw.FontWeight.bold,
fontSize: fontSize,
),
cellStyle: pw.TextStyle(
font: font,
fontWeight: pw.FontWeight.bold,
fontSize: fontSize,
),
columnWidths: columnWidths,
cellPadding: pw.EdgeInsets.all(2),
cellAlignment: pw.Alignment.centerLeft,
border: pw.TableBorder.all(width: 0.5),
),
]);
print('GeneratePDF: Added total row table to page ${pageIndex + 1}: $totalRow, exportId=$exportId');
}

return pw.Column(
crossAxisAlignment: pw.CrossAxisAlignment.start,
children: children,
);
},
),
);
}
final pageEndTime = DateTime.now();
print('GeneratePDF: Page building took ${pageEndTime.difference(pageStartTime).inMilliseconds} ms, exportId=$exportId');

// Save PDF
print('GeneratePDF: Saving PDF, exportId=$exportId');
final saveStartTime = DateTime.now();
final pdfBytes = await pdf.save();
final saveEndTime = DateTime.now();
print('GeneratePDF: PDF save took ${saveEndTime.difference(saveStartTime).inMilliseconds} ms, exportId=$exportId');
print('GeneratePDF: PDF generation completed, returning bytes (${pdfBytes.length} bytes), exportId=$exportId');

return pdfBytes;
}
}