// lib/ReportDashboard/DashboardModel/dashboard_model.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// Helper function for safe parsing of dynamic values to int
int? _safeParseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is num) return value.toInt();
  return null;
}

// Represents the display configuration for a single report card on the dashboard.
class DashboardReportCardConfig {
  // No changes here
  final int reportRecNo;
  final String displayTitle;
  final String? displaySubtitle;
  final IconData? displayIcon;
  final Color? displayColor;

  DashboardReportCardConfig({
    required this.reportRecNo,
    required this.displayTitle,
    this.displaySubtitle,
    this.displayIcon,
    this.displayColor,
  });

  factory DashboardReportCardConfig.fromJson(Map<String, dynamic> json) {
    final int? recNo = _safeParseInt(json['reportRecNo']);
    if (recNo == null) {
      throw FormatException("Invalid or missing 'reportRecNo' in JSON data: ${json['reportRecNo']}");
    }
    final int? iconCodePoint = _safeParseInt(json['displayIcon']);
    IconData? parsedIcon = iconCodePoint != null ? IconData(iconCodePoint, fontFamily: 'MaterialIcons') : null;
    final int? colorValue = _safeParseInt(json['displayColor']);
    Color? parsedColor = colorValue != null ? Color(colorValue) : null;
    return DashboardReportCardConfig(
      reportRecNo: recNo,
      displayTitle: json['displayTitle'] as String,
      displaySubtitle: json['displaySubtitle'] as String?,
      displayIcon: parsedIcon,
      displayColor: parsedColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reportRecNo': reportRecNo,
      'displayTitle': displayTitle,
      'displaySubtitle': displaySubtitle,
      'displayIcon': displayIcon?.codePoint,
      'displayColor': displayColor?.value,
    };
  }
}

// No changes to DashboardTemplateConfig
class DashboardTemplateConfig {
  final String id;
  final String name;
  final String? bannerUrl;
  final Color? accentColor;

  DashboardTemplateConfig({
    required this.id,
    required this.name,
    this.bannerUrl,
    this.accentColor,
  });

  factory DashboardTemplateConfig.fromJson(Map<String, dynamic> json) {
    final int? colorValue = _safeParseInt(json['accentColor']);
    Color? parsedAccentColor = colorValue != null ? Color(colorValue) : null;
    return DashboardTemplateConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      bannerUrl: json['bannerUrl'] as String?,
      accentColor: parsedAccentColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bannerUrl': bannerUrl,
      'accentColor': accentColor?.value,
    };
  }
}

// Model mirroring your Dashboards DB table
class Dashboard {
  // *** FIX: Change dashboardId to String ***
  // New dashboards will have an empty string ID until saved.
  final String dashboardId;
  final String dashboardName;
  final String? dashboardDescription;
  final DashboardTemplateConfig templateConfig;
  final List<DashboardReportCardConfig> reportsOnDashboard;
  final Map<String, dynamic>? globalFiltersConfig;
  final DateTime createdAt;
  final DateTime updatedAt;

  Dashboard({
    required this.dashboardId,
    required this.dashboardName,
    this.dashboardDescription,
    required this.templateConfig,
    required this.reportsOnDashboard,
    this.globalFiltersConfig,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    // *** FIX: Convert DashboardID to String, regardless of its original type ***
    final String dashboardId = json['DashboardID'].toString();

    final Map<String, dynamic> layoutConfigMap = json['LayoutConfig'] is String && json['LayoutConfig'].isNotEmpty
        ? jsonDecode(json['LayoutConfig']) as Map<String, dynamic>
        : <String, dynamic>{};

    final List<dynamic> reportsJson = layoutConfigMap['reports_on_dashboard'] ?? [];
    final List<DashboardReportCardConfig> reports = reportsJson
        .map((rJson) => DashboardReportCardConfig.fromJson(rJson))
        .toList();

    Map<String, dynamic> templateConfigMap;
    if (json['TemplateID'] is String && json['TemplateID'].isNotEmpty) {
      try {
        templateConfigMap = jsonDecode(json['TemplateID']) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error decoding TemplateID JSON: $e. Using default template config.');
        templateConfigMap = {'id': 'classicClean', 'name': 'Classic Clean'};
      }
    } else if (json['TemplateID'] is Map<String, dynamic>) {
      templateConfigMap = json['TemplateID'] as Map<String, dynamic>;
    } else {
      templateConfigMap = {'id': 'classicClean', 'name': 'Classic Clean'};
    }
    final DashboardTemplateConfig templateConf = DashboardTemplateConfig.fromJson(templateConfigMap);

    return Dashboard(
      dashboardId: dashboardId, // Use the string ID
      dashboardName: json['DashboardName'] as String,
      dashboardDescription: json['DashboardDescription'] as String?,
      templateConfig: templateConf,
      reportsOnDashboard: reports,
      globalFiltersConfig: json['GlobalFiltersConfig'] is String && json['GlobalFiltersConfig'].isNotEmpty
          ? jsonDecode(json['GlobalFiltersConfig']) as Map<String, dynamic>
          : (json['GlobalFiltersConfig'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.tryParse(json['CreatedAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['UpdatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // *** FIX: Send ID as a string. If it's a new dashboard, it's an empty string. ***
      // The API should handle an empty string as a "new" item.
      'DashboardID': dashboardId,
      'DashboardName': dashboardName,
      'DashboardDescription': dashboardDescription,
      'TemplateID': jsonEncode(templateConfig.toJson()),
      'LayoutConfig': jsonEncode({
        'reports_on_dashboard': reportsOnDashboard.map((c) => c.toJson()).toList(),
      }),
      'GlobalFiltersConfig': globalFiltersConfig != null ? jsonEncode(globalFiltersConfig) : null,
      'CreatedAt': createdAt.toIso8601String(),
      'UpdatedAt': updatedAt.toIso8601String(),
    };
  }
}