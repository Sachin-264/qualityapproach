// lib/setup_feature/setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import '../ReportUtils/Appbar.dart';
import '../ReportUtils/subtleloader.dart';
import '../ReportDynamic/ReportAPIService.dart';

import 'setup_bloc.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _configNameController = TextEditingController();
  final TextEditingController _serverIPController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // NEW: Controller for the connection string field
  final TextEditingController _connectionStringController = TextEditingController();

  late final SetupBloc _bloc;
  Timer? _debounce;
  late final ReportAPIService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ReportAPIService();
    _bloc = SetupBloc(_apiService);

    _configNameController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateConfigName(_configNameController.text));
    }));
    _serverIPController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateServerIP(_serverIPController.text));
    }));
    _userNameController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateUserName(_userNameController.text));
    }));
    _passwordController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdatePassword(_passwordController.text));
    }));
    // NEW: Listener for the connection string controller
    _connectionStringController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateConnectionString(_connectionStringController.text));
    }));
  }

  void _debouncedUpdate(VoidCallback callback) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), callback);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _configNameController.dispose();
    _serverIPController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _connectionStringController.dispose(); // NEW: Dispose the new controller
    _bloc.close();
    super.dispose();
  }

  void _clearAllControllers() {
    _configNameController.clear();
    _serverIPController.clear();
    _userNameController.clear();
    _passwordController.clear();
    _connectionStringController.clear(); // NEW: Clear the new controller
  }

  // --- WIDGET BUILDERS ---

  Widget _buildTextField({
    required TextEditingController controller,
    String? hintText, // Changed from label to hintText
    IconData? icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hintText, // Using hintText
        hintStyle: GoogleFonts.poppins(color: Colors.grey[500]), // Style for hintText
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600], size: 22) : null,
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05), // Subtle fill color
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)), // Bolder focus
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20), // Adjusted padding
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? label,
    IconData? icon,
  }) {
    // This decoration is updated to match the modern text field style
    return DropdownButtonFormField<String>(
      value: value != null && items.contains(value) ? value : null,
      onChanged: onChanged,
      items: items.isEmpty
          ? [const DropdownMenuItem<String>(value: null, child: Text('No databases available', style: TextStyle(color: Colors.grey)))]
          : items.map((String db) => DropdownMenuItem<String>(value: db, child: Text(db, style: GoogleFonts.poppins()))).toList(),
      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600], size: 22.0) : null,
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05), // Subtle fill color
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20), // Adjusted padding
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(text, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation: 4,
        shadowColor: color.withOpacity(0.3),
      ),
    );
  }

  void _showSummaryDialog(BuildContext context, SetupState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Confirm Configuration', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Config Name: ${state.configName}', style: GoogleFonts.poppins()),
              const SizedBox(height: 8),
              Text('Server IP: ${state.serverIP}', style: GoogleFonts.poppins()),
              const SizedBox(height: 8),
              Text('Username: ${state.userName}', style: GoogleFonts.poppins()),
              const SizedBox(height: 8),
              Text('Database: ${state.databaseName}', style: GoogleFonts.poppins()),
              const SizedBox(height: 8),
              // NEW: Display connection string in summary
              Text('Connection String: ${state.connectionString}', style: GoogleFonts.poppins()),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _bloc.add(const SaveSetup());
            },
            child: Text('Confirm Save', style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _bloc,
      child: Scaffold(
        backgroundColor: Colors.white, // Set page background to white
        appBar: AppBarWidget(
          title: 'Database Setup',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocConsumer<SetupBloc, SetupState>(
          listener: (context, state) {
            if (state.status == SetupStatus.failure && state.errorMessage != null) {
              _showSnackbar(state.errorMessage!, isError: true);
            } else if (state.status == SetupStatus.success) {
              _showSnackbar('Configuration "${state.configName}" saved successfully!');
              _clearAllControllers();
              context.read<SetupBloc>().add(const ResetSetup());
            }
          },
          builder: (context, state) {
            final bool isLoading = state.status == SetupStatus.loading;
            // NEW: Updated form validation to include connectionString
            final bool isFormValid = state.configName.isNotEmpty &&
                state.serverIP.isNotEmpty &&
                state.userName.isNotEmpty &&
                state.password.isNotEmpty &&
                state.connectionString.isNotEmpty && // Required
                state.databaseName.isNotEmpty;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 4, // Slightly reduced elevation
                      shadowColor: Colors.black.withOpacity(0.1), // Softer shadow
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // More rounded corners
                      color: Colors.white, // Set card background to white
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTextField(controller: _configNameController, hintText: 'Configuration Name', icon: Icons.label_important),
                            const SizedBox(height: 16),
                            _buildTextField(controller: _serverIPController, hintText: 'Server IP', icon: Icons.dns),
                            const SizedBox(height: 16),
                            _buildTextField(controller: _userNameController, hintText: 'Username', icon: Icons.person),
                            const SizedBox(height: 16),
                            _buildTextField(controller: _passwordController, hintText: 'Password', icon: Icons.lock, obscureText: true),
                            const SizedBox(height: 16),

                            // NEW: Connection String TextField
                            _buildTextField(controller: _connectionStringController, hintText: 'Database Connection String (Encrypted)', icon: Icons.settings_ethernet),
                            const SizedBox(height: 16),

                            if (state.status == SetupStatus.loadingDatabases)
                              const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                            else
                              _buildDropdownField(
                                value: state.databaseName,
                                items: state.availableDatabases,
                                onChanged: (value) {
                                  if (value != null) {
                                    context.read<SetupBloc>().add(UpdateDatabaseName(value));
                                  }
                                },
                                label: 'Database Name',
                                icon: Icons.storage,
                              ),

                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildButton(
                                  text: 'Reset',
                                  color: Colors.redAccent,
                                  onPressed: isLoading ? null : () {
                                    _clearAllControllers();
                                    context.read<SetupBloc>().add(const ResetSetup());
                                  },
                                  icon: Icons.refresh,
                                ),
                                const SizedBox(width: 12),
                                _buildButton(
                                  text: 'Save',
                                  color: Colors.blueAccent,
                                  onPressed: isFormValid && !isLoading ? () => _showSummaryDialog(context, state) : null,
                                  icon: Icons.save,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (isLoading) const SubtleLoader(),
              ],
            );
          },
        ),
      ),
    );
  }
}