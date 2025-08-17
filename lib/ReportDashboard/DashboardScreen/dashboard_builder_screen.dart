// lib/ReportDashboard/DashboardScreen/dashboard_builder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

import '../../ReportDynamic/ReportAPIService.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../DashboardBloc/dashboard_builder_bloc.dart';
import '../DashboardModel/dashboard_model.dart';
import '../dashboardWidget/dashboard_colour_picker.dart';
import '../dashboardWidget/dashboard_icon_picker.dart';

// Helper to build the inviting "Add Report" placeholder for empty groups
Widget _buildEmptyGroupPlaceholder(BuildContext context, VoidCallback onTap) {
  final theme = Theme.of(context);
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_circle_outline_rounded,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Add Your First Report',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap here to select a report for this group.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ),
  );
}


int? _safeParseInt(dynamic value) { if (value == null) return null; if (value is int) return value; if (value is String) return int.tryParse(value); if (value is num) return value.toInt(); return null; }

enum DashboardTemplateOption { classicClean, modernMinimal, vibrantBold, }

extension DashboardTemplateOptionExtension on DashboardTemplateOption {
  String get id => toString().split('.').last;
  String get name {
    switch (this) {
      case DashboardTemplateOption.classicClean: return 'Classic Clean';
      case DashboardTemplateOption.modernMinimal: return 'Modern Minimal';
      case DashboardTemplateOption.vibrantBold: return 'Vibrant & Bold';
    }
  }
  Color get defaultAccentColor {
    switch (this) {
      case DashboardTemplateOption.classicClean: return Colors.blue;
      case DashboardTemplateOption.modernMinimal: return Colors.grey;
      case DashboardTemplateOption.vibrantBold: return Colors.deepOrange;
    }
  }
}

class DashboardBuilderScreen extends StatefulWidget {
  final ReportAPIService apiService;
  final Dashboard? dashboardToEdit;

  const DashboardBuilderScreen({
    Key? key,
    required this.apiService,
    this.dashboardToEdit,
  }) : super(key: key);

  @override
  State<DashboardBuilderScreen> createState() => _DashboardBuilderScreenState();
}

class _DashboardBuilderScreenState extends State<DashboardBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  DashboardTemplateOption? _selectedTemplateOption;
  Color? _currentAccentColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();

    if (widget.dashboardToEdit != null) {
      final dashboard = widget.dashboardToEdit!;
      _nameController.text = dashboard.dashboardName;
      _descriptionController.text = dashboard.dashboardDescription ?? '';
      _currentAccentColor = dashboard.templateConfig.accentColor;
      _selectedTemplateOption = DashboardTemplateOption.values.firstWhereOrNull(
            (e) => e.id == dashboard.templateConfig.id,
      ) ?? DashboardTemplateOption.classicClean;
      context.read<DashboardBuilderBloc>().add(LoadDashboardBuilderData(dashboardToEdit: dashboard));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptForDatabase());
    }
  }

  Future<void> _promptForDatabase() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SelectDatabaseDialog(apiService: widget.apiService),
    );

    if (result != null && mounted) {
      context.read<DashboardBuilderBloc>().add(InitializeNewDashboard(dbConnectionConfig: result));
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green));
    }
  }

  void _showCardCustomizationDialog(DashboardReportCardConfig cardConfig, String groupId) async {
    final titleController = TextEditingController(text: cardConfig.displayTitle);
    final subtitleController = TextEditingController(text: cardConfig.displaySubtitle);
    final apiUrlController = TextEditingController(text: cardConfig.apiUrl);

    IconData selectedIcon = cardConfig.displayIcon ?? Icons.article;
    Color selectedColor = cardConfig.displayColor ?? Colors.grey;
    GraphType? selectedGraphType = cardConfig.graphType ?? GraphType.bar;
    bool showAsTile = cardConfig.showAsTile;
    bool showAsGraph = cardConfig.showAsGraph;

    await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final bool isApplyButtonDisabled = !showAsTile && !showAsGraph;

              return AlertDialog(
                title: const Text('Customize Report Card'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Display Options', style: TextStyle(fontWeight: FontWeight.bold)),
                      CheckboxListTile(
                        title: const Text('Show as Tile'),
                        value: showAsTile,
                        onChanged: (value) => setDialogState(() => showAsTile = value!),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Show as Graph'),
                        value: showAsGraph,
                        onChanged: (value) => setDialogState(() => showAsGraph = value!),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
                      if (showAsGraph) ...[
                        DropdownButtonFormField<GraphType>(
                          decoration: const InputDecoration(labelText: 'Graph Type'),
                          value: selectedGraphType,
                          items: GraphType.values.map((g) => DropdownMenuItem(value: g, child: Text(g.displayName))).toList(),
                          onChanged: (value) { if (value != null) { setDialogState(() => selectedGraphType = value); } },
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Card Title')),
                      const SizedBox(height: 16),
                      TextField(controller: subtitleController, decoration: const InputDecoration(labelText: 'Card Subtitle (Optional)')),
                      const SizedBox(height: 16),
                      TextField(controller: apiUrlController, decoration: const InputDecoration(labelText: 'API URL (Optional)', hintText: 'https://...')),
                      const SizedBox(height: 16),
                      if (showAsTile) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Tile Icon'),
                          trailing: Icon(selectedIcon, color: selectedColor, size: 28),
                          onTap: () async {
                            final newIcon = await showDialog<IconData>(context: context, builder: (ctx) => IconPickerDialog(selectedIcon: selectedIcon));
                            if (newIcon != null) { setDialogState(() => selectedIcon = newIcon); }
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Tile Icon Color'),
                          trailing: CircleAvatar(backgroundColor: selectedColor, radius: 14),
                          onTap: () async {
                            final newColor = await showDialog<Color>(context: context, builder: (ctx) => ColorPickerDialog(initialColor: selectedColor));
                            if (newColor != null) { setDialogState(() => selectedColor = newColor); }
                          },
                        ),
                      ]
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: isApplyButtonDisabled ? null : () {
                      context.read<DashboardBuilderBloc>().add(UpdateReportCardConfigEvent(
                        groupId: groupId,
                        reportRecNo: cardConfig.reportRecNo,
                        newTitle: titleController.text,
                        newSubtitle: subtitleController.text,
                        newIcon: selectedIcon,
                        newColor: selectedColor,
                        newApiUrl: apiUrlController.text,
                        newShowAsTile: showAsTile,
                        newShowAsGraph: showAsGraph,
                        newGraphType: showAsGraph ? selectedGraphType : null,
                      ));
                      Navigator.of(context).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              );
            },
          );
        }
    );
  }

  void _showGroupDialog({DashboardReportGroup? groupToEdit}) async {
    final _groupNameController = TextEditingController(text: groupToEdit?.groupName ?? '');
    final _groupUrlController = TextEditingController(text: groupToEdit?.groupUrl ?? '');
    final bool isEditing = groupToEdit != null;

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Group' : 'Add New Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _groupNameController, autofocus: true, decoration: const InputDecoration(labelText: 'Group Name', hintText: 'e.g. Sales Reports')),
            const SizedBox(height: 16),
            TextField(controller: _groupUrlController, decoration: const InputDecoration(labelText: 'URL (Optional)', hintText: 'https://your-link.com')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (_groupNameController.text.isNotEmpty) {
                Navigator.of(context).pop({'name': _groupNameController.text, 'url': _groupUrlController.text});
              }
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      final newName = result['name'];
      final newUrl = result['url'];
      if (newName != null && newName.isNotEmpty) {
        if (isEditing) {
          context.read<DashboardBuilderBloc>().add(UpdateReportGroupEvent(groupId: groupToEdit.groupId, newName: newName, newUrl: newUrl));
        } else {
          context.read<DashboardBuilderBloc>().add(AddReportGroupEvent(newName, url: newUrl));
        }
      }
    }
  }

  void _showAddReportDialog(BuildContext parentContext, String groupId, Map<String, dynamic> reportDefinition) async {
    final apiUrlController = TextEditingController();
    final reportName = reportDefinition['Report_label'] ?? reportDefinition['Report_name'] ?? 'Selected Report';

    await showDialog<void>(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add "$reportName"'),
        content: TextField(
          controller: apiUrlController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'API URL (Optional)',
            hintText: 'Enter data source URL...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              parentContext.read<DashboardBuilderBloc>().add(
                AddReportToDashboardEvent(
                  groupId: groupId,
                  reportDefinition: reportDefinition,
                  apiUrl: apiUrlController.text.isNotEmpty ? apiUrlController.text : null,
                ),
              );
              Navigator.of(dialogContext).pop();
              Navigator.of(parentContext).pop();
            },
            child: const Text('Add Report'),
          ),
        ],
      ),
    );
  }

  void _showAddReportSheet(BuildContext context, DashboardBuilderLoaded state, String groupId) {
    final currentDashboard = state.currentDashboard!;
    final allAddedRecNos = currentDashboard.reportGroups
        .expand((group) => group.reports)
        .map((report) => report.reportRecNo)
        .toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Select a Report to Add', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: state.availableReports.length,
                itemBuilder: (listCtx, index) {
                  final report = state.availableReports[index];
                  final int? recNo = _safeParseInt(report['RecNo']);
                  if (recNo == null) return const SizedBox.shrink();

                  final bool isSelected = allAddedRecNos.contains(recNo);
                  return ListTile(
                    title: Text(report['Report_label'] ?? report['Report_name'] ?? 'Report $recNo'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.add_circle_outline),
                    onTap: () {
                      if (!isSelected) {
                        _showAddReportDialog(context, groupId, report);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Icon _getReportLeadingIcon(DashboardReportCardConfig config) {
    if (config.showAsGraph) {
      switch (config.graphType) {
        case GraphType.pie: return const Icon(Icons.pie_chart_outline, color: Colors.purple);
        case GraphType.line: return const Icon(Icons.show_chart, color: Colors.green);
        case GraphType.bar: return const Icon(Icons.bar_chart_outlined, color: Colors.orange);
        default: return const Icon(Icons.insights_outlined, color: Colors.grey);
      }
    }
    if (config.showAsTile) {
      return Icon(config.displayIcon, color: config.displayColor);
    }
    return const Icon(Icons.block, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBarWidget(
        title: widget.dashboardToEdit == null ? 'Create New Dashboard' : 'Edit Dashboard',
        onBackPress: () => Navigator.pop(context),
      ),
      body: BlocConsumer<DashboardBuilderBloc, DashboardBuilderState>(
        listener: (context, state) {
          if (state is DashboardBuilderLoaded) {
            final dashboard = state.currentDashboard;
            if (dashboard != null) {
              if (_nameController.text != dashboard.dashboardName) { _nameController.text = dashboard.dashboardName; }
              if (_descriptionController.text != (dashboard.dashboardDescription ?? '')) { _descriptionController.text = dashboard.dashboardDescription ?? ''; }
              setState(() {
                _currentAccentColor = dashboard.templateConfig.accentColor;
                _selectedTemplateOption = DashboardTemplateOption.values.firstWhereOrNull((e) => e.id == dashboard.templateConfig.id) ?? DashboardTemplateOption.classicClean;
              });
            }
            if (state.message != null) _showSnackBar(state.message!);
            if (state.error != null) _showSnackBar(state.error!, isError: true);
            if (state.message?.toLowerCase().contains('success') == true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pop(context, true);
                }
              });
            }
          } else if (state is DashboardBuilderErrorState) {
            _showSnackBar(state.message, isError: true);
          }
        },
        builder: (context, state) {
          if (state is DashboardBuilderInitial) {
            return const Center(child: Text("Please select a database to begin."));
          }
          if (state is DashboardBuilderLoading) {
            return const Center(child: SubtleLoader());
          }
          if (state is DashboardBuilderLoaded) {
            // --- FIX IS HERE ---
            // Ensure we have a dashboard to build. If not, show a loader.
            // This prevents the null crash when the screen builds with a state
            // from the listing screen (where currentDashboard is null).
            final currentDashboard = state.currentDashboard;
            if (currentDashboard == null) {
              return const Center(child: SubtleLoader());
            }

            return Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(controller: _nameController, decoration: InputDecoration(labelText: 'Dashboard Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (v) => v==null||v.isEmpty?'Please enter a name.':null, onChanged: (v)=>context.read<DashboardBuilderBloc>().add(UpdateDashboardInfo(dashboardName:v))),
                          const SizedBox(height: 16),
                          TextFormField(controller: _descriptionController, decoration: InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), maxLines: 3, onChanged: (v)=>context.read<DashboardBuilderBloc>().add(UpdateDashboardInfo(dashboardDescription:v))),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<DashboardTemplateOption>(decoration: InputDecoration(labelText: 'Select Template', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), value: _selectedTemplateOption, items: DashboardTemplateOption.values.map((o) => DropdownMenuItem(value: o, child: Text(o.name))).toList(), onChanged: (o){if(o!=null){setState((){_selectedTemplateOption=o; _currentAccentColor=o.defaultAccentColor;}); context.read<DashboardBuilderBloc>().add(UpdateDashboardInfo(templateId:o.id, accentColor:o.defaultAccentColor));}}),
                          const SizedBox(height: 16),
                          ListTile(contentPadding: EdgeInsets.zero, title: Text('Accent Color', style: GoogleFonts.poppins()), trailing: CircleAvatar(backgroundColor: _currentAccentColor ?? theme.primaryColor, radius: 15), onTap: () async { final c = await showDialog<Color>(context: context, builder: (ctx) => ColorPickerDialog(initialColor: _currentAccentColor ?? theme.primaryColor)); if (c != null) { setState(() => _currentAccentColor = c); context.read<DashboardBuilderBloc>().add(UpdateDashboardInfo(accentColor: c)); } }),

                          Padding(
                            padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                            child: Column(
                              children: [
                                Text('Report Groups', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Divider(color: theme.colorScheme.outline.withOpacity(0.5)),
                              ],
                            ),
                          ),

                          if (currentDashboard.reportGroups.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 24.0), child: Center(child: Text("No report groups yet. Add one to begin.", style: TextStyle(color: Colors.grey[600])))),

                          ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: currentDashboard.reportGroups.length,
                            onReorder: (oldIndex, newIndex) => context.read<DashboardBuilderBloc>().add(ReorderGroupsEvent(oldIndex, newIndex)),
                            itemBuilder: (context, groupIndex) {
                              final group = currentDashboard.reportGroups[groupIndex];
                              return Padding(
                                key: ValueKey(group.groupId),
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            group.groupName,
                                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Edit Group',
                                          icon: const Icon(Icons.edit_outlined),
                                          iconSize: 20,
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _showGroupDialog(groupToEdit: group),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete Group',
                                          icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                                          iconSize: 20,
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => context.read<DashboardBuilderBloc>().add(RemoveReportGroupEvent(group.groupId)),
                                        ),
                                        ReorderableDragStartListener(
                                          index: groupIndex,
                                          child: const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Icon(Icons.drag_indicator_rounded),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    Card(
                                      elevation: 0,
                                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                                      ),
                                      child: group.reports.isEmpty
                                          ? _buildEmptyGroupPlaceholder(context, () => _showAddReportSheet(context, state, group.groupId))
                                          : Column(
                                        children: [
                                          ReorderableListView.builder(
                                            buildDefaultDragHandles: false,
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: group.reports.length,
                                            onReorder: (oldIndex, newIndex) => context.read<DashboardBuilderBloc>().add(ReorderReportsEvent(groupId: group.groupId, oldIndex: oldIndex, newIndex: newIndex)),
                                            itemBuilder: (context, reportIndex) {
                                              final reportConfig = group.reports[reportIndex];
                                              return ListTile(
                                                key: ValueKey(reportConfig.reportRecNo),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                leading: _getReportLeadingIcon(reportConfig),
                                                title: Text(reportConfig.displayTitle, overflow: TextOverflow.ellipsis),
                                                subtitle: Text('ID: ${reportConfig.reportRecNo}'),
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(icon: const Icon(Icons.palette_outlined), tooltip: 'Customize', onPressed: () => _showCardCustomizationDialog(reportConfig, group.groupId)),
                                                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), tooltip: 'Remove', onPressed: () => context.read<DashboardBuilderBloc>().add(RemoveReportFromDashboardEvent(groupId: group.groupId, reportRecNo: reportConfig.reportRecNo))),
                                                    ReorderableDragStartListener(
                                                      index: reportIndex,
                                                      child: const Padding(
                                                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                                                        child: Icon(Icons.drag_handle_rounded),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                          const Divider(height: 1),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor: theme.primaryColor,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            onPressed: () => _showAddReportSheet(context, state, group.groupId),
                                            icon: const Icon(Icons.add, size: 20),
                                            label: const Text('Add Another Report'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.center,
                            child: ElevatedButton.icon(
                              onPressed: () => _showGroupDialog(),
                              icon: const Icon(Icons.add_circle_outline),
                              label: Text('Add New Group', style: GoogleFonts.poppins()),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: (){ if(_formKey.currentState!.validate()){ context.read<DashboardBuilderBloc>().add(const SaveDashboardEvent()); } },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: theme.primaryColor,
                              foregroundColor: theme.colorScheme.onPrimary,
                            ),
                            child: Text(
                              widget.dashboardToEdit == null ? 'Create Dashboard' : 'Update Dashboard',
                              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (state is DashboardBuilderSaving) ...[
                  const Opacity(opacity: 0.8, child: ModalBarrier(dismissible: false, color: Colors.black)),
                  const Center(child: SubtleLoader())
                ],
              ],
            );
          }
          return const Center(child: Text("An unexpected error occurred."));
        },
      ),
    );
  }
}

// =========================================================================
// == DIALOG WIDGET FOR INITIAL DATABASE SELECTION (No Changes)
// =========================================================================
class _SelectDatabaseDialog extends StatefulWidget {
  final ReportAPIService apiService;

  const _SelectDatabaseDialog({required this.apiService});

  @override
  _SelectDatabaseDialogState createState() => _SelectDatabaseDialogState();
}

class _SelectDatabaseDialogState extends State<_SelectDatabaseDialog> {
  bool _isLoadingApis = true;
  List<Map<String, dynamic>> _availableApis = [];
  Map<String, dynamic>? _selectedApi;
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isFetchingDatabases = false;
  List<String> _databaseList = [];
  String? _selectedDatabase;
  String _feedbackMessage = '';

  @override
  void initState() {
    super.initState();
    _loadApiConnections();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadApiConnections() async {
    try {
      final allApiNames = await widget.apiService.getAvailableApis();
      final List<Map<String, dynamic>> fullDetails = [];
      for (var name in allApiNames) {
        final details = await widget.apiService.getApiDetails(name);
        details['APIName'] = name;
        fullDetails.add(details);
      }
      if (mounted) setState(() { _availableApis = fullDetails; _isLoadingApis = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _isLoadingApis = false; _feedbackMessage = "Failed to load connections: $e"; });
      }
    }
  }

  Future<void> _fetchDatabases() async {
    if (_serverController.text.isEmpty || _userController.text.isEmpty) {
      setState(() { _feedbackMessage = "Server IP and User Name are required."; });
      return;
    }
    setState(() { _isFetchingDatabases = true; _databaseList = []; _selectedDatabase = null; _feedbackMessage = ''; });
    try {
      final databases = await widget.apiService.fetchDatabases(
        serverIP: _serverController.text, userName: _userController.text, password: _passwordController.text,
      );
      if (mounted) setState(() { _databaseList = databases; _isFetchingDatabases = false; });
    } catch (e) {
      if (mounted) { setState(() { _isFetchingDatabases = false; _feedbackMessage = "Error fetching databases: $e"; }); }
    }
  }

  void _confirmSelection() {
    final Map<String, dynamic> connectionDetails = {
      'serverIP': _serverController.text,
      'userName': _userController.text,
      'password': _passwordController.text,
      'database': _selectedDatabase,
    };
    Navigator.of(context).pop(connectionDetails);
  }

  Widget _buildSectionTitle(String number, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar( radius: 14, backgroundColor: Theme.of(context).primaryColor, child: Text(number, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Select Data Source', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('1', 'Choose Connection'),
              if (_isLoadingApis) const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
              else DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedApi, hint: Text('Select saved connection...', style: GoogleFonts.poppins()), isExpanded: true,
                items: _availableApis.map((api) => DropdownMenuItem(value: api, child: Text(api['APIName'] ?? 'Unknown', overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedApi = value;
                    _serverController.text = value?['serverIP'] ?? '';
                    _userController.text = value?['userName'] ?? '';
                    _passwordController.text = value?['password'] ?? '';
                    _databaseList = [];
                    _selectedDatabase = null;
                    _feedbackMessage = '';
                  });
                },
                decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const Divider(height: 24),
              _buildSectionTitle('2', 'Verify & Fetch Databases'),
              TextField(controller: _serverController, decoration: const InputDecoration(labelText: 'Server IP')),
              const SizedBox(height: 8),
              TextField(controller: _userController, decoration: const InputDecoration(labelText: 'User Name')),
              const SizedBox(height: 8),
              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isFetchingDatabases ? null : _fetchDatabases,
                  icon: _isFetchingDatabases ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_sync_outlined),
                  label: const Text("Fetch Databases"),
                ),
              ),
              const Divider(height: 24),
              _buildSectionTitle('3', 'Select Target Database'),
              if (_isFetchingDatabases) const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Fetching...")))
              else if (_databaseList.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text("No databases found.", style: TextStyle(color: Colors.grey))))
              else DropdownButtonFormField<String>(
                  value: _selectedDatabase, hint: Text('Select target database...', style: GoogleFonts.poppins()), isExpanded: true,
                  items: _databaseList.map((db) => DropdownMenuItem(value: db, child: Text(db, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (value) => setState(() => _selectedDatabase = value),
                  decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
              if (_feedbackMessage.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [ const Icon(Icons.error_outline, color: Colors.red), const SizedBox(width: 10), Expanded(child: Text(_feedbackMessage, style: const TextStyle(color: Colors.red, fontSize: 13))) ],),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _selectedDatabase != null ? _confirmSelection : null,
          child: const Text('Confirm Selection'),
        ),
      ],
    );
  }
}