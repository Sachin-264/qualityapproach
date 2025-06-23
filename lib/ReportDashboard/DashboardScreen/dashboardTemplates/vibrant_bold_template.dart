// lib/ReportDashboard/DashboardScreen/dashboardTemplates/vibrant_bold_template.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math; // For dynamic rotation and random values

import '../../DashboardModel/dashboard_model.dart';


class VibrantBoldTemplate extends StatefulWidget {
  final Dashboard dashboard;
  final Function(DashboardReportCardConfig) onReportCardTap;

  const VibrantBoldTemplate({
    Key? key,
    required this.dashboard,
    required this.onReportCardTap,
  }) : super(key: key);

  @override
  State<VibrantBoldTemplate> createState() => _VibrantBoldTemplateState();
}

class _VibrantBoldTemplateState extends State<VibrantBoldTemplate>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  // KPIs
  int _totalReportsCount = 0;
  int _activeProjectsCount = 0;
  int _newThisWeekCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400), // Adjusted duration
    )..forward();

    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();

    _calculateDynamicKPIs(); // Initial calculation

    _searchController.addListener(_filterReports);
  }

  void _calculateDynamicKPIs() {
    _totalReportsCount = widget.dashboard.reportsOnDashboard.length;
    _activeProjectsCount = widget.dashboard.reportsOnDashboard.where((r) => r.displayIcon == Icons.business_center).length;
    _newThisWeekCount = widget.dashboard.reportsOnDashboard.where((r) => r.displayIcon == Icons.new_releases).length;

    // Add some base values for simulation if no specific icons are present
    if (_activeProjectsCount == 0 && _totalReportsCount > 0) _activeProjectsCount = (_totalReportsCount / 3).ceil() + math.Random().nextInt(2);
    if (_newThisWeekCount == 0 && _totalReportsCount > 0) _newThisWeekCount = (_totalReportsCount / 5).ceil();
  }

  void _filterReports() {
    // This template does not have live filtering on the grid for simplicity
    // Search functionality could trigger a dedicated search screen or a modal.
    if (_searchController.text.isNotEmpty && _searchFocusNode.hasFocus) {
      // For this template, just show a snakcbar to indicate search action
      // In a real app, this would perform a search and update the list.
      // setState(() { _filteredReports = _allReports.where(...).toList(); });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Searching for: \"${_searchController.text}\" (Simulated)"),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.removeListener(_filterReports); // Important: remove listener
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = widget.dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Light, cool background
      body: Column(
        children: [
          // --- FIXED HEADER (Structured Energy) ---
          _VibrantBoldHeader(
            dashboard: widget.dashboard,
            accentColor: accentColor,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
          ),

          // --- KPI Bar (Integrated, Horizontal) ---
          _AnimatedListItem(
            index: 0,
            controller: _animationController,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
              child: Row(
                children: [
                  _VibrantKpiBadge(
                      icon: Icons.dashboard_outlined,
                      value: "$_totalReportsCount",
                      label: "Reports",
                      color: accentColor), // Use main accent for total reports
                  const SizedBox(width: 12),
                  _VibrantKpiBadge(
                      icon: Icons.business_center,
                      value: "$_activeProjectsCount",
                      label: "Projects",
                      color: Colors.blueAccent.darken(0.05)), // Slightly darker for contrast
                  const SizedBox(width: 12),
                  _VibrantKpiBadge(
                      icon: Icons.trending_up,
                      value: "$_newThisWeekCount",
                      label: "New Data",
                      color: Colors.green.darken(0.05)), // Slightly darker for contrast
                ],
              ),
            ),
          ),

          // --- Main Content (Scrollable Grid) ---
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                children: [
                  // --- "All Reports" Section Title ---
                  _AnimatedListItem(
                    index: 1,
                    controller: _animationController,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "All Reports",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // --- Report Grid (Dynamic Tiles) ---
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, // Denser grid for smaller cards
                      crossAxisSpacing: 12.0,
                      mainAxisSpacing: 12.0,
                      childAspectRatio: 0.9, // Slightly taller than wide
                    ),
                    itemCount: widget.dashboard.reportsOnDashboard.length,
                    itemBuilder: (context, index) {
                      final cardConfig = widget.dashboard.reportsOnDashboard[index];
                      return _AnimatedListItem(
                        index: index + 2, // Stagger after title
                        controller: _animationController,
                        child: _VibrantBoldDataCard( // The new card
                          cardConfig: cardConfig,
                          accentColor: accentColor,
                          onTap: () => widget.onReportCardTap(cardConfig),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Header for Vibrant & Bold Template (Structured Energy) ---
class _VibrantBoldHeader extends StatelessWidget {
  final Dashboard dashboard;
  final Color accentColor;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  const _VibrantBoldHeader({
    required this.dashboard,
    required this.accentColor,
    required this.searchController,
    required this.searchFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    // Create softer, more pronounced gradient colors for a "beautiful" effect
    final Color startColor = accentColor.lighten(0.1); // Lighter tint of accent
    final Color endColor = accentColor.darken(0.15); // Darker shade of accent

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft, // Diagonal gradient for more dynamism
          end: Alignment.bottomRight,
        ),
        boxShadow: [ // A defined shadow for structure
          BoxShadow(
            color: Colors.black.withOpacity(0.15), // Slightly stronger shadow
            blurRadius: 15, // More blur for softer look
            offset: const Offset(0, 8), // More prominent offset
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
                    fontSize: 30, // Optimized size
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [const Shadow(blurRadius: 4, color: Colors.black38)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton( // Clean notification icon
                icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                onPressed: () { /* Handle notifications */ },
                splashRadius: 28,
              ),
            ],
          ),
          if (dashboard.dashboardDescription != null && dashboard.dashboardDescription!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                dashboard.dashboardDescription!,
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.white.withOpacity(0.85)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 20),
          // Clean search bar within header
          TextField(
            controller: searchController,
            focusNode: searchFocusNode,
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
            decoration: InputDecoration(
              hintText: "Search reports...",
              hintStyle: GoogleFonts.poppins(color: Colors.grey[500]), // Slightly darker hint text
              prefixIcon: Icon(Icons.search, color: accentColor.darken(0.1)), // Use accent color for icon, slightly darker
              filled: true,
              fillColor: Colors.white.withOpacity(0.95), // More opaque white for contrast
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.7), width: 1), // Slightly more visible border
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor.lighten(0.1), width: 2), // Stronger accent on focus
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- NEW KPI Badge for Vibrant Bold ---
class _VibrantKpiBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _VibrantKpiBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color, // Full color background
          borderRadius: BorderRadius.circular(15), // Slightly rounded corners
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start, // Left-aligned content
          children: [
            Icon(icon, color: Colors.white, size: 28), // White icon
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24, // Bolder value
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}


// --- NEW: Dynamic Tile Card for Vibrant Bold ---
class _VibrantBoldDataCard extends StatelessWidget {
  final DashboardReportCardConfig cardConfig;
  final Color accentColor;
  final VoidCallback onTap;

  const _VibrantBoldDataCard({
    required this.cardConfig,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor = cardConfig.displayColor ?? accentColor;

    return Card(
      elevation: 6.0, // Good elevation for "bold" look
      shadowColor: itemColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0), // Clean, moderate rounding
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.3),
        highlightColor: itemColor.withOpacity(0.2), // Subtle highlight
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white, // Default white background for "text box" area
            // Can add a subtle pattern here if desired
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Top Section: Icon & Accent ---
              Container(
                height: 80, // Fixed height for icon section, contributing to small card size
                decoration: BoxDecoration(
                  gradient: LinearGradient( // Subtle gradient based on item color
                    colors: [itemColor.lighten(0.05), itemColor.darken(0.05)],
                    begin: Alignment.topLeft, // Consistent with header gradient direction
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center( // Center the icon
                  child: Icon(
                    cardConfig.displayIcon ?? Icons.analytics_outlined,
                    size: 40, // Prominent icon
                    color: Colors.white,
                  ),
                ),
              ),
              // --- Bottom Section: Title & Subtitle ("Text Box") ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0), // Consistent padding for text area
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // Center contents vertically
                    crossAxisAlignment: CrossAxisAlignment.start, // Left-align text
                    children: [
                      Text(
                        cardConfig.displayTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 15, // Optimal size for 3-column grid
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF333333),
                        ),
                        maxLines: 2, // Allow up to 2 lines for title
                        overflow: TextOverflow.ellipsis, // Truncate if too long
                      ),
                      if (cardConfig.displaySubtitle != null && cardConfig.displaySubtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            cardConfig.displaySubtitle!,
                            style: GoogleFonts.poppins(
                              fontSize: 11, // Smaller for subtitle
                              color: Colors.grey[600],
                            ),
                            maxLines: 1, // Max 1 line for subtitle
                            overflow: TextOverflow.ellipsis, // Truncate if too long
                          ),
                        ),
                    ],
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

// Helper for staggered animations (reused)
class _AnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final AnimationController controller;

  const _AnimatedListItem({
    required this.index,
    required this.child,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // Stagger the animation start and duration slightly
    final startDelay = index * 0.05; // Each item starts 5% later
    final animationDuration = 0.6; // Animation takes 60% of total interval

    final interval = Interval(
      startDelay,
      startDelay + animationDuration,
      curve: Curves.easeOutCubic,
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final animationValue = interval.transform(controller.value);

        return Opacity(
          opacity: animationValue,
          child: Transform.translate(
            offset: Offset(0, (1 - animationValue) * 40), // Slide up from 40px below
            child: child,
          ),
        );
      },
    );
  }
}

// Extension for Color manipulation (lighten/darken)
extension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  Color lighten([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
}