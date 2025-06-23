// lib/ReportDashboard/DashboardScreen/dashboardTemplates/classic_clean_template.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../DashboardModel/dashboard_model.dart';
import '../../dashboardWidget/dashboard_report_card.dart';
// import 'dashboard_header.dart'; // <-- REMOVE this import

class ClassicCleanTemplate extends StatelessWidget {
  final Dashboard dashboard;
  final Function(DashboardReportCardConfig) onReportCardTap;

  const ClassicCleanTemplate({
    Key? key,
    required this.dashboard,
    required this.onReportCardTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String? bannerUrl = dashboard.templateConfig.bannerUrl;
    final Color accentColor = dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor;

    return Container(
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header for Classic Clean
          _ClassicCleanHeader( // <-- Use its own private header
            dashboard: dashboard,
            accentColor: accentColor,
            bannerUrl: bannerUrl,
          ),
          // Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 1.0,
                ),
                itemCount: dashboard.reportsOnDashboard.length,
                itemBuilder: (context, index) {
                  final cardConfig = dashboard.reportsOnDashboard[index];
                  return DashboardReportCard(
                    cardConfig: cardConfig,
                    onTap: () => onReportCardTap(cardConfig),
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

// Private Header Widget for THIS file only
class _ClassicCleanHeader extends StatelessWidget {
  final Dashboard dashboard;
  final Color accentColor;
  final String? bannerUrl;

  const _ClassicCleanHeader({
    required this.dashboard,
    required this.accentColor,
    this.bannerUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: accentColor,
        image: bannerUrl != null && bannerUrl!.isNotEmpty
            ? DecorationImage(
          image: NetworkImage(bannerUrl!),
          fit: BoxFit.cover,
          colorFilter:
          ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
        )
            : null,
        gradient: bannerUrl == null || bannerUrl!.isEmpty
            ? LinearGradient(
          colors: [accentColor, accentColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dashboard.dashboardName,
              style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (dashboard.dashboardDescription != null &&
                dashboard.dashboardDescription!.isNotEmpty)
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Text(
                  dashboard.dashboardDescription!,
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}