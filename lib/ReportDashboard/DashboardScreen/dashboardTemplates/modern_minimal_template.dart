// lib/ReportDashboard/DashboardScreen/dashboardTemplates/modern_minimal_template.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math; // For dynamic data simulation

import '../../DashboardModel/dashboard_model.dart';

// --- Main Template Widget (Stateful for Animations & UI interactions) ---
class ModernMinimalTemplate extends StatefulWidget {
  final Dashboard dashboard;
  final Function(DashboardReportCardConfig) onReportCardTap;

  const ModernMinimalTemplate({
    Key? key,
    required this.dashboard,
    required this.onReportCardTap,
  }) : super(key: key);

  @override
  State<ModernMinimalTemplate> createState() => _ModernMinimalTemplateState();
}

class _ModernMinimalTemplateState extends State<ModernMinimalTemplate>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<DashboardReportCardConfig> _allReports;
  late List<DashboardReportCardConfig> _filteredReports;

  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  int _activeProjectsCount = 0;
  int _newThisWeekCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _allReports = widget.dashboard.reportsOnDashboard;
    _filteredReports = _allReports;

    _calculateDynamicKPIs();

    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchController.addListener(_filterReports);
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
        _filterReports();
      }
    });
  }

  void _calculateDynamicKPIs() {
    _activeProjectsCount = _allReports.where((r) => r.displayIcon == Icons.business_center).length;
    _newThisWeekCount = _allReports.where((r) => r.displayIcon == Icons.new_releases).length;

    if (_activeProjectsCount == 0 && _allReports.isNotEmpty) _activeProjectsCount = (_allReports.length / 4).ceil() + math.Random().nextInt(2);
    if (_newThisWeekCount == 0 && _allReports.isNotEmpty) _newThisWeekCount = (_allReports.length / 6).ceil();
    if (_allReports.isEmpty) { _activeProjectsCount = 0; _newThisWeekCount = 0; }
  }

  void _filterReports() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredReports = _allReports;
      } else {
        _filteredReports = _allReports.where((report) {
          return report.displayTitle.toLowerCase().contains(query) ||
              (report.displaySubtitle?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = widget.dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // --- Fixed Header with integrated search ---
          _ModernMinimalHeader(
            dashboard: widget.dashboard,
            accentColor: accentColor,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
          ),

          // --- Scrollable Content Area ---
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 24),

                  // --- KPI Section ---
                  _AnimatedListItem(
                    index: 0,
                    controller: _animationController,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _StatCard(icon: Icons.bar_chart_rounded, value: "${_filteredReports.length}", label: "Reports", color: accentColor),
                          const SizedBox(width: 12),
                          _StatCard(icon: Icons.business_center, value: "$_activeProjectsCount", label: "Projects", color: Colors.green.shade600),
                          const SizedBox(width: 12),
                          _StatCard(icon: Icons.new_releases_outlined, value: "$_newThisWeekCount", label: "New", color: Colors.orange.shade600),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- "Your Reports" Title ---
                  _AnimatedListItem(
                    index: 1,
                    controller: _animationController,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Your Reports",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Report Grid ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12.0,
                        mainAxisSpacing: 12.0,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _filteredReports.length,
                      itemBuilder: (context, index) {
                        final cardConfig = _filteredReports[index];
                        return _AnimatedListItem(
                          index: index + 2, // Stagger after KPI and title
                          controller: _animationController,
                          child: _MinimalistVibrantCard( // The new card design
                            cardConfig: cardConfig,
                            accentColor: accentColor,
                            onTap: () => widget.onReportCardTap(cardConfig),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Header Widget with Integrated Search ---
class _ModernMinimalHeader extends StatelessWidget {
  final Dashboard dashboard;
  final Color accentColor;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  const _ModernMinimalHeader({
    required this.dashboard,
    required this.accentColor,
    required this.searchController,
    required this.searchFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 50, 24, 16), // Top padding for SafeArea
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [ // Subtle shadow to indicate fixed position
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dashboard.dashboardName,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF222222),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.notifications_none, color: Colors.grey[600]), // Notification icon
                onPressed: () { /* Handle notifications */ },
                splashRadius: 24,
              ),
            ],
          ),
          if (dashboard.dashboardDescription != null && dashboard.dashboardDescription!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                dashboard.dashboardDescription!,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 16),
          // Search input field
          TextField(
            controller: searchController,
            focusNode: searchFocusNode,
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
            decoration: InputDecoration(
              hintText: "Search reports...",
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor.withOpacity(0.5), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Re-named Stat Card (to avoid conflict if used elsewhere) ---
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), // Stronger tint based on color
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column( // Changed to Column for vertical layout
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center, // Center all contents
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16, // Consistent size
                fontWeight: FontWeight.bold,
                color: color.darken(0.1), // Slightly darker for better contrast
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: color.darken(0.3),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Helper Extension for Color (to darken for better text contrast)
extension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}


// --- NEW: Minimalist Vibrant Card ---
class _MinimalistVibrantCard extends StatelessWidget {
  final DashboardReportCardConfig cardConfig;
  final Color accentColor;
  final VoidCallback onTap;

  const _MinimalistVibrantCard({
    required this.cardConfig,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor = cardConfig.displayColor ?? accentColor;

    return Card(
      elevation: 0, // No elevation
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.shade100, width: 1.0),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: onTap,
        splashColor: itemColor.withOpacity(0.08),
        hoverColor: itemColor.withOpacity(0.03), // Subtle hover effect
        child: Container(
          // Inner container for subtle color wash
          decoration: BoxDecoration(
            color: itemColor.withOpacity(0.03), // Very light colored background
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out top and bottom
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch for accent line
            children: [
              // --- Main Content (Icon + Title/Subtitle) ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0), // Padding inside the colored background
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        cardConfig.displayIcon ?? Icons.analytics_outlined,
                        size: 32, // Larger icon to be prominent
                        color: itemColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cardConfig.displayTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14, // Larger for readability
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cardConfig.displaySubtitle != null && cardConfig.displaySubtitle!.isNotEmpty)
                        Text(
                          cardConfig.displaySubtitle!,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
              // --- Vibrant Accent Line at the Bottom ---
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: itemColor, // Solid accent color line
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12.0),
                    bottomRight: Radius.circular(12.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- AnimatedListItem (reused) ---
class _AnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final AnimationController controller;
  const _AnimatedListItem({required this.index, required this.child, required this.controller});
  @override
  Widget build(BuildContext context) {
    final interval = Interval(
      (index * 80) / 1200,
      (250 + index * 80) / 1200,
      curve: Curves.easeOut,
    );
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final animation = interval.transform(controller.value);
        return Opacity(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, (1 - animation) * 20),
            child: child,
          ),
        );
      },
    );
  }
}