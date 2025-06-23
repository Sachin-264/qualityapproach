// lib/ReportDashboard/DashboardScreen/dashboardTemplates/vibrant_bold_template.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../DashboardModel/dashboard_model.dart';


class VibrantBoldTemplate extends StatelessWidget {
  final Dashboard dashboard;
  final Function(DashboardReportCardConfig) onReportCardTap;

  const VibrantBoldTemplate({
    Key? key,
    required this.dashboard,
    required this.onReportCardTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String? bannerUrl = dashboard.templateConfig.bannerUrl;
    final Color accentColor = dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accentColor.withOpacity(0.2), Colors.white],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header for Vibrant & Bold
          _VibrantBoldHeader( // <-- Use its own private header
            dashboard: dashboard,
            accentColor: accentColor,
            bannerUrl: bannerUrl,
          ),
          // Grid (Your existing grid code for this template is fine)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 0.9,
                ),
                itemCount: dashboard.reportsOnDashboard.length,
                itemBuilder: (context, index) {
                  final cardConfig = dashboard.reportsOnDashboard[index];
                  final Color effectiveCardColor = cardConfig.displayColor ?? accentColor;

                  return Transform.rotate(
                    angle: index % 2 == 0 ? 0.02 : -0.02,
                    child: Card(
                      elevation: 8.0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                      color: effectiveCardColor.withOpacity(0.9),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10.0),
                        onTap: () => onReportCardTap(cardConfig),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (cardConfig.displayIcon != null) ...[
                                Icon(cardConfig.displayIcon, size: 64, color: Colors.white),
                                const SizedBox(height: 15),
                              ],
                              Text(
                                cardConfig.displayTitle,
                                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (cardConfig.displaySubtitle != null && cardConfig.displaySubtitle!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  cardConfig.displaySubtitle!,
                                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A unique, private header for the Vibrant & Bold template
class _VibrantBoldHeader extends StatelessWidget {
  final Dashboard dashboard;
  final Color accentColor;
  final String? bannerUrl;

  const _VibrantBoldHeader({
    required this.dashboard,
    required this.accentColor,
    this.bannerUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Bold look with a stronger overlay and dramatic text
    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor,
        image: bannerUrl != null && bannerUrl!.isNotEmpty
            ? DecorationImage(
          image: NetworkImage(bannerUrl!),
          fit: BoxFit.cover,
          colorFilter:
          ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken), // Darker overlay
        )
            : null,
        gradient: bannerUrl == null || bannerUrl!.isEmpty
            ? LinearGradient(
          colors: [accentColor, Colors.black.withOpacity(0.4)], // More dramatic gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            dashboard.dashboardName,
            style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.w900, // Extra bold
                color: Colors.white,
                shadows: [
                  const Shadow(blurRadius: 10, color: Colors.black54)
                ]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}