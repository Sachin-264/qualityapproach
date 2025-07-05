
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../ReportDynamic/ReportAPIService.dart';
import '../../../ReportUtils/subtleloader.dart';
import '../../DashboardModel/dashboard_model.dart';

const double _sideNavWidth = 280.0;

class ModernMinimalTemplate extends StatefulWidget {
  final Dashboard dashboard;
  final Function(DashboardReportCardConfig) onReportCardTap;
  final ReportAPIService apiService;

  const ModernMinimalTemplate({
    Key? key,
    required this.dashboard,
    required this.onReportCardTap,
    required this.apiService,
  }) : super(key: key);

  @override
  State<ModernMinimalTemplate> createState() => _ModernMinimalTemplateState();
}

class _ModernMinimalTemplateState extends State<ModernMinimalTemplate> {
  int _selectedGroupIndex = -1;
  bool _isSideNavVisible = true;

  void _onGroupSelected(int index) {
    setState(() {
      _selectedGroupIndex = index;
    });
  }

  void _toggleSideNav() {
    setState(() {
      _isSideNavVisible = !_isSideNavVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            width: _isSideNavVisible ? _sideNavWidth : 0,
            child: _SideNavigationBar(
              dashboardName: widget.dashboard.dashboardName,
              groups: widget.dashboard.reportGroups,
              selectedIndex: _selectedGroupIndex,
              accentColor: widget.dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor,
              onGroupSelected: _onGroupSelected,
            ),
          ),
          Expanded(
            child: _ContentArea(
              key: ValueKey(_selectedGroupIndex),
              selectedGroup: _selectedGroupIndex == -1 ? null : widget.dashboard.reportGroups[_selectedGroupIndex],
              allGroups: widget.dashboard.reportGroups,
              accentColor: widget.dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor,
              onReportCardTap: widget.onReportCardTap,
              apiService: widget.apiService,
              isSideNavVisible: _isSideNavVisible,
              onToggleNav: _toggleSideNav,
            ),
          ),
        ],
      ),
    );
  }
}

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
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5), width: 1.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Icon(Icons.insights, color: accentColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dashboardName,
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Divider(indent: 24, endIndent: 24, color: Theme.of(context).dividerColor.withOpacity(0.5)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _NavigationItem(
                  icon: Icons.dashboard_customize_outlined,
                  label: 'Dashboard Home',
                  isSelected: selectedIndex == -1,
                  accentColor: accentColor,
                  onTap: () => onGroupSelected(-1),
                ),
                const SizedBox(height: 20),
                Text('REPORT GROUPS', style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                ...List.generate(groups.length, (index) {
                  return _NavigationItem(
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
                color: isSelected ? accentColor : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? accentColor.darken(0.1) : Theme.of(context).colorScheme.onSurface,
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

class _ContentArea extends StatelessWidget {
  final DashboardReportGroup? selectedGroup;
  final List<DashboardReportGroup> allGroups;
  final Color accentColor;
  final Function(DashboardReportCardConfig) onReportCardTap;
  final ReportAPIService apiService;
  final bool isSideNavVisible;
  final VoidCallback onToggleNav;

  const _ContentArea({
    Key? key,
    this.selectedGroup,
    required this.allGroups,
    required this.accentColor,
    required this.onReportCardTap,
    required this.apiService,
    required this.isSideNavVisible,
    required this.onToggleNav,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isHomeView = selectedGroup == null;
    final String title = isHomeView ? 'Home' : selectedGroup!.groupName;
    final reportsSource = isHomeView ? allGroups.expand((g) => g.reports) : selectedGroup!.reports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              IconButton(
                icon: Icon(isSideNavVisible ? Icons.menu_open_rounded : Icons.menu_rounded),
                tooltip: isSideNavVisible ? 'Collapse Sidebar' : 'Expand Sidebar',
                onPressed: onToggleNav,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: reportsSource.isEmpty
              ? Center(child: Text("No reports to display.", style: GoogleFonts.poppins(color: Colors.grey[600])))
              : ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: reportsSource.length,
            itemBuilder: (context, index) {
              return _DashboardReportItem(
                cardConfig: reportsSource.elementAt(index),
                accentColor: accentColor,
                onReportCardTap: onReportCardTap,
                apiService: apiService,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DashboardReportItem extends StatelessWidget {
  final DashboardReportCardConfig cardConfig;
  final Color accentColor;
  final Function(DashboardReportCardConfig) onReportCardTap;
  final ReportAPIService apiService;

  const _DashboardReportItem({
    required this.cardConfig,
    required this.accentColor,
    required this.onReportCardTap,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasBoth = cardConfig.showAsTile && cardConfig.showAsGraph;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cardConfig.showAsTile)
            _MinimalistTileCard(
              cardConfig: cardConfig,
              accentColor: accentColor,
              onTap: () => onReportCardTap(cardConfig),
            ),

          if (hasBoth)
            const _VisualConnector(),

          if (cardConfig.showAsGraph)
            Expanded(
              child: _GraphCardWidget(
                cardConfig: cardConfig,
                apiService: apiService,
                accentColor: accentColor,
                onViewReport: () => onReportCardTap(cardConfig),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisualConnector extends StatelessWidget {
  const _VisualConnector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 150,
      alignment: Alignment.center,
      child: CustomPaint(
        painter: _DashedLinePainter(color: Theme.of(context).dividerColor),
        size: const Size(48, 1),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _MinimalistTileCard extends StatelessWidget {
  final DashboardReportCardConfig cardConfig;
  final Color accentColor;
  final VoidCallback onTap;

  const _MinimalistTileCard({
    required this.cardConfig,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor = cardConfig.displayColor ?? accentColor;
    return SizedBox(
      width: 250,
      height: 150,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        color: itemColor.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  cardConfig.displayIcon ?? Icons.analytics_outlined,
                  size: 36,
                  color: itemColor,
                ),
                const Spacer(),
                Text(
                  cardConfig.displayTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: itemColor.darken(0.2),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YearlySalesData {
  _YearlySalesData(this.year, this.sales, this.color);
  final String year;
  final double sales;
  final Color color;
}

class _ItemGroupSalesData {
  _ItemGroupSalesData(this.groupName, this.sales, this.label);
  final String groupName;
  final double sales;
  final String label;
}

class _ErrorDisplay extends StatelessWidget {
  final String error;
  const _ErrorDisplay({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              'Chart Error',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphCardWidget extends StatelessWidget {
  final DashboardReportCardConfig cardConfig;
  final ReportAPIService apiService;
  final Color accentColor;
  final VoidCallback onViewReport;

  const _GraphCardWidget({
    required this.cardConfig,
    required this.apiService,
    required this.accentColor,
    required this.onViewReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool showViewButton = !cardConfig.showAsTile;

    debugPrint('--- [Building Graph Card: ${cardConfig.displayTitle}] ---');
    debugPrint('   - Graph Type: ${cardConfig.graphType}');
    debugPrint('   - API URL: ${cardConfig.apiUrl}');

    if (cardConfig.apiUrl == null || cardConfig.apiUrl!.isEmpty) {
      return SizedBox(
        height: showViewButton ? 350 : 300,
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          color: Colors.white,
          child: const _ErrorDisplay(error: 'No API URL has been configured for this graph.'),
        ),
      );
    }

    return SizedBox(
      height: showViewButton ? 350 : 300,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cardConfig.displayTitle,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  if (cardConfig.displaySubtitle != null && cardConfig.displaySubtitle!.isNotEmpty)
                    Text(
                      cardConfig.displaySubtitle!,
                      style: GoogleFonts.poppins(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: FutureBuilder<dynamic>(
                      future: apiService.getReportData(cardConfig.apiUrl),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: SubtleLoader());
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return _ErrorDisplay(error: snapshot.error?.toString() ?? 'Failed to load data');
                        }

                        final data = snapshot.data;
                        Widget chartWidget;

                        switch (cardConfig.graphType) {
                          case GraphType.bar:
                          case GraphType.line:
                            chartWidget = (data is Map)
                                ? (cardConfig.graphType == GraphType.bar ? _buildBarChart(Map<String, dynamic>.from(data), context) : _buildLineChart(Map<String, dynamic>.from(data), context))
                                : const _ErrorDisplay(error: 'This chart type requires single object data (JSON Object).');
                            break;
                          case GraphType.pie:
                            if (data is List) {
                              chartWidget = _buildPieChartFromList(data, context);
                            } else if (data is Map) {
                              chartWidget = _buildPieChartFromMap(Map<String, dynamic>.from(data), context);
                            } else {
                              chartWidget = const _ErrorDisplay(error: 'Pie Chart requires either a JSON Object or Array.');
                            }
                            break;
                          default:
                            chartWidget = const Center(child: Text("Unsupported graph type."));
                        }

                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: chartWidget,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (showViewButton) ...[
              const Spacer(),
              const Divider(height: 1),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: onViewReport,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text("View Full Report"),
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, dynamic> data, BuildContext context) {
    final numberFormat = NumberFormat.compact(locale: 'en_IN');
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final List<_YearlySalesData> chartData = [
      _YearlySalesData(data['PreviousToPreviousYearSaleLabel'], data['PreviousToPreviousYearSaleValue'], accentColor.withOpacity(0.4)),
      _YearlySalesData(data['PreviousYearSaleLabel'], data['PreviousYearSaleValue'], accentColor.withOpacity(0.7)),
      _YearlySalesData(data['CurrentYearSaleLabel'], data['CurrentYearSaleValue'], accentColor),
    ];
    return SfCartesianChart(
      primaryXAxis: const CategoryAxis(majorGridLines: MajorGridLines(width: 0)),
      primaryYAxis: NumericAxis(
        numberFormat: numberFormat,
        majorGridLines: const MajorGridLines(width: 1, dashArray: [5, 5]),
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        header: 'Sales',
        format: 'point.x : ${currencyFormat.format(0)}point.y',
      ),
      series: <CartesianSeries>[
        ColumnSeries<_YearlySalesData, String>(
          dataSource: chartData,
          xValueMapper: (_YearlySalesData sales, _) => sales.year,
          yValueMapper: (_YearlySalesData sales, _) => sales.sales,
          pointColorMapper: (_YearlySalesData sales, _) => sales.color,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _buildLineChart(Map<String, dynamic> data, BuildContext context) {
    final numberFormat = NumberFormat.compact(locale: 'en_IN');
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final List<_YearlySalesData> chartData = [
      _YearlySalesData(data['PreviousToPreviousYearSaleLabel'], data['PreviousToPreviousYearSaleValue'], accentColor),
      _YearlySalesData(data['PreviousYearSaleLabel'], data['PreviousYearSaleValue'], accentColor),
      _YearlySalesData(data['CurrentYearSaleLabel'], data['CurrentYearSaleValue'], accentColor),
    ];
    return SfCartesianChart(
      primaryXAxis: const CategoryAxis(
        majorGridLines: MajorGridLines(width: 0),
        labelPlacement: LabelPlacement.onTicks,
      ),
      primaryYAxis: NumericAxis(
        numberFormat: numberFormat,
        majorGridLines: const MajorGridLines(width: 1, dashArray: [5, 5]),
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        header: 'Sales Trend',
        format: 'point.x\n${currencyFormat.format(0)}point.y',
      ),
      series: <CartesianSeries>[
        SplineSeries<_YearlySalesData, String>(
          dataSource: chartData,
          xValueMapper: (_YearlySalesData sales, _) => sales.year,
          yValueMapper: (_YearlySalesData sales, _) => sales.sales,
          color: accentColor,
          width: 3,
          markerSettings: MarkerSettings(
            isVisible: true,
            height: 8,
            width: 8,
            color: accentColor,
            borderColor: Colors.white,
            borderWidth: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildPieChartFromMap(Map<String, dynamic> data, BuildContext context) {
    final List<Map<String, dynamic>> listData = [
      {'ItemGroupName': data['PreviousToPreviousYearSaleLabel'], 'SaleValue': data['PreviousToPreviousYearSaleValue']},
      {'ItemGroupName': data['PreviousYearSaleLabel'], 'SaleValue': data['PreviousYearSaleValue']},
      {'ItemGroupName': data['CurrentYearSaleLabel'], 'SaleValue': data['CurrentYearSaleValue']},
    ];
    return _buildPieChartFromList(listData, context);
  }

  Widget _buildPieChartFromList(List<dynamic> data, BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    List<_ItemGroupSalesData> chartData;
    try {
      final typedData = data.cast<Map<String, dynamic>>();
      final totalValue = typedData.fold<double>(0.0, (sum, item) => sum + (item['SaleValue'] ?? 0.0));
      chartData = typedData.map((item) {
        final value = item['SaleValue']?.toDouble() ?? 0.0;
        final percentage = totalValue > 0 ? (value / totalValue) * 100 : 0.0;
        return _ItemGroupSalesData(
          item['ItemGroupName'] ?? 'Unknown',
          value,
          '${percentage.toStringAsFixed(1)}%',
        );
      }).toList();
    } catch (e) {
      debugPrint("Error parsing Pie Chart data from list: $e");
      return _ErrorDisplay(error: "Data for Pie Chart is a list, but contains invalid items.");
    }

    return SfCircularChart(
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x : ${currencyFormat.format(0)}point.y',
      ),
      legend: const Legend(
        isVisible: true,
        overflowMode: LegendItemOverflowMode.wrap,
        position: LegendPosition.bottom,
      ),
      series: <CircularSeries>[
        DoughnutSeries<_ItemGroupSalesData, String>(
          dataSource: chartData,
          xValueMapper: (_ItemGroupSalesData data, _) => data.groupName,
          yValueMapper: (_ItemGroupSalesData data, _) => data.sales,
          dataLabelMapper: (_ItemGroupSalesData data, _) => data.label,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            connectorLineSettings: ConnectorLineSettings(type: ConnectorType.curve, length: '10%'),
          ),
          radius: '80%',
          innerRadius: '60%',
        ),
      ],
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
}