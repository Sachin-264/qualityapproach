// lib/ReportDashboard/DashboardScreen/dashboardTemplates/classic_clean_template.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math; // For random data simulation

import '../../DashboardModel/dashboard_model.dart';

// --- Main Template Widget (Stateful for Animations & Search) ---
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

class _ClassicCleanTemplateState extends State<ClassicCleanTemplate>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isSearchActive = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late List<DashboardReportCardConfig> _allReports;
  late List<DashboardReportCardConfig> _filteredReports;
  int _activeProjectsCount = 0;
  int _newThisWeekCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _allReports = widget.dashboard.reportsOnDashboard;
    _filteredReports = _allReports;

    _calculateDynamicKPIs();

    _searchController.addListener(_filterReports);
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
        setState(() => _isSearchActive = false);
      }
    });
  }

  void _calculateDynamicKPIs() {
    _activeProjectsCount = _allReports.where((r) => r.displayIcon == Icons.business_center).length;
    _newThisWeekCount = _allReports.where((r) => r.displayIcon == Icons.new_releases).length;
    if (_activeProjectsCount == 0) _activeProjectsCount = (_allReports.length / 4).ceil() + math.Random().nextInt(2);
    if (_newThisWeekCount == 0) _newThisWeekCount = (_allReports.length / 6).ceil();
  }

  void _filterReports() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReports = _allReports.where((report) {
        return report.displayTitle.toLowerCase().contains(query) ||
            (report.displaySubtitle?.toLowerCase().contains(query) ?? false);
      }).toList();
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
      backgroundColor: const Color(0xFFF4F7FC),
      body: Column(
        children: [
          _WaveHeader(dashboard: widget.dashboard, accentColor: accentColor),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 24),
                  _buildAnimatedKPIs(accentColor),
                  const SizedBox(height: 24),
                  _buildAnimatedSearchHeader(),
                  const SizedBox(height: 16),
                  _buildAnimatedReportGrid(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedKPIs(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(child: _AnimatedListItem(index: 0, controller: _animationController, child: _StatCard(icon: Icons.bar_chart_rounded, value: "${_filteredReports.length}", label: "Visible Reports", color: accentColor))),
          const SizedBox(width: 12),
          Expanded(child: _AnimatedListItem(index: 1, controller: _animationController, child: _StatCard(icon: Icons.business_center, value: "$_activeProjectsCount", label: "Active Projects", color: Colors.green))),
          const SizedBox(width: 12),
          Expanded(child: _AnimatedListItem(index: 2, controller: _animationController, child: _StatCard(icon: Icons.new_releases_outlined, value: "$_newThisWeekCount", label: "New this Week", color: Colors.orange))),
        ],
      ),
    );
  }

  Widget _buildAnimatedSearchHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(child: Text("Your Reports", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF333333)), overflow: TextOverflow.ellipsis, maxLines: 1)),
          const SizedBox(width: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            width: _isSearchActive ? 220 : 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _isSearchActive ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)] : [],
            ),
            child: Row(
              children: [
                Expanded(child: _isSearchActive ? Padding(padding: const EdgeInsets.only(left: 16.0), child: TextField(controller: _searchController, focusNode: _searchFocusNode, decoration: const InputDecoration.collapsed(hintText: "Search..."), style: GoogleFonts.poppins())) : const SizedBox.shrink()),
                IconButton(
                  splashRadius: 20,
                  icon: Icon(_isSearchActive ? Icons.close : Icons.search, color: Colors.grey[600]),
                  onPressed: () {
                    setState(() {
                      _isSearchActive = !_isSearchActive;
                      if (_isSearchActive) _searchFocusNode.requestFocus(); else {_searchFocusNode.unfocus(); _searchController.clear();}
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedReportGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
            index: index + 3,
            controller: _animationController,
            child: _AuroraReportCard(
              cardConfig: cardConfig,
              accentColor: widget.dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor,
              onTap: () => widget.onReportCardTap(cardConfig),
            ),
          );
        },
      ),
    );
  }
}

// --- Header Widget ---
class _WaveHeader extends StatelessWidget {
  final Dashboard dashboard;
  final Color accentColor;

  const _WaveHeader({required this.dashboard, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 170,
          decoration: BoxDecoration(
            color: accentColor,
            gradient: LinearGradient(
              colors: [accentColor, accentColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
        ),
        ClipPath(
          clipper: _WaveClipper(),
          child: Container(
            height: 170,
            color: Colors.white.withOpacity(0.05),
          ),
        ),
        ClipPath(
          clipper: _WaveClipper(offset: 20, waveHeight: 40),
          child: Container(
            height: 170,
            color: Colors.white.withOpacity(0.05),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 30, left: 24, right: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dashboard.dashboardName,
                  style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [const Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))]
                  ),
                ),
                if (dashboard.dashboardDescription != null && dashboard.dashboardDescription!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      dashboard.dashboardDescription!,
                      style: GoogleFonts.poppins(fontSize: 15, color: Colors.white.withOpacity(0.9)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- CustomClipper for wave effect ---
class _WaveClipper extends CustomClipper<Path> {
  final double waveHeight;
  final double offset;
  _WaveClipper({this.waveHeight = 60.0, this.offset = 0});
  @override
  Path getClip(Size size) { /* ... Same as before ... */
    var path = Path();
    path.lineTo(0, size.height - waveHeight);
    var firstControlPoint = Offset(size.width / 4 + offset, size.height);
    var firstEndPoint = Offset(size.width / 2.25, size.height - 30.0);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);
    var secondControlPoint = Offset(size.width - (size.width / 3.25), size.height - 65);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


// --- REFINED AURORA CARD: White background with subtle gradient accent ---
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
      elevation: 4.0,
      shadowColor: Colors.black.withOpacity(0.08), // Softer shadow
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: InkWell(
        onTap: onTap,
        splashColor: itemColor.withOpacity(0.1), // Subtle splash
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white, // Clean white background
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row( // Use Row to place the accent bar
            children: [
              // --- Gradient Accent Bar on the Left ---
              Container(
                width: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [itemColor.withOpacity(0.8), itemColor],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    bottomLeft: Radius.circular(16.0),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0), // Internal padding
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Icon with subtle background ---
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: itemColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          cardConfig.displayIcon ?? Icons.analytics_outlined,
                          size: 20,
                          color: itemColor,
                        ),
                      ),
                      const SizedBox(height: 8), // Spacing after icon
                      // --- Large, Bold Black Title ---
                      Text(
                        cardConfig.displayTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 16, // Remains large
                          fontWeight: FontWeight.w700,
                          color: Colors.black87, // High contrast black
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // --- Subtitle ---
                      if (cardConfig.displaySubtitle != null && cardConfig.displaySubtitle!.isNotEmpty)
                        Text(
                          cardConfig.displaySubtitle ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

// --- StatCard remains unchanged ---
class _StatCard extends StatelessWidget {
  final IconData icon; final String value; final String label; final Color color;
  const _StatCard({required this.icon, required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// --- AnimatedListItem remains unchanged ---
class _AnimatedListItem extends StatelessWidget {
  final int index; final Widget child; final AnimationController controller;
  const _AnimatedListItem({required this.index, required this.child, required this.controller});
  @override
  Widget build(BuildContext context) {
    final interval = Interval((index * 100) / 1000, (300 + index * 100) / 1000, curve: Curves.easeOut);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final animation = interval.transform(controller.value);
        return Opacity(opacity: animation, child: Transform.translate(offset: Offset(0, (1 - animation) * 30), child: child));
      },
    );
  }
}