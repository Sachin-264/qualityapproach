// lib/ReportDashboard/DashboardScreen/dashboard_view_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../ReportDynamic/ReportAPIService.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../DashboardBloc/dashboard_builder_bloc.dart';
import '../DashboardBloc/preselectedreportloader.dart';
import '../DashboardModel/dashboard_model.dart';
import 'dashboardTemplates/classic_clean_template.dart';
import 'dashboardTemplates/modern_minimal_template.dart';
import 'dashboardTemplates/vibrant_bold_template.dart';
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
    debugPrint('[DashboardView] initState: Kicking off initial load.');
    _loadDashboardAndReports();
  }

  Future<void> _loadDashboardAndReports() async {
    debugPrint('[DashboardView] --- Starting _loadDashboardAndReports ---');
    if (mounted) {
      setState(() {
        _dashboardFuture = null; // Set to null to show loading indicator on refresh
      });
    }
    try {
      _allReportDefinitions = await widget.apiService.fetchDemoTable();
      debugPrint('[DashboardView] -> Successfully loaded ${_allReportDefinitions.length} total report definitions.');

      final dashboardsJson = await widget.apiService.getDashboards();
      debugPrint('[DashboardView] -> Successfully loaded ${dashboardsJson.length} total dashboards from API.');


      final dashboardJson = dashboardsJson.firstWhere(
            (dash) => dash['DashboardID']?.toString() == widget.dashboardId,
        orElse: () => throw Exception('Dashboard with ID ${widget.dashboardId} not found.'),
      );
      debugPrint('[DashboardView] -> Found matching dashboard JSON for ID: ${widget.dashboardId}');

      final dashboard = Dashboard.fromJson(dashboardJson);
      debugPrint('[DashboardView] -> Successfully parsed dashboard: "${dashboard.dashboardName}"');


      if (mounted) {
        setState(() {
          _dashboardFuture = Future.value(dashboard);
        });
      }
    } catch (e, stacktrace) {
      if (mounted) {
        setState(() {
          _dashboardFuture = Future.error(e, stacktrace);
        });
        debugPrint('[DashboardView] !!! ERROR loading dashboard or reports: $e\n$stacktrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
    debugPrint('[DashboardView] --- Finished _loadDashboardAndReports ---');
  }

  Map<String, dynamic>? _getReportDefinition(int recNo) {
    try {
      debugPrint('[DashboardView] Searching for report definition with RecNo: $recNo');
      final report = _allReportDefinitions.firstWhere(
            (report) => report['RecNo']?.toString() == recNo.toString(),
      );
      debugPrint('[DashboardView] -> Found match for RecNo $recNo: "${report['Report_label']}"');
      return report;
    } catch (e) {
      debugPrint('[DashboardView] !!! FAILED to find a match for RecNo $recNo.');
      return null;
    }
  }

  void _navigateToReport(DashboardReportCardConfig cardConfig) {
    debugPrint('\n--- [DashboardView] Navigating to report ---');
    debugPrint('Tapped card: "${cardConfig.displayTitle}" (RecNo: ${cardConfig.reportRecNo})');
    final reportDef = _getReportDefinition(cardConfig.reportRecNo);
    if (reportDef == null || reportDef.isEmpty) {
      debugPrint('Navigation FAILED: Report definition was not found.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find the definition for report: ${cardConfig.displayTitle}'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (reportDef['API_name'] == null || reportDef['API_name'].toString().isEmpty) {
      debugPrint('Navigation FAILED: API name is missing in the report definition.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Configuration error: API name is missing for this report.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    debugPrint('Checks passed. Navigating to PreSelectedReportLoader with report: "${reportDef['Report_label']}"');
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreSelectedReportLoader(
            reportDefinition: reportDef,
            apiService: widget.apiService,
          ),
        ),
      );
    }
  }

  void _navigateToEditScreen(Dashboard dashboard) async {
    debugPrint('[DashboardView] Navigating to edit screen for dashboard: "${dashboard.dashboardName}"');
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => DashboardBuilderBloc(widget.apiService),
          child: DashboardBuilderScreen(
            apiService: widget.apiService,
            dashboardToEdit: dashboard,
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      debugPrint('[DashboardView] Returned from edit screen with "true" result. Refreshing dashboard...');
      _loadDashboardAndReports();
    } else {
      debugPrint('[DashboardView] Returned from edit screen. No refresh needed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Dashboard>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _dashboardFuture == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Loading...")),
            body: const Center(child: SubtleLoader()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
              appBar: AppBar(title: const Text("Error")),
              body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Failed to load dashboard: ${snapshot.error}', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center)))
          );
        } else if (!snapshot.hasData) {
          return Scaffold(
              appBar: AppBar(title: const Text("Not Found")),
              body: Center(child: Text('Dashboard not found or no data.', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16), textAlign: TextAlign.center))
          );
        } else {
          final dashboard = snapshot.data!;
          final bool hasNoContent = dashboard.reportGroups.isEmpty || dashboard.reportGroups.every((g) => g.reports.isEmpty);

          return Scaffold(
            appBar: AppBarWidget(
              title: dashboard.dashboardName,
              onBackPress: () => Navigator.of(context).pop(),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Dashboard',
                  onPressed: () => _navigateToEditScreen(dashboard),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: _loadDashboardAndReports,
                )
              ],
            ),
            body: hasNoContent
                ? Center(child: Text('This dashboard has no reports configured.', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16), textAlign: TextAlign.center))
                : _DashboardTemplateRenderer(
              dashboard: dashboard,
              onReportCardTap: _navigateToReport,
              apiService: widget.apiService,
            ),
          );
        }
      },
    );
  }
}

class _DashboardTemplateRenderer extends StatelessWidget {
  final Dashboard dashboard;
  final Function(DashboardReportCardConfig) onReportCardTap;
  final ReportAPIService apiService;

  const _DashboardTemplateRenderer({
    Key? key,
    required this.dashboard,
    required this.onReportCardTap,
    required this.apiService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPrint('\n--- [DashboardTemplateRenderer] Rendering Dashboard ---');
    debugPrint('Dashboard Name: "${dashboard.dashboardName}"');
    debugPrint('Template ID from config: "${dashboard.templateConfig.id}"');

    final DashboardTemplateEnum template = DashboardTemplateEnum.values.firstWhere(
          (e) => e.id == dashboard.templateConfig.id,
      orElse: () {
        debugPrint('-> Template ID not found or invalid. Falling back to default: classicClean');
        return DashboardTemplateEnum.classicClean;
      },
    );

    debugPrint('Selected Template Enum: $template');

    switch (template) {
      case DashboardTemplateEnum.classicClean:
        debugPrint('--> Rendering with: ClassicCleanTemplate');
        return ClassicCleanTemplate(dashboard: dashboard, onReportCardTap: onReportCardTap);
      case DashboardTemplateEnum.modernMinimal:
        debugPrint('--> Rendering with: ModernMinimalTemplate');
        return ModernMinimalTemplate(
          dashboard: dashboard,
          onReportCardTap: onReportCardTap,
          apiService: apiService,
        );
      case DashboardTemplateEnum.vibrantBold:
        debugPrint('--> Rendering with: VibrantBoldTemplate');
        return VibrantBoldTemplate(dashboard: dashboard, onReportCardTap: onReportCardTap);
    }
  }
}