// lib/ReportDynamic/ReportGenerator/report_template_selection_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart'; // Import PdfColor
import 'package:qualityapproach/ReportDynamic/ReportGenerator/PrintTemp/pdf_color_extension.dart';
import 'package:qualityapproach/ReportDynamic/ReportGenerator/PrintTemp/printservice.dart';


// Define a custom class to return both template and color
class TemplateSelectionResult {
  final PrintTemplate template;
  final PdfColor color;

  TemplateSelectionResult(this.template, this.color);
}

class ReportTemplateSelectionDialog extends StatefulWidget {
  const ReportTemplateSelectionDialog({super.key});

  @override
  State<ReportTemplateSelectionDialog> createState() => _ReportTemplateSelectionDialogState();
}

class _ReportTemplateSelectionDialogState extends State<ReportTemplateSelectionDialog> {
  PdfColor _selectedColor = PdfColors.blue; // Default selected color

  final List<PdfColor> _availableColors = [
    PdfColors.blue,
    PdfColors.teal,
    PdfColors.indigo,
    PdfColors.purple,
    PdfColors.red,
    PdfColors.green,
    PdfColors.orange,
    PdfColors.grey,
    PdfColors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Print Template & Color',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Color Selection Section
            Text(
              'Choose Accent Color:',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _availableColors.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.toFlutterColor(), // Using our custom extension
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == color ? Colors.black : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: _selectedColor == color
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Divider(thickness: 1, color: Colors.grey[300]),
            const SizedBox(height: 20),


            // Template Selection Section
            ...PrintTemplate.values.map((template) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedColor.toFlutterColor(), // Using our custom extension
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 3,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(TemplateSelectionResult(template, _selectedColor));
                    },
                    child: Text(
                      template.displayName,
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog without selection
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}