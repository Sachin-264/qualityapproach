// lib/ReportUtils/PrintService.dart
import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter/services.dart' show rootBundle; // Keep rootBundle for potential local placeholders
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // Contains PdfPreview widget and PdfGoogleFonts
import 'package:http/http.dart' as http;
import 'package:qualityapproach/ReportDynamic/ReportGenerator/PrintTemp/pdf_color_extension.dart'; // Import the http package


// Enum for template selection
enum PrintTemplate {
  premium,
  minimalist,
  corporate,
  modern,
}

// Extension to get display name for the enum
extension PrintTemplateExtension on PrintTemplate {
  String get displayName {
    switch (this) {
      case PrintTemplate.premium:
        return 'Premium Template';
      case PrintTemplate.minimalist:
        return 'Minimalist Template';
      case PrintTemplate.corporate:
        return 'Corporate Template';
      case PrintTemplate.modern:
        return 'Modern Template';
    }
  }
}

class PrintService {
  // --- Helper Functions (replicated for PDF generation) ---

  static String formatIndianNumber(dynamic number, {int decimalPoints = 2}) {
    if (number == null) return '₹0.00';
    double numValue;
    if (number is num) {
      numValue = number.toDouble();
    } else if (number is String) {
      numValue = double.tryParse(number) ?? 0.0;
    } else {
      return number.toString(); // Fallback for unsupported types
    }

    bool isNegative = numValue < 0;
    numValue = numValue.abs();

    String numStr = numValue.toStringAsFixed(decimalPoints);
    List<String> parts = numStr.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    if (integerPart.length <= 3) {
      String result = integerPart;
      if (decimalPoints > 0 && decimalPart.isNotEmpty) {
        result += '.$decimalPart';
      }
      return isNegative ? '-₹$result' : '₹$result';
    }

    String lastThree = integerPart.substring(integerPart.length - 3);
    String remaining = integerPart.substring(0, integerPart.length - 3);

    String formatted = '';
    for (int i = remaining.length; i > 0; i -= 2) {
      int start = (i - 2 < 0) ? 0 : i - 2;
      String chunk = remaining.substring(start, i);
      if (formatted.isEmpty) {
        formatted = chunk;
      } else {
        formatted = '$chunk,$formatted';
      }
    }

    String result = '$formatted,$lastThree';
    if (decimalPoints > 0 && decimalPart.isNotEmpty) {
      result += '.$decimalPart';
    }

    return isNegative ? '-₹$result' : '₹$result';
  }

  static String formatPrintDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final DateTime date;
      if (dateString.contains('-') && dateString.split('-')[1].length == 3) {
        date = DateFormat('dd-MMM-yyyy').parseStrict(dateString);
      } else if (dateString.contains('/')) {
        date = DateFormat('dd/MM/yyyy').parseStrict(dateString);
      } else if (dateString.contains('-') && dateString.split('-')[0].length == 4) {
        date = DateFormat('yyyy-MM-dd').parseStrict(dateString);
      } else {
        date = DateTime.parse(dateString);
      }
      return DateFormat('dd-MMM-yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  static Map<String, String> parseItemDescription(String fullDescription) {
    final Map<String, String> parsed = {
      'name': '',
      'itemCode': '',
      'itemGroup': '',
      'requiredDate': '',
      'pds1Date': '',
    };
    final List<String> lines = fullDescription.split('\n');
    if (lines.isEmpty) return parsed;
    parsed['name'] = lines[0].trim();
    for (int i = 1; i < lines.length; i++) {
      final String line = lines[i].trim();
      if (line.startsWith('Item Code :')) {
        parsed['itemCode'] = line.substring('Item Code :'.length).trim();
      } else if (line.startsWith('Item Group :')) {
        parsed['itemGroup'] = line.substring('Item Group :'.length).trim();
      } else if (line.startsWith('Required Desired Date :')) {
        parsed['requiredDate'] = formatPrintDate(line.substring('Required Desired Date :'.length).trim());
      } else if (line.startsWith('PDS1 Date :')) {
        parsed['pds1Date'] = formatPrintDate(line.substring('PDS1 Date :'.length).trim());
      }
    }
    return parsed;
  }

  // Used for specific row-based key-value pairs where value might span multiple lines (e.g., Premium template).
  static pw.Widget _buildPdfKeyValuePair(String label, dynamic value, {pw.TextStyle? labelStyle, pw.TextStyle? valueStyle, pw.TextAlign valueTextAlign = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$label: ',
            style: labelStyle ?? pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(
            child: pw.Align(
              alignment: valueTextAlign == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              child: pw.Text(
                value?.toString() ?? 'N/A',
                style: valueStyle ?? const pw.TextStyle(fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<Map<String, pw.MemoryImage>> _preloadImages(List<Map<String, dynamic>> items) async {
    final Map<String, pw.MemoryImage> imageCache = {};
    for (var item in items) {
      final imageUrl = item['ItemImagePath']?.toString();
      if (imageUrl != null && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
        try {
          final response = await http.get(Uri.parse(imageUrl));
          if (response.statusCode == 200) {
            imageCache[imageUrl] = pw.MemoryImage(response.bodyBytes);
          } else {
            print('Failed to load image: $imageUrl, Status: ${response.statusCode}');
          }
        } catch (e) {
          print('Error loading image for PDF: $imageUrl, Error: $e');
        }
      }
    }
    return imageCache;
  }

  // Used for totals section and single-line key-value pairs where space-between is desired.
  static pw.Widget _buildPdfKeyValue(String label, dynamic value, {pw.TextStyle? labelStyle, pw.TextStyle? valueStyle, pw.TextAlign valueTextAlign = pw.TextAlign.left}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('$label:', style: labelStyle ?? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Align(
          alignment: valueTextAlign == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Text(value?.toString() ?? 'N/A', style: valueStyle ?? const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  // Specific helper for Premium template's pw.Table cells (due to its distinct column structure)
  static pw.Widget _buildPremiumTableCell(String text, {bool isHeader = false, pw.TextAlign textAlign = pw.TextAlign.center, required pw.Font font, PdfColor? textColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4), // Increased padding for better look
      child: pw.Text(
        text,
        textAlign: textAlign,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8, // Slightly larger header font
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? (isHeader ? PdfColors.white : PdfColors.black), // Customizable text color
          font: font,
        ),
      ),
    );
  }

  static pw.Widget _buildPdfImageCell(String? imageUrl, Map<String, pw.MemoryImage> imageCache, {double height = 40, double width = 40}) {
    if (imageUrl != null && imageCache.containsKey(imageUrl)) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(2),
        child: pw.Image(imageCache[imageUrl]!, fit: pw.BoxFit.contain, height: height, width: width),
      );
    } else {
      return pw.Center(
        child: pw.Text('No Image', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      );
    }
  }


  // --- PDF Generation Templates ---

  // Template 1: Premium (Classic & Detailed)
  static Future<pw.Document> generatePremiumTemplate(
      Map<String, dynamic> document,
      List<Map<String, dynamic>> items,
      String reportLabel,
      PdfColor accentColor,
      ) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final Map<String, pw.MemoryImage> imageCache = await _preloadImages(items);

    double totalIGST = items.fold<double>(0.0, (sum, item) => sum + (item['IGSTVAL'] as num? ?? 0.0).toDouble());
    double subTotal = (document['SubTotal'] as num? ?? 0.0).toDouble();
    double freightAmt = (document['FreightAmt'] as num? ?? 0.0).toDouble();
    double packageAmt = (document['Packingcharges'] as num? ?? 0.0).toDouble();
    double grandTotal = (document['GrandTotal'] as num? ?? 0.0).toDouble();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          theme: pw.ThemeData(
            defaultTextStyle: pw.TextStyle(font: font, fontSize: 10),
            paragraphStyle: pw.TextStyle(font: font, fontSize: 10),
          ),
        ),
        build: (pw.Context context) {
          return [
            // --- Company Header (Centered) ---
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  document['Branch_FullName']?.toString() ?? 'AcquaViva India Pvt Ltd',
                  style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  document['Branch']?.toString() ?? 'B-12, SECTOR 80, NOIDA',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, font: font),
                  textAlign: pw.TextAlign.center,
                ),
                if (document['BranchGSTNo']?.toString().isNotEmpty == true)
                  pw.Text(
                    'GST NO : ${document['BranchGSTNo']}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, font: font),
                    textAlign: pw.TextAlign.center,
                  ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 2, color: accentColor),
            pw.SizedBox(height: 5),

            // --- Order Type Header ---
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'ORDER OF CUSTOMER',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.3)),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Divider(thickness: 1.5, color: accentColor.lighten(0.5)),
            pw.SizedBox(height: 15),

            // --- Customer and Order Details (Two Columns) ---
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.3))),
                      pw.SizedBox(height: 5),
                      _buildPdfKeyValuePair('Name', document['AccountName'], labelStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                      _buildPdfKeyValuePair('Address', document['Address'], labelStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                      _buildPdfKeyValuePair('StateName/ Code', document['State'], labelStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                      _buildPdfKeyValuePair('GSTIN', document['GSTNo'], labelStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),

                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CUSTOMER -> ${document['GroupName'] ?? 'PROJECT'}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.2)),
                      ),
                      pw.SizedBox(height: 10),
                      _buildPdfKeyValuePair('Order', document['SaleOrderNo'], labelStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                      _buildPdfKeyValuePair('Date', formatPrintDate(document['PostingDate']), labelStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                      _buildPdfKeyValuePair('Delivery Date', formatPrintDate(document['DeliveryDate']), labelStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                      _buildPdfKeyValuePair('Customer PO', document['CustomerPONo'] ?? 'N/A', labelStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                      _buildPdfKeyValuePair('Customer PO Date', formatPrintDate(document['CustomerPODate']), labelStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 25),

            // --- Item Details Table (Full columns with clear borders) ---
            if (items.isNotEmpty) ...[
              pw.Table(
                border: pw.TableBorder.all(color: accentColor.lighten(0.3), width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(40), // SNo - Increased width
                  1: const pw.FixedColumnWidth(60), // Image
                  2: const pw.FlexColumnWidth(3.0), // Item Description
                  3: const pw.FixedColumnWidth(40), // Batch
                  4: const pw.FixedColumnWidth(30), // Qty
                  5: const pw.FixedColumnWidth(60), // Rate
                  6: const pw.FixedColumnWidth(45), // Dis %
                  7: const pw.FixedColumnWidth(60), // Net Rate
                  8: const pw.FixedColumnWidth(70), // Amount
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: accentColor),
                    children: [
                      _buildPremiumTableCell('S.No', isHeader: true, font: boldFont),
                      _buildPremiumTableCell('Image', isHeader: true, font: boldFont),
                      _buildPremiumTableCell('Item Description', isHeader: true, textAlign: pw.TextAlign.left, font: boldFont),
                      _buildPremiumTableCell('Batch', isHeader: true, font: boldFont),
                      _buildPremiumTableCell('Qty', isHeader: true, font: boldFont),
                      _buildPremiumTableCell('Rate', isHeader: true, font: boldFont),
                      _buildPremiumTableCell('Dis %', isHeader: true, font: boldFont),
                      _buildPremiumTableCell('Net Rate', isHeader: true, font: boldFont),
                      _buildPremiumTableCell('Amount', isHeader: true, font: boldFont),
                    ],
                  ),
                  // Table Rows
                  ...items.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final Map<String, dynamic> item = entry.value;
                    final parsedItem = parseItemDescription(item['ItemName']?.toString() ?? '');

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: index % 2 == 0 ? PdfColors.white : accentColor.lighten(0.9)),
                      children: [
                        _buildPremiumTableCell(item['SNo']?.toString() ?? '', font: font),
                        _buildPdfImageCell(item['ItemImagePath']?.toString(), imageCache),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(parsedItem['name'] ?? '', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont)),
                              if (parsedItem['itemCode']!.isNotEmpty)
                                pw.Text('Item Code : ${parsedItem['itemCode']!}', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700, font: font)),
                              if (parsedItem['itemGroup']!.isNotEmpty)
                                pw.Text('Item Group : ${parsedItem['itemGroup']!}', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700, font: font)),
                            ],
                          ),
                        ),
                        _buildPremiumTableCell(item['BatchNo']?.toString() ?? '', font: font),
                        _buildPremiumTableCell(item['Qty']?.toString() ?? '', textAlign: pw.TextAlign.center, font: font),
                        _buildPremiumTableCell(formatIndianNumber(item['MRP'] ?? 0.0, decimalPoints: 2), textAlign: pw.TextAlign.right, font: font),
                        _buildPremiumTableCell('${(item['DisPer'] as num? ?? 0.0).toStringAsFixed(2)} %', textAlign: pw.TextAlign.right, font: font),
                        _buildPremiumTableCell(formatIndianNumber(item['NetRate'] ?? 0.0, decimalPoints: 2), textAlign: pw.TextAlign.right, font: font),
                        _buildPremiumTableCell(formatIndianNumber(item['ItemValue'] ?? 0.0, decimalPoints: 2), textAlign: pw.TextAlign.right, font: font),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // --- Totals Section (Right Aligned) ---
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 250,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _buildPdfKeyValue('SubTotal', formatIndianNumber(subTotal, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                    _buildPdfKeyValue('Freight Amt', formatIndianNumber(freightAmt, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                    _buildPdfKeyValue('Package Amt', formatIndianNumber(packageAmt, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                    pw.SizedBox(height: 5),
                    pw.SizedBox(width: double.infinity, child: pw.Divider(thickness: 0.8, color: accentColor.lighten(0.3))),
                    pw.SizedBox(height: 5),
                    _buildPdfKeyValue('CGST', formatIndianNumber(document['CGSTVAL'] as num? ?? 0.0, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                    _buildPdfKeyValue('SGST', formatIndianNumber(document['SGSTVAL'] as num? ?? 0.0, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                    _buildPdfKeyValue('IGST', formatIndianNumber(totalIGST, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                    pw.SizedBox(height: 5),
                    pw.SizedBox(width: double.infinity, child: pw.Divider(thickness: 0.8, color: accentColor.lighten(0.3))),
                    pw.SizedBox(height: 5),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      decoration: pw.BoxDecoration(
                        color: accentColor.lighten(0.9),
                        border: pw.Border.all(color: accentColor.darken(0.2), width: 0.8),
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: _buildPdfKeyValue('GRAND TOTAL', formatIndianNumber(grandTotal, decimalPoints: 2),
                          labelStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.2)),
                          valueStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.2)),
                          valueTextAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 15),

            // --- Total Quantity and Total Amount In Words ---
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Total Quantity : ${items.fold(0, (sum, item) => sum + (item['Qty'] as num? ?? 0).toInt())}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.3)),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Total Amount In Words : ${document['TotalAmtInWords']?.toString() ?? 'N/A'}',
                    style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, font: font, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Transporter Name : ${document['TransporterName'] ?? 'N/A'}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: font, color: accentColor.darken(0.3)),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // --- Footer ---
            pw.Text('Certified that the particulars given above are true and correct', style: pw.TextStyle(fontSize: 9, font: font, color: PdfColors.grey600)),
            pw.SizedBox(height: 20),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(document['Branch_FullName']?.toString() ?? 'AcquaViva India Pvt Ltd', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.2))),
                      pw.SizedBox(height: 50),
                      pw.Text('_________________________', style: pw.TextStyle(fontSize: 9, font: font, color: PdfColors.grey700)),
                      pw.SizedBox(height: 5),
                      pw.Text('Authorised Signatory', style: pw.TextStyle(fontSize: 9, font: font, color: PdfColors.grey700)),
                      pw.SizedBox(height: 5),
                      pw.Text('Prepared By: ${document['SalesManName'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 9, font: font, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.SizedBox(height: 50),
                      pw.Text('_________________________', style: pw.TextStyle(fontSize: 9, font: font, color: PdfColors.grey700)),
                      pw.SizedBox(height: 5),
                      pw.Text('Customer Signature', style: pw.TextStyle(fontSize: 9, font: font, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Align(
            alignment: pw.Alignment.bottomRight,
            child: pw.Text('Page ${context.pageNumber}/${context.pagesCount}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey, font: font)),
          );
        },
      ),
    );
    return pdf;
  }

  // Template 2: Minimalist (Clean & Airy)
  static Future<pw.Document> generateMinimalistTemplate(
      Map<String, dynamic> document,
      List<Map<String, dynamic>> items,
      String reportLabel,
      PdfColor accentColor,
      ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final Map<String, pw.MemoryImage> imageCache = await _preloadImages(items);

    double totalCGST = items.fold<double>(0.0, (sum, item) => sum + (item['CGSTVAL'] as num? ?? 0.0).toDouble());
    double totalSGST = items.fold<double>(0.0, (sum, item) => sum + (item['SGSTVAL'] as num? ?? 0.0).toDouble());
    double totalIGST = items.fold<double>(0.0, (sum, item) => sum + (item['IGSTVAL'] as num? ?? 0.0).toDouble());
    double totalGST = (totalCGST + totalSGST + totalIGST).toDouble();
    double subTotal = (document['SubTotal'] as num? ?? 0.0).toDouble();
    double freightAmt = (document['FreightAmt'] as num? ?? 0.0).toDouble();
    double packageAmt = (document['Packingcharges'] as num? ?? 0.0).toDouble();
    double grandTotal = (document['GrandTotal'] as num? ?? 0.0).toDouble();


    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          theme: pw.ThemeData(
            defaultTextStyle: pw.TextStyle(font: font, fontSize: 10),
          ),
        ),
        build: (pw.Context context) {
          return [
            // --- Company Header (Smaller, Right aligned) ---
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    document['Branch_FullName']?.toString() ?? 'AcquaViva India Pvt Ltd',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: accentColor.darken(0.1), font: boldFont), // Smaller title
                  ),
                  pw.Text(
                    document['Branch']?.toString() ?? 'B-12, SECTOR 80, NOIDA',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, font: font),
                  ),
                  if (document['BranchGSTNo']?.toString().isNotEmpty == true)
                    pw.Text(
                      'GSTIN: ${document['BranchGSTNo']}',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, font: font),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // --- Report Label (Prominent, left aligned, no divider below) ---
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                reportLabel.toUpperCase(),
                style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: accentColor, font: boldFont), // Very large title
              ),
            ),
            pw.SizedBox(height: 30), // More space after title

            // --- Customer and Order Details (Two Columns, clean, unboxed, all left-aligned) ---
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: accentColor.darken(0.3), font: boldFont)),
                      pw.SizedBox(height: 5),
                      pw.Text(document['AccountName']?.toString() ?? 'N/A', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: boldFont)),
                      pw.Text(document['BillToAddress']?.toString() ?? 'N/A', style: pw.TextStyle(fontSize: 9, font: font)),
                      pw.Text('${document['BillToCity'] ?? 'N/A'}, ${document['BillToState'] ?? 'N/A'} ${document['BillToPinCode'] ?? ''}', style: pw.TextStyle(fontSize: 9, font: font)),
                      if (document['BillToGSTNo']?.toString().isNotEmpty == true)
                        pw.Text('GSTIN: ${document['BillToGSTNo']}', style: pw.TextStyle(fontSize: 9, font: font)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start, // All left-aligned for minimalist
                    children: [
                      pw.Text('ORDER DETAILS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: accentColor.darken(0.3), font: boldFont)),
                      pw.SizedBox(height: 5),
                      pw.Text('Order No: ${document['SaleOrderNo'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 9, font: font)), // Simple text lines
                      pw.Text('Date: ${formatPrintDate(document['PostingDate'])}', style: pw.TextStyle(fontSize: 9, font: font)),
                      pw.Text('Delivery Date: ${formatPrintDate(document['DeliveryDate'])}', style: pw.TextStyle(fontSize: 9, font: font)),
                      pw.Text('PO No: ${document['CustomerPONo'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 9, font: font)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 25),

            // --- Item Details Table (No vertical borders, only horizontal, subtle header) ---
            if (items.isNotEmpty) ...[
              pw.Table.fromTextArray(
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(40), // S.No - Increased width
                  1: const pw.FixedColumnWidth(60), // Image
                  2: const pw.FlexColumnWidth(3.0), // Item Description
                  3: const pw.FixedColumnWidth(40), // Qty
                  4: const pw.FixedColumnWidth(70), // Rate
                  5: const pw.FixedColumnWidth(80), // Amount
                },
                border: null, // No outer table border
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: accentColor.darken(0.3), font: boldFont),
                headerDecoration: const pw.BoxDecoration( // No background, just a light bottom border
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 1.5))),
                cellStyle: pw.TextStyle(fontSize: 8.5, font: font),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey100, width: 0.5))),
                headers: ['S.No', 'Image', 'Item Description', 'Qty', 'Rate', 'Amount'],
                data: items.map((item) {
                  final parsedItem = parseItemDescription(item['ItemName']?.toString() ?? '');
                  return [
                    item['SNo']?.toString() ?? '',
                    _buildPdfImageCell(item['ItemImagePath']?.toString(), imageCache, height: 30, width: 30), // Smaller image
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(parsedItem['name']!, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, font: boldFont)),
                        if (parsedItem['itemCode']!.isNotEmpty)
                          pw.Text('Code: ${parsedItem['itemCode']!}', style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700, font: font)),
                      ],
                    ),
                    item['Qty']?.toString() ?? '',
                    pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(formatIndianNumber(item['MRP'] ?? 0.0, decimalPoints: 2))),
                    pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(formatIndianNumber(item['ItemValue'] ?? 0.0, decimalPoints: 2))),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
            ],

            // --- Totals (Right aligned, subtle) ---
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _buildPdfKeyValue('Subtotal', formatIndianNumber(subTotal, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                  _buildPdfKeyValue('Freight', formatIndianNumber(freightAmt, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                  if (packageAmt > 0)
                    _buildPdfKeyValue('Packing', formatIndianNumber(packageAmt, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                  pw.SizedBox(width: 150, child: pw.Divider(thickness: 0.8, color: PdfColors.grey300)), // Lighter divider
                  _buildPdfKeyValue('Total GST', formatIndianNumber(totalGST, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: pw.BoxDecoration(
                      color: accentColor.lighten(0.95), // Very light accent
                      border: pw.Border.all(color: accentColor.lighten(0.8), width: 0.5), // Very subtle border
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: _buildPdfKeyValue('GRAND TOTAL', formatIndianNumber(grandTotal, decimalPoints: 2),
                        labelStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.2)),
                        valueStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.2)),
                        valueTextAlign: pw.TextAlign.right),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    document['TotalAmtInWords']?.toString() ?? 'N/A',
                    style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600, font: font),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // --- Footer (Very Minimal) ---
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('Certified that the particulars given above are true and correct', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600, font: font)),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Authorised Signatory', style: pw.TextStyle(fontSize: 9, font: font, color: PdfColors.grey700)),
                      pw.SizedBox(height: 30), // Less space
                      pw.Text('Prepared By: ${document['SalesManName'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 8.5, font: font, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Customer Signature', style: pw.TextStyle(fontSize: 9, font: font, color: PdfColors.grey700)),
                      pw.SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Align(
            alignment: pw.Alignment.bottomRight,
            child: pw.Text('Page ${context.pageNumber}/${context.pagesCount}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey, font: font)),
          );
        },
      ),
    );
    return pdf;
  }

  // Template 3: Corporate (Formal & Structured)
  static Future<pw.Document> generateCorporateTemplate(
      Map<String, dynamic> document,
      List<Map<String, dynamic>> items,
      String reportLabel,
      PdfColor accentColor,
      ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final Map<String, pw.MemoryImage> imageCache = await _preloadImages(items);

    double totalCGST = items.fold<double>(0.0, (sum, item) => sum + (item['CGSTVAL'] as num? ?? 0.0).toDouble());
    double totalSGST = items.fold<double>(0.0, (sum, item) => sum + (item['SGSTVAL'] as num? ?? 0.0).toDouble());
    double totalIGST = items.fold<double>(0.0, (sum, item) => sum + (item['IGSTVAL'] as num? ?? 0.0).toDouble());
    double totalGST = (totalCGST + totalSGST + totalIGST).toDouble();
    double subTotal = (document['SubTotal'] as num? ?? 0.0).toDouble();
    double freightAmt = (document['FreightAmt'] as num? ?? 0.0).toDouble();
    double packageAmt = (document['Packingcharges'] as num? ?? 0.0).toDouble();
    double grandTotal = (document['GrandTotal'] as num? ?? 0.0).toDouble();


    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          theme: pw.ThemeData(
            defaultTextStyle: pw.TextStyle(font: font, fontSize: 10),
          ),
        ),
        build: (pw.Context context) {
          return [
            // --- Company Header (Boxed with strong accent) ---
            pw.Container(
              padding: const pw.EdgeInsets.all(15), // Larger padding
              decoration: pw.BoxDecoration(
                color: accentColor.lighten(0.9), // Very light accent background
                border: pw.Border.all(color: accentColor.darken(0.1), width: 1.5), // Stronger border
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    document['Branch_FullName']?.toString() ?? 'AcquaViva India Pvt Ltd',
                    style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: accentColor.darken(0.1), font: boldFont),
                  ),
                  pw.Text(
                    document['Branch']?.toString() ?? 'B-12, SECTOR 80, NOIDA',
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700, font: font),
                  ),
                  if (document['BranchGSTNo']?.toString().isNotEmpty == true)
                    pw.Text(
                      'GSTIN: ${document['BranchGSTNo']}',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, font: font),
                    ),
                  pw.SizedBox(height: 15), // More space
                  pw.Divider(thickness: 2, color: accentColor.darken(0.2)), // Thicker divider
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(
                      reportLabel.toUpperCase(),
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: accentColor.darken(0.3), font: boldFont),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 25),

            // --- Customer and Order Details in structured boxes ---
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12), // Larger padding
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: accentColor.lighten(0.3), width: 0.8),
                      borderRadius: pw.BorderRadius.circular(5),
                      color: PdfColors.white,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: accentColor.darken(0.3), font: boldFont)),
                        pw.SizedBox(height: 5),
                        pw.Text(document['AccountName']?.toString() ?? 'N/A', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: boldFont)),
                        pw.Text(document['BillToAddress']?.toString() ?? 'N/A', style: pw.TextStyle(fontSize: 9, font: font)),
                        pw.Text('${document['BillToCity'] ?? 'N/A'}, ${document['BillToState'] ?? 'N/A'} ${document['BillToPinCode'] ?? ''}', style: pw.TextStyle(fontSize: 9, font: font)),
                        if (document['BillToGSTNo']?.toString().isNotEmpty == true)
                          pw.Text('GSTIN: ${document['BillToGSTNo']}', style: pw.TextStyle(fontSize: 9, font: font)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 15),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12), // Larger padding
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: accentColor.lighten(0.3), width: 0.8),
                      borderRadius: pw.BorderRadius.circular(5),
                      color: PdfColors.white,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ORDER INFORMATION:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: accentColor.darken(0.3), font: boldFont)),
                        pw.SizedBox(height: 5),
                        _buildPdfKeyValue('Order No', document['SaleOrderNo'], labelStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                        _buildPdfKeyValue('Date', formatPrintDate(document['PostingDate']), labelStyle:  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                        _buildPdfKeyValue('Delivery Date', formatPrintDate(document['DeliveryDate']), labelStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                        _buildPdfKeyValue('PO No', document['CustomerPONo'] ?? 'N/A', labelStyle:  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 9, font: font)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 25),

            // --- Item Details Table (Stronger borders, solid header background) ---
            if (items.isNotEmpty) ...[
              pw.Text('ITEM DETAILS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: accentColor.darken(0.3), font: boldFont)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(40), // S.No - Increased width
                  1: const pw.FixedColumnWidth(60), // Image
                  2: const pw.FlexColumnWidth(3.0), // Item Description
                  3: const pw.FixedColumnWidth(40), // Qty
                  4: const pw.FixedColumnWidth(70), // Rate
                  5: const pw.FixedColumnWidth(80), // Amount
                },
                border: pw.TableBorder.all(color: accentColor.darken(0.1), width: 1.0), // Thicker, darker borders
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColors.white, font: boldFont),
                headerDecoration: pw.BoxDecoration(color: accentColor.darken(0.1)), // Solid darker header background
                cellStyle: pw.TextStyle(fontSize: 8.5, font: font),
                rowDecoration: pw.BoxDecoration(color: accentColor.lighten(0.95)), // Alternating light rows
                headers: ['S.No', 'Image', 'Item Description', 'Qty', 'Rate', 'Amount'],
                data: items.map((item) {
                  final parsedItem = parseItemDescription(item['ItemName']?.toString() ?? '');
                  return [
                    item['SNo']?.toString() ?? '',
                    _buildPdfImageCell(item['ItemImagePath']?.toString(), imageCache),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(parsedItem['name']!, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, font: boldFont)),
                        if (parsedItem['itemCode']!.isNotEmpty)
                          pw.Text('Code: ${parsedItem['itemCode']!}', style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700, font: font)),
                      ],
                    ),
                    item['Qty']?.toString() ?? '',
                    pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(formatIndianNumber(item['MRP'] ?? 0.0, decimalPoints: 2))),
                    pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(formatIndianNumber(item['ItemValue'] ?? 0.0, decimalPoints: 2))),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 25),
            ],

            // --- Totals (Right aligned, prominent boxed total) ---
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _buildPdfKeyValue('Subtotal', formatIndianNumber(subTotal, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                  _buildPdfKeyValue('Freight', formatIndianNumber(freightAmt, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                  if (packageAmt > 0)
                    _buildPdfKeyValue('Packing', formatIndianNumber(packageAmt, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                  pw.SizedBox(width: 180, child: pw.Divider(thickness: 0.8, color: accentColor.lighten(0.3))),
                  _buildPdfKeyValue('Total GST', formatIndianNumber(totalGST, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: pw.BoxDecoration(
                      color: accentColor.lighten(0.9),
                      border: pw.Border.all(color: accentColor.darken(0.1), width: 1.0),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: _buildPdfKeyValue('GRAND TOTAL', formatIndianNumber(grandTotal, decimalPoints: 2),
                        labelStyle: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.2)),
                        valueStyle: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.2)),
                        valueTextAlign: pw.TextAlign.right),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    document['TotalAmtInWords']?.toString() ?? 'N/A',
                    style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600, font: font),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // --- Footer ---
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('Certified that the particulars given above are true and correct', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600, font: font)),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(document['Branch_FullName']?.toString() ?? 'AcquaViva India Pvt Ltd', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.2))),
                      pw.SizedBox(height: 50),
                      pw.Text('_________________________', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey, font: font)),
                      pw.Text('Authorised Signatory', style: pw.TextStyle(fontSize: 8.5, font: font, color: PdfColors.grey700)),
                      pw.Text('Prepared By: ${document['SalesManName'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 8.5, font: font, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.SizedBox(height: 50),
                      pw.Text('_________________________', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey, font: font)),
                      pw.Text('Customer Signature', style: pw.TextStyle(fontSize: 8.5, font: font, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Align(
            alignment: pw.Alignment.bottomRight,
            child: pw.Text('Page ${context.pageNumber}/${context.pagesCount}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey, font: font)),
          );
        },
      ),
    );
    return pdf;
  }

  // Template 4: Modern (Dynamic & Contemporary)
  static Future<pw.Document> generateModernTemplate(
      Map<String, dynamic> document,
      List<Map<String, dynamic>> items,
      String reportLabel,
      PdfColor accentColor,
      ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final Map<String, pw.MemoryImage> imageCache = await _preloadImages(items);

    double totalCGST = items.fold<double>(0.0, (sum, item) => sum + (item['CGSTVAL'] as num? ?? 0.0).toDouble());
    double totalSGST = items.fold<double>(0.0, (sum, item) => sum + (item['SGSTVAL'] as num? ?? 0.0).toDouble());
    double totalIGST = items.fold<double>(0.0, (sum, item) => sum + (item['IGSTVAL'] as num? ?? 0.0).toDouble());
    double totalGST = (totalCGST + totalSGST + totalIGST).toDouble();
    double subTotal = (document['SubTotal'] as num? ?? 0.0).toDouble();
    double freightAmt = (document['FreightAmt'] as num? ?? 0.0).toDouble();
    double packageAmt = (document['Packingcharges'] as num? ?? 0.0).toDouble();
    double grandTotal = (document['GrandTotal'] as num? ?? 0.0).toDouble();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData(
            defaultTextStyle: pw.TextStyle(font: font, fontSize: 10),
          ),
        ),
        build: (pw.Context context) {
          return [
            // --- Company Header (Modern/Sleek - Company left, badge right) ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      document['Branch_FullName']?.toString() ?? 'AcquaViva India Pvt Ltd',
                      style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: accentColor.darken(0.1), font: boldFont),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      document['Branch']?.toString() ?? 'B-12, SECTOR 80, NOIDA',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, font: font),
                    ),
                    if (document['BranchGSTNo']?.toString().isNotEmpty == true)
                      pw.Text(
                        'GSTIN: ${document['BranchGSTNo']}',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, font: font),
                      ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: accentColor.darken(0.1), // A modern, dark accent
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    reportLabel.toUpperCase(),
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: boldFont),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 25),
            pw.Divider(thickness: 1.5, color: accentColor.lighten(0.5)),
            pw.SizedBox(height: 20),

            // --- Customer and Order Details (Bill To Left, Order Details Right-aligned) ---
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: accentColor.darken(0.3), font: boldFont)),
                      pw.SizedBox(height: 5),
                      pw.Text(document['AccountName']?.toString() ?? 'N/A', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: boldFont)),
                      pw.Text(document['BillToAddress']?.toString() ?? 'N/A', style: pw.TextStyle(fontSize: 9, font: font)),
                      pw.Text('${document['BillToCity'] ?? 'N/A'}, ${document['BillToState'] ?? 'N/A'} ${document['BillToPinCode'] ?? ''}', style: pw.TextStyle(fontSize: 9, font: font)),
                      if (document['BillToGSTNo']?.toString().isNotEmpty == true)
                        pw.Text('GSTIN: ${document['BillToGSTNo']}', style: pw.TextStyle(fontSize: 9, font: font)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end, // Order Details are RIGHT-ALIGNED
                    children: [
                      _buildPdfKeyValue('Order No', document['SaleOrderNo'], labelStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 10, font: font), valueTextAlign: pw.TextAlign.right),
                      _buildPdfKeyValue('Date', formatPrintDate(document['PostingDate']), labelStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 10, font: font), valueTextAlign: pw.TextAlign.right),
                      _buildPdfKeyValue('Delivery Date', formatPrintDate(document['DeliveryDate']), labelStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 10, font: font), valueTextAlign: pw.TextAlign.right),
                      _buildPdfKeyValue('Customer PO', document['CustomerPONo'] ?? 'N/A', labelStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: boldFont), valueStyle: pw.TextStyle(fontSize: 10, font: font), valueTextAlign: pw.TextAlign.right),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 25),

            // --- Item Details Table (Subtle borders, matching header color) ---
            if (items.isNotEmpty) ...[
              pw.Text('ITEM DETAILS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: accentColor.darken(0.3), font: boldFont)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(40), // S.No - Increased width
                  1: const pw.FixedColumnWidth(60), // Image
                  2: const pw.FlexColumnWidth(3.0), // Item Description
                  3: const pw.FixedColumnWidth(40), // Qty
                  4: const pw.FixedColumnWidth(70), // Rate
                  5: const pw.FixedColumnWidth(80), // Amount
                },
                border: pw.TableBorder.all(color: accentColor.lighten(0.5), width: 0.5), // Subtle borders
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColors.white, font: boldFont),
                headerDecoration: pw.BoxDecoration(color: accentColor.darken(0.1)), // Solid header background
                cellStyle: pw.TextStyle(fontSize: 8.5, font: font),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                headers: ['S.No', 'Image', 'Item Description', 'Qty', 'Rate', 'Amount'],
                data: items.map((item) {
                  final parsedItem = parseItemDescription(item['ItemName']?.toString() ?? '');
                  return [
                    item['SNo']?.toString() ?? '',
                    _buildPdfImageCell(item['ItemImagePath']?.toString(), imageCache),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(parsedItem['name']!, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, font: boldFont)),
                        if (parsedItem['itemCode']!.isNotEmpty)
                          pw.Text('Code: ${parsedItem['itemCode']!}', style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700, font: font)),
                      ],
                    ),
                    item['Qty']?.toString() ?? '',
                    pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(formatIndianNumber(item['MRP'] ?? 0.0, decimalPoints: 2))),
                    pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(formatIndianNumber(item['ItemValue'] ?? 0.0, decimalPoints: 2))),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 25),
            ],

            // --- Totals (Right aligned, highlighted grand total) ---
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _buildPdfKeyValue('Subtotal', formatIndianNumber(subTotal, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                  _buildPdfKeyValue('Freight', formatIndianNumber(freightAmt, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                  if (packageAmt > 0)
                    _buildPdfKeyValue('Packing', formatIndianNumber(packageAmt, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                  pw.SizedBox(width: 180, child: pw.Divider(thickness: 0.8, color: accentColor.lighten(0.3))),
                  _buildPdfKeyValue('Total GST', formatIndianNumber(totalGST, decimalPoints: 2), valueTextAlign: pw.TextAlign.right, labelStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold), valueStyle: pw.TextStyle(font: font)),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: pw.BoxDecoration(
                      color: accentColor.lighten(0.9), // Light accent for total highlight
                      border: pw.Border.all(color: accentColor.lighten(0.5), width: 1.0),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: _buildPdfKeyValue('GRAND TOTAL', formatIndianNumber(grandTotal, decimalPoints: 2),
                        labelStyle: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.2)),
                        valueStyle: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.2)),
                        valueTextAlign: pw.TextAlign.right),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    document['TotalAmtInWords']?.toString() ?? 'N/A',
                    style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600, font: font),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // --- Footer ---
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('Certified that the particulars given above are true and correct', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600, font: font)),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(document['Branch_FullName']?.toString() ?? 'AcquaViva India Pvt Ltd', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, font: boldFont, color: accentColor.darken(0.2))),
                      pw.SizedBox(height: 50),
                      pw.Text('_________________________', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey, font: font)),
                      pw.Text('Authorised Signatory', style: pw.TextStyle(fontSize: 8.5, font: font, color: PdfColors.grey700)),
                      pw.Text('Prepared By: ${document['SalesManName'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 8.5, font: font, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.SizedBox(height: 50),
                      pw.Text('_________________________', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey, font: font)),
                      pw.Text('Customer Signature', style: pw.TextStyle(fontSize: 8.5, font: font, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Align(
            alignment: pw.Alignment.bottomRight,
            child: pw.Text('Page ${context.pageNumber}/${context.pagesCount}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey, font: font)),
          );
        },
      ),
    );
    return pdf;
  }
}