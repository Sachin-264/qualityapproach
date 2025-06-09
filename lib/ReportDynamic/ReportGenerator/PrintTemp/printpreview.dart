// lib/ReportDynamic/ReportGenerator/print_preview_page.dart
import 'dart:typed_data'; // For Uint8List

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart'; // Import PdfColor
import 'package:printing/printing.dart'; // This contains PdfPreview widget
import 'package:qualityapproach/ReportDynamic/ReportAPIService.dart';
// Import the updated printservice.dart which now contains the PrintTemplate enum
import 'package:qualityapproach/ReportDynamic/ReportGenerator/PrintTemp/printservice.dart';

import '../../../ReportUtils/subtleloader.dart'; // Import ReportAPIService

class PrintPreviewPage extends StatefulWidget {
  final String actionApiUrlTemplate;
  final Map<String, String> dynamicApiParams;
  final String reportLabel;
  final PrintTemplate selectedTemplate;
  final PdfColor selectedColor; // Added selectedColor parameter

  const PrintPreviewPage({
    super.key,
    required this.actionApiUrlTemplate,
    required this.dynamicApiParams,
    required this.reportLabel,
    required this.selectedTemplate,
    required this.selectedColor, // Required now
  });

  @override
  State<PrintPreviewPage> createState() => _PrintPreviewPageState();
}

class _PrintPreviewPageState extends State<PrintPreviewPage> {
  Future<Map<String, dynamic>>? _printDataFuture;

  @override
  void initState() {
    super.initState();
    _printDataFuture = _fetchPrintDocumentData();
  }

  // Method to fetch the print document data
  Future<Map<String, dynamic>> _fetchPrintDocumentData() async {
    try {
      String fullPrintApiUrl = widget.actionApiUrlTemplate;
      Uri uri = Uri.parse(fullPrintApiUrl);
      Map<String, String> mergedParams = Map.from(uri.queryParameters);
      mergedParams.addAll(widget.dynamicApiParams); // Dynamic params override defaults

      fullPrintApiUrl = uri.replace(queryParameters: mergedParams).toString();

      final apiService = ReportAPIService();
      final dynamic rawData = await apiService.fetchDataFromFullUrl(fullPrintApiUrl);

      // --- CRITICAL FIX START: Handle List of Lists scenario ---
      if (rawData is List) {
        if (rawData.isNotEmpty) {
          // Check if the first element of the list is also a list (e.g., [[{...}],[{...}]])
          if (rawData.first is List) {
            if (rawData.first.isNotEmpty && rawData.first.first is Map<String, dynamic>) {
              // This is the specific case you found: [[{main_doc_map}, {summary_map}], [item_list]]
              debugPrint('PrintPreviewPage: Detected List of Lists, taking rawData.first.first as main document.');
              return rawData.first.first as Map<String, dynamic>;
            } else {
              // This case implies rawData.first is an empty list, or contains non-map elements
              debugPrint('PrintPreviewPage: RawData.first is a list, but is empty or does not contain maps. RawData.first: ${rawData.first}');
              return {}; // Treat as no document data
            }
          }
          // If rawData.first is not a List, it should be a Map directly (e.g., [{'key': 'value'}])
          else if (rawData.first is Map<String, dynamic>) {
            debugPrint('PrintPreviewPage: Detected List of Maps directly (rawData.first is a Map). Taking rawData.first as main document.');
            return rawData.first as Map<String, dynamic>;
          } else {
            // List is not empty but contains unexpected element types (e.g., List<String>)
            throw Exception('Print API returned a list, but its elements are not Maps or nested Lists of Maps. Received type: ${rawData.first.runtimeType}');
          }
        } else {
          // The outermost list is empty
          debugPrint('PrintPreviewPage: Print API returned an empty list.');
          return {}; // Return an empty map to indicate no document data
        }
      } else if (rawData is Map<String, dynamic>) {
        // Direct map response (e.g., {'key': 'value', 'item': [...]})
        debugPrint('PrintPreviewPage: Detected direct Map as document.');
        return rawData;
      } else {
        // Fallback for completely unexpected root types
        throw Exception('Print API did not return expected top-level data format (expected Map<String, dynamic> or List). Received: ${rawData.runtimeType}');
      }
      // --- CRITICAL FIX END ---

    } catch (e) {
      debugPrint('Error fetching print document data: $e');
      rethrow; // Re-throw to be caught by FutureBuilder
    }
  }

  // This method generates the PDF bytes using the fetched data
  Future<Uint8List> _generatePdfBytes(Map<String, dynamic> documentData, List<Map<String, dynamic>> itemsData) async {
    // Delegate to PrintService based on selected template
    switch (widget.selectedTemplate) {
      case PrintTemplate.premium:
        return (await PrintService.generatePremiumTemplate(documentData, itemsData, widget.reportLabel, widget.selectedColor)).save();
      case PrintTemplate.minimalist:
        return (await PrintService.generateMinimalistTemplate(documentData, itemsData, widget.reportLabel, widget.selectedColor)).save();
      case PrintTemplate.corporate:
        return (await PrintService.generateCorporateTemplate(documentData, itemsData, widget.reportLabel, widget.selectedColor)).save();
      case PrintTemplate.modern:
        return (await PrintService.generateModernTemplate(documentData, itemsData, widget.reportLabel, widget.selectedColor)).save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Print Preview (${widget.selectedTemplate.displayName})',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _printDataFuture, // Use the future that fetches data
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: SubtleLoader()); // Show loader while fetching
          }
          if (snapshot.hasError) {
            // Display specific error for data fetching
            return Center(
              child: Text(
                'Failed to load print data: ${snapshot.error}',
                style: GoogleFonts.poppins(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (snapshot.hasData) {
            final Map<String, dynamic> document = snapshot.data!;
            // Ensure 'item' key exists and is a List before casting
            // Using ?? [] on document['item'] ensures it's an empty list if key is missing or null
            final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(document['item'] ?? []);

            if (document.isEmpty) {
              return Center(
                child: Text(
                  'No print document data received for this selection. Document is empty.',
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }

            // Once data is fetched, build the PdfPreview
            return PdfPreview(
              build: (format) => _generatePdfBytes(document, items), // Pass the fetched document and items
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false, // Removes page format toggle
              canChangeOrientation: false, // Removes orientation toggle
              // previewPageCount: true, // Shows page numbers (e.g., 1/X)
              // PdfPreview naturally supports centering and scrolling, and pinch-to-zoom.
              // No additional widgets are needed for these.
            );
          }
          return const Center(child: Text('No data available for print preview.')); // Fallback
        },
      ),
    );
  }
}