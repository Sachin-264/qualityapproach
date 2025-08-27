// lib/ReportDashboard/DashboardModel/dashboard_model.dart

import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

// Helper function for safe parsing
int? _safeParseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is num) return value.toInt();
  return null;
}

enum GraphType {
  pie,
  line,
  bar;

  String get displayName {
    switch (this) {
      case GraphType.pie: return 'Pie Chart';
      case GraphType.line: return 'Line Chart';
      case GraphType.bar: return 'Bar Chart';
    }
  }

  static GraphType? fromString(String? value) {
    if (value == null) return null;
    return GraphType.values.firstWhere(
          (e) => e.name == value,
      orElse: () => GraphType.bar,
    );
  }
}


// --- MODIFIED & CORRECTED CLASS ---
class DashboardReportCardConfig extends Equatable {
  final int reportRecNo;
  final String displayTitle;
  final String? displaySubtitle;
  final IconData? displayIcon;
  final Color? displayColor;
  final String? apiUrl;
  final bool showAsTile;
  final bool showAsGraph;
  final GraphType? graphType;

  const DashboardReportCardConfig({
    required this.reportRecNo,
    required this.displayTitle,
    this.displaySubtitle,
    this.displayIcon,
    this.displayColor,
    this.apiUrl,
    this.showAsTile = true,
    this.showAsGraph = false,
    this.graphType,
  });

  DashboardReportCardConfig copyWith({
    int? reportRecNo,
    String? displayTitle,
    String? displaySubtitle,
    IconData? displayIcon,
    Color? displayColor,
    String? apiUrl,
    bool? showAsTile,
    bool? showAsGraph,
    GraphType? graphType,
  }) {
    return DashboardReportCardConfig(
      reportRecNo: reportRecNo ?? this.reportRecNo,
      displayTitle: displayTitle ?? this.displayTitle,
      displaySubtitle: displaySubtitle ?? this.displaySubtitle,
      displayIcon: displayIcon ?? this.displayIcon,
      displayColor: displayColor ?? this.displayColor,
      apiUrl: apiUrl ?? this.apiUrl,
      showAsTile: showAsTile ?? this.showAsTile,
      showAsGraph: showAsGraph ?? this.showAsGraph,
      graphType: graphType ?? this.graphType,
    );
  }

  // ========== START: CORRECTED SERIALIZATION LOGIC ==========

  factory DashboardReportCardConfig.fromJson(Map<String, dynamic> json) {
    final int? recNo = _safeParseInt(json['reportRecNo']);
    if (recNo == null) {
      throw FormatException("Invalid or missing 'reportRecNo' in JSON data: ${json['reportRecNo']}");
    }

    // FIX #1: Read icon data using corrected keys that match toJson().
    IconData? parsedIcon;
    if (json['displayIcon_codePoint'] != null) {
      parsedIcon = IconData(
          _safeParseInt(json['displayIcon_codePoint'])!,
          fontFamily: json['displayIcon_fontFamily'] ?? 'MaterialIcons'
      );
    }

    // FIX #2: Read color data using corrected key that matches toJson().
    Color? parsedColor;
    if (json['displayColor_value'] != null) {
      parsedColor = Color(_safeParseInt(json['displayColor_value'])!);
    }


    // Backward compatibility logic to handle old data format
    bool showTile, showGraph;
    if (json.containsKey('showAsTile') || json.containsKey('showAsGraph')) {
      // New format is present
      showTile = json['showAsTile'] ?? false;
      showGraph = json['showAsGraph'] ?? false;
    } else {
      // Fallback to old 'displayType' field if new keys are missing
      final oldDisplayType = json['displayType'];
      showGraph = oldDisplayType == 'graph';
      showTile = oldDisplayType == 'tile' || oldDisplayType == null; // Tiles were the default
    }

    return DashboardReportCardConfig(
      reportRecNo: recNo,
      displayTitle: json['displayTitle'] as String,
      displaySubtitle: json['displaySubtitle'] as String?,
      displayIcon: parsedIcon,
      displayColor: parsedColor,
      apiUrl: json['apiUrl'] as String?,
      showAsTile: showTile,
      showAsGraph: showGraph,
      graphType: GraphType.fromString(json['graphType']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reportRecNo': reportRecNo,
      'displayTitle': displayTitle,
      'displaySubtitle': displaySubtitle,

      // FIX #1: Write icon data using distinct keys to avoid ambiguity.
      'displayIcon_codePoint': displayIcon?.codePoint,
      'displayIcon_fontFamily': displayIcon?.fontFamily,

      // FIX #2: Write color data using a distinct key.
      'displayColor_value': displayColor?.value,

      'apiUrl': apiUrl,

      // These were correct, but are included for completeness.
      'showAsTile': showAsTile,
      'showAsGraph': showAsGraph,
      'graphType': graphType?.name,
    };
  }

  // ========== END: CORRECTED SERIALIZATION LOGIC ==========

  @override
  List<Object?> get props => [
    reportRecNo,
    displayTitle,
    displaySubtitle,
    displayIcon,
    displayColor,
    apiUrl,
    showAsTile,
    showAsGraph,
    graphType,
  ];
}


// --- This class is unchanged ---
class DashboardReportGroup extends Equatable {
  final String groupId;
  final String groupName;
  final String? groupUrl;
  final List<DashboardReportCardConfig> reports;

  const DashboardReportGroup({
    required this.groupId,
    required this.groupName,
    this.groupUrl,
    required this.reports,
  });

  DashboardReportGroup copyWith({
    String? groupId,
    String? groupName,
    String? groupUrl,
    List<DashboardReportCardConfig>? reports,
  }) {
    return DashboardReportGroup(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      groupUrl: groupUrl ?? this.groupUrl,
      reports: reports ?? this.reports,
    );
  }

  factory DashboardReportGroup.fromJson(Map<String, dynamic> json) {
    var reportsList = json['reports'] as List? ?? [];
    List<DashboardReportCardConfig> reports =
    reportsList.map((i) => DashboardReportCardConfig.fromJson(i)).toList();
    return DashboardReportGroup(
      groupId: json['groupId'] ?? const Uuid().v4(),
      groupName: json['groupName'] ?? 'Unnamed Group',
      groupUrl: json['groupUrl'] as String?,
      reports: reports,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'groupUrl': groupUrl,
      'reports': reports.map((report) => report.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [groupId, groupName, groupUrl, reports];
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


// --- This class is unchanged structurally, but relies on updated models ---
class Dashboard extends Equatable {
  final String dashboardId;
  final String dashboardName;
  final String? dashboardDescription;
  final DashboardTemplateConfig templateConfig;
  final List<DashboardReportGroup> reportGroups;
  final Map<String, dynamic> globalFiltersConfig;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Dashboard({
    required this.dashboardId,
    required this.dashboardName,
    this.dashboardDescription,
    required this.templateConfig,
    required this.reportGroups,
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

    List<DashboardReportGroup> groups = [];
    if (layoutConfigMap['report_groups'] != null && layoutConfigMap['report_groups'] is List) {
      var groupsList = layoutConfigMap['report_groups'] as List;
      groups = groupsList.map((g) => DashboardReportGroup.fromJson(g)).toList();
    }
    else if (layoutConfigMap['reports_on_dashboard'] != null && layoutConfigMap['reports_on_dashboard'] is List) {
      debugPrint("Migrating old dashboard format for dashboard ID: $dashboardId");
      final reportsJson = layoutConfigMap['reports_on_dashboard'] as List;
      final List<DashboardReportCardConfig> oldReports = reportsJson
          .map((rJson) => DashboardReportCardConfig.fromJson(rJson))
          .toList();
      if (oldReports.isNotEmpty) {
        groups.add(DashboardReportGroup(
          groupId: const Uuid().v4(),
          groupName: 'Reports',
          groupUrl: null,
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
      reportGroups: groups,
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