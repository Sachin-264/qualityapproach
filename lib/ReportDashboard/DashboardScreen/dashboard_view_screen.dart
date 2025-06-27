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
    _loadDashboardAndReports();
  }

  Future<void> _loadDashboardAndReports() async {
    if (mounted) {
      setState(() {
        _dashboardFuture = null;
      });
    }
    try {
      _allReportDefinitions = await widget.apiService.fetchDemoTable();
      debugPrint('[DashboardView] Loaded ${_allReportDefinitions.length} total report definitions.');

      final dashboardsJson = await widget.apiService.getDashboards();

      final dashboardJson = dashboardsJson.firstWhere(
            (dash) => dash['DashboardID']?.toString() == widget.dashboardId,
        orElse: () => throw Exception('Dashboard with ID ${widget.dashboardId} not found.'),
      );

      final dashboard = Dashboard.fromJson(dashboardJson);

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
        debugPrint('[DashboardView] Error loading dashboard or reports: $e\n$stacktrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Map<String, dynamic>? _getReportDefinition(int recNo) {
    try {
      return _allReportDefinitions.firstWhere(
            (report) => report['RecNo']?.toString() == recNo.toString(),
      );
    } catch (e) {
      debugPrint('[DashboardView] FAILED to find a match for RecNo $recNo.');
      return null;
    }
  }

  void _navigateToReport(DashboardReportCardConfig cardConfig) {
    final reportDef = _getReportDefinition(cardConfig.reportRecNo);
    if (reportDef == null || reportDef.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find the definition for report: ${cardConfig.displayTitle}'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (reportDef['API_name'] == null || reportDef['API_name'].toString().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Configuration error: API name is missing for this report.'), backgroundColor: Colors.red),
        );
      }
      return;
    }
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
      _loadDashboardAndReports();
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
              // --- CHANGE: Pass the apiService down ---
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
  // --- CHANGE: Accept the apiService ---
  final ReportAPIService apiService;

  const _DashboardTemplateRenderer({
    Key? key,
    required this.dashboard,
    required this.onReportCardTap,
    required this.apiService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DashboardTemplateEnum template = DashboardTemplateEnum.values.firstWhere(
          (e) => e.id == dashboard.templateConfig.id,
      orElse: () => DashboardTemplateEnum.classicClean,
    );

    switch (template) {
      case DashboardTemplateEnum.classicClean:
        return ClassicCleanTemplate(dashboard: dashboard, onReportCardTap: onReportCardTap);
      case DashboardTemplateEnum.modernMinimal:
      // --- CHANGE: Pass the apiService to the template ---
        return ModernMinimalTemplate(
          dashboard: dashboard,
          onReportCardTap: onReportCardTap,
          apiService: apiService,
        );
      case DashboardTemplateEnum.vibrantBold:
        return VibrantBoldTemplate(dashboard: dashboard, onReportCardTap: onReportCardTap);
    }
  }
}