import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

// Helper function for safe parsing of dynamic values to int
int? _safeParseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is num) return value.toInt();
  return null;
}

// Represents the display configuration for a single report card on the dashboard.
// This class is unchanged, but now lives inside a DashboardReportGroup.
class DashboardReportCardConfig extends Equatable {
  final int reportRecNo;
  final String displayTitle;
  final String? displaySubtitle;
  final IconData? displayIcon;
  final Color? displayColor;

  const DashboardReportCardConfig({
    required this.reportRecNo,
    required this.displayTitle,
    this.displaySubtitle,
    this.displayIcon,
    this.displayColor,
  });

  DashboardReportCardConfig copyWith({
    int? reportRecNo,
    String? displayTitle,
    String? displaySubtitle,
    IconData? displayIcon,
    Color? displayColor,
  }) {
    return DashboardReportCardConfig(
      reportRecNo: reportRecNo ?? this.reportRecNo,
      displayTitle: displayTitle ?? this.displayTitle,
      displaySubtitle: displaySubtitle ?? this.displaySubtitle,
      displayIcon: displayIcon ?? this.displayIcon,
      displayColor: displayColor ?? this.displayColor,
    );
  }

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

  @override
  List<Object?> get props => [reportRecNo, displayTitle, displaySubtitle, displayIcon, displayColor];
}

// --- NEW CLASS: Represents a group of reports on the dashboard ---
class DashboardReportGroup extends Equatable {
  final String groupId;
  final String groupName;
  final List<DashboardReportCardConfig> reports;

  const DashboardReportGroup({
    required this.groupId,
    required this.groupName,
    required this.reports,
  });

  DashboardReportGroup copyWith({
    String? groupId,
    String? groupName,
    List<DashboardReportCardConfig>? reports,
  }) {
    return DashboardReportGroup(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      reports: reports ?? this.reports,
    );
  }

  factory DashboardReportGroup.fromJson(Map<String, dynamic> json) {
    var reportsList = json['reports'] as List? ?? [];
    List<DashboardReportCardConfig> reports =
    reportsList.map((i) => DashboardReportCardConfig.fromJson(i)).toList();
    return DashboardReportGroup(
      // Assign new ID if missing for safety with old data
      groupId: json['groupId'] ?? const Uuid().v4(),
      groupName: json['groupName'] ?? 'Unnamed Group',
      reports: reports,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'reports': reports.map((report) => report.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [groupId, groupName, reports];
}


// --- This class is unchanged ---
class DashboardTemplateConfig extends Equatable {
  final String id;
  final String name;
  final String? bannerUrl;
  final Color? accentColor;

  const DashboardTemplateConfig({
    required this.id,
    required this.name,
    this.bannerUrl,
    this.accentColor,
  });

  DashboardTemplateConfig copyWith({
    String? id,
    String? name,
    String? bannerUrl,
    Color? accentColor,
  }) {
    return DashboardTemplateConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      accentColor: accentColor ?? this.accentColor,
    );
  }

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

  @override
  List<Object?> get props => [id, name, bannerUrl, accentColor];
}


// --- MODIFIED CLASS: Model mirroring your Dashboards DB table with support for groups ---
class Dashboard extends Equatable {
  final String dashboardId;
  final String dashboardName;
  final String? dashboardDescription;
  final DashboardTemplateConfig templateConfig;
  final List<DashboardReportGroup> reportGroups; // MODIFIED: Using groups now
  final Map<String, dynamic> globalFiltersConfig;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Dashboard({
    required this.dashboardId,
    required this.dashboardName,
    this.dashboardDescription,
    required this.templateConfig,
    required this.reportGroups, // MODIFIED
    required this.globalFiltersConfig,
    required this.createdAt,
    required this.updatedAt,
  });

  Dashboard copyWith({
    String? dashboardId,
    String? dashboardName,
    String? dashboardDescription,
    DashboardTemplateConfig? templateConfig,
    List<DashboardReportGroup>? reportGroups,
    Map<String, dynamic>? globalFiltersConfig,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Dashboard(
      dashboardId: dashboardId ?? this.dashboardId,
      dashboardName: dashboardName ?? this.dashboardName,
      dashboardDescription: dashboardDescription ?? this.dashboardDescription,
      templateConfig: templateConfig ?? this.templateConfig,
      reportGroups: reportGroups ?? this.reportGroups,
      globalFiltersConfig: globalFiltersConfig ?? this.globalFiltersConfig,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    final String dashboardId = json['DashboardID'].toString();

    final Map<String, dynamic> layoutConfigMap = json['LayoutConfig'] is String && json['LayoutConfig'].isNotEmpty
        ? jsonDecode(json['LayoutConfig']) as Map<String, dynamic>
        : <String, dynamic>{};

    // --- MODIFIED: Backward-compatible parsing logic ---
    List<DashboardReportGroup> groups = [];
    // 1. Check for the new 'report_groups' structure first
    if (layoutConfigMap['report_groups'] != null && layoutConfigMap['report_groups'] is List) {
      var groupsList = layoutConfigMap['report_groups'] as List;
      groups = groupsList.map((g) => DashboardReportGroup.fromJson(g)).toList();
    }
    // 2. If not found, check for the old 'reports_on_dashboard' structure and migrate it
    else if (layoutConfigMap['reports_on_dashboard'] != null && layoutConfigMap['reports_on_dashboard'] is List) {
      debugPrint("Migrating old dashboard format for dashboard ID: $dashboardId");
      final reportsJson = layoutConfigMap['reports_on_dashboard'] as List;
      final List<DashboardReportCardConfig> oldReports = reportsJson
          .map((rJson) => DashboardReportCardConfig.fromJson(rJson))
          .toList();
      // If there are any old reports, put them in a single, default group
      if (oldReports.isNotEmpty) {
        groups.add(DashboardReportGroup(
          groupId: const Uuid().v4(), // Generate a new ID for this migrated group
          groupName: 'Reports', // Default name for the migrated group
          reports: oldReports,
        ));
      }
    }

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
      dashboardId: dashboardId,
      dashboardName: json['DashboardName'] as String,
      dashboardDescription: json['DashboardDescription'] as String?,
      templateConfig: templateConf,
      reportGroups: groups, // Use the parsed or migrated groups
      globalFiltersConfig: json['GlobalFiltersConfig'] is String && json['GlobalFiltersConfig'].isNotEmpty
          ? jsonDecode(json['GlobalFiltersConfig']) as Map<String, dynamic>
          : (json['GlobalFiltersConfig'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.tryParse(json['CreatedAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['UpdatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'DashboardID': dashboardId,
      'DashboardName': dashboardName,
      'DashboardDescription': dashboardDescription,
      'TemplateID': jsonEncode(templateConfig.toJson()),
      // --- MODIFIED: Save the new group structure ---
      'LayoutConfig': jsonEncode({
        'report_groups': reportGroups.map((g) => g.toJson()).toList(),
      }),
      'GlobalFiltersConfig': jsonEncode(globalFiltersConfig),
      'CreatedAt': createdAt.toIso8601String(),
      'UpdatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    dashboardId,
    dashboardName,
    dashboardDescription,
    templateConfig,
    reportGroups,
    globalFiltersConfig,
    createdAt,
    updatedAt
  ];
}