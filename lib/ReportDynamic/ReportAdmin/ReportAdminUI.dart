import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import 'EditReportAdmin/EditReportAdmin.dart';
import 'ReportAdminBloc.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ReportAdminUI extends StatefulWidget {
  const ReportAdminUI({super.key});

  @override
  _ReportAdminUIState createState() => _ReportAdminUIState();
}

class _ReportAdminUIState extends State<ReportAdminUI> {
  final TextEditingController _selectedConfigNameController = TextEditingController();
  final TextEditingController _serverIPController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _databaseNameController = TextEditingController();
  final TextEditingController _apiServerURLController = TextEditingController();
  final TextEditingController _apiNameController = TextEditingController();
  final Map<int, TextEditingController> _paramControllers = {};
  bool _showParameters = false;
  bool _isParsingParameters = false;
  bool _wasLoading = false; // Tracks if previous state was loading
  bool _wasSaving = false; // Tracks if the previous action was a save attempt
  bool _showPassword = false; // New state for password visibility toggle

  late final ReportAdminBloc _bloc;
  Timer? _debounce; // For debouncing text field inputs

  @override
  void initState() {
    super.initState();
    _bloc = ReportAdminBloc(ReportAPIService()); // Initialize Bloc instance here

    // Listeners for text controllers with debouncing
    // These listeners dispatch events to the BLoC when text changes after a short delay
    _serverIPController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateServerIP(_serverIPController.text));
    }));

    _userNameController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateUserName(_userNameController.text));
    }));

    _passwordController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdatePassword(_passwordController.text));
    }));

    _databaseNameController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateDatabaseName(_databaseNameController.text));
    }));

    _apiServerURLController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateApiServerURL(_apiServerURLController.text));
    }));

    _apiNameController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateApiName(_apiNameController.text));
    }));
  }

  // Debounces a callback function to avoid too many updates (e.g., from rapid typing)
  void _debouncedUpdate(VoidCallback callback) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), callback);
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Cancel any active debounce timer
    _selectedConfigNameController.dispose();
    _serverIPController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _databaseNameController.dispose();
    _apiServerURLController.dispose();
    _apiNameController.dispose();
    _paramControllers.values.forEach((controller) => controller.dispose()); // Dispose all parameter controllers
    _bloc.close(); // Close the bloc instance to free resources
    super.dispose();
  }

  // Helper widget for consistent TextField styling
  Widget _buildTextField({
    required TextEditingController controller,
    String? label,
    FocusNode? focusNode,
    IconData? icon,
    bool obscureText = false,
    bool isDateField = false,
    VoidCallback? onTap,
    bool isSmall = false,
    Widget? suffixIcon, // Added for custom suffix icons like password toggle
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      readOnly: isDateField, // Make date fields read-only for date picker
      onTap: onTap, // Callback for tapping date fields
      style: GoogleFonts.poppins(fontSize: isSmall ? 14 : 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey[700],
          fontSize: isSmall ? 13 : 15,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: isSmall ? 20 : 22) : null,
        suffixIcon: suffixIcon ?? // Use provided suffixIcon if available
            (isDateField ? Icon(Icons.calendar_today, color: Colors.blueAccent, size: isSmall ? 18 : 20) : null),
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

  // Helper widget for consistent DropdownButtonFormField styling
  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? label,
    IconData? icon,
  }) {
    return DropdownButtonFormField<String>(
      value: value != null && items.contains(value) ? value : null, // Ensure value is in items
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

  // Helper widget for consistent ElevatedButton styling
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

  // Checks if a parameter name or value suggests it's a date field
  bool _isDateParameter(String name, String value) {
    final datePattern = RegExp(r'^\d{2}-[A-Za-z]{3}-\d{4}$'); // e.g., 01-Jan-2023
    return name.toLowerCase().contains('date') || datePattern.hasMatch(value);
  }

  // Shows a date picker and updates the text field and bloc with the selected date
  Future<void> _selectDate(BuildContext context, TextEditingController controller, int index) async {
    DateTime? initialDate;
    try {
      initialDate = DateFormat('dd-MMM-yyyy').parse(controller.text);
    } catch (e) {
      initialDate = DateTime.now(); // Fallback to current date if parsing fails
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000), // Sensible date range
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
      final formattedDate = DateFormat('dd-MMM-yyyy').format(picked);
      controller.text = formattedDate;
      _bloc.add(UpdateParameterValue(index, formattedDate)); // Update bloc with new value
    }
  }

  // Shows a dialog to get a custom field label from the user
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

    labelController.dispose(); // Dispose controller after dialog is closed
    return fieldLabel;
  }

  // Shows a summary of the current configuration before saving
  void _showSummaryDialog(BuildContext context, ReportAdminState state) {
    final uri = Uri.parse(state.apiServerURL);
    final baseUrl = '${uri.scheme}://${uri.host}${uri.path}?';
    final originalParams = uri.queryParameters;
    final changedParams = <String, bool>{};

    // Build the query parameters for the summary
    for (var param in state.parameters) {
      final name = param['name'].toString();
      final value = param['value'].toString();
      changedParams[name] = originalParams[name] != value; // Check if value changed from original URL
    }

    final queryParts = state.parameters.map((param) {
      final name = param['name'].toString();
      final value = param['value'].toString();
      final changed = changedParams[name] ?? false;
      return {'name': name, 'value': value, 'changed': changed};
    }).toList();


    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        title: Text(
          'Configuration Summary',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Server IP: ${state.serverIP}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('Username: ${state.userName}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              // IMPORTANT: Do NOT display the password here in a real application's summary,
              // or handle it with extreme care (e.g., only show if explicitly requested and with user authentication).
              // For demonstration purposes, keeping it as per original request.
              Text('Password: ${state.password}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('Database Name: ${state.databaseName}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('API Server URL: ${state.apiServerURL}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('API Name: ${state.apiName}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('Updated URL:', style: GoogleFonts.poppins(fontSize: 14)),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                  children: [
                    TextSpan(text: baseUrl),
                    ...List.generate(queryParts.length, (index) {
                      final param = queryParts[index];
                      final isLast = index == queryParts.length - 1;
                      return TextSpan(
                        text: '${param['name']}=${param['value']}${isLast ? '' : '&'}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: param['changed'] as bool ? Colors.blueAccent : Colors.black87,
                          fontWeight: param['changed'] as bool ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
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
              Navigator.pop(context);
              setState(() {
                _wasSaving = true; // Set flag to indicate save attempt
              });
              _bloc.add(const SaveDatabaseServer()); // Dispatch save event
            },
            child: Text(
              'Confirm',
              style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Groups parameters for display, prioritizing date pairs
  List<List<Map<String, dynamic>>> _groupParameters(List<Map<String, dynamic>> parameters) {
    final List<List<Map<String, dynamic>>> grouped = [];
    final List<Map<String, dynamic>> remaining = List.from(parameters);
    final datePairNames = ['FromDate', 'ToDate'];

    final datePair = <Map<String, dynamic>>[];
    for (var name in datePairNames) {
      final index = remaining.indexWhere((p) => p['name'] == name);
      if (index != -1) {
        datePair.add(remaining[index]);
        remaining.removeAt(index);
      }
    }
    if (datePair.isNotEmpty) {
      grouped.add(datePair);
    }

    int index = 0;
    while (index < remaining.length) {
      if (index + 1 < remaining.length && index % 2 == 0) {
        grouped.add([remaining[index], remaining[index + 1]]);
        index += 2;
      } else {
        grouped.add([remaining[index]]);
        index += 1;
      }
    }

    return grouped;
  }

  // Clears all text controllers and disposes parameter controllers
  void _clearAllControllers() {
    _selectedConfigNameController.clear();
    _serverIPController.clear();
    _userNameController.clear();
    _passwordController.clear();
    _databaseNameController.clear();
    _apiServerURLController.clear();
    _apiNameController.clear();
    _disposeParameterControllers(); // Dispose existing parameter controllers
  }

  // Helper to dispose existing parameter controllers
  void _disposeParameterControllers() {
    _paramControllers.values.forEach((controller) => controller.dispose());
    _paramControllers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _bloc, // Provide the initialized bloc instance
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Create Report',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocConsumer<ReportAdminBloc, ReportAdminState>(
          listenWhen: (previous, current) =>
          previous.error != current.error ||
              previous.isLoading != current.isLoading ||
              previous.parameters.length != current.parameters.length ||
              previous.availableDatabases != current.availableDatabases ||
              previous.savedConfigurations != current.savedConfigurations || // Listen for saved configs updates
              previous.selectedConfigId != current.selectedConfigId || // Listen for selection changes
              previous.password != current.password || // Explicitly listen for password changes
              previous.serverIP != current.serverIP || // Listen for server IP changes
              previous.userName != current.userName || // Listen for username changes
              previous.databaseName != current.databaseName || // Listen for database name changes
              previous.apiServerURL != current.apiServerURL || // Listen for API URL changes
              previous.apiName != current.apiName, // Listen for API Name changes
          listener: (context, state) {
            // Debugging prints
            print('ReportAdminUI Listener: state.password=${state.password}, _passwordController.text=${_passwordController.text}');

            // Handle errors by showing a SnackBar
            if (state.error != null) {
              String errorMessage = state.error!;
              if (errorMessage.contains('Failed to fetch databases')) {
                errorMessage = 'Unable to fetch databases. Please check server connection or credentials.';
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    errorMessage,
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
            // Handle successful save
            else if (!state.isLoading && _wasSaving && state.error == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Database server saved successfully',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 3),
                ),
              );
              _clearAllControllers(); // Clear controllers after successful save
              setState(() {
                _showParameters = false;
                _isParsingParameters = false;
                _wasSaving = false;
                _showPassword = false; // Reset password visibility
              });
            }
            // Handle selection of a saved configuration OR any state update that changes these fields
            // Only update controller text if it's different from the state to prevent infinite loops
            // caused by the controller's own listener dispatching back to the bloc.
            if (_serverIPController.text != state.serverIP) {
              _serverIPController.text = state.serverIP;
            }
            if (_userNameController.text != state.userName) {
              _userNameController.text = state.userName;
            }
            if (_passwordController.text != state.password) {
              _passwordController.text = state.password;
            }
            if (_databaseNameController.text != state.databaseName) {
              _databaseNameController.text = state.databaseName;
            }
            if (_apiServerURLController.text != state.apiServerURL) {
              _apiServerURLController.text = state.apiServerURL;
            }
            if (_apiNameController.text != state.apiName) {
              _apiNameController.text = state.apiName;
            }

            // Update Autocomplete field when a config is selected or cleared
            final selectedConfigName = state.savedConfigurations
                .firstWhere(
                    (config) => config['ConfigID']?.toString() == state.selectedConfigId,
                orElse: () => <String, dynamic>{})['ConfigName']
                ?.toString() ??
                '';
            // Only update _selectedConfigNameController if it truly needs to change.
            // The Autocomplete's internal controller is handled by the Autocomplete itself.
            if (_selectedConfigNameController.text != selectedConfigName) {
              _selectedConfigNameController.text = selectedConfigName;
            }


            // Parameters visibility and controller management
            if (state.selectedConfigId != null && !_showParameters) {
              // If a config is selected, and parameters are currently hidden, show them
              setState(() {
                _showParameters = true;
              });
            } else if (state.selectedConfigId == null && _showParameters && !state.isLoading) {
              // If no config is selected (e.g., after Reset), hide parameters
              setState(() {
                _showParameters = false;
              });
            }

            if (_showParameters) {
              // Re-create parameter controllers only if parameters have truly changed (length or content)
              bool needsParamControllerUpdate = _paramControllers.length != state.parameters.length;
              if (!needsParamControllerUpdate) {
                for (int i = 0; i < state.parameters.length; i++) {
                  if (!_paramControllers.containsKey(i) ||
                      _paramControllers[i]!.text != state.parameters[i]['value'].toString()) {
                    needsParamControllerUpdate = true;
                    break;
                  }
                }
              }

              if (needsParamControllerUpdate) {
                _disposeParameterControllers(); // Dispose old ones
                for (int i = 0; i < state.parameters.length; i++) {
                  _paramControllers[i] = TextEditingController(
                    text: state.parameters[i]['value'].toString(),
                  )..addListener(() {
                    _debouncedUpdate(() {
                      context.read<ReportAdminBloc>().add(
                        UpdateParameterValue(
                          i,
                          _paramControllers[i]!.text,
                        ),
                      );
                    });
                  });
                }
                if (mounted) setState(() {}); // Rebuild to show new parameter fields
              }
            } else {
              _disposeParameterControllers(); // Dispose if hiding parameters
            }


            _wasLoading = state.isLoading; // Update loading state tracking
            // When parameters are parsed or an error occurs, stop parsing indicator
            if (_isParsingParameters && (state.parameters.isNotEmpty || state.error != null)) {
              setState(() {
                _isParsingParameters = false;
              });
            }
          },
          buildWhen: (previous, current) =>
          previous.serverIP != current.serverIP ||
              previous.userName != current.userName ||
              previous.password != current.password ||
              previous.databaseName != current.databaseName ||
              previous.availableDatabases != current.availableDatabases ||
              previous.apiServerURL != current.apiServerURL ||
              previous.apiName != current.apiName ||
              previous.parameters != current.parameters ||
              previous.isLoading != current.isLoading ||
              previous.savedConfigurations != current.savedConfigurations ||
              previous.selectedConfigId != current.selectedConfigId,
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildButton(
                        text: 'Edit Config',
                        color: Colors.purpleAccent,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const EditReportAdmin()),
                          );
                        },
                        icon: Icons.edit,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
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
                              // Autocomplete for selecting saved configurations
                              Autocomplete<Map<String, dynamic>>(
                                displayStringForOption: (option) => option['ConfigName'] as String,
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return state.savedConfigurations; // Show all options when field is empty
                                  }
                                  return state.savedConfigurations.where((option) {
                                    final configName = option['ConfigName'] as String? ?? '';
                                    return configName.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                  });
                                },
                                onSelected: (Map<String, dynamic> selection) {
                                  // This updates the Autocomplete's internal controller and typically closes the dropdown
                                  // The _selectedConfigNameController will be updated by the listener
                                  context.read<ReportAdminBloc>().add(
                                      SelectSavedConfiguration(selection['ConfigID'].toString()));
                                },
                                fieldViewBuilder: (BuildContext context,
                                    TextEditingController fieldTextEditingController,
                                    FocusNode fieldFocusNode,
                                    VoidCallback onFieldSubmitted) {
                                  // **CRITICAL CHANGE:**
                                  // Removed the WidgetsBinding.instance.addPostFrameCallback block.
                                  // Let Autocomplete manage its own fieldTextEditingController directly.
                                  // The _selectedConfigNameController is updated by the Bloc listener
                                  // and serves as the source of truth from the Bloc state.
                                  return TextField(
                                    controller: fieldTextEditingController, // Use Autocomplete's provided controller
                                    focusNode: fieldFocusNode,
                                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
                                    decoration: InputDecoration(
                                      labelText: 'Select Existing Configuration',
                                      labelStyle: GoogleFonts.poppins(
                                        color: Colors.grey[700],
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      prefixIcon: const Icon(Icons.search, color: Colors.blueAccent, size: 22),
                                      suffixIcon: state.isLoading && state.savedConfigurations.isEmpty
                                          ? const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                                      )
                                          : null, // Show loading indicator
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
                                },
                                optionsViewBuilder: (BuildContext context,
                                    AutocompleteOnSelected<Map<String, dynamic>> onSelected,
                                    Iterable<Map<String, dynamic>> options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4.0,
                                      child: SizedBox(
                                        // Adjust height based on options available
                                        height: options.isNotEmpty ? 200.0 : 0.0,
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          itemCount: options.length,
                                          itemBuilder: (BuildContext context, int index) {
                                            final option = options.elementAt(index);
                                            return GestureDetector(
                                              onTap: () {
                                                onSelected(option);
                                              },
                                              child: ListTile(
                                                title: Text(option['ConfigName'] as String,
                                                    style: GoogleFonts.poppins()),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
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
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Password',
                                icon: Icons.lock,
                                obscureText: !_showPassword, // Controlled by _showPassword state
                                suffixIcon: IconButton( // Suffix icon for password visibility toggle
                                  icon: Icon(
                                    _showPassword ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showPassword = !_showPassword;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Display loading indicator for databases or the dropdown
                              state.isLoading && state.availableDatabases.isEmpty && state.error == null
                                  ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.blueAccent,
                                ),
                              )
                                  : _buildDropdownField(
                                value: state.databaseName,
                                items: state.availableDatabases,
                                onChanged: (value) {
                                  if (value != null) {
                                    _databaseNameController.text = value; // Update local controller
                                    context.read<ReportAdminBloc>().add(UpdateDatabaseName(value));
                                  }
                                },
                                label: 'Database Name',
                                icon: Icons.storage,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _apiServerURLController,
                                label: 'API Server URL',
                                icon: Icons.link,
                              ),
                              const SizedBox(height: 16),
                              _buildButton(
                                text: _showParameters ? 'Hide Parameters' : 'Show Parameters',
                                color: Colors.green,
                                onPressed: () {
                                  setState(() {
                                    _showParameters = !_showParameters;
                                    if (_showParameters) {
                                      _isParsingParameters = true;
                                      context.read<ReportAdminBloc>().add(ParseParameters()); // Parse params if showing
                                    } else {
                                      _disposeParameterControllers(); // Dispose when hiding
                                      _apiNameController.clear();
                                      _isParsingParameters = false;
                                      context.read<ReportAdminBloc>().add(UpdateApiName(''));
                                      context.read<ReportAdminBloc>().add(ParseParameters()); // Clear parameters in bloc
                                    }
                                  });
                                },
                                icon: _showParameters ? Icons.visibility_off : Icons.visibility,
                              ),
                              const SizedBox(height: 16),
                              if (_showParameters) ...[
                                _buildTextField(
                                  controller: _apiNameController,
                                  label: 'API Name',
                                  icon: Icons.api,
                                ),
                                const SizedBox(height: 20),
                                // Conditional display for parameters area
                                _isParsingParameters
                                    ? Center(
                                  child: state.parameters.isEmpty && state.error == null
                                      ? Text(
                                    'No parameters found in URL',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                      : const CircularProgressIndicator(
                                    color: Colors.blueAccent,
                                  ),
                                )
                                    : state.parameters.isEmpty && _apiServerURLController.text.isNotEmpty
                                    ? Text(
                                  'No parameters found in URL',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                                    : state.parameters.isEmpty && _apiServerURLController.text.isEmpty
                                    ? Text(
                                  'Enter an API Server URL to load parameters',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                                    : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'URL Parameters',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Build parameter input fields
                                    ..._groupParameters(state.parameters)
                                        .asMap()
                                        .entries
                                        .map((groupEntry) {
                                      final group = groupEntry.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 16.0),
                                        child: Row(
                                          children: group.asMap().entries.map((paramEntry) {
                                            final param = paramEntry.value;
                                            final paramIndex =
                                            state.parameters.indexOf(param); // Get actual index
                                            final isDate =
                                            _isDateParameter(param['name'], param['value']);

                                            // Ensure controller exists and its text is synchronized
                                            if (!_paramControllers.containsKey(paramIndex)) {
                                              _paramControllers[paramIndex] = TextEditingController();
                                              _paramControllers[paramIndex]!.addListener(() {
                                                _debouncedUpdate(() {
                                                  context.read<ReportAdminBloc>().add(
                                                    UpdateParameterValue(
                                                      paramIndex,
                                                      _paramControllers[paramIndex]!.text,
                                                    ),
                                                  );
                                                });
                                              });
                                            }
                                            // Always update the text to reflect the current bloc state
                                            if (_paramControllers[paramIndex]!.text !=
                                                param['value'].toString()) {
                                              _paramControllers[paramIndex]!.text =
                                                  param['value'].toString();
                                            }

                                            return Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(right: 8.0),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: _buildTextField(
                                                        controller: _paramControllers[paramIndex]!,
                                                        label: param['field_label']?.isNotEmpty ?? false
                                                            ? param['field_label']
                                                            : param['name'],
                                                        isDateField: isDate,
                                                        onTap: isDate
                                                            ? () => _selectDate(
                                                          context,
                                                          _paramControllers[paramIndex]!,
                                                          paramIndex,
                                                        )
                                                            : null,
                                                        isSmall: true,
                                                      ),
                                                    ),
                                                    if (param['show'] ?? false)
                                                      IconButton(
                                                        icon: const Icon(Icons.edit,
                                                            color: Colors.blueAccent, size: 20),
                                                        onPressed: () async {
                                                          final fieldLabel =
                                                          await _showFieldLabelDialog(
                                                            context,
                                                            param['name'],
                                                            param['field_label'],
                                                          );
                                                          if (fieldLabel != null && context.mounted) {
                                                            context.read<ReportAdminBloc>().add(
                                                              UpdateParameterFieldLabel(
                                                                  paramIndex, fieldLabel),
                                                            );
                                                          }
                                                        },
                                                        tooltip: 'Edit Field Label',
                                                      ),
                                                    const SizedBox(width: 8),
                                                    Checkbox(
                                                      value: param['show'] ?? false,
                                                      onChanged: (value) async {
                                                        if (value == true) {
                                                          final fieldLabel =
                                                          await _showFieldLabelDialog(
                                                            context,
                                                            param['name'],
                                                            param['field_label'],
                                                          );
                                                          if (fieldLabel != null &&
                                                              context.mounted) {
                                                            context.read<ReportAdminBloc>().add(
                                                              UpdateParameterFieldLabel(
                                                                  paramIndex, fieldLabel),
                                                            );
                                                            context.read<ReportAdminBloc>().add(
                                                              UpdateParameterShow(
                                                                  paramIndex, true),
                                                            );
                                                          }
                                                        } else {
                                                          context.read<ReportAdminBloc>().add(
                                                            UpdateParameterShow(
                                                                paramIndex, false),
                                                          );
                                                        }
                                                      },
                                                      activeColor: Colors.blueAccent,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildButton(
                                    text: 'Save',
                                    color: Colors.blueAccent,
                                    onPressed: state.serverIP.isNotEmpty &&
                                        state.userName.isNotEmpty &&
                                        state.password.isNotEmpty &&
                                        state.databaseName.isNotEmpty &&
                                        state.apiServerURL.isNotEmpty &&
                                        (state.parameters.isEmpty || state.apiName.isNotEmpty) &&
                                        !state.isLoading
                                        ? () => _showSummaryDialog(context, state)
                                        : null,
                                    icon: Icons.save,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildButton(
                                    text: 'Reset',
                                    color: Colors.redAccent,
                                    onPressed: state.isLoading
                                        ? null
                                        : () {
                                      _clearAllControllers();
                                      setState(() {
                                        _showParameters = false;
                                        _isParsingParameters = false;
                                        _showPassword = false; // Reset password visibility
                                      });
                                      context.read<ReportAdminBloc>().add(const ResetAdminState());
                                    },
                                    icon: Icons.refresh,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                state.isLoading ? const SubtleLoader() : const SizedBox.shrink(),
              ],
            );
          },
        ),
      ),
    );
  }
}