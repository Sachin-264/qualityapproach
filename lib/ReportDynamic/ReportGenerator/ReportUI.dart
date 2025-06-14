// lib/ReportDynamic/ReportUI.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // Add this import for firstWhereOrNull
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import 'ReportMainUI.dart';
import 'Reportbloc.dart';

class ReportUI extends StatefulWidget {
  const ReportUI({super.key});

  @override
  _ReportUIState createState() => _ReportUIState();
}

class _ReportUIState extends State<ReportUI> {
  final TextEditingController _reportLabelDisplayController = TextEditingController();
  Map<String, dynamic>? _selectedReport; // Holds the full selected report metadata from demo_table
  final Map<String, TextEditingController> _paramControllers = {};
  final Map<String, FocusNode> _paramFocusNodes = {};

  final List<DateFormat> _dateFormatsToTry = [
    DateFormat('dd-MM-yyyy'), // e.g., 01-05-2025
    DateFormat('dd-MMM-yyyy'), // e.g., 21-May-2025
    DateFormat('yyyy-MM-dd'), // Common API date format
  ];

  @override
  void dispose() {
    _reportLabelDisplayController.dispose();
    _paramControllers.forEach((_, controller) => controller.dispose());
    _paramControllers.clear(); // Ensure map is cleared after disposing controllers
    _paramFocusNodes.forEach((_, focusNode) => focusNode.dispose());
    _paramFocusNodes.clear(); // Ensure map is cleared after disposing focus nodes
    super.dispose();
  }

  (DateTime?, DateFormat?) _parseDateSmartly(String dateString) {
    if (dateString.isEmpty) return (null, null);
    for (var format in _dateFormatsToTry) {
      try {
        final dateTime = format.parseStrict(dateString);
        return (dateTime, format);
      } catch (e) {
        // Continue to next format if parsing fails
      }
    }
    return (null, null);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? label,
    FocusNode? focusNode,
    Function(String)? onChanged,
    IconData? icon,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    bool enableClearButton = false,
    VoidCallback? onClear,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22) : null,
        suffixIcon: enableClearButton && controller.text.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear, color: Colors.grey),
          onPressed: () {
            controller.clear();
            if (onClear != null) {
              onClear();
            }
            if (onChanged != null) {
              onChanged('');
            }
          },
        )
            : null,
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

  // Encapsulate the reset logic
  void _resetAllFields(BuildContext context) {
    debugPrint('UI: _resetAllFields called.'); // LOG
    _reportLabelDisplayController.clear();
    setState(() { // setState to ensure UI rebuilds and _selectedReport becomes null
      _selectedReport = null;
    });
    // Dispose and clear parameter controllers/focus nodes
    _paramControllers.forEach((key, controller) => controller.dispose());
    _paramControllers.clear();
    _paramFocusNodes.forEach((key, focusNode) => focusNode.dispose());
    _paramFocusNodes.clear();

    final bloc = context.read<ReportBlocGenerate>();
    // Dispatch ResetReports to clear all relevant state in the BLoC
    bloc.add(ResetReports());
    debugPrint('UI: Resetting all fields and state, reports list preserved.');
  }

  // NEW: Helper for Radio Buttons
  Widget _buildRadioParameter({
    required Map<String, dynamic> param,
    required String currentValue,
    required ValueChanged<String> onChanged,
  }) {
    final paramName = param['name'].toString();
    final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : paramName;
    // Ensure options is always a List<Map<String, String>>
    final List<Map<String, String>> options = List<Map<String, String>>.from(
      (param['options'] as List?)?.map((e) => Map<String, String>.from(e ?? {})) ?? [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          paramLabel,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[500]!, width: 1),
          ),
          child: Column(
            children: options.map((option) {
              return RadioListTile<String>(
                title: Text(option['label']!, style: GoogleFonts.poppins(fontSize: 14)),
                value: option['value']!,
                groupValue: currentValue,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    debugPrint('UI: Radio selected for $paramName: label=${option['label']}, value=$newValue');
                    onChanged(newValue);
                  }
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: Colors.blueAccent,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // NEW: Helper for Checkboxes (single-selectable, can be empty)
  Widget _buildCheckboxParameter({
    required Map<String, dynamic> param,
    required String currentValue,
    required ValueChanged<String> onChanged,
  }) {
    final paramName = param['name'].toString();
    final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : paramName;
    // Ensure options is always a List<Map<String, String>>
    final List<Map<String, String>> options = List<Map<String, String>>.from(
      (param['options'] as List?)?.map((e) => Map<String, String>.from(e ?? {})) ?? [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          paramLabel,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[500]!, width: 1),
          ),
          child: Column(
            children: options.map((option) {
              return CheckboxListTile(
                title: Text(option['label']!, style: GoogleFonts.poppins(fontSize: 14)),
                value: currentValue == option['value'],
                onChanged: (bool? isChecked) {
                  String newValue = ''; // Default to empty if unchecked or no longer selected
                  if (isChecked == true) {
                    newValue = option['value']!; // Set to this option's value if checked
                    debugPrint('UI: Checkbox selected for $paramName: label=${option['label']}, value=$newValue');
                  } else {
                    debugPrint('UI: Checkbox unselected for $paramName: label=${option['label']}, value=""');
                  }
                  onChanged(newValue); // Update the BLoC with the single selected value or empty string
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: Colors.blueAccent,
                controlAffinity: ListTileControlAffinity.leading,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
      ReportBlocGenerate(ReportAPIService())
        ..add(LoadReports()), // Initial load on widget creation
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Report Selection',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocListener<ReportBlocGenerate, ReportState>(
          listener: (context, state) {
            // Show error message
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.error!,
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 5),
                ),
              );
              // Clear the error after showing to prevent it from showing again on rebuilds
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<ReportBlocGenerate>().emit(state.copyWith(error: null));
              });
            }
            // Show success message
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.successMessage!,
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 3),
                ),
              );
              // Clear the success message after showing
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<ReportBlocGenerate>().emit(state.copyWith(successMessage: null));
              });
            }
          },
          child: BlocBuilder<ReportBlocGenerate, ReportState>(
            builder: (context, state) {
              // --- LOGGING BUTTON STATE CONDITIONS ---
              debugPrint('--- UI Rebuild Log ---');
              debugPrint('UI: _selectedReport is NULL: ${_selectedReport == null}');
              debugPrint('UI: state.fieldConfigs is EMPTY: ${state.fieldConfigs.isEmpty}');
              debugPrint('UI: Send to Client button enabled? : ${(_selectedReport != null && state.fieldConfigs.isNotEmpty)}');
              debugPrint('-----------------------');
              // --- END LOGGING ---

              // --- Parameter Controller Management ---
              // Identify parameters that are currently displayed and are text-input based
              // This is for rendering the UI input fields. It should always respect param['show']
              final Set<String> currentTextFieldParamNames = state.selectedApiParameters
                  .where((p) {
                final String configType = p['config_type']?.toString().toLowerCase() ?? '';
                final bool isTextOrDatePicker = !(configType == 'radio' || configType == 'checkbox');
                final bool isDatabaseNotPicker = (configType == 'database' && (p['master_table']?.toString().isEmpty == true));
                return p['show'] == true && (isTextOrDatePicker || isDatabaseNotPicker);
              })
                  .map((p) => p['name'].toString())
                  .toSet();

              // Dispose controllers for parameters that are no longer text-input based or are no longer shown
              _paramControllers.keys.toList().forEach((key) {
                if (!currentTextFieldParamNames.contains(key)) {
                  _paramControllers[key]?.dispose();
                  _paramControllers.remove(key);
                  _paramFocusNodes[key]?.dispose();
                  _paramFocusNodes.remove(key);
                }
              });

              // Create or update controllers for currently shown text-input based parameters
              for (var paramName in currentTextFieldParamNames) {
                if (!_paramControllers.containsKey(paramName)) {
                  _paramControllers[paramName] = TextEditingController();
                  _paramFocusNodes[paramName] = FocusNode();
                }

                // Get the full parameter config from state
                final param = state.selectedApiParameters.firstWhere((p) => p['name'] == paramName);

                // Determine if it's a picker field (config_type: database, and has master/display fields)
                final bool isPickerField = (param['config_type']?.toString().toLowerCase() == 'database') &&
                    (param['master_table']?.toString().isNotEmpty == true) &&
                    (param['master_field']?.toString().isNotEmpty == true) &&
                    (param['display_field']?.toString().isNotEmpty == true);

                final String currentMasterValue = state.userParameterValues[paramName] ?? '';
                String displayValueForController = currentMasterValue;

                if (isPickerField && state.pickerOptions.containsKey(paramName) && currentMasterValue.isNotEmpty) {
                  final option = state.pickerOptions[paramName]?.firstWhere(
                        (opt) => opt['value'] == currentMasterValue,
                    orElse: () => {'label': currentMasterValue, 'value': currentMasterValue},
                  );
                  displayValueForController = option!['label']!;
                }

                if (_paramControllers[paramName]!.text != displayValueForController) {
                  _paramControllers[paramName]!.text = displayValueForController;
                }
              }

              // MODIFIED BLOCK: Prepare companyName and displayValuesForExport
              String companyName = '';
              String? companyNameParamLabelToExclude; // Store the label of the company param if found

              final companyParam = state.selectedApiParameters.firstWhereOrNull(
                    (param) => param['is_company_name_field'] == true,
              );

              if (companyParam != null) {
                final paramName = companyParam['name'].toString();
                companyNameParamLabelToExclude = companyParam['field_label']?.isNotEmpty == true ? companyParam['field_label'] : paramName;

                // Determine companyName for the main header (priority: UI value if shown, else cache if not shown)
                if (companyParam['show'] == true) {
                  final String configType = companyParam['config_type']?.toString().toLowerCase() ?? '';
                  if (configType == 'database' && state.pickerOptions.containsKey(paramName)) {
                    final List<Map<String, String>> pickerOptions = state.pickerOptions[paramName] ?? [];
                    companyName = pickerOptions.firstWhere(
                          (opt) => opt['value'] == state.userParameterValues[paramName],
                      orElse: () => {'label': state.userParameterValues[paramName] ?? '', 'value': state.userParameterValues[paramName] ?? ''},
                    )['label']!;
                  } else {
                    companyName = state.userParameterValues[paramName] ?? '';
                  }
                } else if (companyParam['show'] == false && companyParam['display_value_cache']?.toString().isNotEmpty == true) {
                  companyName = companyParam['display_value_cache'].toString();
                }
              }
              debugPrint('UI: Company Name extracted (for main header): $companyName');


              // Prepare displayValuesForExport (for the parameter list section in PDF/Excel)
              final Map<String, String> displayValuesForExport = {};
              for (var param in state.selectedApiParameters) {
                final paramName = param['name'].toString();
                final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : paramName;

                // --- IMPORTANT FILTERING LOGIC ---
                // Skip this parameter if it's the company name field AND its label matches the one used for the main header
                if (param['is_company_name_field'] == true && paramLabel == companyNameParamLabelToExclude) {
                  debugPrint('UI: Excluding parameter "${paramLabel}" from displayValuesForExport as it is the main company field.');
                  continue; // Skip adding this to the parameter list
                }
                // --- END FILTERING LOGIC ---

                // Only include other parameters if they are shown and have a non-empty value
                if (param['show'] == true) {
                  final String currentApiValue = state.userParameterValues[paramName] ?? '';
                  String displayValue = '';

                  final String configType = param['config_type']?.toString().toLowerCase() ?? '';

                  if ((configType == 'radio' || configType == 'checkbox') && currentApiValue.isNotEmpty) {
                    final List<Map<String, String>> options = List<Map<String, String>>.from(param['options']?.map((e) => Map<String, String>.from(e ?? {})) ?? []);
                    displayValue = options.firstWhere(
                          (opt) => opt['value'] == currentApiValue,
                      orElse: () => {'label': currentApiValue, 'value': currentApiValue},
                    )['label']!;
                  } else if (configType == 'database' && currentApiValue.isNotEmpty && state.pickerOptions.containsKey(paramName)) {
                    final List<Map<String, String>> pickerOptions = state.pickerOptions[paramName] ?? [];
                    displayValue = pickerOptions.firstWhere(
                          (opt) => opt['value'] == currentApiValue,
                      orElse: () => {'label': currentApiValue, 'value': currentApiValue},
                    )['label']!;
                  } else {
                    displayValue = currentApiValue;
                  }

                  if (displayValue.isNotEmpty) {
                    displayValuesForExport[paramLabel] = displayValue;
                  }
                }
              }
              debugPrint('UI: displayValuesForExport generated: $displayValuesForExport');


              return Stack( // Use Stack to allow overlaying the loader/empty message
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column( // Main Column for the body content
                      children: [
                        Expanded( // Makes the Card take up remaining space
                          child: Card(
                            color: Colors.white,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column( // Column inside the Card
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Report Label Autocomplete (Fixed at the top)
                                  SizedBox(
                                    child: Autocomplete<Map<String, dynamic>>(
                                      initialValue: TextEditingValue(text: _reportLabelDisplayController.text),
                                      optionsBuilder: (TextEditingValue textEditingValue) {
                                        List<Map<String, dynamic>> filteredReports;

                                        if (textEditingValue.text.isEmpty) {
                                          if (_selectedReport != null) {
                                            // Only reset if _selectedReport was previously set
                                            // and the user cleared the text field.
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              _resetAllFields(context);
                                            });
                                          }
                                          // When text is empty, show all reports
                                          filteredReports = List.from(state.reports); // Create a mutable copy
                                        } else {
                                          // When text is not empty, filter reports
                                          filteredReports = state.reports.where((report) =>
                                              report['Report_label']
                                                  .toString()
                                                  .toLowerCase()
                                                  .contains(textEditingValue.text.toLowerCase()))
                                              .toList(); // Convert to List for sorting
                                        }

                                        // Sort the filtered (or all) reports alphabetically by 'Report_label'
                                        filteredReports.sort((a, b) {
                                          final String labelA = a['Report_label']?.toString().toLowerCase() ?? '';
                                          final String labelB = b['Report_label']?.toString().toLowerCase() ?? '';
                                          return labelA.compareTo(labelB);
                                        });

                                        debugPrint('UI: Autocomplete optionsBuilder - text: "${textEditingValue.text}", returning ${filteredReports.length} options.'); // LOG
                                        return filteredReports;
                                      },
                                      displayStringForOption: (Map<String, dynamic> option) => option['Report_label'],
                                      // --- MODIFIED: onSelected callback to fetch field configs immediately ---
                                      onSelected: (Map<String, dynamic> selection) {
                                        debugPrint('UI: Autocomplete onSelected: ${selection['Report_label']}'); // LOG

                                        final bloc = context.read<ReportBlocGenerate>();
                                        // 1. Immediately reset the BLoC state for a new selection
                                        // This ensures old parameters, field configs, and report data are cleared.
                                        bloc.add(ResetReports());

                                        // 2. Dispose and clear old controllers in UI state
                                        _paramControllers.forEach((key, controller) => controller.dispose());
                                        _paramControllers.clear();
                                        _paramFocusNodes.forEach((key, focusNode) => focusNode.dispose());
                                        _paramFocusNodes.clear();

                                        // 3. Update UI's _selectedReport
                                        setState(() {
                                          _selectedReport = selection;
                                          _reportLabelDisplayController.text = selection['Report_label'];
                                        });
                                        debugPrint('UI: _selectedReport set to: ${_selectedReport!['Report_label']}'); // LOG

                                        // 4. Prepare actions config from selection
                                        List<Map<String, dynamic>> selectedActionsConfig = [];
                                        final dynamic actionsRaw = selection['actions_config'];
                                        if (actionsRaw is List) {
                                          selectedActionsConfig = List<Map<String, dynamic>>.from(actionsRaw);
                                        } else if (actionsRaw is String && actionsRaw.isNotEmpty) {
                                          try {
                                            selectedActionsConfig = List<Map<String, dynamic>>.from(jsonDecode(actionsRaw));
                                          } catch (e) {
                                            debugPrint('UI: Error decoding actions_config string: $e');
                                          }
                                        }
                                        if (selectedActionsConfig.isEmpty) {
                                          debugPrint('UI: Warning: actions_config is empty or invalid for selected report: ${selection['Report_label']}. Value: $actionsRaw');
                                        }

                                        // FIX: Properly extract pdf_footer_datetime from selection.
                                        // Based on logs, it's already a boolean or null after ReportAPIService.
                                        final bool includePdfFooter = selection['pdf_footer_datetime'] == true;
                                        debugPrint('UI: Extracted pdf_footer_datetime from selection: ${selection['pdf_footer_datetime']} (runtimeType: ${selection['pdf_footer_datetime']?.runtimeType}) -> $includePdfFooter');


                                        // 5. Dispatch FetchApiDetails (gets general API params and client DB details)
                                        bloc.add(
                                          FetchApiDetails(
                                            selection['API_name'],
                                            selectedActionsConfig,
                                            includePdfFooterDateTimeFromReportMetadata: includePdfFooter, // Pass the extracted flag
                                          ),
                                        );
                                        debugPrint('UI: FetchApiDetails dispatched for API: ${selection['API_name']}.'); // LOG

                                        // 6. Dispatch FetchFieldConfigs immediately after.
                                        // Use `addPostFrameCallback` to ensure FetchApiDetails has its first emit processed
                                        // before FetchFieldConfigs attempts to fetch field configs for the new RecNo.
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          final recNo = selection['RecNo'].toString();
                                          final apiName = selection['API_name'].toString();
                                          final reportLabel = selection['Report_label'].toString();
                                          bloc.add(
                                            FetchFieldConfigs(
                                              recNo,
                                              apiName,
                                              reportLabel,
                                              dynamicApiParams: bloc.state.userParameterValues, // Pass current user params (initial defaults)
                                            ),
                                          );
                                          debugPrint('UI: FetchFieldConfigs dispatched for RecNo: $recNo.'); // LOG
                                        });
                                      },
                                      // --- End of MODIFIED: onSelected callback ---
                                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                        if (_reportLabelDisplayController.text != controller.text) {
                                          controller.text = _reportLabelDisplayController.text;
                                        }
                                        return _buildTextField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          label: 'Report Label',
                                          icon: Icons.label,
                                          enableClearButton: true,
                                          onClear: () {
                                            _resetAllFields(context);
                                            controller.clear(); // Clear Autocomplete's internal controller
                                          },
                                          onChanged: (value) {
                                            _reportLabelDisplayController.text = value;
                                            if (value.isEmpty && _selectedReport != null) {
                                              WidgetsBinding.instance.addPostFrameCallback((_) { // Use post frame callback to avoid setState during build
                                                _resetAllFields(context);
                                              });
                                            }
                                          },
                                        );
                                      },
                                      optionsViewBuilder: (context, onSelected, options) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 4,
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            child: SizedBox(
                                              width: 300,
                                              height: options.length > 5 ? 250 : null, // Max height of 250, otherwise shrinkWrap
                                              child: ListView.builder(
                                                shrinkWrap: true,
                                                padding: const EdgeInsets.all(8),
                                                itemCount: options.length,
                                                itemBuilder: (context, index) {
                                                  final option = options.elementAt(index);
                                                  return ListTile(
                                                    title: Text(
                                                      option['Report_label'],
                                                      style: GoogleFonts.poppins(fontSize: 14),
                                                    ),
                                                    onTap: () => onSelected(option),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Show/Reset/Send to Client buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      _buildButton(
                                        text: 'Show',
                                        color: Colors.blueAccent,
                                        onPressed: _selectedReport != null
                                            ? () async {
                                          final bloc = context.read<ReportBlocGenerate>();
                                          final recNo = _selectedReport!['RecNo'].toString();
                                          final apiName = _selectedReport!['API_name'].toString();
                                          final reportLabel = _selectedReport!['Report_label'].toString();
                                          final actionsConfigForMainReport = bloc.state.actionsConfig;

                                          debugPrint('UI: "Show" button pressed for report: $reportLabel');
                                          // `FetchFieldConfigs` is already called on selection, but re-calling it here
                                          // ensures it uses the *latest* user-inputted parameters before navigating.
                                          // The `dynamicApiParams` will be `state.userParameterValues` from the text fields.
                                          bloc.add(FetchFieldConfigs(
                                            recNo,
                                            apiName,
                                            reportLabel,
                                            dynamicApiParams: bloc.state.userParameterValues,
                                          ));
                                          if (context.mounted) {
                                            debugPrint('UI: Navigating to ReportMainUI. Passing includePdfFooterDateTime: ${state.includePdfFooterDateTime}'); // LOG
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    BlocProvider.value( // Use BlocProvider.value to share existing bloc
                                                      value: bloc,
                                                      child: ReportMainUI(
                                                        recNo: recNo,
                                                        apiName: apiName,
                                                        reportLabel: reportLabel,
                                                        userParameterValues: state.userParameterValues,
                                                        actionsConfig: actionsConfigForMainReport,
                                                        companyName: companyName, // Pass the extracted company name (fixed)
                                                        displayParameterValues: displayValuesForExport, // Pass display values for export (fixed)
                                                        includePdfFooterDateTime: state.includePdfFooterDateTime, // NEW: Pass the flag here
                                                      ),
                                                    ),
                                              ),
                                            );
                                          }
                                        }
                                            : null,
                                        icon: Icons.visibility,
                                      ),
                                      const SizedBox(width: 12),
                                      // NEW BUTTON: Send to Client
                                      _buildButton(
                                        text: 'Send to Client',
                                        color: Colors.purple, // A distinct color for this action
                                        onPressed: _selectedReport != null && state.fieldConfigs.isNotEmpty
                                            ? () async {
                                          final bloc = context.read<ReportBlocGenerate>();

                                          final Map<String, dynamic> reportMetadataToSend =
                                          Map<String, dynamic>.from(_selectedReport!);

                                          // Ensure 'Parameter' from _selectedReport is a JSON string,
                                          // as required by the PHP script for `demo_table`.
                                          if (reportMetadataToSend['Parameter'] is List) {
                                            reportMetadataToSend['Parameter'] =
                                                jsonEncode(reportMetadataToSend['Parameter']);
                                          } else if (reportMetadataToSend['Parameter'] == null) {
                                            reportMetadataToSend['Parameter'] = '';
                                          }

                                          // Ensure 'actions_config' from _selectedReport is a JSON string.
                                          if (reportMetadataToSend['actions_config'] is List) {
                                            reportMetadataToSend['actions_config'] =
                                                jsonEncode(reportMetadataToSend['actions_config']);
                                          } else if (reportMetadataToSend['actions_config'] == null) {
                                            reportMetadataToSend['actions_config'] = '[]';
                                          } else if (reportMetadataToSend['actions_config'] is String && reportMetadataToSend['actions_config'].isEmpty) {
                                            reportMetadataToSend['actions_config'] = '[]';
                                          }

                                          // NEW: Add pdf_footer_datetime to reportMetadataToSend
                                          // Ensure it's a string '0' or '1' as expected by the PHP script
                                          reportMetadataToSend['pdf_footer_datetime'] = state.includePdfFooterDateTime ? '1' : '0';


                                          final String clientApiName = _selectedReport!['API_name'].toString();

                                          debugPrint('UI: "Send to Client" button pressed for report RecNo: ${reportMetadataToSend['RecNo']}'); // LOG
                                          debugPrint('UI: Client API Name for credentials lookup: $clientApiName'); // LOG


                                          bloc.add(
                                            DeployReportToClient(
                                              reportMetadata: reportMetadataToSend,
                                              fieldConfigs: state.fieldConfigs, // Use the fetched field configs
                                              clientApiName: clientApiName,
                                            ),
                                          );
                                        }
                                            : null,
                                        icon: Icons.cloud_upload,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildButton(
                                        text: 'Reset',
                                        color: Colors.redAccent,
                                        onPressed: () => _resetAllFields(context),
                                        icon: Icons.refresh,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20), // Spacing after buttons

                                  // Parameters section (Scrollable if many parameters)
                                  if (state.selectedApiParameters.isNotEmpty) ...[
                                    Text(
                                      'Parameters',
                                      style: GoogleFonts.poppins(
                                          fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded( // Allows parameters to take remaining height and scroll
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: state.selectedApiParameters.where((
                                              param) => param['show'] == true).map((param) { // This `where` clause keeps it in UI
                                            final paramName = param['name'].toString();
                                            final paramLabel = param['field_label']
                                                ?.isNotEmpty == true
                                                ? param['field_label']
                                                : paramName;

                                            final String configType = param['config_type']?.toString().toLowerCase() ?? '';

                                            // Determine if it's a database picker field (database with master_table)
                                            final bool isDatabasePicker = (configType == 'database') &&
                                                (param['master_table']?.toString().isNotEmpty == true);

                                            // Determine if it's a date field (config_type 'date' takes precedence, then heuristics)
                                            final bool isDateField = (configType == 'date') ||
                                                (configType != 'radio' && configType != 'checkbox' && !isDatabasePicker && // Not radio, checkbox, or a DB picker
                                                    paramName.toLowerCase().contains('date') &&
                                                    state.userParameterValues.containsKey(paramName) &&
                                                    state.userParameterValues[paramName]!.isNotEmpty &&
                                                    _parseDateSmartly(state.userParameterValues[paramName]!).$1 != null
                                                );

                                            // Determine which widget to build based on configType or derived type
                                            Widget parameterInputWidget;

                                            if (configType == 'radio') {
                                              parameterInputWidget = Padding(
                                                padding: const EdgeInsets.only(bottom: 16.0),
                                                child: _buildRadioParameter(
                                                  param: param,
                                                  currentValue: state.userParameterValues[paramName] ?? '',
                                                  onChanged: (newValue) {
                                                    context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, newValue));
                                                  },
                                                ),
                                              );
                                            } else if (configType == 'checkbox') {
                                              parameterInputWidget = Padding(
                                                padding: const EdgeInsets.only(bottom: 16.0),
                                                child: _buildCheckboxParameter(
                                                  param: param,
                                                  currentValue: state.userParameterValues[paramName] ?? '',
                                                  onChanged: (newValue) {
                                                    context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, newValue));
                                                  },
                                                ),
                                              );
                                            } else if (isDatabasePicker) {
                                              final TextEditingController controller = _paramControllers[paramName]!;
                                              final FocusNode focusNode = _paramFocusNodes[paramName]!;
                                              parameterInputWidget = Padding(
                                                padding: const EdgeInsets.only(bottom: 16.0),
                                                child: Autocomplete<Map<String, String>>(
                                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                                    // LOG for picker options
                                                    debugPrint('UI: Autocomplete for param $paramName - text: "${textEditingValue.text}"');
                                                    if (!state.pickerOptions.containsKey(paramName) &&
                                                        state.serverIP != null && state.userName != null &&
                                                        state.password != null && state.databaseName != null) {
                                                      debugPrint('UI: Dispatching FetchPickerOptions for $paramName (because not in state.pickerOptions)');
                                                      context.read<ReportBlocGenerate>().add(
                                                        FetchPickerOptions(
                                                          paramName: paramName,
                                                          serverIP: state.serverIP!,
                                                          userName: state.userName!,
                                                          password: state.password!,
                                                          databaseName: state.databaseName!,
                                                          masterTable: param['master_table'].toString(),
                                                          masterField: param['master_field'].toString(),
                                                          displayField: param['display_field'].toString(),
                                                        ),
                                                      );
                                                    }

                                                    final options = state.pickerOptions[paramName] ?? [];
                                                    if (textEditingValue.text.isEmpty) {
                                                      return options;
                                                    }
                                                    return options.where((option) =>
                                                        option['label']!.toLowerCase()
                                                            .contains(textEditingValue.text.toLowerCase()));
                                                  },
                                                  displayStringForOption: (Map<String, String> option) => option['label']!,
                                                  onSelected: (Map<String, String> selection) {
                                                    debugPrint('UI: Picker selected: ${selection['label']} for $paramName'); // LOG
                                                    controller.text = selection['label']!;
                                                    context.read<ReportBlocGenerate>().add(
                                                      UpdateParameter(paramName, selection['value']!),
                                                    );
                                                  },
                                                  fieldViewBuilder: (context, textEditingControllerFromAutocomplete, currentFocusNode, onFieldSubmitted) {
                                                    if (textEditingControllerFromAutocomplete.text != controller.text) {
                                                      textEditingControllerFromAutocomplete.text = controller.text;
                                                    }
                                                    return _buildTextField(
                                                      controller: textEditingControllerFromAutocomplete,
                                                      focusNode: currentFocusNode,
                                                      label: paramLabel,
                                                      enableClearButton: true,
                                                      onClear: () {
                                                        debugPrint('UI: Clearing picker field: $paramName'); // LOG
                                                        textEditingControllerFromAutocomplete.clear();
                                                        context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, ''));
                                                      },
                                                      onChanged: (value) {
                                                        debugPrint('UI: Changed picker field: $paramName to "$value"'); // LOG
                                                        context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, value));
                                                      },
                                                    );
                                                  },
                                                  optionsViewBuilder: (context, onSelected, options) {
                                                    return Align(
                                                      alignment: Alignment.topLeft,
                                                      child: Material(
                                                        elevation: 4,
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: SizedBox(
                                                          width: 300,
                                                          height: options.length > 5 ? 250 : null, // Max height of 250, otherwise shrinkWrap
                                                          child: ListView.builder(
                                                            shrinkWrap: true,
                                                            padding: const EdgeInsets.all(8),
                                                            itemCount: options.length,
                                                            itemBuilder: (context, index) {
                                                              final option = options.elementAt(index);
                                                              return ListTile(
                                                                title: Text(
                                                                  option['label']!,
                                                                  style: GoogleFonts.poppins(fontSize: 14),
                                                                ),
                                                                onTap: () => onSelected(option),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              );
                                            } else if (isDateField) {
                                              final TextEditingController controller = _paramControllers[paramName]!;
                                              final FocusNode focusNode = _paramFocusNodes[paramName]!;
                                              parameterInputWidget = Padding(
                                                padding: const EdgeInsets.only(bottom: 16.0),
                                                child: _buildTextField(
                                                  label: paramLabel,
                                                  controller: controller,
                                                  focusNode: focusNode,
                                                  icon: Icons.calendar_today,
                                                  readOnly: true,
                                                  enableClearButton: true,
                                                  onClear: () {
                                                    debugPrint('UI: Clearing date field: $paramName'); // LOG
                                                    controller.clear();
                                                    context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, ''));
                                                  },
                                                  onTap: () async {
                                                    debugPrint('UI: Date picker tapped for $paramName'); // LOG
                                                    DateTime? initialDate;
                                                    DateFormat? detectedFormat;

                                                    final parseResult = _parseDateSmartly(controller.text);
                                                    initialDate = parseResult.$1;
                                                    detectedFormat = parseResult.$2;

                                                    initialDate ??= DateTime.now();
                                                    detectedFormat ??= _dateFormatsToTry.first;
                                                    debugPrint('UI: Date picker initial date: $initialDate, detected format: ${detectedFormat.pattern}');

                                                    final pickedDate = await showDatePicker(
                                                      context: context,
                                                      initialDate: initialDate,
                                                      firstDate: DateTime(2000),
                                                      lastDate: DateTime(2100),
                                                      builder: (context, child) {
                                                        return Theme(
                                                          data: ThemeData.light().copyWith(
                                                            colorScheme: const ColorScheme.light(
                                                              primary: Colors.blueAccent,
                                                              onPrimary: Colors.white,
                                                              surface: Colors.white,
                                                              onSurface: Colors.black87,
                                                            ),
                                                            dialogBackgroundColor: Colors.white,
                                                            textButtonTheme: TextButtonThemeData(
                                                              style: TextButton.styleFrom(
                                                                foregroundColor: Colors.blueAccent,
                                                                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                                              ),
                                                            ),
                                                          ),
                                                          child: child!,
                                                        );
                                                      },
                                                    );
                                                    if (pickedDate != null) {
                                                      final formattedDate = detectedFormat.format(pickedDate);
                                                      controller.text = formattedDate;
                                                      debugPrint('UI: Date selected: $formattedDate for $paramName'); // LOG
                                                      context.read<ReportBlocGenerate>().add(
                                                        UpdateParameter(paramName, formattedDate),
                                                      );
                                                    }
                                                  },
                                                ),
                                              );
                                            } else {
                                              // Default to a generic text field if config_type is unknown/empty
                                              // or if config_type is 'database' but master_table is null/empty
                                              parameterInputWidget = Padding(
                                                padding: const EdgeInsets.only(bottom: 16.0),
                                                child: _buildTextField(
                                                  controller: _paramControllers[paramName]!, // Ensure controller exists
                                                  focusNode: _paramFocusNodes[paramName]!, // Ensure focus node exists
                                                  label: paramLabel,
                                                  icon: Icons.text_fields,
                                                  enableClearButton: true,
                                                  onClear: () {
                                                    debugPrint('UI: Clearing text field: $paramName'); // LOG
                                                    _paramControllers[paramName]!.clear();
                                                    context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, ''));
                                                  },
                                                  onChanged: (value) {
                                                    debugPrint('UI: Changed text field: $paramName to "$value"'); // LOG
                                                    context.read<ReportBlocGenerate>().add(
                                                      UpdateParameter(paramName, value),
                                                    );
                                                  },
                                                ),
                                              );
                                            }
                                            return parameterInputWidget;
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Conditional Loader/Empty message as an overlay
                  if (state.isLoading) // Show loader if any loading is happening
                    const Positioned.fill(child: SubtleLoader())
                  else if (state.reports.isEmpty && !state.isLoading && state.error == null)
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          'No reports available. Please select or add one.',
                          style: GoogleFonts.poppins(
                              color: Colors.grey[600], fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}