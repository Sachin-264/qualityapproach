import 'package:flutter/material.dart';

class SubtleLoader extends StatelessWidget {
  const SubtleLoader({super.key});

  @override
  Widget build(BuildContext context) {
    // A simple, clean circular progress indicator
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent), // A common, clean color
        strokeWidth: 4, // Thickness of the spinner
      ),
    );
  }
}