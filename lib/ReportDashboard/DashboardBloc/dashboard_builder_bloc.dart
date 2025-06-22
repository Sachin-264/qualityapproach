// lib/ReportDashboard/DashboardBloc/dashboard_builder_bloc.dart

import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../ReportDynamic/ReportAPIService.dart';
import '../DashboardModel/dashboard_model.dart';

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

class AddReportToDashboardEvent extends DashboardBuilderEvent {
  final Map<String, dynamic> reportDefinition;
  const AddReportToDashboardEvent(this.reportDefinition);
  @override
  List<Object?> get props => [reportDefinition];
}

class RemoveReportFromDashboardEvent extends DashboardBuilderEvent {
  final int reportRecNo;
  const RemoveReportFromDashboardEvent(this.reportRecNo);
  @override
  List<Object?> get props => [reportRecNo];
}

class UpdateReportCardConfigEvent extends DashboardBuilderEvent {
  final int reportRecNo;
  final String? displayTitle;
  final String? displaySubtitle;
  final IconData? displayIcon;
  final Color? displayColor;
  const UpdateReportCardConfigEvent({
    required this.reportRecNo,
    this.displayTitle,
    this.displaySubtitle,
    this.displayIcon,
    this.displayColor,
  });
  @override
  List<Object?> get props => [reportRecNo, displayTitle, displaySubtitle, displayIcon, displayColor];
}

class ReorderReportsEvent extends DashboardBuilderEvent {
  final int oldIndex;
  final int newIndex;
  const ReorderReportsEvent(this.oldIndex, this.newIndex);
  @override
  List<Object?> get props => [oldIndex, newIndex];
}

class SaveDashboardEvent extends DashboardBuilderEvent {
  const SaveDashboardEvent();
}

class DeleteDashboardEvent extends DashboardBuilderEvent {
  // *** FIX: dashboardId is a String ***
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
  }) {
    return DashboardBuilderLoaded(
      currentDashboard: currentDashboard ?? this.currentDashboard,
      availableReports: availableReports ?? this.availableReports,
      existingDashboards: existingDashboards ?? this.existingDashboards,
      message: message,
      error: error,
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

  DashboardBuilderBloc(this.apiService) : super(const DashboardBuilderLoading()) {
    on<LoadDashboardBuilderData>(_onLoadDashboardBuilderData);
    on<UpdateDashboardInfo>(_onUpdateDashboardInfo);
    on<AddReportToDashboardEvent>(_onAddReportToDashboard);
    on<RemoveReportFromDashboardEvent>(_onRemoveReportFromDashboard);
    on<UpdateReportCardConfigEvent>(_onUpdateReportCardConfig);
    on<ReorderReportsEvent>(_onReorderReports);
    on<SaveDashboardEvent>(_onSaveDashboard);
    on<DeleteDashboardEvent>(_onDeleteDashboard);
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
      Dashboard? initialDashboard;
      if (event.dashboardToEdit != null) {
        initialDashboard = event.dashboardToEdit;
      } else {
        initialDashboard = Dashboard(
          dashboardId: '', // Use empty string for new dashboard ID
          dashboardName: '',
          dashboardDescription: '',
          templateConfig: DashboardTemplateConfig(
            id: 'classicClean',
            name: 'Classic Clean',
            bannerUrl: null,
            accentColor: Colors.blue,
          ),
          reportsOnDashboard: [],
          globalFiltersConfig: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
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
    if (state is DashboardBuilderLoaded) {
      final currentState = state as DashboardBuilderLoaded;
      final currentDashboard = currentState.currentDashboard;
      if (currentDashboard != null) {
        String templateName = currentDashboard.templateConfig.name;
        if (event.templateId != null) {
          templateName = _getTemplateNameById(event.templateId!);
        }
        final updatedTemplateConfig = DashboardTemplateConfig(
          id: event.templateId ?? currentDashboard.templateConfig.id,
          name: templateName,
          bannerUrl: event.bannerUrl ?? currentDashboard.templateConfig.bannerUrl,
          accentColor: event.accentColor ?? currentDashboard.templateConfig.accentColor,
        );
        final updatedDashboard = Dashboard(
          dashboardId: currentDashboard.dashboardId,
          dashboardName: event.dashboardName ?? currentDashboard.dashboardName,
          dashboardDescription: event.dashboardDescription ?? currentDashboard.dashboardDescription,
          templateConfig: updatedTemplateConfig,
          reportsOnDashboard: currentDashboard.reportsOnDashboard,
          globalFiltersConfig: currentDashboard.globalFiltersConfig,
          createdAt: currentDashboard.createdAt,
          updatedAt: DateTime.now(),
        );
        emit(currentState.copyWith(currentDashboard: updatedDashboard));
      }
    }
  }

  void _onAddReportToDashboard(
      AddReportToDashboardEvent event,
      Emitter<DashboardBuilderState> emit,
      ) {
    if (state is DashboardBuilderLoaded) {
      final currentState = state as DashboardBuilderLoaded;
      final currentDashboard = currentState.currentDashboard;
      if (currentDashboard != null) {
        final int? recNo = _safeParseInt(event.reportDefinition['RecNo']);
        if (recNo != null && !currentDashboard.reportsOnDashboard.any((card) => card.reportRecNo == recNo)) {
          final newReportCard = DashboardReportCardConfig(
            reportRecNo: recNo,
            displayTitle: event.reportDefinition['Report_label'] ?? event.reportDefinition['Report_name'] ?? 'Report $recNo',
            displaySubtitle: event.reportDefinition['API_name'] ?? '',
            displayIcon: Icons.description,
            displayColor: currentDashboard.templateConfig.accentColor ?? Colors.blue,
          );
          final updatedReports = List<DashboardReportCardConfig>.from(currentDashboard.reportsOnDashboard)..add(newReportCard);
          final updatedDashboard = Dashboard(
            dashboardId: currentDashboard.dashboardId,
            dashboardName: currentDashboard.dashboardName,
            dashboardDescription: currentDashboard.dashboardDescription,
            templateConfig: currentDashboard.templateConfig,
            reportsOnDashboard: updatedReports,
            globalFiltersConfig: currentDashboard.globalFiltersConfig,
            createdAt: currentDashboard.createdAt,
            updatedAt: DateTime.now(),
          );
          emit(currentState.copyWith(currentDashboard: updatedDashboard, message: 'Report added.'));
        } else if (recNo != null) {
          emit(currentState.copyWith(error: 'Report already added to dashboard.'));
        }
      }
    }
  }

  void _onRemoveReportFromDashboard(
      RemoveReportFromDashboardEvent event,
      Emitter<DashboardBuilderState> emit,
      ) {
    if (state is DashboardBuilderLoaded) {
      final currentState = state as DashboardBuilderLoaded;
      final currentDashboard = currentState.currentDashboard;
      if (currentDashboard != null) {
        final updatedReports = List<DashboardReportCardConfig>.from(currentDashboard.reportsOnDashboard)..removeWhere((card) => card.reportRecNo == event.reportRecNo);
        final updatedDashboard = Dashboard(
          dashboardId: currentDashboard.dashboardId,
          dashboardName: currentDashboard.dashboardName,
          dashboardDescription: currentDashboard.dashboardDescription,
          templateConfig: currentDashboard.templateConfig,
          reportsOnDashboard: updatedReports,
          globalFiltersConfig: currentDashboard.globalFiltersConfig,
          createdAt: currentDashboard.createdAt,
          updatedAt: DateTime.now(),
        );
        emit(currentState.copyWith(currentDashboard: updatedDashboard, message: 'Report removed.'));
      }
    }
  }

  void _onUpdateReportCardConfig(
      UpdateReportCardConfigEvent event,
      Emitter<DashboardBuilderState> emit,
      ) {
    if (state is DashboardBuilderLoaded) {
      final currentState = state as DashboardBuilderLoaded;
      final currentDashboard = currentState.currentDashboard;
      if (currentDashboard != null) {
        final updatedReports = currentDashboard.reportsOnDashboard.map((card) {
          if (card.reportRecNo == event.reportRecNo) {
            return DashboardReportCardConfig(
              reportRecNo: card.reportRecNo,
              displayTitle: event.displayTitle ?? card.displayTitle,
              displaySubtitle: event.displaySubtitle ?? card.displaySubtitle,
              displayIcon: event.displayIcon ?? card.displayIcon,
              displayColor: event.displayColor ?? card.displayColor,
            );
          }
          return card;
        }).toList();
        final updatedDashboard = Dashboard(
          dashboardId: currentDashboard.dashboardId,
          dashboardName: currentDashboard.dashboardName,
          dashboardDescription: currentDashboard.dashboardDescription,
          templateConfig: currentDashboard.templateConfig,
          reportsOnDashboard: updatedReports,
          globalFiltersConfig: currentDashboard.globalFiltersConfig,
          createdAt: currentDashboard.createdAt,
          updatedAt: DateTime.now(),
        );
        emit(currentState.copyWith(currentDashboard: updatedDashboard));
      }
    }
  }

  void _onReorderReports(
      ReorderReportsEvent event,
      Emitter<DashboardBuilderState> emit,
      ) {
    if (state is DashboardBuilderLoaded) {
      final currentState = state as DashboardBuilderLoaded;
      final currentDashboard = currentState.currentDashboard;
      if (currentDashboard != null) {
        final List<DashboardReportCardConfig> updatedReports = List.from(currentDashboard.reportsOnDashboard);
        int newIndex = event.newIndex;
        if (newIndex > event.oldIndex) {
          newIndex--;
        }
        final DashboardReportCardConfig item = updatedReports.removeAt(event.oldIndex);
        updatedReports.insert(newIndex, item);
        final updatedDashboard = Dashboard(
          dashboardId: currentDashboard.dashboardId,
          dashboardName: currentDashboard.dashboardName,
          dashboardDescription: currentDashboard.dashboardDescription,
          templateConfig: currentDashboard.templateConfig,
          reportsOnDashboard: updatedReports,
          globalFiltersConfig: currentDashboard.globalFiltersConfig,
          createdAt: currentDashboard.createdAt,
          updatedAt: DateTime.now(),
        );
        emit(currentState.copyWith(currentDashboard: updatedDashboard, message: 'Reports reordered.'));
      }
    }
  }

  Future<void> _onSaveDashboard(
      SaveDashboardEvent event,
      Emitter<DashboardBuilderState> emit,
      ) async {
    if (state is DashboardBuilderLoaded) {
      final currentState = state as DashboardBuilderLoaded;
      final dashboardToSave = currentState.currentDashboard;
      if (dashboardToSave == null) {
        emit(currentState.copyWith(error: 'No dashboard to save.'));
        return;
      }
      if (dashboardToSave.dashboardName.isEmpty) {
        emit(currentState.copyWith(error: 'Dashboard name cannot be empty.'));
        return;
      }
      emit(DashboardBuilderSaving(currentState));
      try {
        if (dashboardToSave.dashboardId.isEmpty) {
          // *** FIX: Expect a String ID back ***
          final String newId = await apiService.saveDashboard(
            dashboardName: dashboardToSave.dashboardName,
            dashboardDescription: dashboardToSave.dashboardDescription,
            templateId: jsonEncode(dashboardToSave.templateConfig.toJson()),
            layoutConfig: {'reports_on_dashboard': dashboardToSave.reportsOnDashboard.map((c) => c.toJson()).toList()},
            globalFiltersConfig: dashboardToSave.globalFiltersConfig,
          );
          final savedDashboard = Dashboard(
            dashboardId: newId,
            dashboardName: dashboardToSave.dashboardName,
            dashboardDescription: dashboardToSave.dashboardDescription,
            templateConfig: dashboardToSave.templateConfig,
            reportsOnDashboard: dashboardToSave.reportsOnDashboard,
            globalFiltersConfig: dashboardToSave.globalFiltersConfig,
            createdAt: dashboardToSave.createdAt,
            updatedAt: DateTime.now(),
          );
          emit(currentState.copyWith(currentDashboard: savedDashboard, message: 'Dashboard saved successfully!'));
        } else {
          // *** FIX: Pass the String ID ***
          await apiService.editDashboard(
            dashboardId: dashboardToSave.dashboardId,
            dashboardName: dashboardToSave.dashboardName,
            dashboardDescription: dashboardToSave.dashboardDescription,
            templateId: jsonEncode(dashboardToSave.templateConfig.toJson()),
            layoutConfig: {'reports_on_dashboard': dashboardToSave.reportsOnDashboard.map((c) => c.toJson()).toList()},
            globalFiltersConfig: dashboardToSave.globalFiltersConfig,
          );
          emit(currentState.copyWith(message: 'Dashboard updated successfully!'));
        }
      } catch (e) {
        emit(currentState.copyWith(error: 'Failed to save dashboard: $e'));
      }
    }
  }

  Future<void> _onDeleteDashboard(
      DeleteDashboardEvent event,
      Emitter<DashboardBuilderState> emit,
      ) async {
    if (state is DashboardBuilderLoaded) {
      final currentState = state as DashboardBuilderLoaded;
      try {
        // *** FIX: Pass the String ID ***
        await apiService.deleteDashboard(dashboardId: event.dashboardId);
        final updatedDashboardsData = await apiService.getDashboards();
        final updatedDashboards = updatedDashboardsData.map((item) => Dashboard.fromJson(item)).toList();
        emit(currentState.copyWith(existingDashboards: updatedDashboards, message: 'Dashboard deleted.'));
      } catch (e) {
        emit(currentState.copyWith(error: 'Failed to delete dashboard: $e'));
      }
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