// lib/ReportDashboard/DashboardScreen/dashboardTemplates/classic_clean_template.dart

import 'dart:ui'; // Needed for ImageFilter (blur effect) - No longer used in AppBar but kept for reference
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// We are using the sticky header package
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

import '../../DashboardModel/dashboard_model.dart';

// --- Main Template Widget (Stateful for Search) ---
class ClassicCleanTemplate extends StatefulWidget {
  final Dashboard dashboard;
  final Function(DashboardReportCardConfig) onReportCardTap;

  const ClassicCleanTemplate({
    Key? key,
    required this.dashboard,
    required this.onReportCardTap,
  }) : super(key: key);

  @override
  State<ClassicCleanTemplate> createState() => _ClassicCleanTemplateState();
}

class _ClassicCleanTemplateState extends State<ClassicCleanTemplate> {
  late final TextEditingController _searchController;
  late List<DashboardReportGroup> _filteredGroups;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredGroups = widget.dashboard.reportGroups;
    _searchController.addListener(_filterReports);
  }

  void _filterReports() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredGroups = widget.dashboard.reportGroups;
      } else {
        _filteredGroups = widget.dashboard.reportGroups.map((group) {
          final filteredReports = group.reports.where((report) {
            return report.displayTitle.toLowerCase().contains(query) ||
                (report.displaySubtitle?.toLowerCase().contains(query) ?? false);
          }).toList();
          return group.copyWith(reports: filteredReports);
        }).where((group) => group.reports.isNotEmpty).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterReports);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = widget.dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      // The new, highly polished AppBar.
      appBar: _ClassicAppBar(
        dashboard: widget.dashboard,
        accentColor: accentColor,
        searchController: _searchController,
      ),
      // The body with the sticky header layout.
      body: CustomScrollView(
        slivers: [
          if (_filteredGroups.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    "No reports match your search.",
                    style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ..._filteredGroups.map((group) {
            return SliverStickyHeader(
              header: _GroupHeader(
                title: group.groupName,
                accentColor: accentColor,
              ),
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12.0,
                    mainAxisSpacing: 12.0,
                    childAspectRatio: 1.0,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final cardConfig = group.reports[index];
                      return _AuroraReportCard(
                        cardConfig: cardConfig,
                        accentColor: accentColor,
                        onTap: () => widget.onReportCardTap(cardConfig),
                      );
                    },
                    childCount: group.reports.length,
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// --- NEW: A custom clipper to create the beautiful curve for the AppBar ---
class _AppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50); // Start point of the curve
    path.quadraticBezierTo(
      size.width / 2, // Control point for the curve
      size.height,    // Apex of the curve
      size.width,     // End point of the curve
      size.height - 50,
    );
    path.lineTo(size.width, 0); // Line to the top-right corner
    path.close(); // Close the path
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


// --- WIDGET 1: The new, sophisticated AppBar ---
class _ClassicAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Dashboard dashboard;
  final Color accentColor;
  final TextEditingController searchController;

  const _ClassicAppBar({
    required this.dashboard,
    required this.accentColor,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    // Use ClipPath to create the custom curved shape
    return ClipPath(
      clipper: _AppBarClipper(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentColor.darken(0.05), accentColor.darken(0.2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  dashboard.dashboardName,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [const Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                ),
                if (dashboard.dashboardDescription != null && dashboard.dashboardDescription!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      dashboard.dashboardDescription!,
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.white.withOpacity(0.9)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const Spacer(),
                // --- The new, clean Search Bar ---
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: Center(
                    child: TextField(
                      controller: searchController,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF2d3748),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: "Search reports...",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 22),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ),
                ),
                // This SizedBox ensures the search bar is pushed up from the bottom curve
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(220.0);
}

// --- WIDGET 2: The polished sticky header for groups (Unchanged) ---
class _GroupHeader extends StatelessWidget {
  final String title;
  final Color accentColor;

  const _GroupHeader({
    Key? key,
    required this.title,
    required this.accentColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2.0,
      shadowColor: Colors.black.withOpacity(0.15),
      child: Container(
        height: 50.0,
        color: Colors.white,
        child: Row(
          children: [
            Container(width: 5, color: accentColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2d3748),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET 3: The report card (Unchanged) ---
class _AuroraReportCard extends StatelessWidget {
  final DashboardReportCardConfig cardConfig;
  final Color accentColor;
  final VoidCallback onTap;

  const _AuroraReportCard({
    required this.cardConfig,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor = cardConfig.displayColor ?? accentColor;

    return Card(
      elevation: 3.0,
      shadowColor: Colors.black.withOpacity(0.06),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        splashColor: itemColor.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border(left: BorderSide(color: itemColor.withOpacity(0.8), width: 5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  cardConfig.displayIcon ?? Icons.analytics_outlined,
                  size: 32,
                  color: itemColor,
                ),
                const Spacer(),
                Text(
                  cardConfig.displayTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1a202c),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (cardConfig.displaySubtitle != null && cardConfig.displaySubtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      cardConfig.displaySubtitle!,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper Extension for Color
extension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}