// lib/ReportDashboard/DashboardScreen/dashboardTemplates/vibrant_bold_template.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // --- MODIFIED: State holds groups ---
  late List<DashboardReportGroup> _allGroups;
  late List<DashboardReportGroup> _filteredGroups;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();

    _allGroups = widget.dashboard.reportGroups;
    _filteredGroups = _allGroups;

    _searchController.addListener(_filterReports);
  }

  void _filterReports() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredGroups = _allGroups;
      } else {
        _filteredGroups = _allGroups.map((group) {
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
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = widget.dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          _VibrantBoldHeader(
            dashboard: widget.dashboard,
            accentColor: accentColor,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                children: [
                  // --- REMOVED KPI Section ---
                  if (_filteredGroups.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          _searchController.text.isNotEmpty ? "No reports match your search." : "This dashboard has no reports.",
                          style: GoogleFonts.poppins(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ..._filteredGroups.map((group) {
                    final groupIndex = _filteredGroups.indexOf(group);
                    return _AnimatedListItem(
                      index: groupIndex,
                      controller: _animationController,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Group Title
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Text(
                                group.groupName,
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                            ),
                            // Report Grid
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 12.0,
                                mainAxisSpacing: 12.0,
                                childAspectRatio: 0.9,
                              ),
                              itemCount: group.reports.length,
                              itemBuilder: (context, reportIndex) {
                                final cardConfig = group.reports[reportIndex];
                                return _AnimatedListItem(
                                  index: reportIndex,
                                  controller: _animationController,
                                  child: _VibrantBoldDataCard(
                                    cardConfig: cardConfig,
                                    accentColor: accentColor,
                                    onTap: () => widget.onReportCardTap(cardConfig),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- All other helper widgets (_VibrantBoldHeader, _VibrantBoldDataCard, etc.) remain unchanged ---
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
    final Color startColor = accentColor.lighten(0.1);
    final Color endColor = accentColor.darken(0.15);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [const Shadow(blurRadius: 4, color: Colors.black38)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
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
          TextField(
            controller: searchController,
            focusNode: searchFocusNode,
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
            decoration: InputDecoration(
              hintText: "Search reports...",
              hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
              prefixIcon: Icon(Icons.search, color: accentColor.darken(0.1)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.95),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.7), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor.lighten(0.1), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
      elevation: 6.0,
      shadowColor: itemColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.3),
        highlightColor: itemColor.withOpacity(0.2),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [itemColor.lighten(0.05), itemColor.darken(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    cardConfig.displayIcon ?? Icons.analytics_outlined,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardConfig.displayTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF333333),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cardConfig.displaySubtitle != null && cardConfig.displaySubtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            cardConfig.displaySubtitle!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    final startDelay = index * 0.05;
    final animationDuration = 0.6;
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
            offset: Offset(0, (1 - animationValue) * 40),
            child: child,
          ),
        );
      },
    );
  }
}

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