import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onBackPress;
  final List<Widget>? actions; // New: Optional list of widgets for actions

  const AppBarWidget({
    super.key,
    required this.title,
    required this.onBackPress,
    this.actions, // Initialize the new parameter
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[800]!, Colors.blue[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: onBackPress,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
      ),
      // New: Pass the optional actions list to the AppBar
      actions: actions,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.4),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}