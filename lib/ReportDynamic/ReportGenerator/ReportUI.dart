// ReportUI.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
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
  final TextEditingController _reportLabelController = TextEditingController();
  Map<String, dynamic>? _selectedReport;
  final Map<String, TextEditingController> _paramControllers = {};
  final Map<String, FocusNode> _paramFocusNodes = {}; // Map to store FocusNodes for parameters

  final List<DateFormat> _dateFormatsToTry = [
    DateFormat('dd-MM-yyyy'),   // e.g., 01-05-2025
    DateFormat('dd-MMM-yyyy'),  // e.g., 21-May-2025
  ];

  @override
  void dispose() {
    _reportLabelController.dispose();
    // Dispose all created _paramControllers
    _paramControllers.forEach((_, controller) => controller.dispose());
    // Dispose all created _paramFocusNodes
    _paramFocusNodes.forEach((_, focusNode) => focusNode.dispose());
    super.dispose();
  }

  // Helper to parse date string with multiple formats and return the format used
  (DateTime?, DateFormat?) _parseDateSmartly(String dateString) {
    if (dateString.isEmpty) return (null, null);

    for (var format in _dateFormatsToTry) {
      try {
        final dateTime = format.parseStrict(dateString);
        return (dateTime, format); // Return the parsed date and the successful format
      } catch (e) {
        // Continue to next format if parsing fails
      }
    }
    return (null, null); // No format matched
  }


  // Method to build a generic text field
  Widget _buildTextField({
    required TextEditingController controller,
    String? label,
    FocusNode? focusNode,
    Function(String)? onChanged,
    IconData? icon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      readOnly: readOnly,
      onTap: onTap,
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

  // Method to build a styled button
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportBlocGenerate(ReportAPIService())..add(LoadReports()),
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Report Selection',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocListener<ReportBlocGenerate, ReportState>(
          listener: (context, state) {
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          },
          child: BlocBuilder<ReportBlocGenerate, ReportState>(
            builder: (context, state) {
              // --- Parameter Controller and FocusNode Management ---
              // This logic ensures that controllers and focus nodes are created/disposed
              // correctly when parameters change (e.g., when a new report is selected).

              // Get current parameter names from state
              final currentParamNames = state.selectedApiParameters.map((p) => p['name'].toString()).toSet();

              // Dispose and remove controllers/focus nodes for parameters that no longer exist
              _paramControllers.keys.toList().forEach((key) {
                if (!currentParamNames.contains(key)) {
                  _paramControllers[key]?.dispose();
                  _paramControllers.remove(key);
                  _paramFocusNodes[key]?.dispose();
                  _paramFocusNodes.remove(key);
                  print('UI: Disposed/removed controller/focus node for missing param: $key');
                }
              });

              // Create/update controllers and focus nodes for current parameters
              for (var param in state.selectedApiParameters) {
                final paramName = param['name'].toString(); // Ensure paramName is String
                if (!_paramControllers.containsKey(paramName)) {
                  _paramControllers[paramName] = TextEditingController();
                  _paramFocusNodes[paramName] = FocusNode();
                  print('UI: Created controller/focus node for param: $paramName');
                }

                final bool isPickerField = param['master_table'] != null && param['master_table'].toString().isNotEmpty &&
                    param['master_field'] != null && param['master_field'].toString().isNotEmpty &&
                    param['display_field'] != null && param['display_field'].toString().isNotEmpty;

                // The master value from the Bloc state (which is what goes to the API)
                final String currentMasterValue = state.userParameterValues[paramName] ?? param['value']?.toString() ?? '';

                String displayValueForController = currentMasterValue; // Default to master value

                // If it's a picker field and we have options loaded, try to find the display value
                if (isPickerField && state.pickerOptions.containsKey(paramName) && currentMasterValue.isNotEmpty) {
                  final option = state.pickerOptions[paramName]?.firstWhere(
                        (opt) => opt['value'] == currentMasterValue,
                    orElse: () => {'label': currentMasterValue, 'value': currentMasterValue}, // Fallback if not found
                  );
                  displayValueForController = option!['label']!;
                }

                // Update the controller's text with the determined display value
                if (_paramControllers[paramName]!.text != displayValueForController) {
                  _paramControllers[paramName]!.text = displayValueForController;
                }
              }
              // --- End Parameter Controller and FocusNode Management ---


              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Card(
                      color: Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              child: Autocomplete<Map<String, dynamic>>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<Map<String, dynamic>>.empty();
                                  }
                                  return state.reports.where((report) => report['Report_label']
                                      .toString()
                                      .toLowerCase()
                                      .contains(textEditingValue.text.toLowerCase()));
                                },
                                displayStringForOption: (Map<String, dynamic> option) => option['Report_label'],
                                onSelected: (Map<String, dynamic> selection) {
                                  // Clear all existing controllers and focus nodes for old parameters
                                  // This is crucial BEFORE dispatching FetchApiDetails,
                                  // as new params might replace old ones.
                                  _paramControllers.forEach((key, controller) => controller.dispose());
                                  _paramControllers.clear();
                                  _paramFocusNodes.forEach((key, focusNode) => focusNode.dispose());
                                  _paramFocusNodes.clear();

                                  setState(() {
                                    _selectedReport = selection;
                                    _reportLabelController.text = selection['Report_label'];
                                  });
                                  context.read<ReportBlocGenerate>().add(
                                    FetchApiDetails(selection['API_name']),
                                  );
                                  print('UI: Report selected: ${selection['Report_label']}');
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  // Sync Autocomplete's internal controller with our _reportLabelController
                                  if (controller.text.isEmpty && _reportLabelController.text.isNotEmpty) {
                                    controller.text = _reportLabelController.text;
                                  } else if (controller.text != _reportLabelController.text && controller.text.isNotEmpty) {
                                    _reportLabelController.text = controller.text;
                                  }
                                  return _buildTextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    label: 'Report Label',
                                    icon: Icons.label,
                                    onChanged: (value) {
                                      _reportLabelController.text = value; // Keep our internal controller in sync
                                      print('UI: Report Label input: $value');
                                      if (value.isEmpty) {
                                        // If input is cleared, reset selected report and clear parameters
                                        setState(() {
                                          _selectedReport = null;
                                          _paramControllers.forEach((key, controller) => controller.dispose());
                                          _paramControllers.clear();
                                          _paramFocusNodes.forEach((key, focusNode) => focusNode.dispose());
                                          _paramFocusNodes.clear();
                                        });
                                        context.read<ReportBlocGenerate>().add(ResetReports());
                                        print('UI: Report Label cleared, resetting state.');
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
                            // Display input fields for parameters with show: true
                            if (state.selectedApiParameters.isNotEmpty) ...[
                              Text(
                                'Parameters',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),
                              ...state.selectedApiParameters.where((param) => param['show'] == true).map((param) {
                                final paramName = param['name'].toString();
                                final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : paramName;

                                // Check for date field (original logic)
                                final isDateField = (param['type']?.toString().toLowerCase() == 'date') ||
                                    (paramName.toLowerCase().contains('date') && param['value'].toString().contains('-'));

                                // NEW LOGIC: Infer picker field by presence of master_table, master_field, and display_field
                                final isPickerField = param['master_table'] != null && param['master_table'].toString().isNotEmpty &&
                                    param['master_field'] != null && param['master_field'].toString().isNotEmpty &&
                                    param['display_field'] != null && param['display_field'].toString().isNotEmpty; // Added display_field check

                                final String masterField = param['master_field']?.toString() ?? '';
                                final String displayField = param['display_field']?.toString() ?? '';

                                print('UI: Param: $paramName, Label: $paramLabel, IsDate: $isDateField, IsPicker: $isPickerField, MasterTable: ${param['master_table']}, MasterField: $masterField, DisplayField: $displayField');

                                // Ensure controller and focus node exist (should be done in management block above)
                                final TextEditingController controller = _paramControllers[paramName]!;
                                final FocusNode focusNode = _paramFocusNodes[paramName]!;

                                Widget parameterInputWidget;
                                if (isPickerField) {
                                  // Build Autocomplete for picker fields
                                  parameterInputWidget = Autocomplete<Map<String, String>>( // Autocomplete works with Map<String, String> now
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      // If options are not loaded for this picker, trigger fetch
                                      if (!state.pickerOptions.containsKey(paramName) &&
                                          state.serverIP != null &&
                                          state.userName != null &&
                                          state.password != null &&
                                          state.databaseName != null) {
                                        print('UI: Dispatching FetchPickerOptions for $paramName');
                                        context.read<ReportBlocGenerate>().add(
                                          FetchPickerOptions(
                                            paramName: paramName,
                                            serverIP: state.serverIP!,
                                            userName: state.userName!,
                                            password: state.password!,
                                            databaseName: state.databaseName!,
                                            masterTable: param['master_table'].toString(),
                                            masterField: masterField,
                                            displayField: displayField,
                                          ),
                                        );
                                      }

                                      final options = state.pickerOptions[paramName] ?? [];
                                      if (textEditingValue.text.isEmpty) {
                                        return options;
                                      }
                                      return options.where((option) =>
                                          option['label']!.toLowerCase().contains(textEditingValue.text.toLowerCase())); // Filter by label
                                    },
                                    displayStringForOption: (Map<String, String> option) => option['label']!, // Display the label
                                    onSelected: (Map<String, String> selection) {
                                      controller.text = selection['label']!; // Update controller text with label (for display)
                                      context.read<ReportBlocGenerate>().add(
                                        UpdateParameter(paramName, selection['value']!), // Send the master_field value to Bloc
                                      );
                                      print('UI: Picker selected for $paramName: Label=${selection['label']}, Value=${selection['value']}');
                                    },
                                    fieldViewBuilder: (context, textEditingController, currentFocusNode, onFieldSubmitted) {
                                      // Ensure Autocomplete's internal controller stays in sync with our widget's controller
                                      if (textEditingController.text != controller.text) {
                                        textEditingController.text = controller.text;
                                      }
                                      return _buildTextField(
                                        controller: textEditingController, // Use Autocomplete's controller
                                        focusNode: currentFocusNode, // Use Autocomplete's focus node
                                        label: paramLabel,
                                        icon: Icons.list,
                                        // onChanged is typically handled by onSelected for Autocomplete,
                                        // or if direct typing should affect Bloc,
                                        // it would need to perform a reverse lookup.
                                        // For simplicity and standard Autocomplete behavior, keep onChanged null here.
                                        // If you need direct typing to update the value, you'd add:
                                        // onChanged: (value) {
                                        //   // This is tricky: if user types "East" how do you get "E"?
                                        //   // You'd need to find the option whose label matches 'value'
                                        //   // and then use its 'value' key. This is usually not required
                                        //   // for Autocomplete where selection from list is primary.
                                        //   // For now, it's best to rely on onSelected.
                                        // },
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
                                            width: 300, // Adjust width as needed
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              padding: const EdgeInsets.all(8),
                                              itemCount: options.length,
                                              itemBuilder: (context, index) {
                                                final option = options.elementAt(index);
                                                return ListTile(
                                                  title: Text(
                                                    option['label']!, // Display the label
                                                    style: GoogleFonts.poppins(fontSize: 14),
                                                  ),
                                                  onTap: () => onSelected(option), // Pass the full map
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                } else if (isDateField) {
                                  // Existing Date Field logic
                                  parameterInputWidget = _buildTextField(
                                    label: paramLabel,
                                    controller: controller,
                                    focusNode: focusNode, // Assign focus node
                                    icon: Icons.calendar_today,
                                    readOnly: true,
                                    onTap: () async {
                                      DateTime? initialDate;
                                      DateFormat? detectedFormat; // To store the format used for parsing

                                      // Attempt to parse the current text in the controller
                                      final parseResult = _parseDateSmartly(controller.text);
                                      initialDate = parseResult.$1;
                                      detectedFormat = parseResult.$2;

                                      // Fallback if parsing failed or text was empty
                                      initialDate ??= DateTime.now();
                                      // Default to the first format in our list if no format was detected
                                      detectedFormat ??= _dateFormatsToTry.first;
                                      print('UI: Date picker initial date: $initialDate, detected format: ${detectedFormat.pattern}');

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
                                        // Format the picked date using the detected (or default) format
                                        final formattedDate = detectedFormat.format(pickedDate); // Use the detected format
                                        controller.text = formattedDate;
                                        context.read<ReportBlocGenerate>().add(
                                          UpdateParameter(paramName, formattedDate),
                                        );
                                        print('UI: Date selected for $paramName: $formattedDate');
                                      }
                                    },
                                  );
                                } else {
                                  // Generic text field
                                  parameterInputWidget = _buildTextField(
                                    controller: controller,
                                    focusNode: focusNode, // Assign focus node
                                    label: paramLabel,
                                    icon: Icons.text_fields,
                                    onChanged: (value) {
                                      context.read<ReportBlocGenerate>().add(
                                        UpdateParameter(paramName, value),
                                      );
                                    },
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: parameterInputWidget,
                                );
                              }).toList(),
                            ],
                            const SizedBox(height: 20),
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

                                    print('UI: "Show" button pressed for report: $reportLabel');
                                    bloc.add(FetchFieldConfigs(recNo, apiName, reportLabel));
                                    // Wait for the state to update (specifically, for isLoading to become false)
                                    // and ensure it's for the correct recNo.
                                    await bloc.stream.firstWhere((s) => !s.isLoading && s.selectedRecNo == recNo,
                                      orElse: () {
                                        print('UI: Timeout/no match found while waiting for field configs and data.');
                                        return state; // Return current state if stream closes or no match found
                                      },
                                    );

                                    if (context.mounted) {
                                      print('UI: Navigating to ReportMainUI.');
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BlocProvider.value(
                                            value: bloc, // Pass the existing bloc instance
                                            child: ReportMainUI(
                                              recNo: recNo,
                                              apiName: apiName,
                                              reportLabel: reportLabel,
                                              userParameterValues: state.userParameterValues, // Pass the current parameter values
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
                                _buildButton(
                                  text: 'Reset',
                                  color: Colors.redAccent,
                                  onPressed: () {
                                    _reportLabelController.clear();
                                    // Dispose and clear all parameter controllers and focus nodes
                                    _paramControllers.forEach((key, controller) => controller.dispose());
                                    _paramControllers.clear();
                                    _paramFocusNodes.forEach((key, focusNode) => focusNode.dispose());
                                    _paramFocusNodes.clear();
                                    setState(() {
                                      _selectedReport = null;
                                    });
                                    context.read<ReportBlocGenerate>().add(ResetReports());
                                    print('UI: Reset button pressed. All fields cleared.');
                                  },
                                  icon: Icons.refresh,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      // Only show loader during initial reports load OR when API details/picker options are loading
                      // (if reports list is empty, indicating initial load or failure to fetch reports)
                      child: (state.isLoading && state.reports.isEmpty) || (state.isLoading && state.selectedApiParameters.isNotEmpty && state.pickerOptions.isEmpty)
                          ? const SubtleLoader()
                          : state.reports.isEmpty && !state.isLoading && state.error == null
                          ? Center(
                        child: Text(
                          'No reports available. Please select or add one.',
                          style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}