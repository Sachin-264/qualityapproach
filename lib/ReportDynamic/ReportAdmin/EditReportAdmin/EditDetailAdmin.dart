import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qualityapproach/ReportUtils/subtleloader.dart';
import '../../../ReportUtils/Appbar.dart';
import '../../ReportAPIService.dart';
import 'EditDetailAdminBloc.dart';
import 'dart:async';

class EditDetailAdmin extends StatelessWidget {
  final Map<String, dynamic> apiData;

  const EditDetailAdmin({super.key, required this.apiData});

  @override
  Widget build(BuildContext context) {
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
    _serverIPController.text = widget.apiData['ServerIP'] ?? '';
    _userNameController.text = widget.apiData['UserName'] ?? '';
    _passwordController.text = widget.apiData['Password'] ?? '';
    _databaseNameController.text = widget.apiData['DatabaseName'] ?? '';
    _apiServerURLController.text = widget.apiData['APIServerURl'] ?? '';
    _apiNameController.text = widget.apiData['APIName'] ?? '';

    // Initialize parameter controllers and listeners from state (IMPORTANT for existing data)
    // Delay this initialization until after the first frame to ensure BLoC state is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        // We need to re-fetch parameters from the BLoC state as it might contain
        // the full, parsed structure including 'is_company_name_field'.
        final parameters = context.read<EditDetailAdminBloc>().state.parameters;
        _initializeParameterControllers(parameters);
      }
    });

    _serverIPController.addListener(() {
      _debouncedUpdate(() {
        context.read<EditDetailAdminBloc>().add(UpdateServerIP(_serverIPController.text));
      });
    });
    _userNameController.addListener(() {
      _debouncedUpdate(() {
        context.read<EditDetailAdminBloc>().add(UpdateUserName(_userNameController.text));
      });
    });
    _passwordController.addListener(() {
      _debouncedUpdate(() {
        context.read<EditDetailAdminBloc>().add(UpdatePassword(_passwordController.text));
      });
    });
    _apiServerURLController.addListener(() {
      _debouncedUpdate(() {
        context.read<EditDetailAdminBloc>().add(UpdateApiServerURL(_apiServerURLController.text));
      });
    });
    _apiNameController.addListener(() {
      _debouncedUpdate(() {
        print('User entered APIName: ${_apiNameController.text}');
        print('Dispatching UpdateApiName with: ${_apiNameController.text}');
        context.read<EditDetailAdminBloc>().add(UpdateApiName(_apiNameController.text));
      });
    });
  }

  // Helper method to consolidate parameter controller initialization
  void _initializeParameterControllers(List<Map<String, dynamic>> parameters) {
    for (var i = 0; i < parameters.length; i++) {
      // Create controller if it doesn't exist
      _paramControllers[i] ??= TextEditingController();
      // Set text from current parameter value
      final String valueToDisplay = parameters[i]['value']?.toString() ?? '';
      if (_paramControllers[i]!.text != valueToDisplay) { // Only update if different to avoid cursor jump
        _paramControllers[i]!.text = valueToDisplay;
      }

      // Add listener if not already added
      if (!_paramControllers[i]!.hasListeners) {
        _paramControllers[i]!.addListener(() {
          _debouncedUpdate(() {
            context.read<EditDetailAdminBloc>().add(UpdateParameterValue(i, _paramControllers[i]!.text));
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _paramControllers.values.forEach((controller) => controller.dispose());
    _serverIPController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _databaseNameController.dispose();
    _apiServerURLController.dispose();
    _apiNameController.dispose();
    super.dispose();
  }

  // Helper to infer date format from a string
  DateFormat? _inferDateFormat(String dateString) {
    if (dateString.isEmpty) return null;

    final List<String> commonFormats = [
      'dd-MMM-yyyy', // e.g., 26-Oct-2023
      'yyyy-MM-dd',  // e.g., 2023-10-26
      'MM/dd/yyyy',  // e.g., 10/26/2023
      'dd/MM/yyyy',  // e.g., 26/10/2023
      'MMM dd, yyyy',// e.g., Oct 26, 2023
    ];

    for (String format in commonFormats) {
      try {
        DateFormat(format).parseStrict(dateString); // Use parseStrict for precise matching
        return DateFormat(format);
      } catch (e) {
        // Not this format, try next
      }
    }
    return null; // No matching format found
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool obscureText = false,
    bool isSmall = false,
    bool isDateField = false,
    VoidCallback? onTap, // For date picker
    IconData? suffixIcon, // New for field selection
    VoidCallback? onSuffixIconTap, // New for field selection
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      readOnly: isDateField, // Keep readOnly for date fields
      onTap: isDateField ? onTap : null, // Only onTap for date fields (opens date picker)
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
            ? Icon(Icons.calendar_today, color: Colors.blueAccent, size: isSmall ? 18 : 20)
            : (suffixIcon != null // If it's not a date field, check for a custom suffixIcon
            ? IconButton(
          icon: Icon(suffixIcon, color: Colors.blueAccent, size: isSmall ? 18 : 20),
          onPressed: onSuffixIconTap, // Use new callback for custom suffix icon
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
    return ElevatedButton(
      onPressed: onPressed, // The onPressed is directly passed, handling null/empty for disabled state
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
    // Check if the parameter name contains 'date' or if the value matches a common date pattern
    final datePattern1 = RegExp(r'^\d{2}-\d{2}-\d{4}$'); // DD-MM-YYYY
    final datePattern2 = RegExp(r'^\d{2}-[A-Za-z]{3}-\d{4}$'); // DD-MMM-YYYY
    final datePattern3 = RegExp(r'^\d{4}-\d{2}-\d{2}$'); // YYYY-MM-DD

    return name.toLowerCase().contains('date') || datePattern1.hasMatch(value) || datePattern2.hasMatch(value) || datePattern3.hasMatch(value);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller, int index) async {
    DateTime? initialDate;
    DateFormat? inferredFormat;

    if (controller.text.isNotEmpty) {
      inferredFormat = _inferDateFormat(controller.text);
      if (inferredFormat != null) {
        try {
          initialDate = inferredFormat.parse(controller.text);
        } catch (e) {
          // If parsing fails despite inferred format (e.g., malformed date), fall back
          initialDate = DateTime.now();
        }
      }
    }
    initialDate ??= DateTime.now(); // Default if no text or no format inferred

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

    if (picked != null && context.mounted) {
      // Use the inferred format for output, or default to dd-MMM-yyyy
      final DateFormat outputFormat = inferredFormat ?? DateFormat('dd-MMM-yyyy');
      final formattedDate = outputFormat.format(picked);
      controller.text = formattedDate;
      context.read<EditDetailAdminBloc>().add(UpdateParameterValue(index, formattedDate));
    }
  }

  Future<String?> _showFieldLabelDialog(BuildContext context, String paramName, String? currentLabel) async {
    final TextEditingController labelController = TextEditingController(text: currentLabel ?? '');
    String? fieldLabel;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        title: Text(
          'Enter Field Label for $paramName',
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              if (labelController.text.trim().isNotEmpty) {
                fieldLabel = labelController.text.trim();
                Navigator.pop(context);
              } else {
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
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), callback);
  }

  // Modified _buildParameterRows to accept the full state
  List<Widget> _buildParameterRows(EditDetailAdminState state, BuildContext context) {
    final List<Widget> rows = [];
    final List<Map<String, dynamic>> allParamsOrdered = state.parameters; // Get from BLoC state

    for (var i = 0; i < allParamsOrdered.length; i++) {
      final param = allParamsOrdered[i];
      final index = i; // This is the actual index in the state.parameters list

      // Ensure controller exists and is linked to the correct value
      // This part was moved to _initializeParameterControllers and should be less critical here
      // But we still need to ensure the text field is updated if state changes from modal
      final currentText = _paramControllers[index]?.text;
      final newValueFromBloc = param['value']?.toString() ?? '';
      if (currentText != newValueFromBloc) {
        _paramControllers[index]?.text = newValueFromBloc; // Use ?. for safety if controller not yet created (shouldn't happen with initState logic)
      }
      _paramControllers[index] ??= TextEditingController(text: newValueFromBloc); // Fallback if controller not yet created

      final bool isDate = _isDateParameter(param['name'].toString(), param['value'].toString());
      final String? masterTable = param['master_table']?.toString();
      final String? masterField = param['master_field']?.toString();
      final String? displayField = param['display_field']?.toString();
      final bool isCompanyNameField = param['is_company_name_field'] ?? false; // NEW: Get company name flag

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
                        controller: _paramControllers[index]!,
                        label: param['field_label']?.isNotEmpty ?? false ? param['field_label'] : param['name'],
                        isSmall: true,
                        isDateField: isDate,
                        onTap: isDate ? () => _selectDate(context, _paramControllers[index]!, index) : null,
                        suffixIcon: isDate ? null : Icons.table_view, // Show table icon for non-date fields
                        onSuffixIconTap: isDate
                            ? null
                            : () async { // Only for non-date fields, allow selecting master values
                          final blocState = context.read<EditDetailAdminBloc>().state;
                          // Pass actual current values for pre-population
                          final result = await showGeneralDialog<Map<String, String?>>(
                            context: context,
                            barrierDismissible: true,
                            barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                            barrierColor: Colors.black54,
                            transitionDuration: const Duration(milliseconds: 200),
                            pageBuilder: (dialogContext, animation, secondaryAnimation) {
                              return _SelectFieldValuesModal(
                                apiService: context.read<EditDetailAdminBloc>().apiService,
                                serverIP: blocState.serverIP,
                                userName: blocState.userName,
                                password: blocState.password,
                                databaseName: blocState.databaseName,
                                initialTable: masterTable,
                                initialField: masterField,
                                initialDisplayField: displayField,
                                initialValue: _paramControllers[index]!.text,
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
                            _paramControllers[index]!.text = result['display_label'] ?? result['value'] ?? '';

                            context.read<EditDetailAdminBloc>().add(UpdateParameterValue(index, result['value']!));

                            context.read<EditDetailAdminBloc>().add(
                              UpdateParameterMasterSelection(
                                index,
                                result['table'],
                                result['field'],
                                result['display_field'],
                              ),
                            );
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
                            context.read<EditDetailAdminBloc>().add(UpdateParameterFieldLabel(index, fieldLabel));
                          }
                        },
                        tooltip: 'Edit Field Label',
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // NEW: Radio button for Company Name Field selection
              Tooltip(
                message: 'Mark as Company Name Field',
                child: Radio<int>(
                  value: index, // Value is the index of the current parameter
                  groupValue: state.parameters.indexWhere((p) => (p['is_company_name_field'] as bool?) == true), // Find the index of the currently marked company name field
                  onChanged: (int? selectedIndex) {
                    if (selectedIndex != null && context.mounted) {
                      context.read<EditDetailAdminBloc>().add(UpdateParameterIsCompanyNameField(selectedIndex));
                    }
                  },
                  activeColor: Colors.deepOrange, // Distinct color
                ),
              ),
              const SizedBox(width: 8), // Space between Radio and Checkbox
              // Existing Checkbox for 'show'
              Checkbox(
                value: param['show'] ?? false,
                onChanged: (value) async {
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
    return Scaffold(
      appBar: AppBarWidget(
        title: 'Edit API: ${widget.apiData['APIName']}',
        onBackPress: () => Navigator.pop(context),
      ),
      body: BlocConsumer<EditDetailAdminBloc, EditDetailAdminState>(
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
            Navigator.pop(context, true);
          }
          // Ensure parameter controller values are synced when state parameters change,
          // especially after a modal or initial load.
          _initializeParameterControllers(state.parameters);
        },
        builder: (context, state) {
          return Stack(
            children: [
              SingleChildScrollView(
                // Adjusted padding to reduce left (and right) space
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
                                child: state.isLoading && state.availableDatabases.isEmpty // Only show loader if no databases are fetched yet
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
                          // Pass the entire state object to get company name selection info
                            ..._buildParameterRows(state, context), // MODIFIED: Passing state
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildButton(
                                text: 'Save',
                                color: Colors.blueAccent,
                                // Disable button when isLoading is true
                                onPressed: state.isLoading
                                    ? () {} // Empty function disables the button
                                    : () {
                                  context.read<EditDetailAdminBloc>().add(SaveChanges());
                                },
                                icon: Icons.save,
                              ),
                              const SizedBox(width: 12),
                              _buildButton(
                                text: 'Cancel',
                                color: Colors.grey,
                                // Also disable cancel during save to prevent navigation mid-operation
                                onPressed: state.isLoading
                                    ? () {}
                                    : () => Navigator.pop(context),
                                icon: Icons.cancel,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Show loader on top of the content when isLoading is true
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
}

// Renamed from _SelectFieldValuesDialog to _SelectFieldValuesModal
// This widget is now built directly within showGeneralDialog
class _SelectFieldValuesModal extends StatefulWidget {
  final ReportAPIService apiService;
  final String? serverIP;
  final String? userName;
  final String? password;
  final String? databaseName; // This is the pre-selected database
  final String? initialTable;
  final String? initialField;
  final String? initialDisplayField;
  final String? initialValue; // The current value in the parameter text field

  const _SelectFieldValuesModal({
    required this.apiService,
    this.serverIP,
    this.userName,
    this.password,
    this.databaseName,
    this.initialTable,
    this.initialField,
    this.initialDisplayField,
    this.initialValue,
  });

  @override
  _SelectFieldValuesModalState createState() => _SelectFieldValuesModalState();
}

class _SelectFieldValuesModalState extends State<_SelectFieldValuesModal> {
  List<String> _tables = [];
  String? _selectedTable;
  List<String> _fields = [];
  String? _selectedMasterField; // This will be the "Master Field (Value)"
  String? _selectedDisplayField; // This will be the "Display Field (Optional)"

  List<Map<String, String>> _allFieldData = []; // Stores { 'value': 'master_val', 'label': 'display_label' }
  String _searchRawText = ''; // For the search bar
  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _tableAutocompleteController = TextEditingController();
  final TextEditingController _masterFieldAutocompleteController = TextEditingController();
  final TextEditingController _displayFieldAutocompleteController = TextEditingController();

  bool _isLoadingTables = false;
  bool _isLoadingFields = false;
  bool _isLoadingFieldData = false; // Changed from _isLoadingFieldValues
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Initialize with initial values from widget
    _selectedTable = widget.initialTable;
    _tableAutocompleteController.text = widget.initialTable ?? '';

    _selectedMasterField = widget.initialField;
    _masterFieldAutocompleteController.text = widget.initialField ?? '';

    _selectedDisplayField = widget.initialDisplayField;
    _displayFieldAutocompleteController.text = widget.initialDisplayField ?? '';


    // Start fetching tables for the pre-selected database immediately
    _fetchTablesForSelectedDatabase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableAutocompleteController.dispose();
    _masterFieldAutocompleteController.dispose();
    _displayFieldAutocompleteController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchRawText = _searchController.text;
    });
  }

  // Filter based on the display label
  List<Map<String, String>> get _filteredFieldData {
    if (_searchRawText.isEmpty) {
      return _allFieldData;
    }
    return _allFieldData
        .where((item) => (item['label'] ?? '').toLowerCase().contains(_searchRawText.toLowerCase()))
        .toList();
  }

  Future<void> _fetchTablesForSelectedDatabase() async {
    setState(() {
      _isLoadingTables = true;
      _error = null;
      _tables = [];
      _fields = [];
      _allFieldData = [];
      _selectedTable = null; // Clear selections if refetching tables
      _selectedMasterField = null;
      _selectedDisplayField = null;
      _tableAutocompleteController.clear();
      _masterFieldAutocompleteController.clear();
      _displayFieldAutocompleteController.clear();
      _searchController.clear();
    });

    if (widget.serverIP == null || widget.userName == null || widget.password == null || widget.databaseName == null) {
      setState(() {
        _error = "Database connection details are incomplete.";
        _isLoadingTables = false;
      });
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
        _isLoadingTables = false;
        // Attempt to pre-populate selected table if initialTable exists
        if (widget.initialTable != null && tables.contains(widget.initialTable)) {
          _selectedTable = widget.initialTable;
          _tableAutocompleteController.text = widget.initialTable!;
          // If initial table is set, immediately fetch its fields
          _fetchFieldsForTable(widget.initialTable!);
        } else {
          // Clear if initial table not found or null
          _selectedTable = null;
          _tableAutocompleteController.clear();
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load tables for database "${widget.databaseName}": $e';
        _isLoadingTables = false;
      });
    }
  }

  Future<void> _fetchFieldsForTable(String tableName) async {
    setState(() {
      _isLoadingFields = true;
      _error = null;
      _fields = []; // Clear previous fields
      _allFieldData = []; // Clear data
      _selectedMasterField = null; // Reset master field
      _selectedDisplayField = null; // Reset display field
      _masterFieldAutocompleteController.clear();
      _displayFieldAutocompleteController.clear();
      _searchController.clear();
    });

    if (widget.serverIP == null || widget.userName == null || widget.password == null || widget.databaseName == null) {
      setState(() {
        _error = "Database connection details are incomplete for fields.";
        _isLoadingFields = false;
      });
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
        _isLoadingFields = false;

        // Try to pre-populate master field
        if (widget.initialField != null && fields.contains(widget.initialField)) {
          _selectedMasterField = widget.initialField;
          _masterFieldAutocompleteController.text = widget.initialField!;
        } else {
          _selectedMasterField = null;
          _masterFieldAutocompleteController.clear();
        }

        // Try to pre-populate display field
        if (widget.initialDisplayField != null && fields.contains(widget.initialDisplayField)) {
          _selectedDisplayField = widget.initialDisplayField;
          _displayFieldAutocompleteController.text = widget.initialDisplayField!;
        } else if (_selectedMasterField != null) {
          // If no initial display field, and master field exists, default display field to master field
          _selectedDisplayField = _selectedMasterField;
          _displayFieldAutocompleteController.text = _selectedMasterField!;
        } else {
          _selectedDisplayField = null;
          _displayFieldAutocompleteController.clear();
        }

        // After setting initial master and display fields, fetch field data
        if (_selectedMasterField != null && _selectedDisplayField != null) {
          _fetchFieldData();
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load fields for table "$tableName": $e';
        _isLoadingFields = false;
      });
    }
  }

  // UPDATED: Fetches `master_field` and `display_field` data pairs
  Future<void> _fetchFieldData() async {
    if (_selectedTable == null || _selectedMasterField == null || _selectedDisplayField == null) return;

    setState(() {
      _isLoadingFieldData = true;
      _error = null;
      _allFieldData = [];
      _searchController.clear();
      _searchRawText = '';
    });

    try {
      // >>> Use the new fetchPickerData method <<<
      final data = await widget.apiService.fetchPickerData(
        server: widget.serverIP!,
        UID: widget.userName!,
        PWD: widget.password!,
        database: widget.databaseName!,
        masterTable: _selectedTable!,
        masterField: _selectedMasterField!,
        displayField: _selectedDisplayField!,
      );

      // Convert the fetched raw data to the { 'value': '...', 'label': '...' } format
      final List<Map<String, String>> mappedData = data.map((item) {
        return {
          'value': item[_selectedMasterField]?.toString() ?? '',
          'label': item[_selectedDisplayField]?.toString() ?? '',
        };
      }).toList();

      setState(() {
        _allFieldData = mappedData;
        _isLoadingFieldData = false;

        // If an initialValue was provided, try to pre-populate the search bar with its display label
        if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
          final matchedItem = mappedData.firstWhere(
                (item) => item['value'] == widget.initialValue,
            orElse: () => {}, // Use empty map as fallback if not found
          );
          if (matchedItem.isNotEmpty && matchedItem['label'] != null) {
            _searchController.text = matchedItem['label']!;
            _searchRawText = matchedItem['label']!;
          } else {
            // If the initialValue doesn't match any fetched picker item,
            // default the search controller to the raw initialValue itself
            _searchController.text = widget.initialValue!;
            _searchRawText = widget.initialValue!;
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load field data for "${_selectedMasterField!}" & "${_selectedDisplayField!}" in "${_selectedTable!}": $e';
        _isLoadingFieldData = false;
        _allFieldData = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;

    final double modalWidth = screenSize.width * 0.8;
    final double modalHeight = screenSize.height * 0.85; // Made slightly taller for more fields

    return Center(
      child: Material(
        type: MaterialType.card,
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
                'Select Master Data (Value & Display Field)',
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
              // Autocomplete for Tables
              _isLoadingTables
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              )
                  : Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return Iterable<String>.empty(); // Or _tables for all options initially
                  }
                  return _tables.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                  // Sync Autocomplete's controller with our internal controller
                  if (textEditingController.text != _tableAutocompleteController.text) {
                    // This update ensures initial values also reflect in the Autocomplete field.
                    // Needs to be done safely using addPostFrameCallback if setting during build.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      textEditingController.text = _tableAutocompleteController.text;
                    });
                  }
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Select Table',
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: GoogleFonts.poppins(),
                  );
                },
                onSelected: (String selection) {
                  setState(() {
                    _selectedTable = selection;
                    _tableAutocompleteController.text = selection; // Keep internal controller synced
                    _selectedMasterField = null; // Reset fields when table changes
                    _masterFieldAutocompleteController.clear();
                    _selectedDisplayField = null;
                    _displayFieldAutocompleteController.clear();
                    _fields = [];
                    _allFieldData = [];
                    _searchController.clear();
                  });
                  _fetchFieldsForTable(selection);
                  FocusScope.of(context).unfocus(); // Dismiss keyboard
                },
              ),
              const SizedBox(height: 16),
              // Autocomplete for Master Field (Value)
              _selectedTable == null
                  ? Container()
                  : _isLoadingFields
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              )
                  : Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return Iterable<String>.empty();
                  }
                  return _fields.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                  if (textEditingController.text != _masterFieldAutocompleteController.text) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      textEditingController.text = _masterFieldAutocompleteController.text;
                    });
                  }
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Select Master Field (Value)',
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: GoogleFonts.poppins(),
                  );
                },
                onSelected: (String selection) {
                  setState(() {
                    _selectedMasterField = selection;
                    _masterFieldAutocompleteController.text = selection;
                    // Auto-select display field to master field if no specific display field was previously set
                    if (_selectedDisplayField == null || _selectedDisplayField == widget.initialField) {
                      _selectedDisplayField = selection;
                      _displayFieldAutocompleteController.text = selection;
                    }
                    _allFieldData = [];
                    _searchController.clear();
                  });
                  _fetchFieldData(); // Fetch paired values/labels
                  FocusScope.of(context).unfocus();
                },
              ),
              const SizedBox(height: 16),
              // Autocomplete for Display Field (Optional)
              if (_selectedTable != null && _selectedMasterField != null)
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return Iterable<String>.empty();
                    }
                    return _fields.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                    if (textEditingController.text != _displayFieldAutocompleteController.text) {
                      WidgetsBinding.instance.addPostFrameCallback((_){
                        textEditingController.text = _displayFieldAutocompleteController.text;
                      });
                    }
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Select Display Field (Optional)',
                        labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      style: GoogleFonts.poppins(),
                    );
                  },
                  onSelected: (String selection) {
                    setState(() {
                      _selectedDisplayField = selection;
                      _displayFieldAutocompleteController.text = selection;
                      _allFieldData = []; // Clear values because display field changes means re-fetch paired data
                      _searchController.clear();
                    });
                    // Only refetch data if master and display fields are both valid.
                    // This handles scenarios where display field might be empty or invalid.
                    if (_selectedMasterField != null && _selectedDisplayField != null && _selectedTable != null) {
                      _fetchFieldData();
                    }
                    FocusScope.of(context).unfocus();
                  },
                ),
              const SizedBox(height: 16),
              // Display Values for selected Master & Display Fields
              if (_selectedTable != null && _selectedMasterField != null && _selectedDisplayField != null)
                _isLoadingFieldData
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                )
                    : Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search values (by Display Field)',
                          prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 14),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                          ),
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _filteredFieldData.isEmpty
                            ? Center(
                          child: Text(
                            _searchRawText.isNotEmpty
                                ? 'No matching values found for "${_searchRawText}".'
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
                            return ListTile(
                              title: Text(displayLabel ?? '', style: GoogleFonts.poppins()),
                              subtitle: (displayLabel != masterValue && masterValue != null && masterValue.isNotEmpty)
                                  ? Text('($masterValue)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))
                                  : null,
                              onTap: () {
                                if (!context.mounted) return;
                                Navigator.pop(context, {
                                  'value': masterValue,       // Actual value for the API parameter
                                  'display_label': displayLabel, // Display value for the UI text field
                                  'table': _selectedTable,
                                  'field': _selectedMasterField,
                                  'display_field': _selectedDisplayField,
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton(
                  onPressed: () {
                    if (!context.mounted) return;
                    Navigator.pop(context); // Pop without result
                  },
                  child: Text('Close', style: GoogleFonts.poppins(color: Colors.redAccent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}