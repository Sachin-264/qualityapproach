import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../ReportUtils/subtleloader.dart';
import 'Reportbloc.dart'; // For showing loader while print data is fetched.


class PrintDocumentPage extends StatefulWidget {
  final String apiName;
  final String actionApiUrlTemplate;
  final Map<String, String> dynamicApiParams;
  final String reportLabel; // For app bar title (e.g., "Sales Order Print")

  const PrintDocumentPage({
    super.key,
    required this.apiName,
    required this.actionApiUrlTemplate,
    required this.dynamicApiParams,
    required this.reportLabel,
  });

  @override
  State<PrintDocumentPage> createState() => _PrintDocumentPageState();
}

class _PrintDocumentPageState extends State<PrintDocumentPage> {
  // Helper for Indian number formatting (can be shared or put in a utility file)
  static String formatIndianNumber(dynamic number, {int decimalPoints = 0}) {
    if (number == null) return '';
    double numValue;
    if (number is num) {
      numValue = number.toDouble();
    } else if (number is String) {
      numValue = double.tryParse(number) ?? 0.0;
    } else {
      return number.toString(); // Fallback for unsupported types
    }

    String numStr = numValue.toStringAsFixed(decimalPoints);
    List<String> parts = numStr.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    bool isNegative = integerPart.startsWith('-');
    if (isNegative) {
      integerPart = integerPart.substring(1);
    }

    if (integerPart.length <= 3) {
      String result = integerPart;
      if (decimalPoints > 0 && decimalPart.isNotEmpty) {
        result += '.$decimalPart';
      }
      return isNegative ? '-$result' : result;
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

    return isNegative ? '-$result' : result;
  }

  // Helper function to format date strings
  static String formatPrintDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final DateTime date;
      // Handle common formats, prioritizing precise ones
      if (dateString.contains('-') && dateString.split('-')[1].length == 3) { // e.g., 01-May-2025
        date = DateFormat('dd-MMM-yyyy').parseStrict(dateString);
      } else if (dateString.contains('/')) { // e.g., 01/05/2025
        date = DateFormat('dd/MM/yyyy').parseStrict(dateString);
      } else if (dateString.contains('-') && dateString.split('-')[0].length == 4) { // e.g., 2025-05-01
        date = DateFormat('yyyy-MM-dd').parseStrict(dateString);
      } else {
        // Fallback for other formats or if strict parsing fails, try a general parse
        date = DateTime.parse(dateString);
      }
      return DateFormat('dd MMM yyyy').format(date); // Output: 01 May 2025
    } catch (e) {
      return dateString; // Fallback to original string if parsing fails
    }
  }

  // New helper for section headers
  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24, color: Colors.blueAccent),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
          const Expanded(child: Divider(indent: 10, thickness: 1.5, color: Colors.blueAccent)),
        ],
      ),
    );
  }

  // Helper widget to build a detail row (Label: Value)
  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150, // Adjusted width for labels
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A', // Display 'N/A' for null or empty values
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for table cells
  Widget _buildTableCell(String text, {bool isHeader = false, TextOverflow overflow = TextOverflow.ellipsis, TextAlign textAlign = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: isHeader ? 13 : 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.blueGrey[800] : Colors.black87,
        ),
        textAlign: textAlign,
        overflow: overflow,
      ),
    );
  }

  // Helper for image cells in table
  Widget _buildImageCell(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty || !(imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
      return Center(
        child: Icon(Icons.image_not_supported, color: Colors.grey[300], size: 24),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        height: 60, // Fixed height for table images
        width: 60, // Fixed width for table images
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 20.0,
              height: 20.0,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
          return Center(
            child: Icon(Icons.broken_image, color: Colors.red[300], size: 24),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The PrintDocumentPage now directly consumes the Bloc state from its own provider.
    return Scaffold(
      backgroundColor: Colors.white, // Set scaffold background to white for print preview
      appBar: AppBar( // Standard AppBar for navigation
        title: Text(
          widget.reportLabel,
          style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 1, // Subtle shadow for the app bar
        iconTheme: const IconThemeData(color: Colors.black87), // Black back button
        centerTitle: true,
      ),
      body: BlocBuilder<ReportBlocGenerate, ReportState>(
        builder: (context, state) {
          if (state.isLoading) { // This isLoading refers to the state of this specific bloc instance
            return const Center(child: SubtleLoader());
          }
          if (state.documentData == null || state.documentData!.isEmpty) {
            return Center(
              child: Text(
                state.error ?? 'No document data available for this report.',
                style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }

          // Assume documentData is a single Map<String, dynamic> representing the main document
          final Map<String, dynamic> document = state.documentData!;
          final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(document['item'] ?? []);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0), // Padding around the container to create A4-like page effect
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white, // Inner background of the "paper"
                  border: Border.all(color: Colors.grey.shade300, width: 2), // Beautiful border
                  borderRadius: BorderRadius.circular(12), // Slightly rounded corners
                  boxShadow: [ // Subtle shadow to make it pop like a paper
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4), // Shadow offset
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0), // Inner padding for document content
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Company Header (Placeholder or dynamically fetched) ---
                      Center(
                        child: Text(
                          document['Branch_FullName']?.toString().toUpperCase() ?? 'YOUR COMPANY NAME',
                          style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal[700]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Center(
                        child: Text(
                          document['Branch']?.toString() ?? 'Company Address Line 1, City, State, Country',
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (document['BranchGSTNo']?.toString().isNotEmpty == true)
                        Center(
                          child: Text(
                            'GSTIN: ${document['BranchGSTNo']}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 20),

                      // --- Document Title ---
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          widget.reportLabel.toUpperCase(), // Make report label prominent
                          style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Section 1: Order Details ---
                      _buildSectionHeader('Order Details', icon: Icons.receipt),
                      _buildDetailRow('Sales Order No:', document['SaleOrderNo']),
                      _buildDetailRow('RecNo:', document['RecNo']),
                      _buildDetailRow('Posting Date:', formatPrintDate(document['PostingDate'])),
                      _buildDetailRow('Customer PO No:', document['CustomerPONo']),
                      _buildDetailRow('Customer PO Date:', formatPrintDate(document['CustomerPODate'])),
                      _buildDetailRow('Delivery Date:', formatPrintDate(document['DeliveryDate'])),
                      _buildDetailRow('Order Status:', document['OrderStatus']),
                      _buildDetailRow('Created By:', document['AddUserName']),
                      const SizedBox(height: 10),

                      // --- Section 2: Customer Details ---
                      _buildSectionHeader('Customer Details', icon: Icons.person),
                      _buildDetailRow('Account Name:', document['AccountName']),
                      _buildDetailRow('Group Name:', document['GroupName']),
                      _buildDetailRow('Bill To Address:', document['BillToAddress']),
                      _buildDetailRow('Bill To City:', document['BillToCity']),
                      _buildDetailRow('Bill To State:', document['BillToState']),
                      _buildDetailRow('Bill To Pincode:', document['BillToPinCode']),
                      if (document['BillToGSTNo']?.toString().isNotEmpty == true)
                        _buildDetailRow('Customer GSTIN:', document['BillToGSTNo']),
                      const SizedBox(height: 10),

                      // --- Section 3: Item Details ---
                      if (items.isNotEmpty) ...[
                        _buildSectionHeader('Item Details', icon: Icons.shopping_cart),
                        Table(
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FlexColumnWidth(0.5), // SNo
                            1: FlexColumnWidth(2),  // ItemName
                            2: FlexColumnWidth(0.8), // Qty
                            3: FlexColumnWidth(1.2), // InvoiceRate
                            4: FlexColumnWidth(1.2), // ItemValue
                            5: FlexColumnWidth(1),  // Image
                          },
                          border: TableBorder.all(color: Colors.grey.shade400, width: 1.0, borderRadius: BorderRadius.circular(8)),
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: Colors.blueGrey[100], borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                              children: [
                                _buildTableCell('S.No', isHeader: true),
                                _buildTableCell('Item Name', isHeader: true, textAlign: TextAlign.left),
                                _buildTableCell('Qty', isHeader: true),
                                _buildTableCell('Rate', isHeader: true),
                                _buildTableCell('Value', isHeader: true, textAlign: TextAlign.right),
                                _buildTableCell('Image', isHeader: true),
                              ],
                            ),
                            ...items.asMap().entries.map((entry) {
                              final int index = entry.key;
                              final Map<String, dynamic> item = entry.value;
                              final bool isEvenRow = index % 2 == 0;
                              return TableRow(
                                decoration: BoxDecoration(color: isEvenRow ? Colors.white : Colors.grey[50]),
                                children: [
                                  _buildTableCell(item['SNo']?.toString() ?? ''),
                                  _buildTableCell(item['ItemName']?.toString() ?? '', overflow: TextOverflow.clip, textAlign: TextAlign.left),
                                  _buildTableCell(item['Qty']?.toString() ?? '', textAlign: TextAlign.center),
                                  _buildTableCell(formatIndianNumber(item['InvoiceRate'] ?? 0.0, decimalPoints: 2), textAlign: TextAlign.right),
                                  _buildTableCell(formatIndianNumber(item['ItemValue'] ?? 0.0, decimalPoints: 2), textAlign: TextAlign.right),
                                  _buildImageCell(item['ItemImagePath']?.toString()),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      // --- Total Section ---
                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildDetailRow('Subtotal:', formatIndianNumber(document['SubTotal'] ?? 0.0, decimalPoints: 2)),
                            _buildDetailRow('Freight Amount:', formatIndianNumber(document['FreightAmt'] ?? 0.0, decimalPoints: 2)),
                            if (document['Packingcharges'] != null && document['Packingcharges'] > 0)
                              _buildDetailRow('Packing Charges:', formatIndianNumber(document['Packingcharges'] ?? 0.0, decimalPoints: 2)),
                            // Add other charges like SplDisAmt, ExciseAmt, CessAmt, HSCessAmt if present and relevant
                            const Divider(height: 10, thickness: 1, color: Colors.black),
                            Text(
                              'GRAND TOTAL: ${formatIndianNumber(document['GrandTotal'] ?? 0.0, decimalPoints: 2)}',
                              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Text(
                              'Amount in Words: ${document['TotalAmtInWords'] ?? 'N/A'}',
                              style: GoogleFonts.poppins(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Remarks ---
                      if (document['ContentRemarks']?.toString().isNotEmpty == true)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remarks:',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                            Text(
                              document['ContentRemarks'],
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),

                      // --- Footer/Signatures (Placeholder) ---
                      const Divider(height: 20, thickness: 1.5, color: Colors.grey),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Authorized By:', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('Customer Signature:', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 50), // Space for signatures
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(document['AuthorizeBy']?.toString() ?? '________________', style: GoogleFonts.poppins(fontSize: 14)),
                          Text('________________', style: GoogleFonts.poppins(fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 30), // Space before print button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Add actual print functionality here (e.g., using printing packages)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Print functionality will be added here!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: const Icon(Icons.print, color: Colors.white),
                          label: Text(
                            'Print Document',
                            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple, // A distinct color for the print button
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 5,
                            shadowColor: Colors.deepPurple.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}