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
    }
    context.read<DashboardBuilderBloc>().add(LoadDashboardBuilderData(dashboardToEdit: widget.dashboardToEdit));
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

    // --- FIX: Provide default values for nullable properties ---
    IconData selectedIcon = cardConfig.displayIcon ?? Icons.article;
    Color selectedColor = cardConfig.displayColor ?? Colors.grey;

    await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Customize Report Card'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Card Title')),
                      const SizedBox(height: 16),
                      TextField(controller: subtitleController, decoration: const InputDecoration(labelText: 'Card Subtitle (Optional)')),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Card Icon'),
                        trailing: Icon(selectedIcon, color: selectedColor, size: 28),
                        onTap: () async {
                          // --- FIX: Pass the required 'selectedIcon' parameter ---
                          final newIcon = await showDialog<IconData>(context: context, builder: (ctx) => IconPickerDialog(selectedIcon: selectedIcon));
                          if (newIcon != null) {
                            setDialogState(() => selectedIcon = newIcon);
                          }
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Card Icon Color'),
                        trailing: CircleAvatar(backgroundColor: selectedColor, radius: 14),
                        onTap: () async {
                          final newColor = await showDialog<Color>(context: context, builder: (ctx) => ColorPickerDialog(initialColor: selectedColor));
                          if (newColor != null) {
                            setDialogState(() => selectedColor = newColor);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () {
                      context.read<DashboardBuilderBloc>().add(UpdateReportCardConfigEvent(
                        groupId: groupId,
                        reportRecNo: cardConfig.reportRecNo,
                        newTitle: titleController.text,
                        newSubtitle: subtitleController.text,
                        newIcon: selectedIcon,
                        newColor: selectedColor,
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

  void _showAddReportSheet(BuildContext context, DashboardBuilderLoaded state, String groupId) {
    final currentDashboard = state.currentDashboard!;
    final allAddedRecNos = currentDashboard.reportGroups
        .expand((group) => group.reports)
        .map((report) => report.reportRecNo)
        .toSet();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Select a Report to Add', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: state.availableReports.length,
              itemBuilder: (ctx, index) {
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
                      context.read<DashboardBuilderBloc>().add(AddReportToDashboardEvent(groupId: groupId, reportDefinition: report));
                      Navigator.pop(ctx);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              if (_nameController.text != dashboard.dashboardName) {
                _nameController.text = dashboard.dashboardName;
              }
              if (_descriptionController.text != (dashboard.dashboardDescription ?? '')) {
                _descriptionController.text = dashboard.dashboardDescription ?? '';
              }
              setState(() {
                _currentAccentColor = dashboard.templateConfig.accentColor;
                _selectedTemplateOption = DashboardTemplateOption.values.firstWhereOrNull(
                      (e) => e.id == dashboard.templateConfig.id,
                ) ?? DashboardTemplateOption.classicClean;
              });
            }
            if (state.message != null) _showSnackBar(state.message!);
            if (state.error != null) _showSnackBar(state.error!, isError: true);
            if (state.message?.contains('successfully') == true) Navigator.pop(context, true);
          } else if (state is DashboardBuilderErrorState) {
            _showSnackBar(state.message, isError: true);
          }
        },
        builder: (context, state) {
          if (state is DashboardBuilderLoading) {
            return const Center(child: SubtleLoader());
          }
          if (state is DashboardBuilderLoaded) {
            final currentDashboard = state.currentDashboard!;

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
                          ListTile(contentPadding: EdgeInsets.zero, title: Text('Accent Color', style: GoogleFonts.poppins()), trailing: CircleAvatar(backgroundColor: _currentAccentColor ?? Theme.of(context).primaryColor, radius: 15), onTap: () async { final c = await showDialog<Color>(context: context, builder: (ctx) => ColorPickerDialog(initialColor: _currentAccentColor ?? Theme.of(context).primaryColor)); if (c != null) { setState(() => _currentAccentColor = c); context.read<DashboardBuilderBloc>().add(UpdateDashboardInfo(accentColor: c)); } }),
                          const Divider(height: 32),
                          Text('Report Groups', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          if (currentDashboard.reportGroups.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Center(child: Text("No report groups yet. Add one to begin.", style: TextStyle(color: Colors.grey[600]))),
                            ),
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: currentDashboard.reportGroups.length,
                            onReorder: (oldIndex, newIndex) => context.read<DashboardBuilderBloc>().add(ReorderGroupsEvent(oldIndex, newIndex)),
                            itemBuilder: (context, groupIndex) {
                              final group = currentDashboard.reportGroups[groupIndex];
                              return Card(
                                key: ValueKey(group.groupId),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 2,
                                child: Column(
                                  children: [
                                    ListTile(
                                      title: Text(group.groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: (group.groupUrl?.isNotEmpty ?? false) ? Text(group.groupUrl!, style: TextStyle(color: Colors.blueGrey.shade700, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis) : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(icon: const Icon(Icons.add_box_outlined), tooltip: 'Add Report to this Group', onPressed: () => _showAddReportSheet(context, state, group.groupId)),
                                          PopupMenuButton<String>(
                                            tooltip: 'Group Options',
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showGroupDialog(groupToEdit: group);
                                              } else if (value == 'delete') {
                                                context.read<DashboardBuilderBloc>().add(RemoveReportGroupEvent(group.groupId));
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(value: 'edit', child: Text('Edit Group')),
                                              const PopupMenuItem(value: 'delete', child: Text('Delete Group', style: TextStyle(color: Colors.red))),
                                            ],
                                          ),
                                          ReorderableDragStartListener(
                                            index: groupIndex,
                                            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0), child: Icon(Icons.drag_handle)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (group.reports.isNotEmpty)
                                      ReorderableListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: group.reports.length,
                                        onReorder: (oldIndex, newIndex) => context.read<DashboardBuilderBloc>().add(ReorderReportsEvent(groupId: group.groupId, oldIndex: oldIndex, newIndex: newIndex)),
                                        itemBuilder: (context, reportIndex) {
                                          final reportConfig = group.reports[reportIndex];
                                          return ListTile(
                                            key: ValueKey(reportConfig.reportRecNo),
                                            visualDensity: VisualDensity.compact,
                                            leading: Icon(reportConfig.displayIcon, color: reportConfig.displayColor),
                                            title: Text(reportConfig.displayTitle, overflow: TextOverflow.ellipsis),
                                            subtitle: Text('ID: ${reportConfig.reportRecNo} - ${reportConfig.displaySubtitle ?? ''}', overflow: TextOverflow.ellipsis),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(icon: const Icon(Icons.palette_outlined), tooltip: 'Customize Card', onPressed: () => _showCardCustomizationDialog(reportConfig, group.groupId)),
                                                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), tooltip: 'Remove Report', onPressed: () => context.read<DashboardBuilderBloc>().add(RemoveReportFromDashboardEvent(groupId: group.groupId, reportRecNo: reportConfig.reportRecNo))),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    if (group.reports.isEmpty)
                                      ListTile(
                                        dense: true,
                                        title: Center(
                                          child: Text("No reports in this group", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(onPressed: () => _showGroupDialog(), icon: const Icon(Icons.add_circle_outline), label: Text('Add New Group', style: GoogleFonts.poppins())),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(onPressed: (){if(_formKey.currentState!.validate()){context.read<DashboardBuilderBloc>().add(const SaveDashboardEvent());}}, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: Theme.of(context).primaryColor), child: Text(widget.dashboardToEdit == null ? 'Create Dashboard' : 'Update Dashboard', style: GoogleFonts.poppins(fontSize: 18, color: Colors.white))),
                        ],
                      ),
                    ),
                  ),
                ),
                if (state is DashboardBuilderSaving) ...[const Opacity(opacity: 0.8, child: ModalBarrier(dismissible: false, color: Colors.black)), const Center(child: SubtleLoader())],
              ],
            );
          }
          return const Center(child: Text("An unexpected error occurred."));
        },
      ),
    );
  }
}