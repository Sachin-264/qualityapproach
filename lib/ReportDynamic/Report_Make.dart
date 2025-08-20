// lib/ReportDynamic/Report_Make.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:collection/collection.dart';

import '../ReportUtils/subtleloader.dart';
import 'ReportAPIService.dart';
import 'ReportMakeEdit/EditReportMaker.dart';
import 'Report_MakeBLoc.dart';
import 'ReportMakeEdit/EditDetailMaker.dart';

// A modern, consistent input decoration for the action configuration panel
InputDecoration _actionInputDecoration({
  required String label,
  IconData? icon,
  String? prefixText,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w500),
    prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 20) : null,
    prefixText: prefixText,
    prefixStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
    filled: true,
    fillColor: Colors.grey.shade50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.blueAccent, width: 1.8),
    ),
  );
}

// Retained your original _wellField for broader use if needed, but the new design is self-contained.
Widget _wellField({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.all(10),
    child: child,
  );
}

class ReportMakerUI extends StatefulWidget {
  const ReportMakerUI({super.key});

  @override
  _ReportMakerUIState createState() => _ReportMakerUIState();
}

class _ReportMakerUIState extends State<ReportMakerUI> with TickerProviderStateMixin {
  final TextEditingController _reportNameController = TextEditingController();
  final TextEditingController _reportLabelController = TextEditingController();
  final TextEditingController _apiController = TextEditingController();
  final TextEditingController _ucodeController = TextEditingController();
  final TextEditingController _fieldNameController = TextEditingController();
  final TextEditingController _fieldLabelController = TextEditingController();
  final TextEditingController _sequenceController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _decimalPointsController = TextEditingController();
  final TextEditingController _apiDrivenUrlController = TextEditingController();
  final TextEditingController _userFillingUrlController = TextEditingController();

  final Map<String, TextEditingController> _userFillingPayloadKeyControllers = {};
  final Map<String, TextEditingController> _userFillingPayloadStaticValueControllers = {};

  String? _selectedApi;
  bool _showConfigPanel = false;
  bool _showMainReportDetails = true;
  bool _showFieldsConfigurationContent = true;
  String? _currentActionId;

  final Map<String, TextEditingController> _actionNameControllers = {};
  final Map<String, TextEditingController> _actionApiControllers = {};
  final Map<String, TextEditingController> _actionReportLabelControllers = {};
  final Map<String, Map<String, TextEditingController>> _actionParamValueControllers = {};
  final Uuid _uuid = const Uuid();
  final Map<String, GlobalKey> _autocompleteFieldKeys = {};
  Map<String, dynamic>? _previousCurrentField;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    for (var controller in [_reportNameController, _reportLabelController, _apiController, _ucodeController]) {
      controller.addListener(_ensureCursorAtEnd(controller));
    }
  }

  VoidCallback _ensureCursorAtEnd(TextEditingController controller) {
    return () {
      if (controller.text.isNotEmpty && controller.selection.baseOffset < controller.text.length) {
        if (controller.selection.baseOffset != controller.text.length || controller.selection.extentOffset != controller.text.length) {
          controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
        }
      }
    };
  }

  @override
  void dispose() {
    _reportNameController.dispose();
    _reportLabelController.dispose();
    _apiController.dispose();
    _ucodeController.dispose();
    _fieldNameController.dispose();
    _fieldLabelController.dispose();
    _sequenceController.dispose();
    _widthController.dispose();
    _decimalPointsController.dispose();
    _apiDrivenUrlController.dispose();
    _userFillingUrlController.dispose();
    _animationController.dispose();
    _actionNameControllers.forEach((_, c) => c.dispose());
    _actionApiControllers.forEach((_, c) => c.dispose());
    _actionReportLabelControllers.forEach((_, c) => c.dispose());
    _actionParamValueControllers.forEach((_, map) => map.forEach((_, c) => c.dispose()));
    _userFillingPayloadKeyControllers.forEach((_, c) => c.dispose());
    _userFillingPayloadStaticValueControllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  void _generateUniqueCode(String reportName) {
    if (reportName.trim().isEmpty) {
      _ucodeController.clear();
      return;
    }
    var sanitizedName = reportName.toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (sanitizedName.length > 35) {
      sanitizedName = sanitizedName.substring(0, 35);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _ucodeController.text = '${sanitizedName}_$timestamp';
  }

  void _toggleConfigPanel() {
    setState(() {
      _showConfigPanel = true;
      _showMainReportDetails = false;
      _showFieldsConfigurationContent = true;
    });
    _animationController.forward();
  }

  void _returnToFieldSelection() {
    setState(() {
      _showConfigPanel = false;
    });
    _animationController.reverse(from: 1.0);
  }

  void _toggleMainReportDetails() => setState(() {
    _showMainReportDetails = !_showMainReportDetails;
    if (_showMainReportDetails) {
      _showFieldsConfigurationContent = false;
    }
  });

  void _toggleFieldsConfigurationContent() => setState(() {
    _showFieldsConfigurationContent = !_showFieldsConfigurationContent;
    if (_showFieldsConfigurationContent) {
      _showMainReportDetails = false;
    }
  });

  void _updateFieldConfigControllers(Map<String, dynamic>? field) {
    if (_previousCurrentField == field && field != null) return;
    if (field == null) {
      _fieldNameController.clear();
      _fieldLabelController.clear();
      _sequenceController.clear();
      _widthController.clear();
      _decimalPointsController.clear();
      _apiDrivenUrlController.clear();
      _userFillingUrlController.clear();
      _userFillingPayloadKeyControllers.forEach((_, c) => c.dispose());
      _userFillingPayloadKeyControllers.clear();
      _userFillingPayloadStaticValueControllers.forEach((_, c) => c.dispose());
      _userFillingPayloadStaticValueControllers.clear();
    } else {
      _fieldNameController.text = field['Field_name']?.toString() ?? '';
      _fieldLabelController.text = field['Field_label']?.toString() ?? '';
      _sequenceController.text = field['Sequence_no']?.toString() ?? '';
      _widthController.text = field['width']?.toString() ?? '';
      _decimalPointsController.text = field['decimal_points']?.toString() ?? '';
      _apiDrivenUrlController.text = field['api_url']?.toString() ?? '';
      _userFillingUrlController.text = field['updated_url']?.toString() ?? '';
      final List<dynamic> payloadStructure = field['payload_structure'] ?? [];
      final Set<String> currentParamIds = payloadStructure.map<String>((p) => p['id'] as String).toSet();
      _userFillingPayloadKeyControllers.keys.toList().forEach((paramId) {
        if (!currentParamIds.contains(paramId)) {
          _userFillingPayloadKeyControllers.remove(paramId)?.dispose();
          _userFillingPayloadStaticValueControllers.remove(paramId)?.dispose();
        }
      });
      for (var param in payloadStructure) {
        final paramId = param['id'] as String;
        _userFillingPayloadKeyControllers.putIfAbsent(paramId, () => TextEditingController(text: param['key']?.toString() ?? ''));
        if (param['value_type'] == 'static') {
          _userFillingPayloadStaticValueControllers.putIfAbsent(paramId, () => TextEditingController(text: param['value']?.toString() ?? ''));
        } else {
          _userFillingPayloadStaticValueControllers.remove(paramId)?.dispose();
        }
      }
    }
    _previousCurrentField = field;
  }

  void _updateActionControllers(List<Map<String, dynamic>> actions) {
    if (actions.isNotEmpty && !_actionNameControllers.keys.contains(_currentActionId)) {
      _currentActionId = actions.first['id'];
    } else if (actions.isEmpty) {
      _currentActionId = null;
    }

    final Set<String> existingActionIds = actions.map((a) => a['id'] as String).toSet();
    _actionNameControllers.keys.toList().forEach((id) {
      if (!existingActionIds.contains(id)) {
        _actionNameControllers.remove(id)?.dispose();
        _actionApiControllers.remove(id)?.dispose();
        _actionReportLabelControllers.remove(id)?.dispose();
        _actionParamValueControllers.remove(id)?.forEach((_, c) => c.dispose());
        _actionParamValueControllers.remove(id);
        _autocompleteFieldKeys.remove(id);
      }
    });
    for (var action in actions) {
      final actionId = action['id'] as String;
      final actionType = action['type'] as String;
      _actionNameControllers.putIfAbsent(actionId, () => TextEditingController(text: action['name']?.toString() ?? ''));
      if (actionType == 'print' || actionType == 'table') _actionApiControllers.putIfAbsent(actionId, () => TextEditingController(text: action['api']?.toString() ?? ''));
      if (actionType == 'table') {
        _autocompleteFieldKeys.putIfAbsent(actionId, () => GlobalKey());
        _actionReportLabelControllers.putIfAbsent(actionId, () => TextEditingController(text: action['reportLabel']?.toString() ?? ''));
      }
      if (actionType == 'print' || actionType == 'table') {
        final params = action['params'] as List<dynamic>? ?? [];
        _actionParamValueControllers.putIfAbsent(actionId, () => {});
        final currentParamMap = _actionParamValueControllers[actionId]!;
        currentParamMap.keys.toList().forEach((paramId) {
          if (!params.any((p) => p['id'] == paramId)) currentParamMap.remove(paramId)?.dispose();
        });
        for (var param in params) {
          final paramId = param['id'] as String;
          currentParamMap.putIfAbsent(paramId, () => TextEditingController(text: param['parameterValue']?.toString() ?? ''));
        }
      }
    }
  }

  InputDecoration _buildInputDecoration({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
      prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportMakerBloc(ReportAPIService())..add(LoadApis()),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Report Maker', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 6, bottom: 6),
              child: ElevatedButton.icon(
                icon: Icon(Icons.edit, color: Colors.blue.shade800, size: 20),
                label: Text(
                  "Edit Reports",
                  style: GoogleFonts.poppins(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditReportMaker())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade800,
                  shape: const StadiumBorder(),
                  elevation: 2,
                ),
              ),
            ),
          ],
          elevation: 4,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[800]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: BlocListener<ReportMakerBloc, ReportMakerState>(
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!), backgroundColor: Colors.redAccent));
            } else if (state.saveSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report saved successfully!'), backgroundColor: Colors.green));
              _reportNameController.clear();
              _reportLabelController.clear();
              _apiController.clear();
              _ucodeController.clear();
              setState(() {
                _selectedApi = null;
                _showConfigPanel = false;
              });
              context.read<ReportMakerBloc>().add(ResetFields());
              _animationController.reset();
            }
            _updateFieldConfigControllers(state.currentField);
            _updateActionControllers(state.actions);
          },
          child: BlocBuilder<ReportMakerBloc, ReportMakerState>(
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Card(
                      elevation: 6,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: _toggleMainReportDetails,
                              borderRadius: BorderRadius.circular(8),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Report Details', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)), Icon(_showMainReportDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey[600])]),
                            ),
                            AnimatedSwitcher(duration: const Duration(milliseconds: 300), transitionBuilder: (child, animation) => SizeTransition(sizeFactor: animation, axisAlignment: -1.0, child: FadeTransition(opacity: animation, child: child)), child: _showMainReportDetails ? _buildMainReportDetailsPanel(context, state) : const SizedBox.shrink(key: ValueKey('empty-details'))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 6,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: _toggleFieldsConfigurationContent,
                              borderRadius: BorderRadius.circular(8),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Fields Configuration', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)), Icon(_showFieldsConfigurationContent ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey[600])]),
                            ),
                            AnimatedSwitcher(duration: const Duration(milliseconds: 300), transitionBuilder: (child, animation) => SizeTransition(sizeFactor: animation, axisAlignment: -1.0, child: FadeTransition(opacity: animation, child: child)), child: _showFieldsConfigurationContent ? _buildFieldsSection(context, state) : const SizedBox.shrink(key: ValueKey('empty-fields'))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildActionSection(context, state),
                    const SizedBox(height: 24),
                    _buildButton(
                        text: 'Save Report',
                        color: Colors.green,
                        onPressed: () {
                          if (_reportNameController.text.isEmpty || _reportLabelController.text.isEmpty || _ucodeController.text.isEmpty || _selectedApi == null || state.selectedFields.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all report details and select at least one field.'), backgroundColor: Colors.redAccent));
                            return;
                          }
                          context.read<ReportMakerBloc>().add(SaveReport(reportName: _reportNameController.text, reportLabel: _reportLabelController.text, apiName: _selectedApi!, ucode: _ucodeController.text, parameter: 'default', needsAction: state.needsAction, actions: state.actions, includePdfFooterDateTime: state.includePdfFooterDateTime));
                        },
                        icon: Icons.save),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _buildModernInputDecoration({required String label, required IconData icon, bool isReadOnly = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 16),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixIcon: Icon(icon, color: isReadOnly ? Colors.grey[600] : Colors.blue.shade700, size: 22),
      filled: true,
      fillColor: isReadOnly ? Colors.grey.shade200 : Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
      ),
    );
  }

  Widget _buildMainReportDetailsPanel(BuildContext context, ReportMakerState state) {
    return Column(
      key: const ValueKey('reportDetailsContent'),
      children: [
        const Divider(height: 24, thickness: 1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _reportNameController,
                style: GoogleFonts.poppins(fontSize: 16),
                decoration: _buildModernInputDecoration(label: 'Report Name', icon: Icons.description),
                onChanged: _generateUniqueCode,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _reportLabelController,
                style: GoogleFonts.poppins(fontSize: 16),
                decoration: _buildModernInputDecoration(label: 'Report Label', icon: Icons.label),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Autocomplete<String>(
                optionsBuilder: (v) => v.text.isEmpty ? const Iterable.empty() : state.apis.where((api) => api.toLowerCase().contains(v.text.toLowerCase())),
                onSelected: (s) {
                  setState(() => _selectedApi = s);
                  _apiController.text = s;
                  context.read<ReportMakerBloc>().add(FetchApiData(s));
                  FocusScope.of(context).unfocus();
                },
                fieldViewBuilder: (c, controller, f, on) {
                  return TextField(
                    controller: controller,
                    focusNode: f,
                    style: GoogleFonts.poppins(fontSize: 16),
                    decoration: _buildModernInputDecoration(label: 'API Name', icon: Icons.api),
                    onChanged: (val) {
                      _selectedApi = val;
                      _apiController.text = val;
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _ucodeController,
                readOnly: true,
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
                decoration: _buildModernInputDecoration(label: 'Unique Code', icon: Icons.vpn_key, isReadOnly: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // A sleeker checkbox implementation
        InkWell(
          onTap: () {
            context.read<ReportMakerBloc>().add(ToggleIncludePdfFooterDateTime(!state.includePdfFooterDateTime));
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Checkbox(
                  value: state.includePdfFooterDateTime,
                  onChanged: (v) => context.read<ReportMakerBloc>().add(ToggleIncludePdfFooterDateTime(v!)),
                  activeColor: Colors.blueAccent,
                ),
                Text('Print Date/Time in Footer', style: GoogleFonts.poppins(fontSize: 16)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.refresh, color: Colors.redAccent),
              label: Text('Reset All', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onPressed: () {
                _reportNameController.clear();
                _reportLabelController.clear();
                _apiController.clear();
                _ucodeController.clear();
                setState(() {
                  _selectedApi = null;
                  _showConfigPanel = false;
                });
                context.read<ReportMakerBloc>().add(ResetFields());
                _animationController.reset();
              },
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildFieldsSection(BuildContext context, ReportMakerState state) {
    return Column(
      key: const ValueKey('fieldsConfigContent'),
      children: [
        const Divider(height: 20, thickness: 1),
        if (state.isLoading) const SizedBox(height: 200, child: SubtleLoader())
        else if (state.fields.isEmpty && _selectedApi != null) const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('No fields found for the selected API.')))
        else if (state.fields.isEmpty && _selectedApi == null) const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('Select an API to load fields.')))
          else _showConfigPanel ? FadeTransition(opacity: _fadeAnimation, child: _buildFieldConfigPanel(context, state)) : _buildFieldSelection(context, state),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, String? label, FocusNode? focusNode, TextInputType? keyboardType, Function(String)? onChanged, IconData? icon, bool readOnly = false}) {
    return TextField(controller: controller, focusNode: focusNode, keyboardType: keyboardType, onChanged: onChanged, readOnly: readOnly, style: GoogleFonts.poppins(fontSize: 16, color: readOnly ? Colors.black54 : Colors.black87), decoration: InputDecoration(labelText: label, labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600), prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22) : null, filled: true, fillColor: readOnly ? Colors.grey.shade200 : Colors.white.withOpacity(0.9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5))));
  }

  Widget _buildButton({required String text, required Color color, required VoidCallback? onPressed, IconData? icon}) {
    return ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), elevation: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [if(icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)], Text(text, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16))]));
  }

  Widget _buildFieldSelection(BuildContext context, ReportMakerState state) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Select Fields', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Wrap(
                spacing: 12, runSpacing: 12,
                children: state.fields.map((field) {
                  final isSelected = state.selectedFields.any((f) => f['Field_name'] == field);
                  return FilterChip(
                    label: Text(field, style: GoogleFonts.poppins(color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    selectedColor: Colors.blueAccent,
                    checkmarkColor: Colors.white,
                    onSelected: (selected) => context.read<ReportMakerBloc>().add(selected ? SelectField(field) : DeselectField(field)),
                  );
                }).toList(),
              ),
            ),
          ),
          if (state.selectedFields.isNotEmpty) ...[const SizedBox(height: 24), Center(child: _buildButton(text: 'Configure Selected Fields', color: Colors.blueAccent, onPressed: _toggleConfigPanel, icon: Icons.arrow_forward))],
        ],
      ),
    );
  }

  Widget _buildFieldConfigPanel(BuildContext context, ReportMakerState state) {
    final sortedFields = List<Map<String, dynamic>>.from(state.selectedFields)..sort((a, b) => (a['Sequence_no'] as int? ?? 9999).compareTo(b['Sequence_no'] as int? ?? 9999));
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7, minHeight: 400),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 250,
            child: Column(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: sortedFields.length,
                    onReorder: (oldIndex, newIndex) => context.read<ReportMakerBloc>().add(ReorderFields(oldIndex, newIndex)),
                    itemBuilder: (context, index) {
                      final field = sortedFields[index];
                      // FIX: Key is now on the direct child of the builder
                      return _buildReorderableFieldItem(context, state, field, index, sortedFields.length);
                    },
                  ),
                ),
                Padding(padding: const EdgeInsets.all(8.0), child: _buildButton(text: 'Back to Selection', color: Colors.grey.shade700, onPressed: _returnToFieldSelection, icon: Icons.arrow_back)),
              ],
            ),
          ),
          Container(width: 1, color: Colors.grey.shade300),
          Expanded(
            child: state.currentField == null ? Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text('Select a field from the left to configure.', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey))))
                : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: _buildAdvancedFieldConfigWidgets(context, state))),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableFieldItem(BuildContext context, ReportMakerState state, Map<String, dynamic> field, int index, int total) {
    final isSelected = state.currentField?['Field_name'] == field['Field_name'];
    return ReorderableDelayedDragStartListener(
      key: ValueKey(field['Field_name']),
      index: index,
      child: InkWell(
        onTap: () => context.read<ReportMakerBloc>().add(UpdateCurrentField(field)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 2, height: 22, color: index == 0 ? Colors.transparent : Colors.grey.shade300),
                  CircleAvatar(radius: 14, backgroundColor: isSelected ? Colors.blueAccent : Colors.grey.shade300, child: Text('${field['Sequence_no']}', style: GoogleFonts.poppins(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 12))),
                  Container(width: 2, height: 22, color: index == total - 1 ? Colors.transparent : Colors.grey.shade300),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blueAccent.withOpacity(0.08) : Colors.transparent,
                    border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(field['Field_name'], style: GoogleFonts.poppins(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? Colors.blueAccent : Colors.black87), overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAdvancedFieldConfigWidgets(BuildContext context, ReportMakerState state) {
    if (state.currentField == null) return [];
    final bool isApiDriven = state.currentField!['is_api_driven'] ?? false;
    final bool isUserFilling = state.currentField!['is_user_filling'] ?? false;

    Widget buildCheckbox(String title, bool value, ValueChanged<bool?> onChanged, {String? subtitle}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Checkbox(value: value, onChanged: onChanged, activeColor: Colors.blueAccent),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins()),
                    if (subtitle != null) Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return [
      TextField(controller: _fieldNameController, readOnly: true, decoration: _buildInputDecoration(label: 'Field Name', icon: Icons.text_fields)),
      const SizedBox(height: 16),
      TextField(controller: _fieldLabelController, decoration: _buildInputDecoration(label: 'Field Label', icon: Icons.label_outline), onChanged: (v) => context.read<ReportMakerBloc>().add(UpdateFieldConfig('Field_label', v))),
      const SizedBox(height: 16),
      buildCheckbox('Is API Driven?', isApiDriven, isUserFilling ? (v){} : (v) => context.read<ReportMakerBloc>().add(ToggleFieldApiDriven(v!))),
      if (isApiDriven) ...[
        const SizedBox(height: 8),
        TextField(controller: _apiDrivenUrlController, decoration: _buildInputDecoration(label: 'API URL', icon: Icons.link), onChanged: (v) { context.read<ReportMakerBloc>().add(UpdateFieldApiUrl(v)); if (v.isNotEmpty) { context.read<ReportMakerBloc>().add(ExtractFieldParametersFromUrl(state.currentField!['Field_name'], v)); } }),
      ],
      const SizedBox(height: 8),
      buildCheckbox('Is User Filling?', isUserFilling, isApiDriven ? (v){} : (v) => context.read<ReportMakerBloc>().add(ToggleFieldUserFilling(v!))),
      if (isUserFilling) ...[
        const SizedBox(height: 8),
        TextField(controller: _userFillingUrlController, decoration: _buildInputDecoration(label: 'Updated URL', icon: Icons.link), onChanged: (v) => context.read<ReportMakerBloc>().add(UpdateFieldUserFillingUrl(v))),
      ] else if (!isApiDriven && !isUserFilling) ...[
        const SizedBox(height: 16),
        TextField(controller: _sequenceController, decoration: _buildInputDecoration(label: 'Sequence No', icon: Icons.sort), keyboardType: TextInputType.number, onChanged: (v) => context.read<ReportMakerBloc>().add(UpdateFieldConfig('Sequence_no', int.tryParse(v) ?? 0))),
        const SizedBox(height: 16),
        TextField(controller: _widthController, decoration: _buildInputDecoration(label: 'Width', icon: Icons.width_normal), keyboardType: TextInputType.number, onChanged: (v) => context.read<ReportMakerBloc>().add(UpdateFieldConfig('width', int.tryParse(v) ?? 100))),
        const SizedBox(height: 16),
        buildCheckbox('Total', state.currentField!['Total'] ?? false, (v) => context.read<ReportMakerBloc>().add(UpdateFieldConfig('Total', v!))),
        if (state.currentField!['Total'] == true) buildCheckbox('Subtotal', state.currentField!['SubTotal'] ?? false, (v) => context.read<ReportMakerBloc>().add(UpdateFieldConfig('SubTotal', v!))),
        buildCheckbox('Breakpoint', state.currentField!['Breakpoint'] ?? false, (v) => context.read<ReportMakerBloc>().add(UpdateFieldConfig('Breakpoint', v!))),
        buildCheckbox('Image', state.currentField!['image'] ?? false, (v) => context.read<ReportMakerBloc>().add(UpdateFieldConfig('image', v!))),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: _buildInputDecoration(label: 'Number Alignment'),
          value: state.currentField!['num_alignment'] ?? 'left',
          items: ['left', 'center', 'right'].map((a) => DropdownMenuItem(value: a, child: Text(a.toCapitalized()))).toList(),
          onChanged: (v) => context.read<ReportMakerBloc>().add(UpdateFieldConfig('num_alignment', v!)),
          dropdownColor: Colors.white,
          menuMaxHeight: 300.0,
        ),
        const SizedBox(height: 16),
        buildCheckbox('Indian Number Format', state.currentField!['num_format'] ?? false, (v) => context.read<ReportMakerBloc>().add(UpdateFieldConfig('num_format', v!)), subtitle: 'Example: 12,34,567'),
        const SizedBox(height: 16),
        TextField(controller: _decimalPointsController, decoration: _buildInputDecoration(label: 'Decimal Points', icon: Icons.numbers), keyboardType: TextInputType.number, onChanged: (v) => context.read<ReportMakerBloc>().add(UpdateFieldConfig('decimal_points', int.tryParse(v) ?? 0))),
        if (state.currentField!['Field_name'].toString().toLowerCase().contains('date')) ...[
          const SizedBox(height: 8),
          buildCheckbox('Show Time', state.currentField!['time'] ?? false, (v) => context.read<ReportMakerBloc>().add(UpdateFieldConfig('time', v!))),
        ],
      ],
    ];
  }

  Widget _buildActionSection(BuildContext context, ReportMakerState state) {
    bool canAddMoreActions = state.actions.length < 5;
    bool formExists = state.actions.any((a) => a['type'] == 'form');
    final currentAction =
    state.actions.firstWhereOrNull((a) => a['id'] == _currentActionId);

    return Card(
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with modern toggle
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.flash_on, color: Colors.blueAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Actions',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                      Text('Enable and configure additional interactions',
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                // Cupertino-like switch
                Switch.adaptive(
                  value: state.needsAction,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.blueAccent,
                  onChanged: (value) => context
                      .read<ReportMakerBloc>()
                      .add(ToggleNeedsActionEvent(value)),
                ),
              ],
            ),

            // Collapsible content
            AnimatedCrossFade(
              crossFadeState: state.needsAction
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
              firstCurve: Curves.easeInOut,
              secondCurve: Curves.easeInOut,
              sizeCurve: Curves.easeInOut,
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Divider(height: 24, thickness: 1),

                  // Add Actions header
                  Row(
                    children: [
                      Text('Add Actions',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          '${state.actions.length}/5',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                      const Spacer(),
                      if (!canAddMoreActions)
                        Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.redAccent, size: 18),
                            const SizedBox(width: 6),
                            Text('Max actions reached',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.redAccent)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Action adders as modern “soft” buttons
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _softActionButton(
                        label: 'Form',
                        icon: Icons.assignment,
                        color: Colors.purple,
                        onPressed: canAddMoreActions && !formExists
                            ? () => context
                            .read<ReportMakerBloc>()
                            .add(AddAction('form', _uuid.v4()))
                            : null,
                      ),
                      _softActionButton(
                        label: 'Print',
                        icon: Icons.print,
                        color: Colors.orange,
                        onPressed: canAddMoreActions
                            ? () => context
                            .read<ReportMakerBloc>()
                            .add(AddAction('print', _uuid.v4()))
                            : null,
                      ),
                      _softActionButton(
                        label: 'Report',
                        icon: Icons.table_chart,
                        color: Colors.teal,
                        onPressed: canAddMoreActions
                            ? () => context
                            .read<ReportMakerBloc>()
                            .add(AddAction('table', _uuid.v4()))
                            : null,
                      ),
                      _softActionButton(
                        label: 'Graph',
                        icon: Icons.bar_chart,
                        color: Colors.indigo,
                        onPressed: canAddMoreActions
                            ? () => context
                            .read<ReportMakerBloc>()
                            .add(AddAction('graph', _uuid.v4()))
                            : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  if (state.actions.isNotEmpty) ...[
                    // Action selector chips
                    Text('Your Actions',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(height: 10),
                    _modernActionTabs(context, state), // REPLACED CHIP-SET
                    const SizedBox(height: 14),

                    // Config card with smooth transition
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: currentAction != null
                          ? _buildActionConfigCard(context, state, currentAction)
                          : const SizedBox.shrink(),
                    )
                  ] else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              color: Colors.amber.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No actions added yet. Add an action to get started.',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

// Soft, modern action add button
  Widget _softActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled ? Colors.grey.shade300 : color.withOpacity(0.5),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: disabled ? Colors.grey : color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: disabled ? Colors.grey : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

// NEW: Modern action tabs using custom-styled InkWell widgets
  Widget _modernActionTabs(BuildContext context, ReportMakerState state) {
    IconData getIcon(String type) {
      switch (type) {
        case 'form': return Icons.assignment;
        case 'print': return Icons.print;
        case 'table': return Icons.table_chart;
        case 'graph': return Icons.bar_chart;
        default: return Icons.help_outline;
      }
    }
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.actions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final action = state.actions[index];
          final actionId = action['id'] as String;
          final isSelected = _currentActionId == actionId;
          final controller = _actionNameControllers[actionId];

          return InkWell(
            onTap: () {
              setState(() => _currentActionId = actionId);
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blueAccent : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    getIcon(action['type']),
                    size: 18,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                  const SizedBox(width: 8),
                  ListenableBuilder(
                    listenable: controller!,
                    builder: (context, child) => Text(
                      controller.text.isNotEmpty ? controller.text : (action['name'] ?? 'Action'),
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }



  Widget _buildActionConfigCard(BuildContext context, ReportMakerState state, Map<String, dynamic> action) {
    // Using actionId as the key for AnimatedSwitcher
    final actionId = action['id'] as String;
    final actionType = action['type'] as String;
    final List<dynamic> params = action['params'] as List<dynamic>? ?? [];
    final bool isPrintOrTable = actionType == 'print' || actionType == 'table';
    final bool isTableAction = actionType == 'table';
    final List<String> apiParameters = state.apiParametersCache[actionId] ?? [];
    final bool isFetchingParams = state.isFetchingApiParams && state.currentActionIdFetching == actionId;
    final List<String> reportLabels = state.allReportLabels;
    final List<String> allApiFieldNames = state.fields;

    IconData typeIcon;
    Color typeColor;
    String headerText;
    switch (actionType) {
      case 'form': typeIcon = Icons.assignment; typeColor = Colors.purple; headerText = 'Form Action'; break;
      case 'print': typeIcon = Icons.print; typeColor = Colors.orange; headerText = 'Print Action'; break;
      case 'table': typeIcon = Icons.table_chart; typeColor = Colors.teal; headerText = 'Report Action'; break;
      case 'graph': typeIcon = Icons.bar_chart; typeColor = Colors.indigo; headerText = 'Graph Action'; break;
      default: typeIcon = Icons.help_outline; typeColor = Colors.grey; headerText = 'Unknown Action';
    }

    final String selectedTemplate = action['printTemplate']?.toString() ?? PrintTemplateForMaker.premium.name;
    final String selectedColor = action['printColor']?.toString() ?? 'Blue';
    final String selectedGraphType = action['graphType']?.toString() ?? 'Line Chart';

    return Card(
      key: ValueKey(actionId), // Important for AnimatedSwitcher
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [Icon(typeIcon, color: typeColor, size: 24), const SizedBox(width: 8), Text(headerText, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: typeColor))]),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => context.read<ReportMakerBloc>().add(RemoveAction(actionId))),
              ],
            ),
            const Divider(height: 24),
            TextField(
                controller: _actionNameControllers[actionId]!,
                style: GoogleFonts.poppins(),
                decoration: _actionInputDecoration(label: '${StringCasingExtension(actionType).toCapitalized()} Name', icon: Icons.title),
                onChanged: (value) => context.read<ReportMakerBloc>().add(UpdateActionConfig(actionId, 'name', value))
            ),
            const SizedBox(height: 16),
            if (actionType == 'graph') ...[
              DropdownButtonFormField<String>(
                decoration: _actionInputDecoration(label: 'Graph Type', icon: Icons.show_chart),
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
                value: selectedGraphType,
                items: ["Line Chart", "Bar Chart", "Pie Chart"]
                    .map((type) => DropdownMenuItem<String>(value: type, child: Text(type, style: GoogleFonts.poppins())))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    context.read<ReportMakerBloc>().add(UpdateActionConfig(actionId, 'graphType', value));
                  }
                },
                dropdownColor: Colors.white,
                menuMaxHeight: 300.0,
              ),
              const SizedBox(height: 16),

              _GraphAxisField(
                key: ValueKey('${actionId}_x_axis'),
                allApiFieldNames: allApiFieldNames,
                actionId: actionId,
                fieldKey: 'xAxisField',
                initialValue: action['xAxisField'] as String? ?? '',
                label: 'X-Axis Field',
                icon: Icons.arrow_right_alt,
              ),
              const SizedBox(height: 16),

              _GraphAxisField(
                key: ValueKey('${actionId}_y_axis'),
                allApiFieldNames: allApiFieldNames,
                actionId: actionId,
                fieldKey: 'yAxisField',
                initialValue: action['yAxisField'] as String? ?? '',
                label: 'Y-Axis Field',
                icon: Icons.arrow_upward,
              ),
            ],

            if (isTableAction) ...[
              Autocomplete<String>(
                key: _autocompleteFieldKeys.putIfAbsent(actionId, () => GlobalKey()),
                optionsBuilder: (v) => v.text.isEmpty
                    ? const Iterable.empty()
                    : reportLabels.where((o) => o.toLowerCase().contains(v.text.toLowerCase())),
                onSelected: (s) {
                  _actionReportLabelControllers[actionId]!.text = s;
                  context.read<ReportMakerBloc>().add(UpdateTableActionReport(actionId, s));
                },
                fieldViewBuilder: (c, controller, f, on) {
                  controller.text = _actionReportLabelControllers[actionId]!.text;
                  controller.selection = _actionReportLabelControllers[actionId]!.selection;
                  return TextField(
                    controller: controller,
                    focusNode: f,
                    decoration: _actionInputDecoration(label: 'Select Report Name', icon: Icons.description),
                    onChanged: (v) {
                      _actionReportLabelControllers[actionId]!.text = v;
                      context.read<ReportMakerBloc>().add(UpdateActionConfig(actionId, 'reportLabel', v));
                    },
                  );
                },
                optionsViewBuilder: (c, onSelected, options) {
                  final renderBox = _autocompleteFieldKeys[actionId]?.currentContext?.findRenderObject() as RenderBox?;
                  final width = renderBox?.size.width ?? MediaQuery.of(context).size.width;
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: SizedBox(
                        width: width,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (c, i) {
                            final option = options.elementAt(i);
                            return ListTile(title: Text(option), onTap: () => onSelected(option));
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _actionApiControllers[actionId]!,
                readOnly: true,
                decoration: _actionInputDecoration(label: 'Resolved API URL', icon: Icons.link),
              ),
            ],

            if (actionType == 'print') ...[
              TextField(
                controller: _actionApiControllers[actionId]!,
                decoration: _actionInputDecoration(label: 'API URL', icon: Icons.link),
                onChanged: (value) {
                  context.read<ReportMakerBloc>().add(UpdateActionConfig(actionId, 'api', value));
                  Future.delayed(const Duration(milliseconds: 700), () {
                    if (_actionApiControllers[actionId]?.text == value && value.isNotEmpty) {
                      context.read<ReportMakerBloc>().add(ExtractParametersFromUrlForAction(actionId, value));
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: _actionInputDecoration(label: 'Print Template'),
                value: selectedTemplate,
                items: PrintTemplateForMaker.values
                    .map((t) => DropdownMenuItem<String>(value: t.name, child: Text(t.displayName, style: GoogleFonts.poppins())))
                    .toList(),
                onChanged: (v) => context.read<ReportMakerBloc>().add(UpdateActionConfig(actionId, 'printTemplate', v!)),
                dropdownColor: Colors.white,
                menuMaxHeight: 300.0,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: _actionInputDecoration(label: 'Theme Color'),
                value: selectedColor,
                items: predefinedPdfColors.keys
                    .map((c) => DropdownMenuItem<String>(
                  value: c,
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: predefinedPdfColors[c]!.toFlutterColor(),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(c, style: GoogleFonts.poppins()),
                    ],
                  ),
                ))
                    .toList(),
                onChanged: (v) => context.read<ReportMakerBloc>().add(UpdateActionConfig(actionId, 'printColor', v!)),
                dropdownColor: Colors.white,
                menuMaxHeight: 300.0,
              ),
            ],

            if (isPrintOrTable) ...[
              const Divider(height: 32),
              Row(
                children: [
                  Text('Dynamic Parameters:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                    onPressed: () => context.read<ReportMakerBloc>().add(AddActionParameter(actionId, _uuid.v4())),
                  ),
                ],
              ),
              if (isFetchingParams)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [SubtleLoader(), SizedBox(width: 8), Text('Fetching parameters...')],
                  ),
                )
              else if (action['api']?.isNotEmpty == true && apiParameters.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No parameters found for this API.', style: GoogleFonts.poppins(color: Colors.redAccent)),
                )
              else
                Column(
                  children: params.map<Widget>((param) {
                    final paramId = param['id'] as String;
                    final paramValueController = _actionParamValueControllers[actionId]![paramId]!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200)
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                decoration: _actionInputDecoration(label: 'Parameter Name'),
                                value: apiParameters.contains(param['parameterName']) ? param['parameterName'] : null,
                                items: apiParameters.map((n) => DropdownMenuItem<String>(value: n, child: Text(n))).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    context.read<ReportMakerBloc>().add(UpdateActionParameter(actionId, paramId, 'parameterName', v));
                                  }
                                },
                                dropdownColor: Colors.white,
                                menuMaxHeight: 300.0,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: Autocomplete<String>(
                                optionsBuilder: (v) => v.text.isEmpty
                                    ? const Iterable.empty()
                                    : allApiFieldNames.where((o) => o.toLowerCase().contains(v.text.toLowerCase())),
                                onSelected: (s) {
                                  FocusScope.of(context).unfocus();
                                  paramValueController.text = s;
                                  context.read<ReportMakerBloc>().add(UpdateActionParameter(actionId, paramId, 'parameterValue', s));
                                },
                                fieldViewBuilder: (c, controller, f, on) {
                                  controller.text = paramValueController.text;
                                  return TextField(
                                    controller: controller,
                                    focusNode: f,
                                    decoration: _actionInputDecoration(label: 'Value'),
                                    onChanged: (v) {
                                      paramValueController.text = v;
                                      context.read<ReportMakerBloc>().add(UpdateActionParameter(actionId, paramId, 'parameterValue', v));
                                    },
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                              onPressed: () => context.read<ReportMakerBloc>().add(RemoveActionParameter(actionId, paramId)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],

          ],
        ),
      ),
    );
  }
}

class _GraphAxisField extends StatefulWidget {
  final List<String> allApiFieldNames;
  final String actionId;
  final String fieldKey;
  final String initialValue;
  final String label;
  final IconData icon;

  const _GraphAxisField({
    Key? key,
    required this.allApiFieldNames,
    required this.actionId,
    required this.fieldKey,
    required this.initialValue,
    required this.label,
    required this.icon,
  }) : super(key: key);

  @override
  State<_GraphAxisField> createState() => _GraphAxisFieldState();
}

class _GraphAxisFieldState extends State<_GraphAxisField> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.initialValue),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return widget.allApiFieldNames;
        }
        return widget.allApiFieldNames.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        FocusScope.of(context).unfocus();
        _debounceTimer?.cancel();
        context.read<ReportMakerBloc>().add(UpdateActionConfig(widget.actionId, widget.fieldKey, selection));
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
          decoration: _actionInputDecoration(label: widget.label, icon: widget.icon),

          onChanged: (value) {
            if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 400), () {
              if(mounted) {
                context.read<ReportMakerBloc>().add(UpdateActionConfig(widget.actionId, widget.fieldKey, value));
              }
            });
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final renderBox = context.findRenderObject() as RenderBox?;
        final width = renderBox?.size.width ?? MediaQuery.of(context).size.width * 0.4;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: SizedBox(
              width: width,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(title: Text(option, style: GoogleFonts.poppins()), onTap: () => onSelected(option));
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PayloadParameterItem extends StatefulWidget {
  final Map<String, dynamic> param;
  final List<String> allApiFieldNames;
  final Function(Map<String, dynamic> updatedParam) onUpdate;
  final Function(bool value) onToggleUserInput;
  final VoidCallback onRemove;
  final TextEditingController keyController;
  final TextEditingController staticValueController;
  final String fieldName;

  const _PayloadParameterItem({
    Key? key,
    required this.param,
    required this.allApiFieldNames,
    required this.onUpdate,
    required this.onToggleUserInput,
    required this.onRemove,
    required this.keyController,
    required this.staticValueController,
    required this.fieldName,
  }) : super(key: key);

  @override
  __PayloadParameterItemState createState() => __PayloadParameterItemState();
}

class __PayloadParameterItemState extends State<_PayloadParameterItem> {
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.keyController.addListener(_onKeyChanged);
    widget.staticValueController.addListener(_onStaticValueChanged);
  }

  void _onKeyChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (widget.keyController.text != (widget.param['key']?.toString() ?? '')) {
        widget.onUpdate({'property_name': 'key', 'property_value': widget.keyController.text});
      }
    });
  }

  void _onStaticValueChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (widget.staticValueController.text != (widget.param['value']?.toString() ?? '')) {
        widget.onUpdate({'property_name': 'value', 'property_value': widget.staticValueController.text});
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.keyController.removeListener(_onKeyChanged);
    widget.staticValueController.removeListener(_onStaticValueChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String valueType = widget.param['value_type']?.toString() ?? 'dynamic';
    final bool isUserInput = widget.param['is_user_input'] ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 1, child: TextField(controller: widget.keyController, style: GoogleFonts.poppins(), decoration: InputDecoration(labelText: 'Key', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Value Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), value: valueType, items: const [DropdownMenuItem(value: 'static', child: Text('Static')), DropdownMenuItem(value: 'dynamic', child: Text('Dynamic (Map to Field)'))], onChanged: (v) {if(v != null) { widget.onUpdate({'property_name': 'value_type', 'property_value': v}); widget.onUpdate({'property_name': 'value', 'property_value': ''});}}),
              if (valueType == 'static') Padding(padding: const EdgeInsets.only(top: 8.0), child: TextField(controller: widget.staticValueController, style: GoogleFonts.poppins(), decoration: InputDecoration(labelText: 'Literal Value', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))))
              else if (valueType == 'dynamic') Padding(padding: const EdgeInsets.only(top: 8.0), child: Autocomplete<String>(initialValue: TextEditingValue(text: widget.param['value']?.toString() ?? ''), optionsBuilder: (v) => v.text.isEmpty ? const Iterable.empty() : widget.allApiFieldNames.where((o) => o.toLowerCase().contains(v.text.toLowerCase())), onSelected: (s) {FocusScope.of(context).unfocus(); widget.onUpdate({'property_name': 'value', 'property_value': s}); _debounceTimer?.cancel();}, fieldViewBuilder: (c, controller, f, on) {if (!f.hasFocus && controller.text != (widget.param['value']?.toString() ?? '')) {controller.text = widget.param['value']?.toString() ?? '';} return TextField(controller: controller, focusNode: f, style: GoogleFonts.poppins(), decoration: InputDecoration(labelText: 'Select Field', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), onChanged: (v) {if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel(); _debounceTimer = Timer(const Duration(milliseconds: 300), () => widget.onUpdate({'property_name': 'value', 'property_value': v}));});}))
            ])),
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: widget.onRemove),
          ]),
          CheckboxListTile(title: Text('User Input Field', style: GoogleFonts.poppins(fontSize: 14)), value: isUserInput, onChanged: (v) => widget.onToggleUserInput(v!), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, activeColor: Colors.blueAccent),
        ],
      ),
    );
  }
}