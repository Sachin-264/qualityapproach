// lib/ReportDashboard/DashboardScreen/dashboardTemplates/modern_minimal_template.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../DashboardModel/dashboard_model.dart';
import '../../dashboardWidget/dashboard_report_card.dart';


class ModernMinimalTemplate extends StatelessWidget {
  final Dashboard dashboard;
  final Function(DashboardReportCardConfig) onReportCardTap;

  const ModernMinimalTemplate({
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, accentColor.withOpacity(0.1)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header for Modern Minimal
          _ModernMinimalHeader( // <-- Use its own private header
            dashboard: dashboard,
            accentColor: accentColor,
            bannerUrl: bannerUrl,
          ),
          // Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 24.0,
                  mainAxisSpacing: 24.0,
                  childAspectRatio: 1.1,
                ),
                itemCount: dashboard.reportsOnDashboard.length,
                itemBuilder: (context, index) {
                  final cardConfig = dashboard.reportsOnDashboard[index];
                  return DashboardReportCard(
                    cardConfig: cardConfig,
                    onTap: () => onReportCardTap(cardConfig),
                    // elevation: 2.0, // Example of custom styling for this template
                    // borderRadius: BorderRadius.circular(16),
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

// A unique, private header for Modern Minimal template
class _ModernMinimalHeader extends StatelessWidget {
  final Dashboard dashboard;
  final Color accentColor;
  final String? bannerUrl;

  const _ModernMinimalHeader({
    required this.dashboard,
    required this.accentColor,
    this.bannerUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Flat, no shadow, no rounded corners for a minimal look
    return Container(
      height: 160, // Slightly shorter
      color: accentColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dashboard.dashboardName,
            style: GoogleFonts.poppins(
                fontSize: 32, fontWeight: FontWeight.w600, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (dashboard.dashboardDescription != null &&
              dashboard.dashboardDescription!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              dashboard.dashboardDescription!,
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]
        ],
      ),
    );
  }
}