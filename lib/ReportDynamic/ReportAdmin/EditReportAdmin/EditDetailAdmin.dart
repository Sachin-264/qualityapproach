// EditDetailAdmin.dart
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

    // Initialize parameter controllers from state (IMPORTANT for existing data)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        final parameters = context.read<EditDetailAdminBloc>().state.parameters;
        for (var i = 0; i < parameters.length; i++) {
          _paramControllers[i] ??= TextEditingController(); // Ensure controller is created
          _paramControllers[i]!.text = parameters[i]['value'].toString();
          if (!_paramControllers[i]!.hasListeners) { // Avoid adding duplicate listeners
            _paramControllers[i]!.addListener(() {
              _debouncedUpdate(() {
                context.read<EditDetailAdminBloc>().add(UpdateParameterValue(i, _paramControllers[i]!.text));
              });
            });
          }
        }
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
    // Check if the parameter name contains 'date' or if the value matches the dd-MMM-yyyy pattern
    final datePattern = RegExp(r'^\d{2}-[A-Za-z]{3}-\d{4}$');
    return name.toLowerCase().contains('date') || datePattern.hasMatch(value);
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

  List<Widget> _buildParameterRows(List<Map<String, dynamic>> parameters, BuildContext context) {
    final List<Widget> rows = [];
    final List<Map<String, dynamic>> allParamsOrdered = [...parameters];

    for (var i = 0; i < allParamsOrdered.length; i++) {
      final param1 = allParamsOrdered[i];
      final index1 = i; // This is the actual index in the state.parameters list

      // Ensure controller exists and is linked to the correct value
      if (!_paramControllers.containsKey(index1)) {
        _paramControllers[index1] = TextEditingController(text: param1['value'].toString());
        _paramControllers[index1]!.addListener(() {
          _debouncedUpdate(() {
            context.read<EditDetailAdminBloc>().add(UpdateParameterValue(index1, _paramControllers[index1]!.text));
          });
        });
      } else {
        // Update controller text if state value has changed externally (e.g., from modal selection)
        // Only update if the text is different to avoid infinite loops or cursor issues
        if (_paramControllers[index1]!.text != param1['value'].toString()) {
          _paramControllers[index1]!.text = param1['value'].toString();
        }
      }

      final bool isDate = _isDateParameter(param1['name'], param1['value']);

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
                        controller: _paramControllers[index1]!,
                        label: param1['field_label']?.isNotEmpty ?? false ? param1['field_label'] : param1['name'],
                        isSmall: true,
                        isDateField: isDate,
                        onTap: isDate ? () => _selectDate(context, _paramControllers[index1]!, index1) : null,
                        suffixIcon: isDate ? null : Icons.table_view, // Show table icon for non-date fields
                        onSuffixIconTap: isDate ? null : () async { // Only for non-date fields
                          final blocState = context.read<EditDetailAdminBloc>().state;
                          // MODIFIED: Change expected return type to Map<String, String?>?
                          final result = await showGeneralDialog<Map<String, String?>?>(
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
                                // Pass current master_table/field/display_field if available for pre-filling
                                initialTable: param1['master_table'],
                                initialField: param1['master_field'],
                                initialDisplayField: param1['display_field'], // NEW: Pass initial display field
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
                            // Update the text controller
                            _paramControllers[index1]!.text = result['value'] ?? ''; // Handle null value just in case
                            // Dispatch events to update BLoC state
                            context.read<EditDetailAdminBloc>().add(UpdateParameterValue(index1, result['value']!));
                            context.read<EditDetailAdminBloc>().add(
                              // MODIFIED: Pass the new display field
                              UpdateParameterMasterSelection(index1, result['table'], result['field'], result['display_field']),
                            );
                          }
                        },
                      ),
                    ),
                    if (param1['show'] ?? false)
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                        onPressed: () async {
                          final fieldLabel = await _showFieldLabelDialog(context, param1['name'], param1['field_label']);
                          if (fieldLabel != null && context.mounted) {
                            context.read<EditDetailAdminBloc>().add(UpdateParameterFieldLabel(index1, fieldLabel));
                          }
                        },
                        tooltip: 'Edit Field Label',
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: param1['show'] ?? false,
                onChanged: (value) async {
                  if (value == true) {
                    final fieldLabel = await _showFieldLabelDialog(context, param1['name'], param1['field_label']);
                    if (fieldLabel != null && context.mounted) {
                      context.read<EditDetailAdminBloc>().add(UpdateParameterFieldLabel(index1, fieldLabel));
                      context.read<EditDetailAdminBloc>().add(UpdateParameterShow(index1, true));
                    }
                  } else {
                    context.read<EditDetailAdminBloc>().add(UpdateParameterShow(index1, false));
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
        },
        builder: (context, state) {
          return Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                                  child: CircularProgressIndicator(color: Colors.blueAccent),
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
                            ..._buildParameterRows(state.parameters, context),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildButton(
                                text: 'Save',
                                color: Colors.blueAccent,
                                onPressed: state.isLoading
                                    ? () {}
                                    : () {
                                  context.read<EditDetailAdminBloc>().add(SaveChanges());
                                },
                                icon: Icons.save,
                              ),
                              const SizedBox(width: 12),
                              _buildButton(
                                text: 'Cancel',
                                color: Colors.grey,
                                onPressed: () => Navigator.pop(context),
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
  final String serverIP;
  final String userName;
  final String password;
  final String databaseName;
  final String? initialTable;
  final String? initialField;
  final String? initialDisplayField; // NEW: Added initialDisplayField

  const _SelectFieldValuesModal({
    required this.apiService,
    required this.serverIP,
    required this.userName,
    required this.password,
    required this.databaseName,
    this.initialTable,
    this.initialField,
    this.initialDisplayField, // NEW: Added initialDisplayField
  });

  @override
  _SelectFieldValuesModalState createState() => _SelectFieldValuesModalState();
}

class _SelectFieldValuesModalState extends State<_SelectFieldValuesModal> {
  List<String> _tables = [];
  String? _selectedTable;
  List<String> _fields = [];
  String? _selectedField;
  String? _selectedDisplayField; // NEW: State for selected display field
  List<String> _allFieldValues = [];
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tableSearchController = TextEditingController();
  final TextEditingController _fieldSearchController = TextEditingController();
  final TextEditingController _displayFieldSearchController = TextEditingController(); // NEW: Controller for display field

  bool _isLoadingTables = false;
  bool _isLoadingFields = false;
  bool _isLoadingFieldValues = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _tableSearchController.addListener(() {
      setState(() {}); // Rebuild to filter autocomplete options
    });
    _fieldSearchController.addListener(() {
      setState(() {}); // Rebuild to filter autocomplete options
    });
    _displayFieldSearchController.addListener(() { // NEW: Listener for display field search
      setState(() {});
    });

    if (widget.initialTable != null) {
      _tableSearchController.text = widget.initialTable!;
      _selectedTable = widget.initialTable;
      _fetchTables(thenFetchFields: true); // Fetch tables, then fields if initial table exists
    } else {
      _fetchTables();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableSearchController.dispose();
    _fieldSearchController.dispose();
    _displayFieldSearchController.dispose(); // NEW: Dispose new controller
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchText = _searchController.text;
    });
  }

  List<String> get _filteredFieldValues {
    if (_searchText.isEmpty) {
      return _allFieldValues;
    }
    return _allFieldValues
        .where((value) => value.toLowerCase().contains(_searchText.toLowerCase()))
        .toList();
  }

  Future<void> _fetchTables({bool thenFetchFields = false}) async {
    setState(() {
      _isLoadingTables = true;
      _error = null;
      _fields = [];
      _selectedField = null;
      _selectedDisplayField = null; // NEW: Clear display field
      _allFieldValues = [];
      _searchText = '';
      _searchController.clear();
      _fieldSearchController.clear();
      _displayFieldSearchController.clear(); // NEW: Clear display field search
    });
    try {
      final tables = await widget.apiService.fetchDatabases(
        serverIP: widget.serverIP,
        userName: widget.userName,
        password: widget.password,
      );
      setState(() {
        _tables = tables;
        _isLoadingTables = false;
      });

      if (thenFetchFields && widget.initialTable != null && tables.contains(widget.initialTable)) {
        // If initialTable was provided and exists, fetch fields for it
        _fetchFieldsForTable(widget.initialTable!, thenFetchValues: true);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load tables: $e';
        _isLoadingTables = false;
      });
    }
  }

  Future<void> _fetchFieldsForTable(String tableName, {bool thenFetchValues = false}) async {
    setState(() {
      _isLoadingFields = true;
      _error = null;
      _allFieldValues = [];
      _searchText = '';
      _searchController.clear();
    });
    try {
      final fields = await widget.apiService.fetchFields(
        server: widget.serverIP,
        UID: widget.userName,
        PWD: widget.password,
        database: widget.databaseName,
        table: tableName,
      );
      setState(() {
        _fields = fields;
        _isLoadingFields = false;
      });

      // NEW/MODIFIED: Check for initialField and initialDisplayField
      if (thenFetchValues && widget.initialField != null && fields.contains(widget.initialField)) {
        _selectedField = widget.initialField;
        _fieldSearchController.text = widget.initialField!;
        _fetchFieldValues(); // Fetch values for the master field

        if (widget.initialDisplayField != null && fields.contains(widget.initialDisplayField)) {
          _selectedDisplayField = widget.initialDisplayField;
          _displayFieldSearchController.text = widget.initialDisplayField!;
        } else {
          // If initialDisplayField not found or not provided, default to master field
          _selectedDisplayField = widget.initialField;
          _displayFieldSearchController.text = widget.initialField!;
        }
      } else {
        // Default display field to master field if no initial display field
        _selectedDisplayField = null;
        _displayFieldSearchController.clear();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load fields for table "$tableName": $e';
        _isLoadingFields = false;
      });
    }
  }

  Future<void> _fetchFieldValues() async {
    if (_selectedTable == null || _selectedField == null) return;

    setState(() {
      _isLoadingFieldValues = true;
      _error = null;
      _allFieldValues = [];
      _searchText = '';
      _searchController.clear();
    });
    try {
      final values = await widget.apiService.fetchFieldValues(
        server: widget.serverIP,
        UID: widget.userName,
        PWD: widget.password,
        database: widget.databaseName,
        table: _selectedTable!,
        field: _selectedField!,
      );
      setState(() {
        _allFieldValues = values;
        _isLoadingFieldValues = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load field values for "${_selectedField!}" in "${_selectedTable!}": $e';
        _isLoadingFieldValues = false;
        _allFieldValues = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;

    final double modalWidth = screenSize.width * 0.8;
    final double modalHeight = screenSize.height * 0.7;

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
                'Select Table, Value & Display Field', // MODIFIED: Title
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
              _isLoadingTables
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              )
                  : Autocomplete<String>( // Autocomplete for Tables
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return Iterable<String>.empty();
                  }
                  return _tables.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                  // Sync internal controller with Autocomplete's controller
                  if (textEditingController.text != _tableSearchController.text) {
                    _tableSearchController.text = textEditingController.text;
                  }
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Select Table',
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: _isLoadingTables ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                    ),
                    style: GoogleFonts.poppins(),
                  );
                },
                onSelected: (String selection) {
                  _selectedTable = selection;
                  _tableSearchController.text = selection; // Keep the controller synced
                  _selectedField = null; // Reset field when table changes
                  _fieldSearchController.clear(); // Clear field search
                  _selectedDisplayField = null; // NEW: Reset display field
                  _displayFieldSearchController.clear(); // NEW: Clear display field search
                  _fields = [];
                  _allFieldValues = [];
                  _searchText = '';
                  _searchController.clear();
                  _fetchFieldsForTable(selection);
                  FocusScope.of(context).unfocus(); // Dismiss keyboard
                },
              ),
              const SizedBox(height: 16),
              _selectedTable == null
                  ? Container()
                  : _isLoadingFields
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              )
                  : Autocomplete<String>( // Autocomplete for Fields (Master Field)
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return Iterable<String>.empty();
                  }
                  return _fields.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                  // Sync internal controller with Autocomplete's controller
                  if (textEditingController.text != _fieldSearchController.text) {
                    _fieldSearchController.text = textEditingController.text;
                  }
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Select Master Field (Value)', // MODIFIED: Label clarity
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: _isLoadingFields ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                    ),
                    style: GoogleFonts.poppins(),
                  );
                },
                onSelected: (String selection) {
                  _selectedField = selection;
                  _fieldSearchController.text = selection; // Keep the controller synced
                  // NEW: Automatically set display field to master field when master field changes
                  _selectedDisplayField = selection;
                  _displayFieldSearchController.text = selection;
                  _allFieldValues = [];
                  _searchText = '';
                  _searchController.clear();
                  _fetchFieldValues();
                  FocusScope.of(context).unfocus(); // Dismiss keyboard
                },
              ),
              const SizedBox(height: 16),
              // NEW: Autocomplete for Display Field
              if (_selectedField != null) // Display only after master field is selected
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return Iterable<String>.empty();
                    }
                    return _fields.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                    if (textEditingController.text != _displayFieldSearchController.text) {
                      _displayFieldSearchController.text = textEditingController.text;
                    }
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Select Display Field (Optional)', // Label for display field
                        labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      style: GoogleFonts.poppins(),
                    );
                  },
                  onSelected: (String selection) {
                    setState(() {
                      _selectedDisplayField = selection;
                      _displayFieldSearchController.text = selection; // Keep the controller synced
                    });
                    FocusScope.of(context).unfocus(); // Dismiss keyboard
                  },
                ),
              const SizedBox(height: 16),
              if (_selectedField != null)
                _isLoadingFieldValues
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
                          labelText: 'Search values',
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
                        child: _filteredFieldValues.isEmpty
                            ? Center(
                          child: Text(
                            _searchText.isNotEmpty
                                ? 'No matching values found for "${_searchText}".'
                                : 'No values available for this field.',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                            : ListView.builder(
                          itemCount: _filteredFieldValues.length,
                          itemBuilder: (context, index) {
                            final value = _filteredFieldValues[index];
                            return ListTile(
                              title: Text(value, style: GoogleFonts.poppins()),
                              onTap: () {
                                if (!context.mounted) return; // Safety check
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  Navigator.pop(context, {
                                    'value': value,
                                    'table': _selectedTable,
                                    'field': _selectedField,
                                    'display_field': _selectedDisplayField, // NEW: Return display_field
                                  }); // Return map of selected data
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
                    if (!context.mounted) return; // Safety check
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.pop(context);
                    });
                  },
                  child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.redAccent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}