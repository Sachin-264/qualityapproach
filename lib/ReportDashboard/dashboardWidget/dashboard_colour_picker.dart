// lib/ReportDashboard/dashboardWidget/dashboard_colour_picker.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const ColorPickerDialog({Key? key, required this.initialColor}) : super(key: key);

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = [
      Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
      Colors.brown, Colors.grey, Colors.blueGrey, Colors.black,
      Colors.white,
      Colors.redAccent, Colors.pinkAccent, Colors.purpleAccent, Colors.deepPurpleAccent,
      Colors.indigoAccent, Colors.blueAccent, Colors.lightBlueAccent, Colors.cyanAccent,
      Colors.tealAccent, Colors.greenAccent, Colors.lightGreenAccent, Colors.limeAccent,
      Colors.amberAccent, Colors.orangeAccent, Colors.deepOrangeAccent,
    ];


    Widget colorGrid = SizedBox(
      height: 300.0, // Fixed height for the content area
      width: 300.0,  // Fixed width for the content area
      child: GridView.builder(
        itemCount: colors.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(

          crossAxisCount: 7,
          // Minimal spacing
          crossAxisSpacing: 6.0,
          mainAxisSpacing: 6.0,
        ),
        itemBuilder: (context, index) {
          final color = colors[index];
          return InkWell(
            onTap: () {
              setState(() {
                _selectedColor = color;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selectedColor == color ? Colors.blueAccent : (color == Colors.white ? Colors.grey.shade400 : Colors.transparent),
                  width: _selectedColor == color ? 3.5 : 1, // Thicker border for selection
                ),
              ),
            ),
          );
        },
      ),
    );

    return AlertDialog(
      title: Text('Choose a Color', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      // We directly use the widget we built. The AlertDialog will manage its size.
      content: colorGrid,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedColor),
          child: Text('Select', style: GoogleFonts.poppins(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
        ),
      ],
    );
  }
}