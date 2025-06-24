// lib/ReportAdmin/EditAPI/EditDetailAdmin.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qualityapproach/ReportUtils/subtleloader.dart';
import '../../../ReportUtils/Appbar.dart';
import '../../ReportAPIService.dart';
import 'EditDetailAdminBloc.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Import for debugPrint

class EditDetailAdmin extends StatelessWidget {
  final Map<String, dynamic> apiData;

  const EditDetailAdmin({super.key, required this.apiData});

  @override
  Widget build(BuildContext context) {
    debugPrint('EditDetailAdmin: Building with API Data: ${apiData['APIName']}');
    return BlocProvider(
      create: (context) => EditDetailAdminBloc(ReportAPIService(), apiData)
        ..add(FetchDatabases(
          serverIP: apiData['ServerIP'] ?? '',
          userName: apiData['UserName'] ?? '',
          password: apiData['Password'] ?? '',
        )),
      child: _EditDetailAdminContent(apiData: apiData),
    );
  }
}

class _EditDetailAdminContent extends StatefulWidget {
  final Map<String, dynamic> apiData;

  const _EditDetailAdminContent({required this.apiData});

  @override
  _EditDetailAdminContentState createState() => _EditDetailAdminContentState();
}

class _EditDetailAdminContentState extends State<_EditDetailAdminContent> {
  final Map<int, TextEditingController> _paramControllers = {};
  final TextEditingController _serverIPController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _databaseNameController = TextEditingController();
  final TextEditingController _apiServerURLController = TextEditingController();
  final TextEditingController _apiNameController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    debugPrint('_EditDetailAdminContentState: Initializing state.');
    _serverIPController.text = widget.apiData['ServerIP'] ?? '';
    _userNameController.text = widget.apiData['UserName'] ?? '';
    _passwordController.text = widget.apiData['Password'] ?? '';
    _databaseNameController.text = widget.apiData['DatabaseName'] ?? '';
    _apiServerURLController.text = widget.apiData['APIServerURl'] ?? '';
    _apiNameController.text = widget.apiData['APIName'] ?? '';

    _serverIPController.addListener(() {
      _debouncedUpdate(() {
        debugPrint('ServerIP Controller: Value changed to ${_serverIPController.text}');
        context.read<EditDetailAdminBloc>().add(UpdateServerIP(_serverIPController.text));
      });
    });
    _userNameController.addListener(() {
      _debouncedUpdate(() {
        debugPrint('UserName Controller: Value changed to ${_userNameController.text}');
        context.read<EditDetailAdminBloc>().add(UpdateUserName(_userNameController.text));
      });
    });
    _passwordController.addListener(() {
      _debouncedUpdate(() {
        debugPrint('Password Controller: Value changed to ${_passwordController.text}');
        context.read<EditDetailAdminBloc>().add(UpdatePassword(_passwordController.text));
      });
    });
    _apiServerURLController.addListener(() {
      _debouncedUpdate(() {
        debugPrint('APIServerURL Controller: Value changed to ${_apiServerURLController.text}');
        context.read<EditDetailAdminBloc>().add(UpdateApiServerURL(_apiServerURLController.text));
      });
    });
    _apiNameController.addListener(() {
      _debouncedUpdate(() {
        debugPrint('APIName Controller: Value changed to ${_apiNameController.text}');
        context.read<EditDetailAdminBloc>().add(UpdateApiName(_apiNameController.text));
      });
    });
  }

// This function is now part of _buildParameterRows, but the logic is applied there.
  void _initializeParameterControllers(List<Map<String, dynamic>> parameters) {
    // This function body is intentionally left empty as its logic is now inside _buildParameterRows
    // to avoid redundant iterations and ensure controllers are handled in one place.
  }

  @override
  void dispose() {
    debugPrint('_EditDetailAdminContentState: Disposing controllers.');
    _debounce?.cancel();
    _paramControllers.values.forEach((controller) => controller.dispose()); // Dispose all param controllers
    _serverIPController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _databaseNameController.dispose();
    _apiServerURLController.dispose();
    _apiNameController.dispose();
    super.dispose();
  }

  DateFormat? _inferDateFormat(String dateString) {
    if (dateString.isEmpty) return null;
    debugPrint('Inferring date format for: "$dateString"');

    final List<String> commonFormats = [
      'dd-MMM-yyyy',
      'yyyy-MM-dd',
      'MM/dd/yyyy',
      'dd/MM/yyyy',
      'MMM dd, yyyy',
    ];

    for (String format in commonFormats) {
      try {
        DateFormat(format).parseStrict(dateString);
        debugPrint('  Inferred format: $format');
        return DateFormat(format);
      } catch (e) {
// Not this format, try next
      }
    }
    debugPrint('  Could not infer format. Returning null.');
    return null;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool obscureText = false,
    bool isSmall = false,
    bool isDateField = false,
    VoidCallback? onTap,
    VoidCallback? onAutoDateTap, // New parameter for auto-date icon tap
    IconData? suffixIcon,
    VoidCallback? onSuffixIconTap,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      readOnly: isDateField || readOnly,
      onTap: isDateField ? onTap : null,
      style: GoogleFonts.poppins(fontSize: isSmall ? 14 : 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey[700],
          fontSize: isSmall ? 13 : 15,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: isSmall ? 20 : 22) : null,
        suffixIcon: isDateField
            ? Row(
          mainAxisSize: MainAxisSize.min, // Essential for proper layout
          children: [
            IconButton(
              icon: Icon(Icons.auto_awesome, color: Colors.orangeAccent, size: isSmall ? 18 : 20),
              onPressed: onAutoDateTap,
              tooltip: 'Select Predefined Date',
            ),
            IconButton(
              icon: Icon(Icons.calendar_today, color: Colors.blueAccent, size: isSmall ? 18 : 20),
              onPressed: onTap,
              tooltip: 'Pick Date from Calendar',
            ),
          ],
        )
            : (suffixIcon != null
            ? IconButton(
          icon: Icon(suffixIcon, color: Colors.blueAccent, size: isSmall ? 18 : 20),
          onPressed: onSuffixIconTap,
        )
            : null),
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
        contentPadding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16, horizontal: isSmall ? 12 : 16),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String label,
    IconData? icon,
  }) {
    debugPrint('Building dropdown for $label with value: $value, items: ${items.length}');
    return DropdownButtonFormField<String>(
      value: value != null && items.contains(value) ? value : null,
      onChanged: onChanged,
      items: items.isEmpty
          ? [
        const DropdownMenuItem<String>(
          value: null,
          child: Text(
            'No databases available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ]
          : items.map((String database) {
        return DropdownMenuItem<String>(
          value: database,
          child: Text(
            database,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
          ),
        );
      }).toList(),
      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22.0) : null,
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
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    debugPrint('Building button: $text');
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
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
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

  bool _isDateParameter(String name, String value) {
    final datePattern1 = RegExp(r'^\d{2}-\d{2}-\d{4}$');
    final datePattern2 = RegExp(r'^\d{2}-[A-Za-z]{3}-\d{4}$');
    final datePattern3 = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    final bool isDate = name.toLowerCase().contains('date') ||
        datePattern1.hasMatch(value) ||
        datePattern2.hasMatch(value) ||
        datePattern3.hasMatch(value);
    debugPrint('Checking if parameter "${name}" (value: "$value") is date: $isDate');
    return isDate;
  }

  // --- START: NEW DATE HELPER METHODS ---

  DateTime _getFinancialYearStart([DateTime? fromDate]) {
    final now = fromDate ?? DateTime.now();
    // Indian Financial year starts on April 1st.
    // If current month is Jan, Feb, or Mar (1, 2, 3), the FY started last year.
    final year = now.month < 4 ? now.year - 1 : now.year;
    return DateTime(year, 4, 1);
  }

  DateTime _getFinancialYearEnd([DateTime? fromDate]) {
    final now = fromDate ?? DateTime.now();
    // Indian Financial year ends on March 31st.
    // If current month is Jan, Feb, or Mar (1, 2, 3), the FY ends this year.
    final year = now.month < 4 ? now.year : now.year + 1;
    return DateTime(year, 3, 31);
  }

  DateTime _getStartOfMonth([DateTime? fromDate]) {
    final now = fromDate ?? DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime _getEndOfMonth([DateTime? fromDate]) {
    final now = fromDate ?? DateTime.now();
    // Go to the next month and get day 0, which is the last day of the current month.
    return DateTime(now.year, now.month + 1, 0);
  }

  DateTime _getStartOfWeek([DateTime? fromDate]) {
    final now = fromDate ?? DateTime.now();
    // weekday is 1 for Monday and 7 for Sunday.
    return now.subtract(Duration(days: now.weekday - 1));
  }

  DateTime _getEndOfWeek([DateTime? fromDate]) {
    final now = fromDate ?? DateTime.now();
    return now.add(Duration(days: DateTime.daysPerWeek - now.weekday));
  }

  void _updateDateParameter(
      DateTime? pickedDate, TextEditingController controller, int index, DateFormat? existingFormat) {
    if (pickedDate != null && context.mounted) {
      debugPrint('Date picked/selected: $pickedDate for index $index');
      // Use the existing format if available, otherwise default to dd-MMM-yyyy
      final DateFormat outputFormat = existingFormat ?? DateFormat('dd-MMM-yyyy');
      final formattedDate = outputFormat.format(pickedDate);
      debugPrint('  Formatted date: $formattedDate');
      controller.text = formattedDate;
      // Update the BLoC state
      context.read<EditDetailAdminBloc>().add(UpdateParameterUIValue(index, formattedDate));
    } else {
      debugPrint('Date picker/selector dismissed or no date selected for index $index.');
    }
  }

  Future<DateTime?> _showAutoDateSelectionDialog(BuildContext context) async {
    return await showDialog<DateTime>(
      context: context,
      builder: (BuildContext dialogContext) {
        // Helper to build list tiles
        Widget buildOption(String title, DateTime date) {
          return ListTile(
            leading: const Icon(Icons.touch_app, color: Colors.blueAccent),
            title: Text(title, style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.of(dialogContext).pop(date);
            },
          );
        }

        final now = DateTime.now();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Select a Predefined Date', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildOption('Current Date', now),
                const Divider(),
                buildOption('Start of This Week', _getStartOfWeek(now)),
                buildOption('End of This Week', _getEndOfWeek(now)),
                const Divider(),
                buildOption('Start of This Month', _getStartOfMonth(now)),
                buildOption('End of This Month', _getEndOfMonth(now)),
                const Divider(),
                buildOption('Starting of Financial Year', _getFinancialYearStart(now)),
                buildOption('Ending of Financial Year', _getFinancialYearEnd(now)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  // --- END: NEW DATE HELPER METHODS ---

  Future<void> _selectDate(BuildContext context, TextEditingController controller, int index) async {
    debugPrint('Selecting date for index $index, current value: ${controller.text}');
    DateTime? initialDate;
    DateFormat? inferredFormat;

    if (controller.text.isNotEmpty) {
      inferredFormat = _inferDateFormat(controller.text);
      if (inferredFormat != null) {
        try {
          initialDate = inferredFormat.parse(controller.text);
          debugPrint('  Parsed initial date: $initialDate');
        } catch (e) {
          debugPrint('  Error parsing initial date: $e. Using DateTime.now().');
          initialDate = DateTime.now();
        }
      }
    }
    initialDate ??= DateTime(2000); // Fallback to a sensible default if parsing fails or text is empty

    final DateTime? picked = await showDatePicker(
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

    _updateDateParameter(picked, controller, index, inferredFormat);
  }

  Future<String?> _showFieldLabelDialog(BuildContext context, String paramName, String? currentLabel) async {
    debugPrint('Showing field label dialog for parameter: $paramName, current label: "$currentLabel"');
    final TextEditingController labelController = TextEditingController(text: currentLabel ?? '');
    String? fieldLabel;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        title: Text(
          'Edit Field Label for ${paramName.toUpperCase()}',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: _buildTextField(
          controller: labelController,
          label: 'Field Label',
          icon: Icons.label,
          isSmall: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('Field label dialog: Cancelled.');
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              if (labelController.text.trim().isNotEmpty) {
                fieldLabel = labelController.text.trim();
                debugPrint('Field label dialog: OK, new label: "$fieldLabel"');
                Navigator.pop(context);
              } else {
                debugPrint('Field label dialog: Attempted to save empty label.');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Field label cannot be empty',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: Text(
              'OK',
              style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    labelController.dispose();
    return fieldLabel;
  }

  void _debouncedUpdate(VoidCallback callback) {
    if (_debounce?.isActive ?? false) {
      debugPrint('Debounce: Cancelling previous timer.');
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      debugPrint('Debounce: Executing callback.');
      callback();
    });
  }

  List<Widget> _buildParameterRows(EditDetailAdminState state, BuildContext context) {
    debugPrint('_buildParameterRows: Building UI for parameters.');
    final List<Widget> rows = [];
    final List<Map<String, dynamic>> allParamsOrdered = state.parameters;

    for (var i = 0; i < allParamsOrdered.length; i++) {
      final param = allParamsOrdered[i];
      final index = i;

      _paramControllers.putIfAbsent(index, () => TextEditingController());
      final TextEditingController paramController = _paramControllers[index]!;

// MODIFICATION 1: Always display the raw 'value' in the text field.
      String textToDisplayInField = param['value']?.toString() ?? '';

      debugPrint('  Param $i (${param['name']}): current UI text "${paramController.text}", Bloc value "${param['value']}", Display cache "${param['display_value_cache']}", Text to display "${textToDisplayInField}" (config_type: ${param['config_type']})');

      if (paramController.text != textToDisplayInField) {
        debugPrint('  Param $i (${param['name']}): Updating UI text from "${paramController.text}" to "$textToDisplayInField"');
        paramController.text = textToDisplayInField;
        paramController.selection = TextSelection.fromPosition(TextPosition(offset: paramController.text.length));
      }

      if (!paramController.hasListeners) {
        debugPrint('  Param $i (${param['name']}): Re-adding listener to controller.');
        paramController.addListener(() {
          _debouncedUpdate(() {
            debugPrint('  Param ${param['name']} Controller: Typed value changed to ${paramController.text}');
            final bloc = context.read<EditDetailAdminBloc>();
// MODIFICATION 2: Adjust the guard to compare against 'value' to prevent feedback loops.
            if (i < bloc.state.parameters.length && bloc.state.parameters[i]['value']?.toString() != paramController.text) {
              debugPrint('  Controller text differs from BLoC state value. Dispatching update.');
              context.read<EditDetailAdminBloc>().add(UpdateParameterUIValue(i, paramController.text));
            } else {
              debugPrint('  Skipping update: controller text matches BLoC state value.');
            }
          });
        });
      }

      final bool isDate = _isDateParameter(param['name'].toString(), param['value'].toString());
      final String configType = param['config_type'] ?? 'database';

      IconData suffixIcon = Icons.settings;
      switch (configType) {
        case 'database':
          suffixIcon = Icons.storage;
          break;
        case 'radio':
          suffixIcon = Icons.radio_button_checked;
          break;
        case 'checkbox':
          suffixIcon = Icons.check_box;
          break;
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: paramController,
                        label: (param['field_label']?.toString().isNotEmpty == true)
                            ? param['field_label']!.toString()
                            : (param['name']?.toString() ?? 'Unnamed Parameter'),
                        isSmall: true,
                        isDateField: isDate,
                        readOnly: true, // Make date fields read-only to force using pickers
                        onTap: isDate ? () => _selectDate(context, paramController, index) : null,
                        onAutoDateTap: isDate
                            ? () async {
                          final pickedDate = await _showAutoDateSelectionDialog(context);
                          final inferredFormat = _inferDateFormat(paramController.text);
                          _updateDateParameter(pickedDate, paramController, index, inferredFormat);
                        }
                            : null,
                        suffixIcon: isDate ? null : suffixIcon,
                        onSuffixIconTap: isDate
                            ? null
                            : () async {
                          debugPrint('Opening config modal for parameter: ${param['name']}');
                          final blocState = context.read<EditDetailAdminBloc>().state;
                          final currentParam = blocState.parameters[index];

                          final Map<String, dynamic>? result = await showGeneralDialog<Map<String, dynamic>>(
                            context: context,
                            barrierDismissible: true,
                            barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                            barrierColor: Colors.black54,
                            transitionDuration: const Duration(milliseconds: 200),
                            pageBuilder: (dialogContext, animation, secondaryAnimation) {
                              return _ParameterConfigModal(
                                apiService: context.read<EditDetailAdminBloc>().apiService,
                                paramIndex: index,
                                currentParam: currentParam,
                                serverIP: blocState.serverIP,
                                userName: blocState.userName,
                                password: blocState.password,
                                databaseName: blocState.databaseName,
                              );
                            },
                            transitionBuilder: (context, a1, a2, child) {
                              return ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: a1,
                                  curve: Curves.easeOutBack,
                                ),
                                child: child,
                              );
                            },
                          );

                          if (result != null && context.mounted) {
                            debugPrint('Config modal returned result: $result');

                            context.read<EditDetailAdminBloc>().add(
                              UpdateParameterFromModal(
                                index: index,
                                newConfigType: result['config_type'],
                                newValue: result['value'],
                                newDisplayLabel: result['display_label'],
                                newMasterTable: result['master_table'],
                                newMasterField: result['master_field'],
                                newDisplayField: result['display_field'],
                                newOptions: (result['options'] as List?)
                                    ?.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
                                    .toList(),
                                newSelectedValues: result['selected_values']?.cast<String>(),
                              ),
                            );
                          } else {
                            debugPrint('Config modal dismissed or returned null.');
                          }
                        },
                      ),
                    ),
                    if (param['show'] ?? false)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                        onPressed: () async {
                          final fieldLabel = await _showFieldLabelDialog(context, param['name'], param['field_label']);
                          if (fieldLabel != null && context.mounted) {
                            debugPrint('Updating field label for ${param['name']} to "$fieldLabel"');
                            context.read<EditDetailAdminBloc>().add(UpdateParameterFieldLabel(index, fieldLabel));
                          }
                        },
                        tooltip: 'Edit Field Label',
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Mark as Company Name Field',
                child: Radio<int>(
                  value: index,
                  groupValue: state.parameters.indexWhere((p) => (p['is_company_name_field'] as bool?) == true),
                  onChanged: (int? selectedIndex) {
                    if (selectedIndex != null && context.mounted) {
                      debugPrint('Setting company name field to index $selectedIndex (${state.parameters[selectedIndex]['name']})');
                      context.read<EditDetailAdminBloc>().add(UpdateParameterIsCompanyNameField(selectedIndex));
                    }
                  },
                  activeColor: Colors.deepOrange,
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: param['show'] ?? false,
                onChanged: (value) async {
                  debugPrint('Toggling "show" for parameter ${param['name']} to $value');
                  if (value == true) {
                    final fieldLabel = await _showFieldLabelDialog(context, param['name'], param['field_label']);
                    if (fieldLabel != null && context.mounted) {
                      context.read<EditDetailAdminBloc>().add(UpdateParameterFieldLabel(index, fieldLabel));
                      context.read<EditDetailAdminBloc>().add(UpdateParameterShow(index, true));
                    }
                  } else {
                    context.read<EditDetailAdminBloc>().add(UpdateParameterShow(index, false));
                  }
                },
                activeColor: Colors.blueAccent,
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('_EditDetailAdminContentState: Rebuilding widget tree.');
    return Scaffold(
      appBar: AppBarWidget(
        title: 'Edit API: ${widget.apiData['APIName']}',
        onBackPress: () {
          debugPrint('Back button pressed.');
          Navigator.pop(context);
        },
      ),
      body: BlocConsumer<EditDetailAdminBloc, EditDetailAdminState>(
        listener: (context, state) {
          debugPrint('BlocConsumer Listener: State updated. isLoading: ${state.isLoading}, error: ${state.error}, saveInitiated: ${state.saveInitiated}');
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
          } else if (!state.isLoading && state.saveInitiated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Changes saved successfully',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 3),
              ),
            );
            debugPrint('Save successful, popping navigator.');
            Navigator.pop(context, true);
          }
// The build method will now handle controller updates via _buildParameterRows
        },
        builder: (context, state) {
          debugPrint('BlocConsumer Builder: Current state - DatabaseName: ${state.databaseName}, Parameters: ${state.parameters.length}');
          return Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                  child: Card(
                    color: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit API Configuration',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _serverIPController,
                                  label: 'Server IP',
                                  icon: Icons.dns,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _userNameController,
                                  label: 'Username',
                                  icon: Icons.person,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  icon: Icons.lock,
                                  obscureText: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: state.isLoading && state.availableDatabases.isEmpty
                                    ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                                    child: CircularProgressIndicator(color: Colors.blueAccent),
                                  ),
                                )
                                    : _buildDropdownField(
                                  value: state.databaseName,
                                  items: state.availableDatabases,
                                  onChanged: (value) {
                                    if (value != null) {
                                      debugPrint('Database dropdown changed to: $value');
                                      _databaseNameController.text = value;
                                      context.read<EditDetailAdminBloc>().add(UpdateDatabaseName(value));
                                    }
                                  },
                                  label: 'Database Name',
                                  icon: Icons.storage,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _apiServerURLController,
                                  label: 'API Server URL',
                                  icon: Icons.link,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _apiNameController,
                                  label: 'API Name',
                                  icon: Icons.api,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.grey, thickness: 1),
                          const SizedBox(height: 10),
                          const SizedBox(height: 10),
                          Text(
                            'Parameters',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (state.parameters.isEmpty)
                            Text(
                              'No parameters available',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            ..._buildParameterRows(state, context),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildButton(
                                text: 'Save',
                                color: Colors.blueAccent,
                                onPressed: state.isLoading
                                    ? () {
                                  debugPrint('Save button pressed (loading state).');
                                }
                                    : () {
                                  debugPrint('Save button pressed.');
                                  context.read<EditDetailAdminBloc>().add(SaveChanges());
                                },
                                icon: Icons.save,
                              ),
                              const SizedBox(width: 12),
                              _buildButton(
                                text: 'Cancel',
                                color: Colors.grey,
                                onPressed: state.isLoading
                                    ? () {
                                  debugPrint('Cancel button pressed (loading state).');
                                }
                                    : () {
                                  debugPrint('Cancel button pressed.');
                                  Navigator.pop(context);
                                },
                                icon: Icons.cancel,
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          const Divider(color: Colors.grey, thickness: 1),
                          const SizedBox(height: 20),
                          _buildHelpSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (state.isLoading)
                const Center(
                  child: SubtleLoader(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHelpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to configure parameters:',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        _buildHelpRow(
          icon: Icons.visibility,
          label: 'Show/Hide Parameter (Checkbox):',
          description: 'Check this box to make a parameter visible and editable to the end-user. Uncheck to hide it.',
        ),
        _buildHelpRow(
          icon: Icons.edit,
          label: 'Edit Field Label (Pencil Icon):',
          description: 'Click this icon to customize the display name (label) of the parameter that users will see.',
        ),
        _buildHelpRow(
          icon: Icons.radio_button_checked,
          label: 'Mark as Company Name Field (Radio Button):',
          description:
          'Select one parameter to be used as the "Company Name" for specific features like linking data across reports. Only one can be selected per API.',
          color: Colors.deepOrange,
        ),
        _buildHelpRow(
          icon: Icons.settings,
          label: 'Configure Parameter Input (Settings Icon):',
          description:
          'Click this icon next to the parameter value field to open a detailed configuration dialog. Here, you can define how the user inputs the value for this parameter:',
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpRow(
                icon: Icons.storage,
                label: 'Database Picker (Tab in Dialog):',
                description:
                'Link this parameter to a table in your database. Users will get a dropdown/searchable list of values from the specified \'Master Field\' (API Value), with a friendly \'Display Field\' (User Value).',
                isSubItem: true,
              ),
              _buildHelpRow(
                icon: Icons.radio_button_checked,
                label: 'Radio Buttons (Tab in Dialog):',
                description:
                'Define a fixed set of options. Users can choose only one value from this set. Provide an \'API Value\' (actual data) and a \'Display Field\' (what the user sees). The API value will be shown in the main parameter field.',
                isSubItem: true,
              ),
              _buildHelpRow(
                icon: Icons.check_box,
                label: 'Checkboxes (Tab in Dialog):',
                description:
                'Define a fixed set of options. Users can select multiple values from this set. Provide an \'API Value\' and a \'Display Field\'. The API value(s) will be shown in the main parameter field (e.g., comma-separated).',
                isSubItem: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpRow({
    required IconData icon,
    required String label,
    required String description,
    Color color = Colors.blueAccent,
    bool isSubItem = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.0, left: isSubItem ? 16.0 : 0.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParameterConfigModal extends StatefulWidget {
  final ReportAPIService apiService;
  final int paramIndex;
  final Map<String, dynamic> currentParam;
  final String? serverIP;
  final String? userName;
  final String? password;
  final String? databaseName;

  const _ParameterConfigModal({
    required this.apiService,
    required this.paramIndex,
    required this.currentParam,
    this.serverIP,
    this.userName,
    this.password,
    this.databaseName,
  });

  @override
  _ParameterConfigModalState createState() => _ParameterConfigModalState();
}

class _ParameterConfigModalState extends State<_ParameterConfigModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedConfigType = 'database';

// Database Picker state
  List<String> _tables = [];
  String? _selectedTable;
  List<String> _fields = [];
  String? _selectedMasterField;
  String? _selectedDisplayField;
  List<Map<String, String>> _allFieldData = []; // Data fetched from master/display fields
  final TextEditingController _dbPickerSearchController = TextEditingController();
  String _dbPickerSearchRawText = ''; // To manage search filter state

  final TextEditingController _tableAutocompleteController = TextEditingController();
  final TextEditingController _masterFieldAutocompleteController = TextEditingController();
  final TextEditingController _displayFieldAutocompleteController = TextEditingController();

// Radio/Checkbox options state
  List<Map<String, String>> _options = []; // For static options
  String? _radioSelectedValue; // For radio button selection
  List<String> _checkboxSelectedValues = []; // For checkbox selections

  final TextEditingController _apiValueController = TextEditingController();
  final TextEditingController _displayFieldOptionController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    debugPrint('_ParameterConfigModalState: Initializing state.');
    _dbPickerSearchController.addListener(_onDbPickerSearchChanged);

    _selectedConfigType = widget.currentParam['config_type'] ?? 'database';
    _tabController = TabController(length: 3, vsync: this);
    _tabController.index = _configTypeToIndex(_selectedConfigType);
    _tabController.addListener(_handleTabSelection);

    _selectedTable = widget.currentParam['master_table'];
    _tableAutocompleteController.text = _selectedTable ?? '';

    _selectedMasterField = widget.currentParam['master_field'];
    _masterFieldAutocompleteController.text = _selectedMasterField ?? '';

    _selectedDisplayField = widget.currentParam['display_field'];
    _displayFieldAutocompleteController.text = _selectedDisplayField ?? '';

    _options = (widget.currentParam['options'] as List<dynamic>?)
        ?.map((e) => e is Map ? Map<String, String>.from(e.cast<String, String>()) : <String, String>{})
        .where((map) => map.isNotEmpty)
        .toList() ??
        [];
    debugPrint('  Modal initial options: ${_options.length} items');

    if (_selectedConfigType == 'radio') {
      _radioSelectedValue = widget.currentParam['value'];
      debugPrint('  Modal initial radio selected value: $_radioSelectedValue');
    } else if (_selectedConfigType == 'checkbox') {
      _checkboxSelectedValues = List<String>.from(widget.currentParam['selected_values']?.cast<String>() ?? []);
      debugPrint('  Modal initial checkbox selected values: $_checkboxSelectedValues');
    }

    if (_selectedConfigType == 'database') {
      debugPrint('  Modal config type is database. Fetching tables.');
      _fetchTablesForSelectedDatabase();
    }
  }

  int _configTypeToIndex(String configType) {
    switch (configType) {
      case 'database':
        return 0;
      case 'radio':
        return 1;
      case 'checkbox':
        return 2;
      default:
        return 0;
    }
  }

  String _indexToConfigType(int index) {
    switch (index) {
      case 0:
        return 'database';
      case 1:
        return 'radio';
      case 2:
        return 'checkbox';
      default:
        return 'database';
    }
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedConfigType = _indexToConfigType(_tabController.index);
        debugPrint('Modal: Tab selected: $_selectedConfigType');
        if (_selectedConfigType == 'database' && _tables.isEmpty && widget.databaseName != null) {
          debugPrint('  Switching to database tab, tables are empty. Fetching tables.');
          _fetchTablesForSelectedDatabase();
        }
      });
    }
  }

  @override
  void dispose() {
    debugPrint('_ParameterConfigModalState: Disposing controllers.');
    _dbPickerSearchController.dispose();
    _apiValueController.dispose();
    _displayFieldOptionController.dispose();
    _tableAutocompleteController.dispose();
    _masterFieldAutocompleteController.dispose();
    _displayFieldAutocompleteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onDbPickerSearchChanged() {
    setState(() {
      _dbPickerSearchRawText = _dbPickerSearchController.text;
      debugPrint('DB Picker Search changed: "$_dbPickerSearchRawText"');
    });
  }

  List<Map<String, String>> get _filteredFieldData {
    if (_dbPickerSearchRawText.isEmpty) {
      return _allFieldData;
    }
    debugPrint('Filtering field data for: "$_dbPickerSearchRawText"');
    return _allFieldData
        .where((item) => (item['label'] ?? '').toLowerCase().contains(_dbPickerSearchRawText.toLowerCase()))
        .toList();
  }

  Future<void> _fetchTablesForSelectedDatabase() async {
    debugPrint('Attempting to fetch tables for selected database...');
    setState(() {
      _isLoading = true;
      _error = null;
      _tables = [];
      _fields = [];
      _allFieldData = [];
      _dbPickerSearchController.clear();

      _tableAutocompleteController.clear();
      _masterFieldAutocompleteController.clear();
      _displayFieldAutocompleteController.clear();

      _selectedTable = null;
      _selectedMasterField = null;
      _selectedDisplayField = null;
    });

    if (widget.serverIP == null || widget.userName == null || widget.password == null || widget.databaseName == null) {
      setState(() {
        _error = "Database connection details are incomplete.";
        _isLoading = false;
      });
      debugPrint('Error: Database connection details incomplete for fetching tables.');
      return;
    }

    try {
      final tables = await widget.apiService.fetchTables(
        server: widget.serverIP!,
        UID: widget.userName!,
        PWD: widget.password!,
        database: widget.databaseName!,
      );
      setState(() {
        _tables = tables;
        _isLoading = false;
        debugPrint('Successfully fetched ${tables.length} tables.');
        if (widget.currentParam['master_table'] != null && tables.contains(widget.currentParam['master_table'])) {
          _selectedTable = widget.currentParam['master_table'];
          _tableAutocompleteController.text = _selectedTable!;
          debugPrint('  Pre-selected table: $_selectedTable');
          _fetchFieldsForTable(_selectedTable!); // Call to fetch fields for pre-selected table
        } else {
          debugPrint('  No master_table pre-selected or found in fetched tables.');
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load tables for database "${widget.databaseName}": $e';
        _isLoading = false;
      });
      debugPrint('Error fetching tables: $e');
    }
  }

  Future<void> _fetchFieldsForTable(String tableName) async {
    debugPrint('Attempting to fetch fields for table: "$tableName"');
    setState(() {
      _isLoading = true;
      _error = null;
      _fields = [];
      _allFieldData = [];

      _selectedMasterField = null;
      _masterFieldAutocompleteController.clear();
      _selectedDisplayField = null;
      _displayFieldAutocompleteController.clear();
      _dbPickerSearchController.clear();
    });

    if (widget.serverIP == null || widget.userName == null || widget.password == null || widget.databaseName == null) {
      setState(() {
        _error = "Database connection details are incomplete for fields.";
        _isLoading = false;
      });
      debugPrint('Error: Database connection details incomplete for fetching fields.');
      return;
    }

    try {
      final fields = await widget.apiService.fetchFields(
        server: widget.serverIP!,
        UID: widget.userName!,
        PWD: widget.password!,
        database: widget.databaseName!,
        table: tableName,
      );
      setState(() {
        _fields = fields;
        _isLoading = false;
        debugPrint('Successfully fetched ${fields.length} fields for table "$tableName".');

// Attempt to pre-select master field if it exists and is in the fetched fields
        if (widget.currentParam['master_field'] != null && fields.contains(widget.currentParam['master_field'])) {
          _selectedMasterField = widget.currentParam['master_field'];
          _masterFieldAutocompleteController.text = _selectedMasterField!;
          debugPrint('  Pre-selected master field: $_selectedMasterField');
        } else {
          debugPrint('  No master_field pre-selected or found in fetched fields.');
        }

// Attempt to pre-select display field. Prefer existing, then default to master field.
        if (widget.currentParam['display_field'] != null && fields.contains(widget.currentParam['display_field'])) {
          _selectedDisplayField = widget.currentParam['display_field'];
          _displayFieldAutocompleteController.text = _selectedDisplayField!;
          debugPrint('  Pre-selected display field: $_selectedDisplayField');
        } else if (_selectedMasterField != null) {
// If display field is not set or not valid, default it to master field
          _selectedDisplayField = _selectedMasterField;
          _displayFieldAutocompleteController.text = _selectedMasterField!;
          debugPrint('  Display field defaulted to master field: $_selectedDisplayField');
        } else {
          debugPrint('  No display_field pre-selected and no master field to default to.');
        }

// If both master and display fields are selected, fetch actual data for the picker list
        if (_selectedMasterField != null && _selectedDisplayField != null) {
          debugPrint('  Master and display fields selected. Fetching field data...');
          _fetchFieldData();
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load fields for table "$tableName": $e';
        _isLoading = false;
      });
      debugPrint('Error fetching fields for table "$tableName": $e');
    }
  }

  Future<void> _fetchFieldData() async {
    debugPrint('Attempting to fetch actual field data for picker...');
    if (_selectedTable == null || _selectedMasterField == null || _selectedDisplayField == null) {
      setState(() {
        _allFieldData = [];
        _error = "Please select a table, master field, and display field to fetch data.";
        _isLoading = false;
      });
      debugPrint('Error: Missing table, master, or display field for fetching data.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _allFieldData = [];
      _dbPickerSearchController.clear();
      _dbPickerSearchRawText = '';
    });

    try {
      final List<Map<String, dynamic>> rawData = await widget.apiService.fetchPickerData(
        server: widget.serverIP!,
        UID: widget.userName!,
        PWD: widget.password!,
        database: widget.databaseName!,
        masterTable: _selectedTable!,
        masterField: _selectedMasterField!,
        displayField: _selectedDisplayField!,
      );
      debugPrint('Successfully fetched ${rawData.length} raw data items for picker.');

      final List<Map<String, String>> mappedData = [];
      for (var item in rawData) {
        final String value = item[_selectedMasterField]?.toString() ?? '';
        final String label = item[_selectedDisplayField]?.toString() ?? '';
        if (value.isNotEmpty && label.isNotEmpty) {
          mappedData.add({
            'value': value,
            'label': label,
          });
        }
      }
      debugPrint('Mapped ${mappedData.length} valid data items for picker.');

      setState(() {
        _allFieldData = mappedData;
        _isLoading = false;

// Populate search controller with initial value if it matches.
// This is for displaying the *label* in the modal's search field
// if the initial parameter value corresponds to a known label.
        if (widget.currentParam['config_type'] == 'database' &&
            widget.currentParam['value'] != null &&
            widget.currentParam['value'].toString().isNotEmpty) {
          final String initialParamValue = widget.currentParam['value'].toString();

// Try to find a matching label for the initial value
          final matchedItem = mappedData.firstWhere(
                (item) => item['value'] == initialParamValue,
            orElse: () => {},
          );

          if (matchedItem.isNotEmpty && matchedItem['label'] != null) {
            _dbPickerSearchController.text = matchedItem['label']!;
            _dbPickerSearchRawText = matchedItem['label']!;
            debugPrint('  Found match in data. Setting modal search controller to label: "${matchedItem['label']!}"');
          } else {
// If no label found for the initial value, use the value itself or an empty string
            _dbPickerSearchController.text = initialParamValue;
            _dbPickerSearchRawText = initialParamValue;
            debugPrint('  No exact label found for value. Setting modal search controller to initial param value: "$initialParamValue"');
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load field data: $e';
        _isLoading = false;
        _allFieldData = [];
      });
      debugPrint('Error fetching field data for picker: $e');
    }
  }

  void _addOption() {
    final apiValue = _apiValueController.text.trim();
    final displayField = _displayFieldOptionController.text.trim();
    debugPrint('Adding option: API Value: "$apiValue", Display Field: "$displayField"');
    if (apiValue.isNotEmpty && displayField.isNotEmpty) {
      setState(() {
        _options.add({'label': displayField, 'value': apiValue});
        _apiValueController.clear();
        _displayFieldOptionController.clear();
        debugPrint('Option added. Total options: ${_options.length}');
      });
    } else {
      debugPrint('Failed to add option: API Value or Display Field is empty.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Both API Value and Display Field are required.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _removeOption(int index) {
    debugPrint('Removing option at index: $index');
    setState(() {
      final removedOption = _options.removeAt(index);
      if (_selectedConfigType == 'radio' && _radioSelectedValue == removedOption['value']) {
        _radioSelectedValue = null;
        debugPrint('  Removed selected radio value.');
      } else if (_selectedConfigType == 'checkbox' && _checkboxSelectedValues.contains(removedOption['value'])) {
        _checkboxSelectedValues.remove(removedOption['value']);
        debugPrint('  Removed selected checkbox value.');
      }
      debugPrint('Option removed. Remaining options: ${_options.length}');
    });
  }

  InputDecoration _buildDialogTextFieldDecoration(String labelText, {String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('_ParameterConfigModal: Rebuilding modal content.');
    final mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;

    final double modalWidth = screenSize.width * 0.8;
    final double modalHeight = screenSize.height * 0.85;

    return Center(
      child: Material(
        type: MaterialType.card,
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 10,
        child: Container(
          width: modalWidth,
          height: modalHeight,
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure Parameter: ${widget.currentParam['name']?.toString().toUpperCase() ?? 'N/A'}',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _error!,
                    style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              TabBar(
                controller: _tabController,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blueAccent,
                tabs: const [
                  Tab(text: 'Database'),
                  Tab(text: 'Radio Buttons'),
                  Tab(text: 'Checkboxes'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildDatabasePickerView(),
                    _buildOptionsConfigView('radio'),
                    _buildOptionsConfigView('checkbox'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        if (!context.mounted) return;
                        debugPrint('Modal: Cancel button pressed.');
                        Navigator.pop(context);
                      },
                      child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.redAccent)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (!context.mounted) return;
                        debugPrint('Modal: Select button pressed.');
                        _returnResult();
                      },
                      child: Text('Select', style: GoogleFonts.poppins(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatabasePickerView() {
    debugPrint('Modal: Building Database Picker View.');
    return Column(
      children: [
        const SizedBox(height: 16),
        _isLoading && _selectedConfigType == 'database'
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                return _tables.where((String option) {
                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              fieldViewBuilder: (
                  BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                  ) {
                if (textEditingController.text != _tableAutocompleteController.text) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) textEditingController.text = _tableAutocompleteController.text;
                  });
                }
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: _buildDialogTextFieldDecoration(
                    'Select Table',
                    suffixIcon: textEditingController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        debugPrint('Table Autocomplete: Clearing text and resetting state.');
                        textEditingController.clear();
                        setState(() {
                          _selectedTable = null;
                          _tableAutocompleteController.clear();
                          _selectedMasterField = null;
                          _masterFieldAutocompleteController.clear();
                          _selectedDisplayField = null;
                          _displayFieldAutocompleteController.clear();
                          _fields = [];
                          _allFieldData = [];
                          _dbPickerSearchController.clear();
                        });
                      },
                    )
                        : null,
                  ),
                  style: GoogleFonts.poppins(),
                  onChanged: (value) {
                    _tableAutocompleteController.text = value;
                    if (!_tables.contains(value) && _selectedTable != null && _selectedTable != value) {
                      debugPrint('Table Autocomplete: Value changed, table not in list. Resetting fields.');
                      setState(() {
                        _selectedTable = null;
                        _selectedMasterField = null;
                        _selectedDisplayField = null;
                        _fields = [];
                        _allFieldData = [];
                      });
                    }
                  },
                );
              },
              onSelected: (String selection) {
                debugPrint('Table Autocomplete: Selected table: "$selection"');
                setState(() {
                  _selectedTable = selection;
                  _tableAutocompleteController.text = selection;
                  _selectedMasterField = null;
                  _masterFieldAutocompleteController.clear();
                  _selectedDisplayField = null;
                  _displayFieldAutocompleteController.clear();
                  _fields = [];
                  _allFieldData = [];
                  _dbPickerSearchController.clear();
                });
                _fetchFieldsForTable(selection);
                FocusScope.of(context).unfocus();
              },
            ),
            const SizedBox(height: 16),
            if (_selectedTable != null)
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  return _fields.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController textEditingController,
                    FocusNode focusNode,
                    VoidCallback onFieldSubmitted,
                    ) {
                  if (textEditingController.text != _masterFieldAutocompleteController.text) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) textEditingController.text = _masterFieldAutocompleteController.text;
                    });
                  }
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: _buildDialogTextFieldDecoration(
                      'Select Master Field (API Value)',
                      hintText: 'e.g., CustomerID, ItemCode',
                      suffixIcon: textEditingController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          debugPrint('Master Field Autocomplete: Clearing text and resetting state.');
                          textEditingController.clear();
                          setState(() {
                            _selectedMasterField = null;
                            _selectedDisplayField = null;
                            _allFieldData = [];
                            _masterFieldAutocompleteController.clear();
                            _displayFieldAutocompleteController.clear();
                            _dbPickerSearchController.clear();
                          });
                        },
                      )
                          : null,
                    ),
                    style: GoogleFonts.poppins(),
                    onChanged: (value) {
                      _masterFieldAutocompleteController.text = value;
                      if (!_fields.contains(value) && _selectedMasterField != null && _selectedMasterField != value) {
                        debugPrint('Master Field Autocomplete: Value changed, field not in list. Resetting.');
                        setState(() {
                          _selectedMasterField = null;
                          _selectedDisplayField = null;
                          _allFieldData = [];
                        });
                      }
                    },
                  );
                },
                onSelected: (String selection) {
                  debugPrint('Master Field Autocomplete: Selected master field: "$selection"');
                  setState(() {
                    _selectedMasterField = selection;
                    _masterFieldAutocompleteController.text = selection;
                    if (_selectedDisplayField == null ||
                        _selectedDisplayField == widget.currentParam['master_field'] ||
                        !(_fields.contains(_selectedDisplayField))) {
                      _selectedDisplayField = selection;
                      _displayFieldAutocompleteController.text = selection;
                    }
                    _allFieldData = [];
                    _dbPickerSearchController.clear();
                  });
                  _fetchFieldData();
                  FocusScope.of(context).unfocus();
                },
              ),
            const SizedBox(height: 16),
            if (_selectedTable != null && _selectedMasterField != null)
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  return _fields.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController textEditingController,
                    FocusNode focusNode,
                    VoidCallback onFieldSubmitted,
                    ) {
                  if (textEditingController.text != _displayFieldAutocompleteController.text) {
                    WidgetsBinding.instance.addPostFrameCallback((_){
                      if (context.mounted) textEditingController.text = _displayFieldAutocompleteController.text;
                    });
                  }
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: _buildDialogTextFieldDecoration(
                      'Select Display Field (User Value)',
                      hintText: 'e.g., CustomerName, ItemDescription',
                      suffixIcon: textEditingController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          debugPrint('Display Field Autocomplete: Clearing text and resetting state.');
                          textEditingController.clear();
                          setState(() {
                            _selectedDisplayField = null;
                            _allFieldData = [];
                            _displayFieldAutocompleteController.clear();
                            _dbPickerSearchController.clear();
                          });
                        },
                      )
                          : null,
                    ),
                    style: GoogleFonts.poppins(),
                    onChanged: (value) {
                      _displayFieldAutocompleteController.text = value;
                      if (!_fields.contains(value) && _selectedDisplayField != null && _selectedDisplayField != value) {
                        debugPrint('Display Field Autocomplete: Value changed, field not in list. Resetting.');
                        setState(() {
                          _selectedDisplayField = null;
                          _allFieldData = [];
                        });
                      }
                    },
                  );
                },
                onSelected: (String selection) {
                  debugPrint('Display Field Autocomplete: Selected display field: "$selection"');
                  setState(() {
                    _selectedDisplayField = selection;
                    _displayFieldAutocompleteController.text = selection;
                    _allFieldData = [];
                    _dbPickerSearchController.clear();
                  });
                  if (_selectedMasterField != null && _selectedDisplayField != null) {
                    _fetchFieldData();
                  }
                  FocusScope.of(context).unfocus();
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedTable != null && _selectedMasterField != null && _selectedDisplayField != null)
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: _dbPickerSearchController,
                  decoration: _buildDialogTextFieldDecoration(
                    'Search values (by User Value)',
                    suffixIcon: _dbPickerSearchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        debugPrint('Search field cleared.');
                        _dbPickerSearchController.clear();
                      },
                    )
                        : null,
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _filteredFieldData.isEmpty
                      ? Center(
                    child: Text(
                      _dbPickerSearchRawText.isNotEmpty
                          ? 'No matching values found for "${_dbPickerSearchRawText}".'
                          : 'No values available for this field combination.',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    itemCount: _filteredFieldData.length,
                    itemBuilder: (context, index) {
                      final item = _filteredFieldData[index];
                      final displayLabel = item['label'];
                      final masterValue = item['value'];
                      debugPrint('  List item: label="$displayLabel", value="$masterValue"');
                      return ListTile(
                        title: Text(displayLabel ?? '', style: GoogleFonts.poppins()),
                        subtitle: (displayLabel != masterValue && masterValue != null && masterValue.isNotEmpty)
                            ? Text('API Value: ($masterValue)',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))
                            : null,
                        onTap: () {
                          if (!context.mounted) return;
                          debugPrint('List item tapped: label="$displayLabel", value="$masterValue"');
// When a picker item is tapped, explicitly return both value and display_label
                          Navigator.pop(context, {
                            'config_type': 'database',
                            'value': masterValue,
                            'display_label': displayLabel,
                            'master_table': _selectedTable,
                            'master_field': _selectedMasterField,
                            'display_field': _selectedDisplayField,
                            'options': [], // Clear options as this is database picker
                            'selected_values': [], // Clear selected values
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOptionsConfigView(String type) {
    bool isRadio = type == 'radio';
    debugPrint('Modal: Building Options Config View (Type: $type).');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Define ${isRadio ? 'Radio Button' : 'Checkbox'} Options',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _apiValueController,
                decoration: _buildDialogTextFieldDecoration(
                  'API Value',
                  hintText: 'e.g., A, 1, Active',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _apiValueController.clear,
                  ),
                ),
                style: GoogleFonts.poppins(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _displayFieldOptionController,
                decoration: _buildDialogTextFieldDecoration(
                  'Display Field (User Value)',
                  hintText: 'e.g., Option A, Value 1, True',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _displayFieldOptionController.clear,
                  ),
                ),
                style: GoogleFonts.poppins(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addOption,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _options.isEmpty
              ? Center(
            child: Text(
              'No options added yet.',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          )
              : ListView.builder(
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final option = _options[index];
              debugPrint('  Option item: label="${option['label']}", value="${option['value']}"');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  title: Text(option['label']!, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  subtitle: Text('API Value: ${option['value']!}',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  leading: isRadio
                      ? Radio<String>(
                    value: option['value']!,
                    groupValue: _radioSelectedValue,
                    onChanged: (String? value) {
                      setState(() {
                        _radioSelectedValue = value;
                        debugPrint('Radio button selected: $_radioSelectedValue');
                      });
                    },
                  )
                      : Checkbox(
                    value: _checkboxSelectedValues.contains(option['value']!),
                    onChanged: (bool? checked) {
                      setState(() {
                        if (checked == true) {
                          _checkboxSelectedValues.add(option['value']!);
                          debugPrint('Checkbox selected: ${option['value']!}');
                        } else {
                          _checkboxSelectedValues.remove(option['value']!);
                          debugPrint('Checkbox unselected: ${option['value']!}');
                        }
                      });
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      debugPrint('Deleting option: ${option['label']}');
                      _removeOption(index);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _returnResult() {
    debugPrint('Modal: Returning result to parent widget. Config type: $_selectedConfigType');
    String? finalValue;
    String? finalDisplayLabel;
    Map<String, dynamic> result = {
      'config_type': _selectedConfigType,
      'master_table': null,
      'master_field': null,
      'display_field': null,
      'options': _options, // Always send all options data for radio/checkbox
      'selected_values': [],
    };

    if (_selectedConfigType == 'radio') {
      finalValue = _radioSelectedValue;
// Get the label for the selected radio value
      finalDisplayLabel =
      _options.firstWhere((opt) => opt['value'] == finalValue, orElse: () => {})['label'];
      result['selected_values'] = finalValue != null ? [finalValue] : [];
      debugPrint('  Radio result: value="$finalValue", display_label="$finalDisplayLabel"');
    } else if (_selectedConfigType == 'checkbox') {
// For checkboxes, value is comma-separated API values
      finalValue = _checkboxSelectedValues.join(',');
// For checkboxes, display_label is comma-separated labels
      finalDisplayLabel = _checkboxSelectedValues
          .map((val) => _options.firstWhere((opt) => opt['value'] == val, orElse: () => {})['label'] ?? val)
          .join(', ');
      result['selected_values'] = _checkboxSelectedValues;
      debugPrint('  Checkbox result: value="$finalValue", display_label="$finalDisplayLabel"');
    } else {
// config_type == 'database'
// When 'Select' is pressed for database picker, prioritize value from search controller
// If the search controller's text matches a filtered item, use its value/label
      debugPrint('  Database picker result: checking search controller value: "${_dbPickerSearchController.text}"');
      final matchedItem = _allFieldData.firstWhere(
            (item) => item['label']?.toLowerCase() == _dbPickerSearchController.text.toLowerCase(),
        orElse: () => {},
      );

      if (matchedItem.isNotEmpty && matchedItem['value'] != null && matchedItem['label'] != null) {
        finalValue = matchedItem['value'];
        finalDisplayLabel = matchedItem['label'];
        debugPrint('  Matched item found: value="$finalValue", display_label="$finalDisplayLabel"');
      } else {
// If no match found, use the raw text from the search controller for finalValue
// and set finalDisplayLabel to null.
        finalValue = _dbPickerSearchController.text.isNotEmpty ? _dbPickerSearchController.text : null;
        finalDisplayLabel = null; // If no match, no distinct display label
        debugPrint('  No exact match found. Using raw text for value, display_label is null: "$finalValue"');
      }

      result['master_table'] = _selectedTable;
      result['master_field'] = _selectedMasterField;
      result['display_field'] = _selectedDisplayField;
    }

    result['value'] = finalValue;
    result['display_label'] = finalDisplayLabel; // Pass null if no label found/applicable
    debugPrint('Modal will pop with result: $result');
    Navigator.pop(context, result);
  }
}