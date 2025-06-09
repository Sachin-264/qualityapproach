// lib/ReportUtils/pdf_color_extensions.dart
import 'package:pdf/pdf.dart'; // Import PdfColor
import 'package:flutter/material.dart' show Color; // Only import Flutter's Color

/// An extension on [PdfColor] to provide utility methods for color manipulation
/// and conversion to Flutter's [Color] type.
extension PdfColorExtension on PdfColor {
  /// Converts a [PdfColor] to a Flutter [Color].
  ///
  /// This is useful when you need to display a [PdfColor] in Flutter UI,
  /// as [PdfColor] is from the `pdf` package and Flutter widgets expect `flutter.Color`.
  Color toFlutterColor() {
    return Color.fromARGB(
      (alpha * 255).round(), // Alpha component (0.0-1.0 to 0-255)
      (red * 255).round(),   // Red component (0.0-1.0 to 0-255)
      (green * 255).round(), // Green component (0.0-1.0 to 0-255)
      (blue * 255).round(),  // Blue component (0.0-1.0 to 0-255)
    );
  }

  /// Creates a darker shade of the [PdfColor].
  ///
  /// The `factor` determines how much darker the color should be.
  /// It should be between 0.0 (no change) and 1.0 (black).
  ///
  /// Example: `myColor.darken(0.2)` will make the color 20% darker.
  PdfColor darken([double factor = 0.1]) {
    assert(factor >= 0.0 && factor <= 1.0);
    return PdfColor(
      red * (1.0 - factor),
      green * (1.0 - factor),
      blue * (1.0 - factor),
      alpha,
    );
  }

  /// Creates a lighter shade of the [PdfColor].
  ///
  /// The `factor` determines how much lighter the color should be.
  /// It should be between 0.0 (no change) and 1.0 (white).
  ///
  /// Example: `myColor.lighten(0.2)` will make the color 20% lighter.
  PdfColor lighten([double factor = 0.1]) {
    assert(factor >= 0.0 && factor <= 1.0);
    return PdfColor(
      red + (1.0 - red) * factor,
      green + (1.0 - green) * factor,
      blue + (1.0 - blue) * factor,
      alpha,
    );
  }
}