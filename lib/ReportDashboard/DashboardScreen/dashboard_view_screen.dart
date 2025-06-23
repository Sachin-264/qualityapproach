// lib/ReportDashboard/DashboardScreen/dashboard_view_screen.dart

import 'dart:convert';
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
              final dashboard = await _dashboardFuture;
              if (dashboard != null && mounted) {
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
            return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Failed to load dashboard: ${snapshot.error}', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center)));
          } else if (!snapshot.hasData) {
            return Center(child: Text('Dashboard not found or no data.', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16), textAlign: TextAlign.center));
          } else {
            final dashboard = snapshot.data!;
            if (dashboard.reportsOnDashboard.isEmpty) {
              return Center(child: Text('This dashboard has no reports configured.', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16), textAlign: TextAlign.center));
            }
            // *** UPDATED: Use the new renderer widget ***
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
    final DashboardTemplateEnum template = DashboardTemplateEnum.values.firstWhere(
          (e) => e.id == dashboard.templateConfig.id,
      orElse: () => DashboardTemplateEnum.classicClean, // Fallback
    );

    // This switch now just returns the correct template widget
    switch (template) {
      case DashboardTemplateEnum.classicClean:
        return ClassicCleanTemplate(dashboard: dashboard, onReportCardTap: onReportCardTap);
      case DashboardTemplateEnum.modernMinimal:
        return ModernMinimalTemplate(dashboard: dashboard, onReportCardTap: onReportCardTap);
      case DashboardTemplateEnum.vibrantBold:
        return VibrantBoldTemplate(dashboard: dashboard, onReportCardTap: onReportCardTap);
    }
  }
}