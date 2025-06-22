// lib/ReportDashboard/DashboardScreen/dashboard_builder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import '../../ReportDynamic/ReportAPIService.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../DashboardBloc/dashboard_builder_bloc.dart';
import '../DashboardModel/dashboard_model.dart';
import '../dashboardWidget/dashboard_colour_picker.dart';
import '../dashboardWidget/dashboard_icon_picker.dart';

// ... (Helper function and enums are unchanged) ...
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

  // *** FIX: State variable to hold the image bytes for preview ***
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green));
    }
  }

  Future<void> _pickBannerImage() async {
    debugPrint("[BANNER] Step 1: Opening file picker...");
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result == null || result.files.isEmpty) {
      debugPrint("[BANNER] Step 2: User canceled picking. No action.");
      return;
    }

    final PlatformFile file = result.files.first;
    debugPrint("[BANNER] Step 2: File selected.");
    debugPrint("  - Name: ${file.name}");
    debugPrint("  - Size: ${file.bytes?.length ?? 'N/A'} bytes");
    // *** FIX: Do not access file.path on web. It will crash. ***

    // Store the bytes for immediate preview
    setState(() {
      _bannerImageBytes = file.bytes;
      _currentBannerUrl = null; // Clear old network URL to prioritize memory image
    });

    await _uploadImageToServer(file.bytes, file.name);
  }

  Future<void> _uploadImageToServer(Uint8List? imageBytes, String fileName) async {
    if (imageBytes == null) {
      debugPrint("[BANNER] ERROR: Cannot upload, file bytes are null.");
      _showSnackBar('Could not read file for upload.', isError: true);
      return;
    }

    debugPrint("[BANNER] Step 3: Simulating upload of $fileName to server...");
    _showSnackBar('Uploading image...');

    // In a real app, you would have:
    // try {
    //   final String realUrl = await widget.apiService.uploadImage(imageBytes, fileName);
    //   _updateBannerUrlInState(realUrl);
    // } catch (e) {
    //   debugPrint("[BANNER] FAILED! Server upload error: $e");
    //   _showSnackBar('Server upload failed: $e', isError: true);
    // }

    // --- Simulation Block ---
    await Future.delayed(const Duration(seconds: 2));
    final String placeholderUrl = 'https://your-server.com/images/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    debugPrint("[BANNER] Step 4: SIMULATION SUCCESS! Got back URL: $placeholderUrl");
    _updateBannerUrlInState(placeholderUrl);
    // --- End Simulation Block ---
  }

  void _updateBannerUrlInState(String newUrl) {
    debugPrint("[BANNER] Step 5: Updating BLoC with new banner URL.");
    context.read<DashboardBuilderBloc>().add(UpdateDashboardInfo(bannerUrl: newUrl));
    _showSnackBar('Banner image updated successfully!');
    debugPrint("[BANNER] Step 6: Process complete.");
  }

  // ... (showCardCustomizationDialog is unchanged) ...
  void _showCardCustomizationDialog(DashboardReportCardConfig cardConfig) async { final currentState = context.read<DashboardBuilderBloc>().state; DashboardReportCardConfig currentCardState = cardConfig; if (currentState is DashboardBuilderLoaded && currentState.currentDashboard != null) { currentCardState = currentState.currentDashboard!.reportsOnDashboard.firstWhere( (c) => c.reportRecNo == cardConfig.reportRecNo, orElse: () => cardConfig, ); } String tempTitle = currentCardState.displayTitle; IconData tempIcon = currentCardState.displayIcon ?? Icons.description; Color tempColor = currentCardState.displayColor ?? Theme.of(context).primaryColor; String tempSubtitle = currentCardState.displaySubtitle ?? ''; await showDialog( context: context, builder: (context) { return StatefulBuilder( builder: (dialogContext, setDialogState) { return AlertDialog( title: Text('Customize Card', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), content: SingleChildScrollView( child: Column( mainAxisSize: MainAxisSize.min, children: [ TextFormField(initialValue: tempTitle, decoration: const InputDecoration(labelText: 'Card Title'), onChanged: (value) => tempTitle = value,), const SizedBox(height: 10), TextFormField(initialValue: tempSubtitle, decoration: const InputDecoration(labelText: 'Card Subtitle (Optional)'), onChanged: (value) => tempSubtitle = value,), const SizedBox(height: 20), ListTile( title: const Text('Select Icon'), trailing: Icon(tempIcon), onTap: () async { final selected = await showDialog<IconData>(context: dialogContext, builder: (c) => IconPickerDialog(selectedIcon: tempIcon)); if (selected != null) { setDialogState(() => tempIcon = selected); } }, ), ListTile( title: const Text('Select Card Color'), trailing: CircleAvatar(backgroundColor: tempColor, radius: 15), onTap: () async { final selected = await showDialog<Color>(context: dialogContext, builder: (c) => ColorPickerDialog(initialColor: tempColor)); if (selected != null) { setDialogState(() => tempColor = selected); } }, ), ], ), ), actions: [ TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')), ElevatedButton( onPressed: () { context.read<DashboardBuilderBloc>().add(UpdateReportCardConfigEvent(reportRecNo: cardConfig.reportRecNo, displayTitle: tempTitle, displaySubtitle: tempSubtitle, displayIcon: tempIcon, displayColor: tempColor)); Navigator.of(dialogContext).pop(); }, child: const Text('Apply'), ), ], ); }, ); }, ); }

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
              setState(() {
                _currentBannerUrl = dashboard.templateConfig.bannerUrl;
                _currentAccentColor = dashboard.templateConfig.accentColor;
                _selectedTemplateOption = DashboardTemplateOption.values.firstWhere( (e) => e.id == dashboard.templateConfig.id, orElse: () => DashboardTemplateOption.classicClean, );
                if (_currentBannerUrl == null || _currentBannerUrl!.isEmpty) { _bannerImageBytes = null; }
              });
            }
            if (state.message != null) { _showSnackBar(state.message!); }
            else if (state.error != null) { _showSnackBar(state.error!, isError: true); }
            if (state.message?.contains('successfully') == true) { Navigator.pop(context, true); }
          } else if (state is DashboardBuilderErrorState) { _showSnackBar(state.message, isError: true); }
        },
        builder: (context, state) {
          if (state is DashboardBuilderLoaded) {
            final currentDashboard = state.currentDashboard!;
            final availableReports = state.availableReports;

            return Stack(
              children: [
                // *** FIX 3: Added SingleChildScrollView for vertical scrolling ***
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
                          Text('Banner Image', style: GoogleFonts.poppins(color: Colors.grey[700])),
                          const SizedBox(height: 8),
                          Container(
                            height: 150,
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // *** FIX: Image Preview Logic ***
                                // Prioritize newly picked image bytes for preview
                                if (_bannerImageBytes != null)
                                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_bannerImageBytes!, width: double.infinity, fit: BoxFit.cover))
                                // Else, if bytes are null but a network URL exists (from editing), show that
                                else if (_currentBannerUrl != null && _currentBannerUrl!.isNotEmpty)
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        _currentBannerUrl!, width: double.infinity, height: 150, fit: BoxFit.cover,
                                        loadingBuilder: (ctx, child, prog) => prog == null ? child : const Center(child: CircularProgressIndicator()),
                                        errorBuilder: (ctx, err, st) => const Center(child: Icon(Icons.error_outline, color: Colors.red, size: 40)),
                                      )
                                  )
                                // If nothing exists, show placeholder
                                else
                                  const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40)),

                                Positioned(
                                  bottom: 8, right: 8,
                                  child: ElevatedButton.icon(
                                    onPressed: _pickBannerImage,
                                    icon: const Icon(Icons.upload_file),
                                    label: Text((_bannerImageBytes != null || (_currentBannerUrl?.isNotEmpty ?? false)) ? 'Change' : 'Upload'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(contentPadding: EdgeInsets.zero, title: Text('Accent Color', style: GoogleFonts.poppins()), trailing: CircleAvatar(backgroundColor: _currentAccentColor ?? Theme.of(context).primaryColor, radius: 15), onTap: () async { final c = await showDialog<Color>(context: context, builder: (ctx) => ColorPickerDialog(initialColor: _currentAccentColor ?? Theme.of(context).primaryColor)); if (c != null) { setState(() => _currentAccentColor = c); context.read<DashboardBuilderBloc>().add(UpdateDashboardInfo(accentColor: c)); } }),
                          const SizedBox(height: 16),
                          Text('Reports on Dashboard:', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          // Use a Container with a fixed height for the ReorderableListView
                          // to prevent it from trying to take infinite height inside the SingleChildScrollView
                          Container(
                            height: 250, // Adjust this height as needed
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                            child: currentDashboard.reportsOnDashboard.isEmpty
                                ? const Center(child: Text("No reports added yet.", style: TextStyle(color: Colors.grey)))
                                : ReorderableListView.builder(
                              itemCount: currentDashboard.reportsOnDashboard.length,
                              onReorder: (old, newIdx) => context.read<DashboardBuilderBloc>().add(ReorderReportsEvent(old, newIdx)),
                              itemBuilder: (context, index) {
                                final reportConfig = currentDashboard.reportsOnDashboard[index];
                                return Card(key: ValueKey(reportConfig.reportRecNo), margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), child: ListTile(leading: Icon(reportConfig.displayIcon, color: reportConfig.displayColor), title: Text(reportConfig.displayTitle), subtitle: Text('ID: ${reportConfig.reportRecNo} - ${reportConfig.displaySubtitle ?? ''}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.palette), onPressed: () => _showCardCustomizationDialog(reportConfig)), IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => context.read<DashboardBuilderBloc>().add(RemoveReportFromDashboardEvent(reportConfig.reportRecNo)))])));
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(alignment: Alignment.centerLeft, child: ElevatedButton.icon(onPressed: () { showModalBottomSheet(context: context, builder: (ctx) => Column(children: [const Padding(padding: EdgeInsets.all(16.0), child: Text('Select Reports to Add', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), Expanded(child: ListView.builder(itemCount: availableReports.length, itemBuilder: (ctx, index) { final report = availableReports[index]; final int? recNo = _safeParseInt(report['RecNo']); if (recNo == null) return const SizedBox.shrink(); final bool isSelected = currentDashboard.reportsOnDashboard.any((r) => r.reportRecNo == recNo); return ListTile(title: Text(report['Report_label'] ?? report['Report_name'] ?? 'Report $recNo'), trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.add_circle_outline), onTap: () { if (!isSelected) { context.read<DashboardBuilderBloc>().add(AddReportToDashboardEvent(report)); Navigator.pop(ctx); } }); }))])); }, icon: const Icon(Icons.add_box), label: Text('Add Report', style: GoogleFonts.poppins()))),
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
          return const Center(child: SubtleLoader());
        },
      ),
    );
  }
}