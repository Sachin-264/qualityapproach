// lib/ReportDashboard/DashboardScreen/dashboardTemplates/modern_minimal_template.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../DashboardModel/dashboard_model.dart';

const double _sideNavWidth = 280.0;
final Color _borderColor = Colors.grey.shade200;

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

class _ModernMinimalTemplateState extends State<ModernMinimalTemplate> {
  // Use -1 to represent the "Dashboard Home" / All Reports view
  int _selectedGroupIndex = -1;

  void _onGroupSelected(int index) {
    setState(() {
      _selectedGroupIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // The main layout is now a Row for side-by-side navigation and content
      body: Row(
        children: [
          // --- 1. The Fixed Side Navigation Panel ---
          _SideNavigationBar(
            dashboardName: widget.dashboard.dashboardName,
            groups: widget.dashboard.reportGroups,
            selectedIndex: _selectedGroupIndex,
            accentColor: widget.dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor,
            onGroupSelected: _onGroupSelected,
          ),

          // --- 2. The Main Content Area ---
          Expanded(
            child: _ContentArea(
              // Pass null for the "Home" view, or the selected group
              selectedGroup: _selectedGroupIndex == -1 ? null : widget.dashboard.reportGroups[_selectedGroupIndex],
              allGroups: widget.dashboard.reportGroups,
              accentColor: widget.dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor,
              onReportCardTap: widget.onReportCardTap,
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET 1: The Side Navigation Panel ---
class _SideNavigationBar extends StatelessWidget {
  final String dashboardName;
  final List<DashboardReportGroup> groups;
  final int selectedIndex;
  final Color accentColor;
  final ValueChanged<int> onGroupSelected;

  const _SideNavigationBar({
    required this.dashboardName,
    required this.groups,
    required this.selectedIndex,
    required this.accentColor,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _sideNavWidth,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA), // A very light grey for the nav area
        border: Border(right: BorderSide(color: _borderColor, width: 1.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header for the Nav Panel ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Icon(Icons.insights, color: accentColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dashboardName,
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: 24, endIndent: 24),

          // --- Navigation Items ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // "Home" navigation item
                _NavigationItem(
                  icon: Icons.dashboard_customize_outlined,
                  label: 'Dashboard Home',
                  isSelected: selectedIndex == -1,
                  accentColor: accentColor,
                  onTap: () => onGroupSelected(-1),
                ),
                const SizedBox(height: 20),
                Text('REPORT GROUPS', style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 8),

                // List of group navigation items
                ...List.generate(groups.length, (index) {
                  return _NavigationItem(
                    // You can add icons to your group model later
                    icon: Icons.folder_copy_outlined,
                    label: groups[index].groupName,
                    isSelected: selectedIndex == index,
                    accentColor: accentColor,
                    onTap: () => onGroupSelected(index),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// --- WIDGET 2: A single tappable item in the side navigation ---
class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: accentColor.withOpacity(0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? accentColor : Colors.grey[700],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? accentColor.darken(0.1) : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGET 3: The Main Content Area on the right ---
class _ContentArea extends StatelessWidget {
  final DashboardReportGroup? selectedGroup;
  final List<DashboardReportGroup> allGroups;
  final Color accentColor;
  final Function(DashboardReportCardConfig) onReportCardTap;

  const _ContentArea({
    this.selectedGroup,
    required this.allGroups,
    required this.accentColor,
    required this.onReportCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isHomeView = selectedGroup == null;
    final String title = isHomeView ? 'All Reports' : selectedGroup!.groupName;
    final List<DashboardReportCardConfig> reportsToShow = isHomeView
        ? allGroups.expand((g) => g.reports).toList()
        : selectedGroup!.reports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header for the content area ---
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Text(
            title,
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
          ),
        ),

        // --- The Grid of Reports ---
        Expanded(
          child: reportsToShow.isEmpty
              ? Center(child: Text("No reports to display.", style: GoogleFonts.poppins(color: Colors.grey[600])))
              : GridView.builder(
            key: ValueKey(selectedGroup?.groupId ?? 'home'),
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 1.0,
            ),
            itemCount: reportsToShow.length,
            itemBuilder: (context, index) {
              final cardConfig = reportsToShow[index];
              return _MinimalistVibrantCard(
                cardConfig: cardConfig,
                accentColor: accentColor,
                onTap: () => onReportCardTap(cardConfig),
              );
            },
          ),
        ),
      ],
    );
  }
}


// --- The Report Card widget (Unchanged, it already looks great) ---
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
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.shade200, width: 1.0),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: onTap,
        splashColor: itemColor.withOpacity(0.08),
        hoverColor: itemColor.withOpacity(0.03),
        child: Container(
          decoration: BoxDecoration(
            color: itemColor.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        cardConfig.displayIcon ?? Icons.analytics_outlined,
                        size: 32,
                        color: itemColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cardConfig.displayTitle,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cardConfig.displaySubtitle != null && cardConfig.displaySubtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            cardConfig.displaySubtitle!,
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: itemColor,
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

// Helper Extension for Color
extension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}