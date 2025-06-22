import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../DashboardModel/dashboard_model.dart';


class DashboardReportCard extends StatelessWidget {
  final DashboardReportCardConfig cardConfig;
  final VoidCallback onTap;

  const DashboardReportCard({
    Key? key,
    required this.cardConfig,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color cardColor = cardConfig.displayColor ?? Theme.of(context).primaryColor.withOpacity(0.1);
    final Color iconColor = cardConfig.displayColor ?? Theme.of(context).primaryColor;

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: cardColor.withOpacity(0.5), width: 1.0),
      ),
      color: cardColor.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (cardConfig.displayIcon != null) ...[
                Icon(
                  cardConfig.displayIcon,
                  size: 48,
                  color: iconColor,
                ),
                const SizedBox(height: 10),
              ],
              Text(
                cardConfig.displayTitle,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (cardConfig.displaySubtitle != null && cardConfig.displaySubtitle!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  cardConfig.displaySubtitle!,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}