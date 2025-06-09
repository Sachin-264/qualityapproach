// ReportUI.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
  Map<String, dynamic>? _selectedReport;
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
    _reportLabelDisplayController.clear();
    _selectedReport = null;
    // Dispose and clear parameter controllers/focus nodes
    _paramControllers.forEach((key, controller) => controller.dispose());
    _paramControllers.clear();
    _paramFocusNodes.forEach((key, focusNode) => focusNode.dispose());
    _paramFocusNodes.clear();

    final bloc = context.read<ReportBlocGenerate>();
    bloc.add(ResetReports());
    debugPrint('UI: Resetting all fields and state, reports list preserved.');
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
            }
          },
          child: BlocBuilder<ReportBlocGenerate, ReportState>(
            builder: (context, state) {
              // --- Parameter Controller Management ---
              final currentParamNames = state.selectedApiParameters.map((p) => p['name'].toString()).toSet();
              _paramControllers.keys.toList().forEach((key) {
                if (!currentParamNames.contains(key)) {
                  _paramControllers[key]?.dispose();
                  _paramControllers.remove(key);
                  _paramFocusNodes[key]?.dispose();
                  _paramFocusNodes.remove(key);
                }
              });

              for (var param in state.selectedApiParameters) {
                final paramName = param['name'].toString();
                if (!_paramControllers.containsKey(paramName)) {
                  _paramControllers[paramName] = TextEditingController();
                  _paramFocusNodes[paramName] = FocusNode();
                }

                final bool isPickerField = param['master_table'] != null &&
                    param['master_table'].toString().isNotEmpty &&
                    param['master_field'] != null && param['master_field'].toString().isNotEmpty &&
                    param['display_field'] != null && param['display_field'].toString().isNotEmpty;

                final String currentMasterValue = state.userParameterValues[paramName] ?? '';

                String displayValueForController = currentMasterValue;

                if (isPickerField &&
                    state.pickerOptions.containsKey(paramName) &&
                    currentMasterValue.isNotEmpty) {
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
                                        if (textEditingValue.text.isEmpty) {
                                          if (_selectedReport != null) {
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              _resetAllFields(context);
                                            });
                                          }
                                          return const Iterable<Map<String, dynamic>>.empty();
                                        }
                                        return state.reports.where((report) =>
                                            report['Report_label']
                                                .toString()
                                                .toLowerCase()
                                                .contains(
                                                textEditingValue.text.toLowerCase()));
                                      },
                                      displayStringForOption: (Map<String, dynamic> option) => option['Report_label'],
                                      onSelected: (Map<String, dynamic> selection) {
                                        // Dispose and clear old controllers
                                        _paramControllers.forEach((key, controller) => controller.dispose());
                                        _paramControllers.clear();
                                        _paramFocusNodes.forEach((key, focusNode) => focusNode.dispose());
                                        _paramFocusNodes.clear();

                                        setState(() {
                                          _selectedReport = selection;
                                          _reportLabelDisplayController.text = selection['Report_label'];
                                        });

                                        // Extract actions_config from the selected report's metadata
                                        List<Map<String, dynamic>> selectedActionsConfig = [];
                                        final dynamic actionsRaw = selection['actions_config'];
                                        if (actionsRaw is List) {
                                          selectedActionsConfig = List<Map<String, dynamic>>.from(actionsRaw);
                                        } else {
                                          debugPrint('UI: Warning: actions_config is not a List for selected report: ${selection['Report_label']}. Value: $actionsRaw');
                                        }

                                        context.read<ReportBlocGenerate>().add(
                                          FetchApiDetails(
                                            selection['API_name'],
                                            selectedActionsConfig,
                                          ),
                                        );
                                        debugPrint('UI: Report selected: ${selection['Report_label']}');
                                      },
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
                                              _resetAllFields(context);
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

                                  // Show/Reset buttons (MOVED here, below report label)
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
                                          bloc.add(FetchFieldConfigs(recNo, apiName, reportLabel));
                                          if (context.mounted) {
                                            debugPrint('UI: Navigating to ReportMainUI.');
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
                                              param) => param['show'] == true).map((param) {
                                            final paramName = param['name'].toString();
                                            final paramLabel = param['field_label']
                                                ?.isNotEmpty == true
                                                ? param['field_label']
                                                : paramName;

                                            final isDateField = (param['type']
                                                ?.toString()
                                                .toLowerCase() == 'date') ||
                                                (paramName.toLowerCase().contains('date') &&
                                                    state.userParameterValues.containsKey(paramName) &&
                                                    state.userParameterValues[paramName]!.isNotEmpty &&
                                                    _parseDateSmartly(state.userParameterValues[paramName]!).$1 != null
                                                );

                                            final isPickerField = param['master_table'] !=
                                                null && param['master_table']
                                                .toString()
                                                .isNotEmpty &&
                                                param['master_field'] != null &&
                                                param['master_field']
                                                    .toString()
                                                    .isNotEmpty &&
                                                param['display_field'] != null &&
                                                param['display_field']
                                                    .toString()
                                                    .isNotEmpty;

                                            final String masterField = param['master_field']
                                                ?.toString() ?? '';
                                            final String displayField = param['display_field']
                                                ?.toString() ?? '';

                                            final TextEditingController controller = _paramControllers[paramName]!;
                                            final FocusNode focusNode = _paramFocusNodes[paramName]!;

                                            Widget parameterInputWidget;
                                            if (isPickerField) {
                                              parameterInputWidget =
                                                  Autocomplete<Map<String, String>>(
                                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                                      if (!state.pickerOptions.containsKey(paramName) &&
                                                          state.serverIP != null && state.userName != null &&
                                                          state.password != null && state.databaseName != null) {
                                                        debugPrint('UI: Dispatching FetchPickerOptions for $paramName');
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
                                                          option['label']!.toLowerCase()
                                                              .contains(textEditingValue.text.toLowerCase()));
                                                    },
                                                    displayStringForOption: (Map<String, String> option) => option['label']!,
                                                    onSelected: (Map<String, String> selection) {
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
                                                          textEditingControllerFromAutocomplete.clear();
                                                          context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, ''));
                                                        },
                                                        onChanged: (value) {
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
                                                  );
                                            } else if (isDateField) {
                                              parameterInputWidget = _buildTextField(
                                                label: paramLabel,
                                                controller: controller,
                                                focusNode: focusNode,
                                                icon: Icons.calendar_today,
                                                readOnly: true,
                                                enableClearButton: true,
                                                onClear: () {
                                                  controller.clear();
                                                  context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, ''));
                                                },
                                                onTap: () async {
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
                                                    context.read<ReportBlocGenerate>().add(
                                                      UpdateParameter(paramName, formattedDate),
                                                    );
                                                  }
                                                },
                                              );
                                            } else {
                                              parameterInputWidget = _buildTextField(
                                                controller: controller,
                                                focusNode: focusNode,
                                                label: paramLabel,
                                                icon: Icons.text_fields,
                                                enableClearButton: true,
                                                onClear: () {
                                                  controller.clear();
                                                  context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, ''));
                                                },
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
                  if ((state.isLoading && state.reports.isEmpty) ||
                      (state.isLoading && state.selectedApiParameters.isNotEmpty && state.pickerOptions.isEmpty))
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