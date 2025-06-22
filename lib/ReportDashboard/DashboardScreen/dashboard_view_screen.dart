// lib/screens/dashboard_view_screen.dart

import 'dart:convert'; // For jsonDecode
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../ReportDynamic/ReportAPIService.dart';
import '../../ReportDynamic/ReportGenerator/ReportMainUI.dart';
import '../../ReportDynamic/ReportGenerator/Reportbloc.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../DashboardBloc/dashboard_builder_bloc.dart';
import '../DashboardModel/dashboard_model.dart';
import '../dashboardWidget/dashboard_report_card.dart';
import 'dashboard_builder_screen.dart';



enum DashboardTemplateEnum {
  classicClean,
  modernMinimal,
  vibrantBold,
}

extension DashboardTemplateEnumExtension on DashboardTemplateEnum {
  String get id => toString().split('.').last;
}

class DashboardViewScreen extends StatefulWidget {
  final String dashboardId;
  final ReportAPIService apiService;

  const DashboardViewScreen({
    Key? key,
    required this.dashboardId,
    required this.apiService,
  }) : super(key: key);

  @override
  State<DashboardViewScreen> createState() => _DashboardViewScreenState();
}

class _DashboardViewScreenState extends State<DashboardViewScreen> {
  Future<Dashboard>? _dashboardFuture;
  List<Map<String, dynamic>> _allReportDefinitions = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardAndReports();
  }

  Future<void> _loadDashboardAndReports() async {
    setState(() {
      _dashboardFuture = null; // Clear previous state to show loader
    });
    try {
      // Fetch all available report definitions once for quick lookup
      _allReportDefinitions = await widget.apiService.fetchDemoTable();
      debugPrint('Fetched ${_allReportDefinitions.length} report definitions.');

      // Then fetch the specific dashboard configuration
      final dashboardsJson = await widget.apiService.getDashboards();
      final dashboardJson = dashboardsJson.firstWhere(
            (dash) => dash['DashboardID'] == widget.dashboardId,
        orElse: () => throw Exception('Dashboard with ID ${widget.dashboardId} not found.'),
      );
      final dashboard = Dashboard.fromJson(dashboardJson);

      setState(() {
        _dashboardFuture = Future.value(dashboard);
      });
    } catch (e) {
      setState(() {
        _dashboardFuture = Future.error(e);
      });
      debugPrint('Error loading dashboard or reports: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper to get full report definition from cached list
  Map<String, dynamic>? _getReportDefinition(int recNo) {
    return _allReportDefinitions.firstWhere(
          (report) => report['RecNo'] == recNo,
      orElse: () => {}, // Return empty map if not found, handle null/empty outside
    );
  }

  void _navigateToReportMainUI(DashboardReportCardConfig cardConfig) async {
    final reportDef = _getReportDefinition(cardConfig.reportRecNo);

    if (reportDef == null || reportDef.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report data for ${cardConfig.displayTitle} not found!'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final String recNo = reportDef['RecNo']?.toString() ?? cardConfig.reportRecNo.toString();
    final String apiName = reportDef['API_name']?.toString() ?? '';
    final String reportLabel = reportDef['Report_label']?.toString() ?? cardConfig.displayTitle;
    final List<Map<String, dynamic>> actionsConfig = (reportDef['actions_config'] is String && reportDef['actions_config'].isNotEmpty
        ? jsonDecode(reportDef['actions_config']) as List
        : [])
        .cast<Map<String, dynamic>>();
    final bool includePdfFooterDateTime = reportDef['pdf_footer_datetime'] == 1 || reportDef['pdf_footer_datetime'] == true;

    // These values could come from globalFiltersConfig on the Dashboard if implemented
    final Map<String, String> userParameterValues = {};
    final Map<String, String> displayParameterValues = {};
    const String companyName = 'Your Company Name'; // Replace with actual company name logic

    if (apiName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API name for $reportLabel is missing from report configuration!'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider<ReportBlocGenerate>(
            create: (_) => ReportBlocGenerate(widget.apiService)
              ..add(FetchApiDetails(apiName, const []))
              ..add(FetchFieldConfigs(recNo, apiName, reportLabel)),
            child: ReportMainUI(
              recNo: recNo,
              apiName: apiName,
              reportLabel: reportLabel,
              userParameterValues: userParameterValues,
              actionsConfig: actionsConfig,
              displayParameterValues: displayParameterValues,
              companyName: companyName,
              includePdfFooterDateTime: includePdfFooterDateTime,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: 'Dashboard Viewer',
        onBackPress: () => Navigator.pop(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardAndReports,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              if (_dashboardFuture != null && _dashboardFuture is Future<Dashboard>) {
                final dashboard = await _dashboardFuture;
                if (dashboard != null) {
                  // Ensure BlocProvider is provided for DashboardBuilderScreen
                  if (mounted) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BlocProvider<DashboardBuilderBloc>(
                          create: (context) => DashboardBuilderBloc(widget.apiService),
                          child: DashboardBuilderScreen(
                            apiService: widget.apiService,
                            dashboardToEdit: dashboard,
                          ),
                        ),
                      ),
                    );
                    _loadDashboardAndReports(); // Refresh after edit
                  }
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<Dashboard>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: SubtleLoader());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Failed to load dashboard: ${snapshot.error}',
                  style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          } else if (!snapshot.hasData) {
            return Center(
              child: Text(
                'Dashboard not found or no data.',
                style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          } else {
            final dashboard = snapshot.data!;
            if (dashboard.reportsOnDashboard.isEmpty) {
              return Center(
                child: Text(
                  'This dashboard has no reports configured.',
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }

            // Delegate rendering to a helper to keep build method clean
            // The template rendering logic is now inside this helper
            return _DashboardTemplateRenderer(
              dashboard: dashboard,
              onReportCardTap: _navigateToReportMainUI,
            );
          }
        },
      ),
    );
  }
}

// --- HELPER CLASS: Renders the specific dashboard template ---
class _DashboardTemplateRenderer extends StatelessWidget {
  final Dashboard dashboard;
  final Function(DashboardReportCardConfig) onReportCardTap;

  const _DashboardTemplateRenderer({
    Key? key,
    required this.dashboard,
    required this.onReportCardTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine which template to render based on dashboard.templateConfig.id
    final DashboardTemplateEnum template = DashboardTemplateEnum.values.firstWhere(
          (e) => e.id == dashboard.templateConfig.id,
      orElse: () => DashboardTemplateEnum.classicClean, // Fallback to Classic Clean
    );

    final String? bannerUrl = dashboard.templateConfig.bannerUrl;
    final Color accentColor = dashboard.templateConfig.accentColor ?? Theme.of(context).primaryColor;

    // These properties will be adjusted based on the selected template style
    BoxDecoration backgroundDecoration;
    double cardElevation = 4.0;
    BorderRadius cardBorderRadius = BorderRadius.circular(12.0);
    int crossAxisCount = 2; // Default grid columns
    double cardSpacing = 16.0;
    double cardAspectRatio = 1.0; // Default square

    // Apply template-specific styles
    switch (template) {
      case DashboardTemplateEnum.classicClean:
        backgroundDecoration = BoxDecoration(color: Colors.grey[100]);
        cardElevation = 4.0;
        cardBorderRadius = BorderRadius.circular(12.0);
        crossAxisCount = 2;
        cardSpacing = 16.0;
        cardAspectRatio = 1.0;
        break;
      case DashboardTemplateEnum.modernMinimal:
        backgroundDecoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, accentColor.withOpacity(0.1)],
          ),
        );
        cardElevation = 2.0;
        cardBorderRadius = BorderRadius.circular(16.0);
        crossAxisCount = 2;
        cardSpacing = 24.0;
        cardAspectRatio = 1.1;
        break;
      case DashboardTemplateEnum.vibrantBold:
        backgroundDecoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accentColor.withOpacity(0.2), Colors.white],
          ),
        );
        cardElevation = 8.0;
        cardBorderRadius = BorderRadius.circular(10.0);
        crossAxisCount = 2; // Can be 3 for wider screens if desired
        cardSpacing = 16.0;
        cardAspectRatio = 0.9;
        break;
    }

    return Container(
      decoration: backgroundDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dashboard Header / Banner Area
          Container(
            height: 180, // Fixed height for header
            decoration: BoxDecoration(
              color: accentColor, // Use accent color as base
              image: bannerUrl != null && bannerUrl.isNotEmpty
                  ? DecorationImage(
                image: NetworkImage(bannerUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3), // Darken image slightly
                  BlendMode.darken,
                ),
              )
                  : null,
              gradient: bannerUrl == null || bannerUrl.isEmpty
                  ? LinearGradient( // Apply gradient if no banner image
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
                  offset: const Offset(0, 5),
                ),
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
                      color: Colors.white, // Header text is white for contrast
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dashboard.dashboardDescription != null && dashboard.dashboardDescription!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: Text(
                        dashboard.dashboardDescription!,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white70, // Slightly transparent white
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Main content area for reports (grid)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: cardSpacing,
                  mainAxisSpacing: cardSpacing,
                  childAspectRatio: cardAspectRatio,
                ),
                itemCount: dashboard.reportsOnDashboard.length,
                itemBuilder: (context, index) {
                  final cardConfig = dashboard.reportsOnDashboard[index];

                  // Special rendering for Vibrant & Bold template
                  if (template == DashboardTemplateEnum.vibrantBold) {
                    final Color effectiveCardColor = cardConfig.displayColor ?? accentColor; // Use card's color or template's accent
                    return Transform.rotate( // Apply rotation
                      angle: index % 2 == 0 ? 0.02 : -0.02, // Minor alternating tilt
                      child: Card(
                        elevation: cardElevation,
                        shape: RoundedRectangleBorder(
                          borderRadius: cardBorderRadius,
                        ),
                        color: effectiveCardColor.withOpacity(0.9), // Stronger opaque color
                        child: InkWell(
                          borderRadius: cardBorderRadius,
                          onTap: () => onReportCardTap(cardConfig),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (cardConfig.displayIcon != null) ...[
                                  Icon(
                                    cardConfig.displayIcon,
                                    size: 64, // Larger icon
                                    color: Colors.white, // White icon for vibrant colors
                                  ),
                                  const SizedBox(height: 15),
                                ],
                                Text(
                                  cardConfig.displayTitle,
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900, // Extra bold text
                                    color: Colors.white, // White text for vibrant colors
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (cardConfig.displaySubtitle != null && cardConfig.displaySubtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    cardConfig.displaySubtitle!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white70, // Slightly muted white subtitle
                                    ),
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
                  } else {
                    // For ClassicClean and ModernMinimal, use the reusable DashboardReportCard
                    return DashboardReportCard(
                      cardConfig: cardConfig, // Passes original card config
                      onTap: () => onReportCardTap(cardConfig),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}