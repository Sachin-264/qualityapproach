// lib/ReportDashboard/DashboardBloc/dashboard_builder_bloc.dart

import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../ReportDynamic/ReportAPIService.dart';
import '../DashboardModel/dashboard_model.dart';

// --- Events ---
abstract class DashboardBuilderEvent extends Equatable {
  const DashboardBuilderEvent();
  @override
  List<Object?> get props => [];
}

// Specifically for fetching the list of dashboards for the listing screen.
class FetchDashboardList extends DashboardBuilderEvent {
  const FetchDashboardList();
}

// This event is now ONLY for loading an existing dashboard to edit.
class LoadDashboardBuilderData extends DashboardBuilderEvent {
  final Dashboard dashboardToEdit;
  const LoadDashboardBuilderData({required this.dashboardToEdit});
  @override
  List<Object?> get props => [dashboardToEdit];
}

// Triggered after the user selects a database for a new dashboard.
class InitializeNewDashboard extends DashboardBuilderEvent {
  final Map<String, dynamic> dbConnectionConfig;
  const InitializeNewDashboard({required this.dbConnectionConfig});
  @override
  List<Object?> get props => [dbConnectionConfig];
}


class UpdateDashboardInfo extends DashboardBuilderEvent {
  final String? dashboardName;
  final String? dashboardDescription;
  final String? templateId;
  final Color? accentColor;
  const UpdateDashboardInfo({
    this.dashboardName,
    this.dashboardDescription,
    this.templateId,
    this.accentColor,
  });
  @override
  List<Object?> get props => [dashboardName, dashboardDescription, templateId, accentColor];
}

class AddReportGroupEvent extends DashboardBuilderEvent {
  final String groupName;
  final String? url;
  const AddReportGroupEvent(this.groupName, {this.url});
  @override
  List<Object?> get props => [groupName, url];
}

class UpdateReportGroupEvent extends DashboardBuilderEvent {
  final String groupId;
  final String newName;
  final String? newUrl;
  const UpdateReportGroupEvent({required this.groupId, required this.newName, this.newUrl});
  @override
  List<Object?> get props => [groupId, newName, newUrl];
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

class AddReportToDashboardEvent extends DashboardBuilderEvent {
  final String groupId;
  final Map<String, dynamic> reportDefinition;
  final String? apiUrl;
  const AddReportToDashboardEvent({required this.groupId, required this.reportDefinition, this.apiUrl});
  @override
  List<Object?> get props => [groupId, reportDefinition, apiUrl];
}

class RemoveReportFromDashboardEvent extends DashboardBuilderEvent {
  final String groupId;
  final int reportRecNo;
  const RemoveReportFromDashboardEvent({required this.groupId, required this.reportRecNo});
  @override
  List<Object?> get props => [groupId, reportRecNo];
}

class UpdateReportCardConfigEvent extends DashboardBuilderEvent {
  final String groupId;
  final int reportRecNo;
  final String newTitle;
  final String? newSubtitle;
  final IconData newIcon;
  final Color newColor;
  final String? newApiUrl;
  final bool newShowAsTile;
  final bool newShowAsGraph;
  final GraphType? newGraphType;

  const UpdateReportCardConfigEvent({
    required this.groupId,
    required this.reportRecNo,
    required this.newTitle,
    this.newSubtitle,
    required this.newIcon,
    required this.newColor,
    this.newApiUrl,
    required this.newShowAsTile,
    required this.newShowAsGraph,
    this.newGraphType,
  });
  @override
  List<Object?> get props => [groupId, reportRecNo, newTitle, newSubtitle, newIcon, newColor, newApiUrl, newShowAsTile, newShowAsGraph, newGraphType];
}

class ReorderReportsEvent extends DashboardBuilderEvent {
  final String groupId;
  final int oldIndex;
  final int newIndex;
  const ReorderReportsEvent({required this.groupId, required this.oldIndex, required this.newIndex});
  @override
  List<Object?> get props => [groupId, oldIndex, newIndex];
}

class SaveDashboardEvent extends DashboardBuilderEvent {
  const SaveDashboardEvent();
}

class DeleteDashboardEvent extends DashboardBuilderEvent {
  final String dashboardId;
  const DeleteDashboardEvent(this.dashboardId);
  @override
  List<Object?> get props => [dashboardId];
}

// --- States ---
abstract class DashboardBuilderState extends Equatable {
  const DashboardBuilderState();
  @override
  List<Object?> get props => [];
}

class DashboardBuilderInitial extends DashboardBuilderState {
  const DashboardBuilderInitial();
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

  DashboardBuilderBloc(this.apiService) : super(const DashboardBuilderInitial()) {
    on<FetchDashboardList>(_onFetchDashboardList);
    on<LoadDashboardBuilderData>(_onLoadDashboardBuilderData);
    on<InitializeNewDashboard>(_onInitializeNewDashboard);
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

  (DashboardBuilderLoaded?, Dashboard?) _getCurrentStateAndDashboard() {
    final s = state;
    if (s is DashboardBuilderLoaded) {
      return (s, s.currentDashboard);
    }
    return (null, null);
  }

  Future<void> _onFetchDashboardList(
      FetchDashboardList event,
      Emitter<DashboardBuilderState> emit,
      ) async {
    emit(const DashboardBuilderLoading());
    try {
      final allDashboardsData = await apiService.getDashboards();
      final allDashboards = allDashboardsData.map((item) => Dashboard.fromJson(item)).toList();

      emit(DashboardBuilderLoaded(
        existingDashboards: allDashboards,
        availableReports: const [], // Not needed for the listing screen
        currentDashboard: null, // No dashboard is being edited
      ));
    } catch (e, stacktrace) {
      debugPrint('[DashboardBuilderBloc] Error in _onFetchDashboardList: $e\n$stacktrace');
      emit(DashboardBuilderErrorState('Failed to load dashboard list: $e'));
    }
  }


  Future<void> _onInitializeNewDashboard(
      InitializeNewDashboard event,
      Emitter<DashboardBuilderState> emit,
      ) async {
    debugPrint('[DashboardBuilderBloc] Initializing new dashboard...');
    emit(const DashboardBuilderLoading());
    try {
      final String? databaseName = event.dbConnectionConfig['database'];
      debugPrint('[DashboardBuilderBloc] -> For database: $databaseName');
      if (databaseName == null || databaseName.isEmpty) {
        throw Exception("Database name is missing from the connection configuration.");
      }

      final availableReports = await apiService.fetchReportsForApi(databaseName);
      final allDashboardsData = await apiService.getDashboards();
      final allDashboards = allDashboardsData.map((item) => Dashboard.fromJson(item)).toList();
      debugPrint('[DashboardBuilderBloc] -> Fetched ${availableReports.length} available reports and ${allDashboards.length} existing dashboards.');

      Dashboard initialDashboard = Dashboard(
        dashboardId: '',
        dashboardName: '',
        dashboardDescription: '',
        templateConfig: DashboardTemplateConfig(
          id: 'classicClean',
          name: 'Classic Clean',
          accentColor: Colors.blue,
        ),
        reportGroups: [],
        globalFiltersConfig: {
          'db_connection': event.dbConnectionConfig,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      emit(DashboardBuilderLoaded(
        currentDashboard: initialDashboard,
        availableReports: availableReports,
        existingDashboards: allDashboards,
      ));
    } catch (e, stacktrace) {
      debugPrint('[DashboardBuilderBloc] Error in _onInitializeNewDashboard: $e\n$stacktrace');
      emit(DashboardBuilderErrorState('Failed to initialize new dashboard: $e'));
    }
  }

  Future<void> _onLoadDashboardBuilderData(
      LoadDashboardBuilderData event,
      Emitter<DashboardBuilderState> emit,
      ) async {
    debugPrint('[DashboardBuilderBloc] Loading existing dashboard for editing: "${event.dashboardToEdit.dashboardName}" (ID: ${event.dashboardToEdit.dashboardId})');
    emit(const DashboardBuilderLoading());
    try {
      final dbConnectionConfig = event.dashboardToEdit.globalFiltersConfig['db_connection'];
      if (dbConnectionConfig is! Map<String, dynamic>) {
        throw Exception("Invalid or missing database connection configuration in the saved dashboard.");
      }

      final String? databaseName = dbConnectionConfig['database'];
      debugPrint('[DashboardBuilderBloc] -> Associated database: $databaseName');
      if (databaseName == null || databaseName.isEmpty) {
        throw Exception("Database name is missing from the dashboard's connection configuration.");
      }

      final availableReports = await apiService.fetchReportsForApi(databaseName);
      final allDashboardsData = await apiService.getDashboards();
      final allDashboards = allDashboardsData.map((item) => Dashboard.fromJson(item)).toList();
      debugPrint('[DashboardBuilderBloc] -> Fetched ${availableReports.length} available reports and ${allDashboards.length} existing dashboards.');


      emit(DashboardBuilderLoaded(
        currentDashboard: event.dashboardToEdit,
        availableReports: availableReports,
        existingDashboards: allDashboards,
      ));
    } catch (e, stacktrace) {
      debugPrint('[DashboardBuilderBloc] Error in _onLoadDashboardBuilderData: $e\n$stacktrace');
      emit(DashboardBuilderErrorState('Failed to load dashboard data for editing: $e'));
    }
  }

  void _onUpdateDashboardInfo(
      UpdateDashboardInfo event,
      Emitter<DashboardBuilderState> emit,
      ) {
    final (currentState, currentDashboard) = _getCurrentStateAndDashboard();
    if (currentState == null || currentDashboard == null) return;

    debugPrint('[DashboardBuilderBloc] Updating dashboard info: name=${event.dashboardName}, template=${event.templateId}');

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
        accentColor: event.accentColor,
      ),
      updatedAt: DateTime.now(),
    );

    emit(currentState.copyWith(currentDashboard: updatedDashboard));
  }

  void _onAddReportGroup(AddReportGroupEvent event, Emitter<DashboardBuilderState> emit) {
    final (currentState, currentDashboard) = _getCurrentStateAndDashboard();
    if (currentState == null || currentDashboard == null) return;

    debugPrint('[DashboardBuilderBloc] Adding new report group: "${event.groupName}"');

    final newGroup = DashboardReportGroup(
      groupId: _uuid.v4(),
      groupName: event.groupName,
      groupUrl: event.url,
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

    debugPrint('[DashboardBuilderBloc] Updating group "${event.groupId}" to name "${event.newName}"');

    final updatedGroups = currentDashboard.reportGroups.map((group) {
      if (group.groupId == event.groupId) {
        return group.copyWith(
          groupName: event.newName,
          groupUrl: event.newUrl,
        );
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

    debugPrint('[DashboardBuilderBloc] Removing group: "${event.groupId}"');

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

  void _onAddReportToDashboard(
      AddReportToDashboardEvent event,
      Emitter<DashboardBuilderState> emit,
      ) {
    final (currentState, currentDashboard) = _getCurrentStateAndDashboard();
    if (currentState == null || currentDashboard == null) return;

    final int? recNo = _safeParseInt(event.reportDefinition['RecNo']);
    debugPrint('[DashboardBuilderBloc] Attempting to add report RecNo: $recNo to group: ${event.groupId}');
    if (recNo == null) {
      debugPrint('[DashboardBuilderBloc] -> FAILED: RecNo is null.');
      return;
    }

    final bool alreadyExists = currentDashboard.reportGroups
        .any((group) => group.reports.any((report) => report.reportRecNo == recNo));

    if (alreadyExists) {
      debugPrint('[DashboardBuilderBloc] -> FAILED: Report already exists in the dashboard.');
      emit(currentState.copyWith(error: 'Report already added to dashboard.', clearMessage: true));
      return;
    }

    final newReportCard = DashboardReportCardConfig(
      reportRecNo: recNo,
      displayTitle: event.reportDefinition['Report_label'] ?? event.reportDefinition['Report_name'] ?? 'Report $recNo',
      displaySubtitle: event.reportDefinition['API_name'] ?? '',
      displayIcon: Icons.description,
      displayColor: currentDashboard.templateConfig.accentColor ?? Colors.blue,
      apiUrl: event.apiUrl,
      showAsTile: true,
      showAsGraph: false,
      graphType: null,
    );

    final updatedGroups = currentDashboard.reportGroups.map((group) {
      if (group.groupId == event.groupId) {
        final updatedReports = List<DashboardReportCardConfig>.from(group.reports)..add(newReportCard);
        return group.copyWith(reports: updatedReports);
      }
      return group;
    }).toList();

    debugPrint('[DashboardBuilderBloc] -> SUCCESS: Report card added.');
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

    debugPrint('[DashboardBuilderBloc] Removing report RecNo: ${event.reportRecNo} from group ${event.groupId}');

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

    debugPrint('[DashboardBuilderBloc] Updating card config for RecNo ${event.reportRecNo}. New settings: showAsGraph=${event.newShowAsGraph}, graphType=${event.newGraphType}');

    final updatedGroups = currentDashboard.reportGroups.map((group) {
      if (group.groupId == event.groupId) {
        final updatedReports = group.reports.map((card) {
          if (card.reportRecNo == event.reportRecNo) {
            return card.copyWith(
              displayTitle: event.newTitle,
              displaySubtitle: event.newSubtitle,
              displayIcon: event.newIcon,
              displayColor: event.newColor,
              apiUrl: event.newApiUrl,
              showAsTile: event.newShowAsTile,
              showAsGraph: event.newShowAsGraph,
              graphType: event.newGraphType,
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
      debugPrint('[DashboardBuilderBloc] Save aborted: Current state is invalid.');
      if (state is DashboardBuilderLoaded) {
        emit((state as DashboardBuilderLoaded).copyWith(error: 'No dashboard to save.'));
      }
      return;
    }
    debugPrint('[DashboardBuilderBloc] Attempting to save dashboard: "${dashboardToSave.dashboardName}"');

    if (dashboardToSave.dashboardName.isEmpty) {
      debugPrint('[DashboardBuilderBloc] -> FAILED: Dashboard name is empty.');
      emit(currentState.copyWith(error: 'Dashboard name cannot be empty.'));
      return;
    }
    emit(DashboardBuilderSaving(currentState));
    try {
      final layoutConfigPayload = {'report_groups': dashboardToSave.reportGroups.map((g) => g.toJson()).toList()};
      final templateConfigPayload = jsonEncode(dashboardToSave.templateConfig.toJson());

      debugPrint('[DashboardBuilderBloc] -> Is new dashboard? ${dashboardToSave.dashboardId.isEmpty}');
      debugPrint('[DashboardBuilderBloc] -> Payload (Template): $templateConfigPayload');
      debugPrint('[DashboardBuilderBloc] -> Payload (Layout): ${jsonEncode(layoutConfigPayload)}');


      if (dashboardToSave.dashboardId.isEmpty) {
        // Saving a NEW dashboard
        final String newId = await apiService.saveDashboard(
          dashboardName: dashboardToSave.dashboardName,
          dashboardDescription: dashboardToSave.dashboardDescription,
          templateId: templateConfigPayload, // Sending full template config
          layoutConfig: layoutConfigPayload,
          globalFiltersConfig: dashboardToSave.globalFiltersConfig,
        );
        debugPrint('[DashboardBuilderBloc] -> SUCCESS: New dashboard created with ID: $newId');
        final savedDashboard = dashboardToSave.copyWith(
          dashboardId: newId,
          updatedAt: DateTime.now(),
        );
        final previousState = (state as DashboardBuilderSaving).previousState;
        emit(previousState.copyWith(
            currentDashboard: savedDashboard,
            message: 'Dashboard saved successfully!'
        ));
      } else {
        // Editing an EXISTING dashboard
        await apiService.editDashboard(
          dashboardId: dashboardToSave.dashboardId,
          dashboardName: dashboardToSave.dashboardName,
          dashboardDescription: dashboardToSave.dashboardDescription,
          templateId: templateConfigPayload, // Sending full template config
          layoutConfig: layoutConfigPayload,
          globalFiltersConfig: dashboardToSave.globalFiltersConfig,
        );
        debugPrint('[DashboardBuilderBloc] -> SUCCESS: Dashboard updated.');
        final previousState = (state as DashboardBuilderSaving).previousState;
        emit(previousState.copyWith(message: 'Dashboard updated successfully!'));
      }
    } catch (e, stacktrace) {
      debugPrint('[DashboardBuilderBloc] !!! FAILED to save dashboard: $e\n$stacktrace');
      final previousState = (state as DashboardBuilderSaving).previousState;
      emit(previousState.copyWith(error: 'Failed to save dashboard: $e'));
    }
  }

  Future<void> _onDeleteDashboard(
      DeleteDashboardEvent event,
      Emitter<DashboardBuilderState> emit,
      ) async {
    final (currentState, _) = _getCurrentStateAndDashboard();
    if (currentState == null) return;
    debugPrint('[DashboardBuilderBloc] Deleting dashboard with ID: ${event.dashboardId}');

    try {
      await apiService.deleteDashboard(dashboardId: event.dashboardId);
      final updatedDashboardsData = await apiService.getDashboards();
      final updatedDashboards = updatedDashboardsData.map((item) => Dashboard.fromJson(item)).toList();
      emit(currentState.copyWith(existingDashboards: updatedDashboards, message: 'Dashboard deleted.'));
      debugPrint('[DashboardBuilderBloc] -> SUCCESS: Dashboard deleted.');
    } catch (e, stacktrace) {
      debugPrint('[DashboardBuilderBloc] !!! FAILED to delete dashboard: $e\n$stacktrace');
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