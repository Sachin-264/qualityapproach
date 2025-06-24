// lib/ReportDashboard/DashboardBloc/dashboard_builder_bloc.dart

import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart'; // Import uuid
import '../../ReportDynamic/ReportAPIService.dart';
import '../DashboardModel/dashboard_model.dart';

// NOTE: The DashboardReportGroup class should be in your dashboard_model.dart file.
// It is included here for completeness if you haven't moved it yet.
/*
class DashboardReportGroup extends Equatable { ... }
*/

// --- Events ---
abstract class DashboardBuilderEvent extends Equatable {
  const DashboardBuilderEvent();
  @override
  List<Object?> get props => [];
}

class LoadDashboardBuilderData extends DashboardBuilderEvent {
  final Dashboard? dashboardToEdit;
  const LoadDashboardBuilderData({this.dashboardToEdit});
  @override
  List<Object?> get props => [dashboardToEdit];
}

class UpdateDashboardInfo extends DashboardBuilderEvent {
  final String? dashboardName;
  final String? dashboardDescription;
  final String? templateId;
  final String? bannerUrl;
  final Color? accentColor;
  const UpdateDashboardInfo({
    this.dashboardName,
    this.dashboardDescription,
    this.templateId,
    this.bannerUrl,
    this.accentColor,
  });
  @override
  List<Object?> get props => [dashboardName, dashboardDescription, templateId, bannerUrl, accentColor];
}

// --- NEW GROUP EVENTS ---
class AddReportGroupEvent extends DashboardBuilderEvent {
  final String groupName;
  const AddReportGroupEvent(this.groupName);
  @override
  List<Object?> get props => [groupName];
}

class UpdateReportGroupEvent extends DashboardBuilderEvent {
  final String groupId;
  final String newName;
  const UpdateReportGroupEvent({required this.groupId, required this.newName});
  @override
  List<Object?> get props => [groupId, newName];
}

class RemoveReportGroupEvent extends DashboardBuilderEvent {
  final String groupId;
  const RemoveReportGroupEvent(this.groupId);
  @override
  List<Object?> get props => [groupId];
}

class ReorderGroupsEvent extends DashboardBuilderEvent {
  final int oldIndex;
  final int newIndex;
  const ReorderGroupsEvent(this.oldIndex, this.newIndex);
  @override
  List<Object?> get props => [oldIndex, newIndex];
}
// --- END NEW GROUP EVENTS ---


// --- MODIFIED REPORT EVENTS ---
class AddReportToDashboardEvent extends DashboardBuilderEvent {
  final String groupId; // <-- ADDED
  final Map<String, dynamic> reportDefinition;
  const AddReportToDashboardEvent({required this.groupId, required this.reportDefinition});
  @override
  List<Object?> get props => [groupId, reportDefinition];
}

class RemoveReportFromDashboardEvent extends DashboardBuilderEvent {
  final String groupId; // <-- ADDED
  final int reportRecNo;
  const RemoveReportFromDashboardEvent({required this.groupId, required this.reportRecNo});
  @override
  List<Object?> get props => [groupId, reportRecNo];
}

class UpdateReportCardConfigEvent extends DashboardBuilderEvent {
  final String groupId; // <-- ADDED
  final int reportRecNo;
  final String? displayTitle;
  final String? displaySubtitle;
  final IconData? displayIcon;
  final Color? displayColor;
  const UpdateReportCardConfigEvent({
    required this.groupId, // <-- ADDED
    required this.reportRecNo,
    this.displayTitle,
    this.displaySubtitle,
    this.displayIcon,
    this.displayColor,
  });
  @override
  List<Object?> get props => [groupId, reportRecNo, displayTitle, displaySubtitle, displayIcon, displayColor];
}

class ReorderReportsEvent extends DashboardBuilderEvent {
  final String groupId; // <-- ADDED
  final int oldIndex;
  final int newIndex;
  const ReorderReportsEvent({required this.groupId, required this.oldIndex, required this.newIndex});
  @override
  List<Object?> get props => [groupId, oldIndex, newIndex];
}
// --- END MODIFIED REPORT EVENTS ---


class SaveDashboardEvent extends DashboardBuilderEvent {
  const SaveDashboardEvent();
}

class DeleteDashboardEvent extends DashboardBuilderEvent {
  final String dashboardId;
  const DeleteDashboardEvent(this.dashboardId);
  @override
  List<Object?> get props => [dashboardId];
}

// --- States (No changes) ---
abstract class DashboardBuilderState extends Equatable {
  const DashboardBuilderState();
  @override
  List<Object?> get props => [];
}

class DashboardBuilderLoading extends DashboardBuilderState {
  const DashboardBuilderLoading();
}

class DashboardBuilderLoaded extends DashboardBuilderState {
  final Dashboard? currentDashboard;
  final List<Map<String, dynamic>> availableReports;
  final List<Dashboard> existingDashboards;
  final String? message;
  final String? error;

  const DashboardBuilderLoaded({
    this.currentDashboard,
    required this.availableReports,
    required this.existingDashboards,
    this.message,
    this.error,
  });

  DashboardBuilderLoaded copyWith({
    Dashboard? currentDashboard,
    List<Map<String, dynamic>>? availableReports,
    List<Dashboard>? existingDashboards,
    String? message,
    String? error,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return DashboardBuilderLoaded(
      currentDashboard: currentDashboard ?? this.currentDashboard,
      availableReports: availableReports ?? this.availableReports,
      existingDashboards: existingDashboards ?? this.existingDashboards,
      message: clearMessage ? null : message ?? this.message,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [currentDashboard, availableReports, existingDashboards, message, error];
}

class DashboardBuilderSaving extends DashboardBuilderState {
  final DashboardBuilderLoaded previousState;
  const DashboardBuilderSaving(this.previousState);
  @override
  List<Object?> get props => [previousState];
}

class DashboardBuilderErrorState extends DashboardBuilderState {
  final String message;
  const DashboardBuilderErrorState(this.message);
  @override
  List<Object> get props => [message];
}

// --- Bloc ---
class DashboardBuilderBloc extends Bloc<DashboardBuilderEvent, DashboardBuilderState> {
  final ReportAPIService apiService;
  final Uuid _uuid = const Uuid();

  DashboardBuilderBloc(this.apiService) : super(const DashboardBuilderLoading()) {
    on<LoadDashboardBuilderData>(_onLoadDashboardBuilderData);
    on<UpdateDashboardInfo>(_onUpdateDashboardInfo);
    on<AddReportGroupEvent>(_onAddReportGroup);
    on<UpdateReportGroupEvent>(_onUpdateReportGroup);
    on<RemoveReportGroupEvent>(_onRemoveReportGroup);
    on<ReorderGroupsEvent>(_onReorderGroups);
    on<AddReportToDashboardEvent>(_onAddReportToDashboard);
    on<RemoveReportFromDashboardEvent>(_onRemoveReportFromDashboard);
    on<UpdateReportCardConfigEvent>(_onUpdateReportCardConfig);
    on<ReorderReportsEvent>(_onReorderReports);
    on<SaveDashboardEvent>(_onSaveDashboard);
    on<DeleteDashboardEvent>(_onDeleteDashboard);
  }

  // --- Helper to get the current loaded state and dashboard ---
  (DashboardBuilderLoaded?, Dashboard?) _getCurrentStateAndDashboard() {
    final s = state;
    if (s is DashboardBuilderLoaded) {
      return (s, s.currentDashboard);
    }
    return (null, null);
  }

  Future<void> _onLoadDashboardBuilderData(
      LoadDashboardBuilderData event,
      Emitter<DashboardBuilderState> emit,
      ) async {
    emit(const DashboardBuilderLoading());
    try {
      final allReports = await apiService.fetchDemoTable();
      final allDashboardsData = await apiService.getDashboards();
      final allDashboards = allDashboardsData.map((item) => Dashboard.fromJson(item)).toList();

      Dashboard initialDashboard = event.dashboardToEdit ?? Dashboard(
        dashboardId: '', // Use empty string for new dashboard ID
        dashboardName: '',
        dashboardDescription: '',
        templateConfig: DashboardTemplateConfig(
          id: 'classicClean',
          name: 'Classic Clean',
          bannerUrl: null,
          accentColor: Colors.blue,
        ),
        // reportGroups is now an empty list
        reportGroups: [],
        globalFiltersConfig: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      emit(DashboardBuilderLoaded(
        currentDashboard: initialDashboard,
        availableReports: allReports,
        existingDashboards: allDashboards,
      ));
    } catch (e, stacktrace) {
      debugPrint('Error in _onLoadDashboardBuilderData: $e\n$stacktrace');
      emit(DashboardBuilderErrorState('Failed to load dashboard data: $e'));
    }
  }

  void _onUpdateDashboardInfo(
      UpdateDashboardInfo event,
      Emitter<DashboardBuilderState> emit,
      ) {
    final (currentState, currentDashboard) = _getCurrentStateAndDashboard();
    if (currentState == null || currentDashboard == null) return;

    String templateName = currentDashboard.templateConfig.name;
    if (event.templateId != null) {
      templateName = _getTemplateNameById(event.templateId!);
    }

    final updatedDashboard = currentDashboard.copyWith(
      dashboardName: event.dashboardName ?? currentDashboard.dashboardName,
      dashboardDescription: event.dashboardDescription ?? currentDashboard.dashboardDescription,
      templateConfig: currentDashboard.templateConfig.copyWith(
        id: event.templateId,
        name: templateName,
        bannerUrl: event.bannerUrl,
        accentColor: event.accentColor,
      ),
      updatedAt: DateTime.now(),
    );

    emit(currentState.copyWith(currentDashboard: updatedDashboard));
  }

  // --- NEW GROUP HANDLERS ---
  void _onAddReportGroup(AddReportGroupEvent event, Emitter<DashboardBuilderState> emit) {
    final (currentState, currentDashboard) = _getCurrentStateAndDashboard();
    if (currentState == null || currentDashboard == null) return;

    final newGroup = DashboardReportGroup(
      groupId: _uuid.v4(),
      groupName: event.groupName,
      reports: [],
    );

    final updatedGroups = List<DashboardReportGroup>.from(currentDashboard.reportGroups)..add(newGroup);
    emit(currentState.copyWith(
      currentDashboard: currentDashboard.copyWith(reportGroups: updatedGroups, updatedAt: DateTime.now()),
      message: 'Group added.',
      clearError: true,
    ));
  }

  void _onUpdateReportGroup(UpdateReportGroupEvent event, Emitter<DashboardBuilderState> emit) {
    final (currentState, currentDashboard) = _getCurrentStateAndDashboard();
    if (currentState == null || currentDashboard == null) return;

    final updatedGroups = currentDashboard.reportGroups.map((group) {
      if (group.groupId == event.groupId) {
        return group.copyWith(groupName: event.newName);
      }
      return group;
    }).toList();

    emit(currentState.copyWith(
      currentDashboard: currentDashboard.copyWith(reportGroups: updatedGroups, updatedAt: DateTime.now()),
    ));
  }

  void _onRemoveReportGroup(RemoveReportGroupEvent event, Emitter<DashboardBuilderState> emit) {
    final (currentState, currentDashboard) = _getCurrentStateAndDashboard();
    if (currentState == null || currentDashboard == null) return;

    final updatedGroups = List<DashboardReportGroup>.from(currentDashboard.reportGroups)
      ..removeWhere((group) => group.groupId == event.groupId);

    emit(currentState.copyWith(
      currentDashboard: currentDashboard.copyWith(reportGroups: updatedGroups, updatedAt: DateTime.now()),
      message: 'Group removed.',
      clearError: true,
    ));
  }

  void _onReorderGroups(ReorderGroupsEvent event, Emitter<DashboardBuilderState> emit) {
    final (currentState, currentDashboard) = _getCurrentStateAndDashboard();
    if (currentState == null || currentDashboard == null) return;

    final List<DashboardReportGroup> updatedGroups = List.from(currentDashboard.reportGroups);
    int newIndex = event.newIndex;
    if (newIndex > event.oldIndex) {
      newIndex--;
    }
    final DashboardReportGroup item = updatedGroups.removeAt(event.oldIndex);
    updatedGroups.insert(newIndex, item);

    emit(currentState.copyWith(
      currentDashboard: currentDashboard.copyWith(reportGroups: updatedGroups, updatedAt: DateTime.now()),
    ));
  }
  // --- END NEW GROUP HANDLERS ---


  void _onAddReportToDashboard(
      AddReportToDashboardEvent event,
      Emitter<DashboardBuilderState> emit,
      ) {
    final (currentState, currentDashboard) = _getCurrentStateAndDashboard();
    if (currentState == null || currentDashboard == null) return;

    final int? recNo = _safeParseInt(event.reportDefinition['RecNo']);
    if (recNo == null) return;

    // Check if report already exists anywhere on the dashboard
    final bool alreadyExists = currentDashboard.reportGroups
        .any((group) => group.reports.any((report) => report.reportRecNo == recNo));

    if (alreadyExists) {
      emit(currentState.copyWith(error: 'Report already added to dashboard.', clearMessage: true));
      return;
    }

    final newReportCard = DashboardReportCardConfig(
      reportRecNo: recNo,
      displayTitle: event.reportDefinition['Report_label'] ?? event.reportDefinition['Report_name'] ?? 'Report $recNo',
      displaySubtitle: event.reportDefinition['API_name'] ?? '',
      displayIcon: Icons.description,
      displayColor: currentDashboard.templateConfig.accentColor ?? Colors.blue,
    );

    final updatedGroups = currentDashboard.reportGroups.map((group) {
      if (group.groupId == event.groupId) {
        final updatedReports = List<DashboardReportCardConfig>.from(group.reports)..add(newReportCard);
        return group.copyWith(reports: updatedReports);
      }
      return group;
    }).toList();

    emit(currentState.copyWith(
      currentDashboard: currentDashboard.copyWith(reportGroups: updatedGroups, updatedAt: DateTime.now()),
      message: 'Report added.',
      clearError: true,
    ));
  }

  void _onRemoveReportFromDashboard(
      RemoveReportFromDashboardEvent event,
      Emitter<DashboardBuilderState> emit,
      ) {
    final (currentState, currentDashboard) = _getCurrentStateAndDashboard();
    if (currentState == null || currentDashboard == null) return;

    final updatedGroups = currentDashboard.reportGroups.map((group) {
      if (group.groupId == event.groupId) {
        final updatedReports = List<DashboardReportCardConfig>.from(group.reports)
          ..removeWhere((card) => card.reportRecNo == event.reportRecNo);
        return group.copyWith(reports: updatedReports);
      }
      return group;
    }).toList();

    emit(currentState.copyWith(
      currentDashboard: currentDashboard.copyWith(reportGroups: updatedGroups, updatedAt: DateTime.now()),
      message: 'Report removed.',
      clearError: true,
    ));
  }

  void _onUpdateReportCardConfig(
      UpdateReportCardConfigEvent event,
      Emitter<DashboardBuilderState> emit,
      ) {
    final (currentState, currentDashboard) = _getCurrentStateAndDashboard();
    if (currentState == null || currentDashboard == null) return;

    final updatedGroups = currentDashboard.reportGroups.map((group) {
      if (group.groupId == event.groupId) {
        final updatedReports = group.reports.map((card) {
          if (card.reportRecNo == event.reportRecNo) {
            return card.copyWith(
              displayTitle: event.displayTitle,
              displaySubtitle: event.displaySubtitle,
              displayIcon: event.displayIcon,
              displayColor: event.displayColor,
            );
          }
          return card;
        }).toList();
        return group.copyWith(reports: updatedReports);
      }
      return group;
    }).toList();

    emit(currentState.copyWith(
      currentDashboard: currentDashboard.copyWith(reportGroups: updatedGroups, updatedAt: DateTime.now()),
      clearError: true,
      clearMessage: true,
    ));
  }

  void _onReorderReports(
      ReorderReportsEvent event,
      Emitter<DashboardBuilderState> emit,
      ) {
    final (currentState, currentDashboard) = _getCurrentStateAndDashboard();
    if (currentState == null || currentDashboard == null) return;

    final updatedGroups = currentDashboard.reportGroups.map((group) {
      if (group.groupId == event.groupId) {
        final List<DashboardReportCardConfig> updatedReports = List.from(group.reports);
        int newIndex = event.newIndex;
        if (newIndex > event.oldIndex) {
          newIndex--;
        }
        final DashboardReportCardConfig item = updatedReports.removeAt(event.oldIndex);
        updatedReports.insert(newIndex, item);
        return group.copyWith(reports: updatedReports);
      }
      return group;
    }).toList();

    emit(currentState.copyWith(
      currentDashboard: currentDashboard.copyWith(reportGroups: updatedGroups, updatedAt: DateTime.now()),
    ));
  }

  Future<void> _onSaveDashboard(
      SaveDashboardEvent event,
      Emitter<DashboardBuilderState> emit,
      ) async {
    final (currentState, dashboardToSave) = _getCurrentStateAndDashboard();
    if (currentState == null || dashboardToSave == null) {
      if (currentState != null) emit(currentState.copyWith(error: 'No dashboard to save.'));
      return;
    }

    if (dashboardToSave.dashboardName.isEmpty) {
      emit(currentState.copyWith(error: 'Dashboard name cannot be empty.'));
      return;
    }
    emit(DashboardBuilderSaving(currentState));
    try {
      final layoutConfigPayload = {'report_groups': dashboardToSave.reportGroups.map((g) => g.toJson()).toList()};

      if (dashboardToSave.dashboardId.isEmpty) {
        final String newId = await apiService.saveDashboard(
          dashboardName: dashboardToSave.dashboardName,
          dashboardDescription: dashboardToSave.dashboardDescription,
          templateId: jsonEncode(dashboardToSave.templateConfig.toJson()),
          layoutConfig: layoutConfigPayload,
          globalFiltersConfig: dashboardToSave.globalFiltersConfig,
        );
        final savedDashboard = dashboardToSave.copyWith(
          dashboardId: newId,
          updatedAt: DateTime.now(),
        );
        emit(currentState.copyWith(currentDashboard: savedDashboard, message: 'Dashboard saved successfully!'));
      } else {
        await apiService.editDashboard(
          dashboardId: dashboardToSave.dashboardId,
          dashboardName: dashboardToSave.dashboardName,
          dashboardDescription: dashboardToSave.dashboardDescription,
          templateId: jsonEncode(dashboardToSave.templateConfig.toJson()),
          layoutConfig: layoutConfigPayload,
          globalFiltersConfig: dashboardToSave.globalFiltersConfig,
        );
        emit(currentState.copyWith(message: 'Dashboard updated successfully!'));
      }
    } catch (e) {
      emit(currentState.copyWith(error: 'Failed to save dashboard: $e'));
    }
  }

  Future<void> _onDeleteDashboard(
      DeleteDashboardEvent event,
      Emitter<DashboardBuilderState> emit,
      ) async {
    final (currentState, _) = _getCurrentStateAndDashboard();
    if (currentState == null) return;

    try {
      await apiService.deleteDashboard(dashboardId: event.dashboardId);
      final updatedDashboardsData = await apiService.getDashboards();
      final updatedDashboards = updatedDashboardsData.map((item) => Dashboard.fromJson(item)).toList();
      emit(currentState.copyWith(existingDashboards: updatedDashboards, message: 'Dashboard deleted.'));
    } catch (e) {
      emit(currentState.copyWith(error: 'Failed to delete dashboard: $e'));
    }
  }

  String _getTemplateNameById(String id) {
    switch (id) {
      case 'classicClean': return 'Classic Clean';
      case 'modernMinimal': return 'Modern Minimal';
      case 'vibrantBold': return 'Vibrant & Bold';
      default: return 'Unknown Template';
    }
  }

  int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }
}