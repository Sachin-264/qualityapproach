import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';

class SubtleLoader extends StatelessWidget {
  final String? loadingText;

  const SubtleLoader({
    Key? key,
    this.loadingText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A clean, modern spinner from the flutter_spinkit package.
          const SpinKitFadingCircle(
            color: Colors.blueAccent,
            size: 50.0,
          ),
          // Optionally display text below the spinner.
          if (loadingText != null) ...[
            const SizedBox(height: 24),
            Text(
              loadingText!,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ]
        ],
      ),
    );
  }
}