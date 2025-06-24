// lib/ReportDashboard/DashboardScreen/dashboard_builder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
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
extension DashboardTemplateOptionExtension on DashboardTemplateOption { String get id => toString().split('.').last; String get name { switch (this) { case DashboardTemplateOption.classicClean: return 'Classic Clean'; case DashboardTemplateOption.modernMinimal: return 'Modern Minimal'; case DashboardTemplateOption.vibrantBold: return 'Vibrant & Bold'; } } String? get defaultBannerUrl { switch (this) { case DashboardTemplateOption.classicClean: return 'https://via.placeholder.com/600x180/E0E0E0/9E9E9E?text=Classic+Banner'; case DashboardTemplateOption.modernMinimal: return null; case DashboardTemplateOption.vibrantBold: return 'https://via.placeholder.com/600x180/FF5722/FFFFFF?text=Vibrant+Banner'; } } Color get defaultAccentColor { switch (this) { case DashboardTemplateOption.classicClean: return Colors.blue; case DashboardTemplateOption.modernMinimal: return Colors.grey; case DashboardTemplateOption.vibrantBold: return Colors.deepOrange; } } }

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
  String? _currentBannerUrl;
  Uint8List? _bannerImageBytes;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();

    if (widget.dashboardToEdit != null) {
      final dashboard = widget.dashboardToEdit!;
      _nameController.text = dashboard.dashboardName;
      _descriptionController.text = dashboard.dashboardDescription ?? '';
      _currentBannerUrl = dashboard.templateConfig.bannerUrl;
      _currentAccentColor = dashboard.templateConfig.accentColor;
      _selectedTemplateOption = DashboardTemplateOption.values.firstWhere(
            (e) => e.id == dashboard.templateConfig.id,
        orElse: () => DashboardTemplateOption.classicClean,
      );
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

  Future<void> _pickBannerImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _bannerImageBytes = file.bytes;
      _currentBannerUrl = null;
    });
    await _uploadImageToServer(file.bytes, file.name);
  }

  Future<void> _uploadImageToServer(Uint8List? imageBytes, String fileName) async {
    if (imageBytes == null) {
      _showSnackBar('Could not read file for upload.', isError: true);
      return;
    }
    _showSnackBar('Uploading image...');
    await Future.delayed(const Duration(seconds: 1)); // Simulate upload
    final String placeholderUrl = 'https://your-server.com/images/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    _updateBannerUrlInState(placeholderUrl);
  }

  void _updateBannerUrlInState(String newUrl) {
    context.read<DashboardBuilderBloc>().add(UpdateDashboardInfo(bannerUrl: newUrl));
    _showSnackBar('Banner image updated successfully!');
  }

  void _showCardCustomizationDialog(DashboardReportCardConfig cardConfig, String groupId) {
    // Logic is the same, but the event now needs the groupId
    // ...
    // In the final "Apply" button's onPressed:
    context.read<DashboardBuilderBloc>().add(UpdateReportCardConfigEvent(
      groupId: groupId, // Pass the group ID
      reportRecNo: cardConfig.reportRecNo,
      // ... other properties
    ));
    // ...
  }

  // --- NEW: Dialog to add or edit a group name ---
  void _showGroupDialog({DashboardReportGroup? groupToEdit}) async {
    final _groupNameController = TextEditingController(text: groupToEdit?.groupName ?? '');
    final bool isEditing = groupToEdit != null;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Group Name' : 'Add New Group'),
        content: TextField(
          controller: _groupNameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Group Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (_groupNameController.text.isNotEmpty) {
                Navigator.of(context).pop(_groupNameController.text);
              }
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      if (isEditing) {
        context.read<DashboardBuilderBloc>().add(UpdateReportGroupEvent(groupId: groupToEdit.groupId, newName: newName));
      } else {
        context.read<DashboardBuilderBloc>().add(AddReportGroupEvent(newName));
      }
    }
  }

  // --- NEW: Bottom sheet to add reports to a specific group ---
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
              // Only update controllers if the text differs to avoid cursor jumps
              if (_nameController.text != dashboard.dashboardName) {
                _nameController.text = dashboard.dashboardName;
              }
              if (_descriptionController.text != (dashboard.dashboardDescription ?? '')) {
                _descriptionController.text = dashboard.dashboardDescription ?? '';
              }
              setState(() {
                _currentBannerUrl = dashboard.templateConfig.bannerUrl;
                _currentAccentColor = dashboard.templateConfig.accentColor;
                _selectedTemplateOption = DashboardTemplateOption.values.firstWhereOrNull(
                      (e) => e.id == dashboard.templateConfig.id,
                ) ?? DashboardTemplateOption.classicClean;
                if (_currentBannerUrl == null || _currentBannerUrl!.isEmpty) {
                  _bannerImageBytes = null;
                }
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
                          // --- Dashboard Info Fields (unchanged) ---
                          TextFormField(controller: _nameController, decoration: InputDecoration(labelText: 'Dashboard Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (v) => v==null||v.isEmpty?'Please enter a name.':null, onChanged: (v)=>context.read<DashboardBuilderBloc>().add(UpdateDashboardInfo(dashboardName:v))),
                          const SizedBox(height: 16),
                          TextFormField(controller: _descriptionController, decoration: InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), maxLines: 3, onChanged: (v)=>context.read<DashboardBuilderBloc>().add(UpdateDashboardInfo(dashboardDescription:v))),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<DashboardTemplateOption>(decoration: InputDecoration(labelText: 'Select Template', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), value: _selectedTemplateOption, items: DashboardTemplateOption.values.map((o) => DropdownMenuItem(value: o, child: Text(o.name))).toList(), onChanged: (o){if(o!=null){setState((){_selectedTemplateOption=o; _currentAccentColor=o.defaultAccentColor;}); context.read<DashboardBuilderBloc>().add(UpdateDashboardInfo(templateId:o.id, accentColor:o.defaultAccentColor));}}),
                          const SizedBox(height: 16),
                          // --- Banner Image (unchanged) ---
                          Text('Banner Image', style: GoogleFonts.poppins(color: Colors.grey[700])),
                          const SizedBox(height: 8),
                          Container( height: 150, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Stack( alignment: Alignment.center, children: [ if (_bannerImageBytes != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_bannerImageBytes!, width: double.infinity, fit: BoxFit.cover)) else if (_currentBannerUrl != null && _currentBannerUrl!.isNotEmpty) ClipRRect( borderRadius: BorderRadius.circular(8), child: Image.network( _currentBannerUrl!, width: double.infinity, height: 150, fit: BoxFit.cover, loadingBuilder: (ctx, child, prog) => prog == null ? child : const Center(child: CircularProgressIndicator()), errorBuilder: (ctx, err, st) => const Center(child: Icon(Icons.error_outline, color: Colors.red, size: 40)), ) ) else const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40)), Positioned( bottom: 8, right: 8, child: ElevatedButton.icon( onPressed: _pickBannerImage, icon: const Icon(Icons.upload_file), label: Text((_bannerImageBytes != null || (_currentBannerUrl?.isNotEmpty ?? false)) ? 'Change' : 'Upload'), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white), ), ), ], ), ),
                          const SizedBox(height: 16),
                          ListTile(contentPadding: EdgeInsets.zero, title: Text('Accent Color', style: GoogleFonts.poppins()), trailing: CircleAvatar(backgroundColor: _currentAccentColor ?? Theme.of(context).primaryColor, radius: 15), onTap: () async { final c = await showDialog<Color>(context: context, builder: (ctx) => ColorPickerDialog(initialColor: _currentAccentColor ?? Theme.of(context).primaryColor)); if (c != null) { setState(() => _currentAccentColor = c); context.read<DashboardBuilderBloc>().add(UpdateDashboardInfo(accentColor: c)); } }),
                          const Divider(height: 32),

                          // --- NEW: Report Groups Section ---
                          Text('Report Groups', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),

                          if (currentDashboard.reportGroups.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Center(child: Text("No report groups yet. Add one to begin.", style: TextStyle(color: Colors.grey[600]))),
                            ),

                          // A list view that can be reordered
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
                                    // Group Header
                                    ListTile(
                                      title: Text(group.groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(icon: const Icon(Icons.add_box_outlined), tooltip: 'Add Report to this Group', onPressed: () => _showAddReportSheet(context, state, group.groupId)),
                                          IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit Group Name', onPressed: () => _showGroupDialog(groupToEdit: group)),
                                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'Delete Group', onPressed: () => context.read<DashboardBuilderBloc>().add(RemoveReportGroupEvent(group.groupId))),
                                          ReorderableDragStartListener(index: groupIndex, child: const Icon(Icons.drag_handle)),
                                        ],
                                      ),
                                    ),
                                    // Nested Reorderable List for Reports
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
                                            leading: Icon(reportConfig.displayIcon, color: reportConfig.displayColor),
                                            title: Text(reportConfig.displayTitle),
                                            subtitle: Text('ID: ${reportConfig.reportRecNo} - ${reportConfig.displaySubtitle ?? ''}'),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(icon: const Icon(Icons.palette_outlined), onPressed: () => _showCardCustomizationDialog(reportConfig, group.groupId)),
                                                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => context.read<DashboardBuilderBloc>().add(RemoveReportFromDashboardEvent(groupId: group.groupId, reportRecNo: reportConfig.reportRecNo))),
                                                ReorderableDragStartListener(index: reportIndex, child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.drag_indicator, size: 20))),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    if (group.reports.isEmpty)
                                      Padding(padding: const EdgeInsets.all(16.0), child: Text('No reports in this group.', style: TextStyle(color: Colors.grey[600]))),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              onPressed: () => _showGroupDialog(),
                              icon: const Icon(Icons.add_circle_outline),
                              label: Text('Add New Group', style: GoogleFonts.poppins()),
                            ),
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