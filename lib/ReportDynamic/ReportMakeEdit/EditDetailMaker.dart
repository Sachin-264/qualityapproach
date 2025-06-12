import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import 'package:pdf/pdf.dart'; // For PdfColor constants
import 'dart:ui' as ui; // Import for ui.Color to distinguish from PdfColor

import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart'; // Assuming this provides ReportAPIService
import 'EditDetailMakerBloc.dart';

// Extension to capitalize first letter of a string
extension StringCasingExtension on String {
  String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
}

// Enum for print templates (matching printservice.dart)
enum PrintTemplateForMaker {
  premium,
  minimalist,
  corporate,
  modern,
}

// Extension to get display name for PrintTemplateForMaker
extension PrintTemplateForMakerExtension on PrintTemplateForMaker {
  String get displayName {
    switch (this) {
      case PrintTemplateForMaker.premium:
        return 'Premium';
      case PrintTemplateForMaker.minimalist:
        return 'Minimalist';
      case PrintTemplateForMaker.corporate:
        return 'Corporate';
      case PrintTemplateForMaker.modern:
        return 'Modern';
    }
  }
}

// Map for predefined PDF colors for selection
final Map<String, PdfColor> predefinedPdfColors = {
  'Blue': PdfColors.blue,
  'Red': PdfColors.red,
  'Green': PdfColors.green,
  'Orange': PdfColors.orange,
  'Purple': PdfColors.purple,
  'Grey': PdfColors.grey,
  'Black': PdfColors.black,
};

// NEW: Extension to convert PdfColor to Flutter's ui.Color
extension PdfColorToFlutterColor on PdfColor {
  ui.Color toFlutterColor() {
    return ui.Color.fromARGB(
      (alpha * 255).round(), // Alpha component (0.0-1.0 scaled to 0-255)
      (red * 255).round(),   // Red component (0.0-1.0 scaled to 0-255)
      (green * 255).round(), // Green component (0.0-1.0 scaled to 0-255)
      (blue * 255).round(),  // Blue component (0.0-1.0 scaled to 0-255)
    );
  }
}


class EditDetailMaker extends StatefulWidget {
  final int recNo;
  final String reportName;
  final String reportLabel;
  final String apiName;

  const EditDetailMaker({
    super.key,
    required this.recNo,
    required this.reportName,
    required this.reportLabel,
    required this.apiName,
  });

  @override
  _EditDetailMakerState createState() => _EditDetailMakerState();
}

class _EditDetailMakerState extends State<EditDetailMaker> with SingleTickerProviderStateMixin {
  final TextEditingController _reportNameController = TextEditingController();
  final TextEditingController _reportLabelController = TextEditingController();
  final TextEditingController _apiController = TextEditingController();
  final TextEditingController _fieldNameController = TextEditingController();
  final TextEditingController _fieldLabelController = TextEditingController();
  final TextEditingController _sequenceController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _decimalPointsController = TextEditingController();

  String? _selectedApi;
  bool _showConfigPanel = false; // For showing field config (left panel + right details) vs field selection (chips)
  bool _showMainReportDetails = true; // Control visibility of main report details card
  bool _showFieldsConfigurationContent = true; // Control visibility of field configuration card's *content*
  late EditDetailMakerBloc _bloc;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

// Controllers for actions, managed in maps by actionId
  final Map<String, TextEditingController> _actionNameControllers = {};
  final Map<String, TextEditingController> _actionApiControllers = {};
  final Map<String, TextEditingController> _actionReportLabelControllers = {};
  final Map<String, Map<String, TextEditingController>> _actionParamValueControllers = {};

  final Uuid _uuid = const Uuid();

// GlobalKey to get the size of the Autocomplete's TextField for optionsViewBuilder
// This will store keys like {'actionId_1': GlobalKey(), 'actionId_2': GlobalKey()}
  final Map<String, GlobalKey> _autocompleteFieldKeys = {};

  @override
  void initState() {
    super.initState();
    debugPrint('UI: EditDetailMaker initState: recNo=${widget.recNo}, apiName=${widget.apiName}'); // Retained debugPrint
    _reportNameController.text = widget.reportName;
    _reportLabelController.text = widget.reportLabel;
    _apiController.text = widget.apiName;
    _selectedApi = widget.apiName;

    _bloc = EditDetailMakerBloc(ReportAPIService());

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

// General listener for text controllers to move cursor to end.
    for (var controller in [
      _reportNameController,
      _reportLabelController,
      _apiController,
      _fieldNameController,
      _fieldLabelController,
      _sequenceController,
      _widthController,
      _decimalPointsController
    ]) {
      controller.addListener(_ensureCursorAtEnd(controller));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('UI: Dispatching LoadPreselectedFields: recNo=${widget.recNo}, apiName=${widget.apiName}'); // Retained debugPrint
      _bloc.add(LoadPreselectedFields(widget.recNo, widget.apiName));
    });
  }

// Helper to ensure cursor is at the end for text controllers
  VoidCallback _ensureCursorAtEnd(TextEditingController controller) {
    return () {
      if (controller.text.isNotEmpty && controller.selection.baseOffset < controller.text.length) {
        if (controller.selection.baseOffset != controller.text.length || controller.selection.extentOffset != controller.text.length) {
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        }
      }
    };
  }

  @override
  void dispose() {
    debugPrint('UI: EditDetailMaker dispose'); // Retained debugPrint
    _reportNameController.dispose();
    _reportLabelController.dispose();
    _apiController.dispose();
    _fieldNameController.dispose();
    _fieldLabelController.dispose();
    _sequenceController.dispose();
    _widthController.dispose();
    _decimalPointsController.dispose();
    _animationController.dispose();
    _bloc.close();

// Dispose all controllers in the maps
    _actionNameControllers.forEach((_, controller) => controller.dispose());
    _actionApiControllers.forEach((_, controller) => controller.dispose());
    _actionReportLabelControllers.forEach((_, controller) => controller.dispose());
    _actionParamValueControllers.forEach((_, paramMap) {
      paramMap.forEach((_, controller) => controller.dispose());
    });
    super.dispose();
  }

  void _toggleConfigPanel() {
    debugPrint('UI: Toggling config panel to show.'); // Retained debugPrint
    setState(() {
      _showConfigPanel = true;
      _showMainReportDetails = false;
      _showFieldsConfigurationContent = true;
      _animationController.forward();
    });
  }

  void _returnToFieldSelection() {
    debugPrint('UI: Returning to field selection: showConfigPanel=false'); // Retained debugPrint
    setState(() {
      _showConfigPanel = false;
      _animationController.reverse(from: 1.0);
    });
  }

  void _toggleMainReportDetails() {
    debugPrint('UI: Toggling main report details visibility.'); // Retained debugPrint
    setState(() {
      _showMainReportDetails = !_showMainReportDetails;
      if (_showMainReportDetails) {
        _showConfigPanel = false;
        _showFieldsConfigurationContent = false;
      }
    });
  }

  void _toggleFieldsConfigurationContent() {
    debugPrint('UI: Toggling fields configuration content visibility.'); // Retained debugPrint
    setState(() {
      _showFieldsConfigurationContent = !_showFieldsConfigurationContent;
      if (_showFieldsConfigurationContent) {
        _showMainReportDetails = false;
        _showConfigPanel = false;
      }
    });
  }

  void _updateFieldConfigControllers(Map<String, dynamic>? field) {
    debugPrint('UI: _updateFieldConfigControllers called with field=${field?['Field_name']}'); // Retained debugPrint
    if (field == null) {
      if (_fieldNameController.text.isNotEmpty || _fieldLabelController.text.isNotEmpty) {
        _fieldNameController.clear();
        _fieldLabelController.clear();
        _sequenceController.clear();
        _widthController.clear();
        _decimalPointsController.clear();
        debugPrint('UI: Cleared field config controllers (field is null).'); // Retained debugPrint
      }
    } else {
      if (_fieldNameController.text != (field['Field_name']?.toString() ?? '')) {
        _fieldNameController.text = field['Field_name']?.toString() ?? '';
      }
      if (_fieldLabelController.text != (field['Field_label']?.toString() ?? '')) {
        _fieldLabelController.text = field['Field_label']?.toString() ?? '';
      }
      if (_sequenceController.text != (field['Sequence_no']?.toString() ?? '')) {
        _sequenceController.text = field['Sequence_no']?.toString() ?? '';
      }
      if (_widthController.text != (field['width']?.toString() ?? '')) {
        _widthController.text = field['width']?.toString() ?? '';
      }
      if (_decimalPointsController.text != (field['decimal_points']?.toString() ?? '')) {
        _decimalPointsController.text = field['decimal_points']?.toString() ?? '';
      }
      debugPrint('UI: Updated field config controllers for ${field['Field_name']}.'); // Retained debugPrint
    }
  }

  void _updateActionControllers(List<Map<String, dynamic>> actions) {
    final Set<String> existingActionIds = actions.map((a) => a['id'] as String).toSet();

    _actionNameControllers.keys.toList().forEach((id) {
      if (!existingActionIds.contains(id)) {
        _actionNameControllers.remove(id)?.dispose();
        _actionApiControllers.remove(id)?.dispose();
        _actionReportLabelControllers.remove(id)?.dispose();
        _actionParamValueControllers.remove(id)?.forEach((_, controller) => controller.dispose());
        _actionParamValueControllers.remove(id);
        _autocompleteFieldKeys.remove(id); // Also remove the GlobalKey
      }
    });

    for (var action in actions) {
      final actionId = action['id'] as String;
      final actionType = action['type'] as String;

      if (!_actionNameControllers.containsKey(actionId)) {
        _actionNameControllers[actionId] = TextEditingController(text: action['name']?.toString() ?? '');
      } else if (_actionNameControllers[actionId]!.text != (action['name']?.toString() ?? '')) {
        _actionNameControllers[actionId]!.text = action['name']?.toString() ?? '';
      }

      if (!_actionApiControllers.containsKey(actionId)) {
        _actionApiControllers[actionId] = TextEditingController(text: action['api']?.toString() ?? '');
      } else if (_actionApiControllers[actionId]!.text != (action['api']?.toString() ?? '')) {
        _actionApiControllers[actionId]!.text = action['api']?.toString() ?? '';
      }

      if (actionType == 'table') {
        _autocompleteFieldKeys.putIfAbsent(actionId, () => GlobalKey());
        if (!_actionReportLabelControllers.containsKey(actionId)) {
          _actionReportLabelControllers[actionId] = TextEditingController(text: action['reportLabel']?.toString() ?? '');
          _actionReportLabelControllers[actionId]!.addListener(_ensureCursorAtEnd(_actionReportLabelControllers[actionId]!));
        } else if (_actionReportLabelControllers[actionId]!.text != (action['reportLabel']?.toString() ?? '')) {
          _actionReportLabelControllers[actionId]!.text = action['reportLabel']?.toString() ?? '';
        }
      } else {
        _autocompleteFieldKeys.remove(actionId);
        // FIX: Use actionId instead of 'id' which is out of scope here.
        _actionReportLabelControllers.remove(actionId)?.dispose();
      }

      if (actionType == 'print' || actionType == 'table') {
        final params = action['params'] as List<dynamic>? ?? [];
        if (!_actionParamValueControllers.containsKey(actionId)) {
          _actionParamValueControllers[actionId] = {};
        }

        final currentParamMap = _actionParamValueControllers[actionId]!;
        currentParamMap.keys.toList().forEach((paramId) {
          if (!params.any((p) => p['id'] == paramId)) {
            currentParamMap.remove(paramId)?.dispose();
          }
        });

        for (var param in params) {
          final paramId = param['id'] as String;
          if (!currentParamMap.containsKey(paramId)) {
            currentParamMap[paramId] = TextEditingController(text: param['parameterValue']?.toString() ?? '');
            currentParamMap[paramId]!.addListener(_ensureCursorAtEnd(currentParamMap[paramId]!));
          } else if (currentParamMap[paramId]!.text != (param['parameterValue']?.toString() ?? '')) {
            currentParamMap[paramId]!.text = param['parameterValue']?.toString() ?? '';
          }
        }
      } else {
        if (_actionParamValueControllers.containsKey(actionId)) {
          _actionParamValueControllers[actionId]?.forEach((_, controller) => controller.dispose());
          _actionParamValueControllers.remove(actionId);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('UI: Building EditDetailMaker UI'); // Retained debugPrint
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Edit Report Details',
          onBackPress: () {
            debugPrint('UI: AppBar back pressed'); // Retained debugPrint
            Navigator.pop(context, true);
          },
        ),
        body: BlocListener<EditDetailMakerBloc, EditDetailMakerState>(
          listener: (context, state) {
            debugPrint('UI: BlocListener: isLoading=${state.isLoading}, error=${state.error}, saveSuccess=${state.saveSuccess}, selectedFields=${state.selectedFields.length}, needsAction=${state.needsAction}, actions=${state.actions.length}'); // Retained debugPrint
            if (state.error != null) {
              debugPrint('UI: Showing error SnackBar: ${state.error}'); // Retained debugPrint
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.error!,
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 5),
                ),
              );
            } else if (state.saveSuccess) {
              debugPrint('UI: Showing success SnackBar'); // Retained debugPrint
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Report and field configurations updated successfully!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 5),
                ),
              );
              debugPrint('UI: Navigating back with refresh indicator'); // Retained debugPrint
              Navigator.pop(context, true);
            }
            _updateFieldConfigControllers(state.currentField);
            _updateActionControllers(state.actions);
          },
          child: BlocBuilder<EditDetailMakerBloc, EditDetailMakerState>(
            builder: (context, state) {
              debugPrint('UI: BlocBuilder: isLoading=${state.isLoading}, fields=${state.fields.length}, selectedFields=${state.selectedFields.length}, preselectedFields=${state.preselectedFields.length}'); // Retained debugPrint
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Report Details Section
                      Card(
                        color: Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _toggleMainReportDetails,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Report Details',
                                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                    Icon(
                                      _showMainReportDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: Colors.grey[600],
                                    ),
                                  ],
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return SizeTransition(
                                      sizeFactor: animation,
                                      axisAlignment: -1.0,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _showMainReportDetails
                                      ? Column(
                                    key: const ValueKey('reportDetailsContent'),
                                    children: [
                                      const Divider(height: 20, thickness: 1),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildTextField(
                                              controller: _reportNameController,
                                              label: 'Report Name',
                                              icon: Icons.description,
                                              onChanged: (value) {},
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildTextField(
                                              controller: _reportLabelController,
                                              label: 'Report Label',
                                              icon: Icons.label,
                                              onChanged: (value) {},
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildTextField(
                                              controller: _apiController,
                                              label: 'API Name',
                                              icon: Icons.api,
                                              readOnly: true,
                                              onChanged: (value) {},
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      // NEW: Checkbox for PDF Footer Date/Time
                                      CheckboxListTile(
                                        title: Text('Include Generation Date/Time in PDF Footer', style: GoogleFonts.poppins(fontSize: 16)),
                                        value: state.includePdfFooterDateTime,
                                        onChanged: (value) {
                                          debugPrint('UI: Include PDF Footer Date/Time checkbox changed to: $value'); // Retained debugPrint
                                          context.read<EditDetailMakerBloc>().add(ToggleIncludePdfFooterDateTime(value!));
                                        },
                                        activeColor: Colors.blueAccent,
                                        controlAffinity: ListTileControlAffinity.leading,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          _buildButton(
                                            text: 'Reset Form',
                                            color: Colors.redAccent,
                                            onPressed: () {
                                              debugPrint('UI: Reset Form button pressed'); // Retained debugPrint
                                              context.read<EditDetailMakerBloc>().add(ResetFields());
                                              _reportNameController.text = widget.reportName;
                                              _reportLabelController.text = widget.reportLabel;
                                              _apiController.text = widget.apiName;
                                              setState(() {
                                                _selectedApi = widget.apiName;
                                                _showConfigPanel = false;
                                                _showMainReportDetails = true;
                                                _showFieldsConfigurationContent = false;
                                              });
                                              _animationController.reset();
                                            },
                                            icon: Icons.refresh,
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                      : const SizedBox.shrink(key: ValueKey('reportDetailsEmpty')),
                                ),
                              ], // Closing bracket for children list
                            ), // Closing parenthesis for Column widget
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Field Configuration Section Card
                      Card(
                        color: Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _toggleFieldsConfigurationContent,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Fields Configuration',
                                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                    Icon(
                                      _showFieldsConfigurationContent ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: Colors.grey[600],
                                    ),
                                  ],
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return SizeTransition(
                                      sizeFactor: animation,
                                      axisAlignment: -1.0,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _showFieldsConfigurationContent
                                      ? Column(
                                    key: const ValueKey('fieldsConfigContent'),
                                    children: [
                                      const Divider(height: 20, thickness: 1, color: Colors.grey),
                                      if (state.isLoading)
                                        const SizedBox(height: 200, child: SubtleLoader())
                                      else if (state.error != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(vertical: 20),
                                          alignment: Alignment.center,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Error loading fields: ${state.error}',
                                                style: GoogleFonts.poppins(fontSize: 16, color: Colors.redAccent),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 16),
                                              _buildButton(
                                                text: 'Retry Load Fields',
                                                color: Colors.blueAccent,
                                                onPressed: () {
                                                  debugPrint('UI: Retry button pressed for field loading.'); // Retained debugPrint
                                                  context.read<EditDetailMakerBloc>().add(
                                                    LoadPreselectedFields(widget.recNo, widget.apiName),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (state.fields.isEmpty && state.selectedFields.isEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(vertical: 20),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'No fields available from the API for this report. Check API response.',
                                              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                                              textAlign: TextAlign.center,
                                            ),
                                          )
                                        else
                                          _showConfigPanel
                                              ? _buildFieldConfigPanel(context, state)
                                              : _buildFieldSelection(context, state),
                                    ],
                                  )
                                      : const SizedBox.shrink(key: ValueKey('fieldsConfigEmpty')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Action Section
                      _buildActionSection(context, state),
                      const SizedBox(height: 16),
                      // Save button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildButton(
                            text: 'Save Changes',
                            color: Colors.green,
                            onPressed: () {
                              debugPrint('UI: Save Changes button pressed'); // Retained debugPrint
                              if (_reportNameController.text.isEmpty ||
                                  _reportLabelController.text.isEmpty ||
                                  _selectedApi == null ||
                                  state.selectedFields.isEmpty) {
                                debugPrint('UI: Validation failed: showing SnackBar'); // Retained debugPrint
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Please fill all report details and select at least one field.'),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                                return;
                              }

                              if (state.currentField != null && _sequenceController.text.isNotEmpty) {
                                final parsed = int.tryParse(_sequenceController.text);
                                if (parsed != null && parsed > 0 && (state.currentField!['Sequence_no'] != parsed)) {
                                  debugPrint('UI: Final Sequence_no update before save for current field.'); // Retained debugPrint
                                  context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Sequence_no', parsed));
                                }
                              }

                              Future.delayed(const Duration(milliseconds: 100), () {
                                debugPrint('UI: Dispatching SaveReport event after potential field config update.'); // Retained debugPrint
                                context.read<EditDetailMakerBloc>().add(
                                  SaveReport(
                                    recNo: widget.recNo,
                                    reportName: _reportNameController.text,
                                    reportLabel: _reportLabelController.text,
                                    apiName: _selectedApi!,
                                    parameter: 'default',
                                    needsAction: state.needsAction,
                                    actions: state.actions,
                                    includePdfFooterDateTime: state.includePdfFooterDateTime, // Pass the new field
                                  ),
                                );
                              });
                            },
                            icon: Icons.save,
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? label,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    IconData? icon,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      onChanged: onChanged,
      readOnly: readOnly,
      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22) : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation: 4,
        shadowColor: color.withOpacity(0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldSelection(BuildContext context, EditDetailMakerState state) {
    debugPrint('UI: Building field selection view. Fields count: ${state.fields.length}, Selected count: ${state.selectedFields.length}, Preselected count: ${state.preselectedFields.length}'); // Retained debugPrint
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select Fields',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: state.fields.map((field) {
                  final isSelected = state.selectedFields.any((f) => f['Field_name'] == field);
                  final isPreselected = state.preselectedFields.any((f) => f['Field_name'] == field);

                  return FilterChip(
                    label: Text(
                      field,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: isPreselected && isSelected
                        ? Colors.blueAccent
                        : isSelected
                        ? Colors.green
                        : null,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isPreselected && isSelected
                            ? Colors.blueAccent
                            : isSelected
                            ? Colors.green
                            : Colors.grey.shade300,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    onSelected: (selected) {
                      debugPrint('UI: Chip tapped: field=$field, selected=$selected'); // Retained debugPrint
                      if (selected) {
                        context.read<EditDetailMakerBloc>().add(SelectField(field));
                      } else {
                        context.read<EditDetailMakerBloc>().add(DeselectField(field));
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          if (state.selectedFields.isNotEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: _buildButton(
                text: 'Configure Selected Fields',
                color: Colors.blueAccent,
                onPressed: _toggleConfigPanel,
                icon: Icons.arrow_forward,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldConfigPanel(BuildContext context, EditDetailMakerState state) {
    debugPrint('UI: Building field config panel. Selected fields count: ${state.selectedFields.length}'); // Retained debugPrint
    final sortedFields = List<Map<String, dynamic>>.from(state.selectedFields)
      ..sort((a, b) {
        final aSeq = a['Sequence_no'] as int? ?? 9999;
        final bSeq = b['Sequence_no'] as int? ?? 9999;
        return aSeq.compareTo(bSeq);
      });

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6, // Sets max height to 60% of screen height
        minHeight: 200, // Ensures a minimum height
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: sortedFields.length,
                    itemBuilder: (context, index) {
                      final field = sortedFields[index];
                      final isSelected = state.currentField?['Field_name'] == field['Field_name'];
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Material(
                              color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  debugPrint('UI: Field tapped in list: ${field['Field_name']}}'); // Retained debugPrint
                                  if (state.currentField != null && _sequenceController.text.isNotEmpty) {
                                    final parsed = int.tryParse(_sequenceController.text);
                                    if (parsed != null && parsed >= 0 && (state.currentField!['Sequence_no'] != parsed)) {
                                      context.read<EditDetailMakerBloc>().add(
                                        UpdateFieldConfig('Sequence_no', parsed),
                                      );
                                      debugPrint('UI: Updating sequence for previous field (${state.currentField!['Field_name']}) before switching.'); // Retained debugPrint
                                    }
                                  }
                                  context.read<EditDetailMakerBloc>().add(UpdateCurrentField(field));
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: isSelected ? Colors.blueAccent : Colors.grey.shade300,
                                        child: Text(
                                          '${field['Sequence_no'] ?? 'N/A'}',
                                          style: GoogleFonts.poppins(
                                            color: isSelected ? Colors.white : Colors.black87,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          field['Field_name'],
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            color: isSelected ? Colors.blueAccent : Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                        onPressed: () {
                                          debugPrint('UI: Deleting field from list: ${field['Field_name']}'); // Retained debugPrint
                                          context.read<EditDetailMakerBloc>().add(DeselectField(field['Field_name']));
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (index < sortedFields.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.grey.shade300,
                              indent: 24,
                              endIndent: 24,
                            ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: ElevatedButton(
                    onPressed: _returnToFieldSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 4,
                      shadowColor: Colors.blueAccent.withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Back to Selection',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: state.currentField == null
                  ? Center(
                child: Text(
                  'Select a field from the left panel to configure its properties.',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              )
                  : SingleChildScrollView(
                child: Column(
                  children: _buildFieldConfigWidgets(context, state),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFieldConfigWidgets(BuildContext context, EditDetailMakerState state) {
    debugPrint('UI: Building field config widgets for: ${state.currentField!['Field_name']}'); // Retained debugPrint
    if (state.currentField == null) {
      return [];
    }
    return [
      _buildTextField(
        controller: _fieldNameController,
        label: 'Field Name',
        icon: Icons.text_fields,
        readOnly: true,
        onChanged: (value) {}, // readOnly, so onChanged won't be called
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _fieldLabelController,
        label: 'Field Label',
        icon: Icons.label_outline,
        onChanged: (value) {
          debugPrint('UI: Field Label changed to: $value'); // Retained debugPrint
          context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Field_label', value));
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _sequenceController,
        label: 'Sequence No',
        icon: Icons.sort,
        keyboardType: TextInputType.number,
        onChanged: (value) {
          final parsed = int.tryParse(value);
          if (parsed != null && parsed >= 0) {
            debugPrint('UI: Sequence No changed to: $parsed'); // Retained debugPrint
            context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Sequence_no', parsed));
          } else if (value.isEmpty) {
            context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Sequence_no', null));
          }
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _widthController,
        label: 'Width',
        icon: Icons.width_normal,
        keyboardType: TextInputType.number,
        onChanged: (value) {
          final parsed = int.tryParse(value);
          if (parsed != null && parsed >= 0) {
            debugPrint('UI: Width changed to: $parsed'); // Retained debugPrint
            context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('width', parsed));
          } else if (value.isEmpty) {
            context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('width', null));
          }
        },
      ),
      const SizedBox(height: 16),
      CheckboxListTile(
        title: Text('Total', style: GoogleFonts.poppins()),
        value: state.currentField!['Total'] ?? false,
        activeColor: Colors.blueAccent,
        onChanged: (value) {
          debugPrint('UI: Total checkbox changed to: $value'); // Retained debugPrint
          context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Total', value!));
        },
      ),
      const SizedBox(height: 16),
      CheckboxListTile(
        title: Text('Breakpoint', style: GoogleFonts.poppins()),
        value: state.currentField!['Breakpoint'] ?? false,
        activeColor: Colors.blueAccent,
        onChanged: (value) {
          debugPrint('UI: Breakpoint checkbox changed to: $value'); // Retained debugPrint
          context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Breakpoint', value!));
        },
      ),
      if (state.currentField!['Total'] == true) ...[
        const SizedBox(height: 16),
        CheckboxListTile(
          title: Text('Subtotal', style: GoogleFonts.poppins()),
          value: state.currentField!['SubTotal'] ?? false,
          activeColor: Colors.blueAccent,
          onChanged: (value) {
            debugPrint('UI: Subtotal checkbox changed to: $value'); // Retained debugPrint
            context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('SubTotal', value!));
          },
        ),
      ],
      const SizedBox(height: 16),
      CheckboxListTile(
        title: Text('Image', style: GoogleFonts.poppins()),
        value: state.currentField!['image'] ?? false,
        activeColor: Colors.blueAccent,
        onChanged: (value) {
          debugPrint('UI: Image checkbox changed to: $value'); // Retained debugPrint
          context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('image', value!));
        },
      ),
      const Divider(
        color: Colors.grey,
        thickness: 2,
        height: 32,
      ),
      DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Number Alignment',
          labelStyle: GoogleFonts.poppins(),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
        value: (state.currentField!['num_alignment']?.toString().toLowerCase() ?? 'left').contains('left')
            ? 'left'
            : ((state.currentField!['num_alignment']?.toString().toLowerCase() ?? 'left').contains('center') ? 'center' : 'right'),
        items: const [
          DropdownMenuItem(value: 'left', child: Text('Left')),
          DropdownMenuItem(value: 'center', child: Text('Center')),
          DropdownMenuItem(value: 'right', child: Text('Right')),
        ].map((item) => DropdownMenuItem(
          value: item.value,
          child: Text(StringCasingExtension(item.value!).toCapitalized(), style: GoogleFonts.poppins()), // Capitalize dropdown item
        )).toList(),
        onChanged: (value) {
          debugPrint('UI: Number Alignment changed to: $value'); // Retained debugPrint
          context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('num_alignment', value!));
        },
        dropdownColor: Colors.white,
      ),
      const SizedBox(height: 16),
      CheckboxListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Indian Number Format', style: GoogleFonts.poppins()),
            Text(
              'Example: 1234555 becomes 12,34,555',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        value: state.currentField!['num_format'] ?? false,
        activeColor: Colors.blueAccent,
        onChanged: (value) {
          debugPrint('UI: Indian Number Format changed to: $value'); // Retained debugPrint
          context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('num_format', value!));
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _decimalPointsController,
        label: 'Decimal Points',
        icon: Icons.numbers,
        keyboardType: TextInputType.number,
        onChanged: (value) {
          final parsed = int.tryParse(value);
          if (parsed != null && parsed >= 0) {
            debugPrint('UI: Decimal Points changed to: $parsed'); // Retained debugPrint
            context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('decimal_points', parsed));
          } else if (value.isEmpty) {
            context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('decimal_points', null));
          }
        },
      ),
      if (state.currentField!['Field_name'].toString().toLowerCase().contains('date')) ...[
        const SizedBox(height: 16),
        CheckboxListTile(
          title: Text('Time', style: GoogleFonts.poppins()),
          value: state.currentField!['time'] ?? false,
          activeColor: Colors.blueAccent,
          onChanged: (value) {
            debugPrint('UI: Time checkbox changed to: $value'); // Retained debugPrint
            context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('time', value!));
          },
        ),
      ],
    ];
  }

  Widget _buildActionSection(BuildContext context, EditDetailMakerState state) {
    bool canAddMoreActions = state.actions.length < 5;
    bool formExists = state.actions.any((a) => a['type'] == 'form');

    return Card(
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              title: Text(
                'Do you need actions?',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              value: state.needsAction,
              onChanged: (value) {
                debugPrint('UI: Needs Action checkbox changed to: $value'); // Retained debugPrint
                context.read<EditDetailMakerBloc>().add(ToggleNeedsActionEvent(value!));
                setState(() {
                  _showMainReportDetails = false;
                  _showFieldsConfigurationContent = false;
                });
              },
              activeColor: Colors.blueAccent,
            ),
            if (state.needsAction) ...[
              const Divider(height: 30, thickness: 1),
              Text(
                'Add Actions (Max 5)',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildButton(
                    text: 'Add Form',
                    color: Colors.purple,
                    icon: Icons.assignment,
                    onPressed: canAddMoreActions && !formExists
                        ? () => context.read<EditDetailMakerBloc>().add(AddAction('form', _uuid.v4()))
                        : null,
                  ),
                  _buildButton(
                    text: 'Add Print',
                    color: Colors.orange,
                    icon: Icons.print,
                    onPressed: canAddMoreActions
                        ? () => context.read<EditDetailMakerBloc>().add(AddAction('print', _uuid.v4()))
                        : null,
                  ),
                  _buildButton(
                    text: 'Add Report',
                    color: Colors.teal,
                    icon: Icons.table_chart,
                    onPressed: canAddMoreActions
                        ? () => context.read<EditDetailMakerBloc>().add(AddAction('table', _uuid.v4()))
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (state.actions.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    child: Column(
                      children: state.actions.map((action) {
                        return _buildActionConfigCard(context, state, action);
                      }).toList(),
                    ),
                  ),
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Text(
                      'No actions added yet.',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionConfigCard(
      BuildContext context,
      EditDetailMakerState state,
      Map<String, dynamic> action,
      ) {
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
      case 'form':
        typeIcon = Icons.assignment;
        typeColor = Colors.purple;
        headerText = 'Form Action';
        break;
      case 'print':
        typeIcon = Icons.print;
        typeColor = Colors.orange;
        headerText = 'Print Action';
        break;
      case 'table':
        typeIcon = Icons.table_chart;
        typeColor = Colors.teal;
        headerText = 'Report Action';
        break;
      default:
        typeIcon = Icons.help_outline;
        typeColor = Colors.grey;
        headerText = 'Unknown Action';
    }

    // NEW: Template and Color for Print actions
    final String selectedTemplate = action['printTemplate']?.toString() ?? PrintTemplateForMaker.premium.name;
    final String selectedColor = action['printColor']?.toString() ?? 'Blue'; // Default to 'Blue'

    return Card(
      color: Colors.white,
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(typeIcon, color: typeColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      headerText,
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: typeColor),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    context.read<EditDetailMakerBloc>().add(RemoveAction(actionId));
                  },
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _actionNameControllers[actionId]!,
              label: '${StringCasingExtension(actionType).toCapitalized()} Name',
              icon: Icons.title,
              onChanged: (value) {
                context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'name', value));
              },
            ),
            const SizedBox(height: 16),
            if (isTableAction) ...[
              Autocomplete<String>(
                key: _autocompleteFieldKeys.putIfAbsent(actionId, () => GlobalKey()),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  debugPrint('UI: Autocomplete optionsBuilder - current text: ${textEditingValue.text}, reportLabels: ${reportLabels.length}'); // Retained debugPrint
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return reportLabels.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  }).toList();
                },
                onSelected: (String selection) {
                  _actionReportLabelControllers[actionId]!.text = selection;
                  context.read<EditDetailMakerBloc>().add(UpdateTableActionReport(actionId, selection));
                },
                fieldViewBuilder: (BuildContext context,
                    TextEditingController textEditingController,
                    FocusNode focusNode,
                    VoidCallback onFieldSubmitted) {
                  textEditingController.text = _actionReportLabelControllers[actionId]!.text;
                  textEditingController.selection = _actionReportLabelControllers[actionId]!.selection;

                  return _buildTextField(
                    controller: textEditingController,
                    label: 'Select Report Name',
                    icon: Icons.description,
                    focusNode: focusNode,
                    onChanged: (value) {
                      _actionReportLabelControllers[actionId]!.text = value;
                      context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'reportLabel', value));
                    },
                  );
                },
                optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final RenderBox? renderBox = _autocompleteFieldKeys[actionId]?.currentContext?.findRenderObject() as RenderBox?;
                      final double width = renderBox?.size.width ?? constraints.maxWidth;

                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: SizedBox(
                            width: width,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String originalOption = options.elementAt(index);
                                final String displayedOption = originalOption.replaceAll(RegExp(r'\bTable\b', caseSensitive: false), 'Report');

                                return ListTile(
                                  title: Text(displayedOption, style: GoogleFonts.poppins()),
                                  onTap: () {
                                    onSelected(originalOption);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _actionApiControllers[actionId]!,
                label: 'Resolved API URL',
                icon: Icons.link,
                readOnly: true,
                onChanged: (value) {},
              ),
            ] else if (actionType == 'print') ...[
              _buildTextField(
                controller: _actionApiControllers[actionId]!,
                label: 'API URL',
                icon: Icons.link,
                onChanged: (value) {
                  context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'api', value));
                  Future.delayed(const Duration(milliseconds: 700), () {
                    if (_actionApiControllers[actionId]?.text == value && value.isNotEmpty && Uri.tryParse(value)?.isAbsolute == true) {
                      context.read<EditDetailMakerBloc>().add(ExtractParametersFromUrl(actionId, value));
                    } else if (value.isEmpty) {
                      final currentAction = state.actions.firstWhere((element) => element['id'] == actionId);
                      if (currentAction['params'] != null && currentAction['params'].isNotEmpty) {
                        context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'params', []));
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              // NEW: Print Template Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Print Template',
                  labelStyle: GoogleFonts.poppins(),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
                value: PrintTemplateForMaker.values.any((e) => e.name == selectedTemplate)
                    ? selectedTemplate
                    : PrintTemplateForMaker.premium.name, // Ensure valid value
                items: PrintTemplateForMaker.values.map((template) {
                  return DropdownMenuItem<String>(
                    value: template.name,
                    child: Text(template.displayName, style: GoogleFonts.poppins()),
                  );
                }).toList(),
                onChanged: (value) {
                  debugPrint('UI: Print Template changed to: $value'); // Retained debugPrint
                  context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'printTemplate', value!));
                },
                dropdownColor: Colors.white,
              ),
              const SizedBox(height: 16),
              // NEW: Print Color Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Theme Color',
                  labelStyle: GoogleFonts.poppins(),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
                value: predefinedPdfColors.keys.any((key) => key == selectedColor)
                    ? selectedColor
                    : 'Blue', // Ensure valid value
                items: predefinedPdfColors.keys.map((colorName) {
                  return DropdownMenuItem<String>(
                    value: colorName,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          // CORRECTED LINE: Using the new extension method
                          color: predefinedPdfColors[colorName]!.toFlutterColor(),
                        ),
                        const SizedBox(width: 8),
                        Text(colorName, style: GoogleFonts.poppins()),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  debugPrint('UI: Print Color changed to: $value'); // Retained debugPrint
                  context.read<EditDetailMakerBloc>().add(UpdateActionConfig(actionId, 'printColor', value!));
                },
                dropdownColor: Colors.white,
              ),
            ],
            if (isPrintOrTable) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Dynamic Parameters:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                    onPressed: () {
                      context.read<EditDetailMakerBloc>().add(AddActionParameter(actionId, _uuid.v4()));
                    },
                  ),
                ],
              ),
              if (isFetchingParams)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SubtleLoader(),
                      SizedBox(width: 8),
                      Text('Fetching parameters...', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              else if (action['api']?.isNotEmpty == true && apiParameters.isEmpty && !isFetchingParams)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No parameters found for this API, or API is invalid.',
                    style: GoogleFonts.poppins(color: Colors.redAccent),
                  ),
                ),
              Column(
                children: params.map<Widget>((param) {
                  final paramId = param['id'] as String;
                  if (!_actionParamValueControllers.containsKey(actionId) || !_actionParamValueControllers[actionId]!.containsKey(paramId)) {
                    _actionParamValueControllers[actionId] ??= {};
                    _actionParamValueControllers[actionId]![paramId] =
                        TextEditingController(text: param['parameterValue']?.toString() ?? '');
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Parameter Name',
                              labelStyle: GoogleFonts.poppins(),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            ),
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                            value: apiParameters.contains(param['parameterName']) ? param['parameterName'] : null,
                            items: apiParameters.map((String name) {
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Text(name, style: GoogleFonts.poppins()),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                context.read<EditDetailMakerBloc>().add(
                                  UpdateActionParameter(
                                    actionId,
                                    paramId,
                                    'parameterName',
                                    newValue,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              return allApiFieldNames.where((String option) {
                                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                              }).toList();
                            },
                            onSelected: (String selection) {
                              FocusScope.of(context).unfocus();
                              _actionParamValueControllers[actionId]![paramId]!.text = selection;
                              context.read<EditDetailMakerBloc>().add(
                                UpdateActionParameter(
                                  actionId,
                                  paramId,
                                  'parameterValue',
                                  selection,
                                ),
                              );
                            },
                            fieldViewBuilder: (BuildContext context,
                                TextEditingController textEditingController,
                                FocusNode focusNode,
                                VoidCallback onFieldSubmitted) {
                              final managedController = _actionParamValueControllers[actionId]![paramId]!;
                              textEditingController.text = managedController.text;
                              textEditingController.selection = managedController.selection;

                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
                                decoration: InputDecoration(
                                  labelText: 'Value',
                                  labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                ),
                                onChanged: (value) {
                                  managedController.text = value;
                                  context.read<EditDetailMakerBloc>().add(
                                    UpdateActionParameter(
                                      actionId,
                                      paramId,
                                      'parameterValue',
                                      value,
                                    ),
                                  );
                                },
                              );
                            },
                            optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                              final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                              final double width = renderBox?.size.width ?? MediaQuery.of(context).size.width * 0.4;

                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4.0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  child: SizedBox(
                                    width: width,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (BuildContext context, int index) {
                                        final String option = options.elementAt(index);
                                        return ListTile(
                                          title: Text(option, style: GoogleFonts.poppins()),
                                          onTap: () {
                                            onSelected(option);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: () {
                            context.read<EditDetailMakerBloc>().add(RemoveActionParameter(actionId, paramId));
                          },
                        ),
                      ],
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