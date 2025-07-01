// lib/setup_feature/setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

// Assuming these are in your project already
import '../ReportUtils/Appbar.dart';
import '../ReportUtils/subtleloader.dart';
import '../ReportDynamic/ReportAPIService.dart'; // Import the API service

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

  late final SetupBloc _bloc;
  Timer? _debounce;
  late final ReportAPIService _apiService; // Declare the API service

  @override
  void initState() {
    super.initState();
    _apiService = ReportAPIService(); // Initialize the API service
    _bloc = SetupBloc(_apiService); // Pass the API service to the bloc

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
    _bloc.close();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? label,
    IconData? icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey[700],
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
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

  void _showSummaryDialog(BuildContext context, SetupState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        title: Text(
          'Confirm Configuration',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Configuration Name: ${state.configName}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('Server IP: ${state.serverIP}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('Username: ${state.userName}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('Password: ${state.password}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 12),
              Text(
                'Please ensure all details are correct before saving.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
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
              _bloc.add(const SaveSetup());
            },
            child: Text(
              'Confirm Save',
              style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _bloc,
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Database Setup',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocConsumer<SetupBloc, SetupState>(
          listenWhen: (previous, current) =>
          previous.error != current.error || previous.isLoading != current.isLoading || previous.isSaved != current.isSaved,
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
            } else if (state.isSaved) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Configuration "${state.configName}" saved successfully!',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 3),
                ),
              );
              _configNameController.clear();
              _serverIPController.clear();
              _userNameController.clear();
              _passwordController.clear();
              context.read<SetupBloc>().add(const ResetSetup());
            }
          },
          buildWhen: (previous, current) =>
          previous.configName != current.configName ||
              previous.serverIP != current.serverIP ||
              previous.userName != current.userName ||
              previous.password != current.password ||
              previous.isLoading != current.isLoading,
          builder: (context, state) {
            final bool isFormValid = state.configName.isNotEmpty &&
                state.serverIP.isNotEmpty &&
                state.userName.isNotEmpty &&
                state.password.isNotEmpty;

            return Column(
              children: [
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
                              _buildTextField(
                                controller: _configNameController,
                                label: 'Configuration Name',
                                icon: Icons.label_important,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _serverIPController,
                                label: 'Server IP',
                                icon: Icons.dns,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _userNameController,
                                label: 'Username',
                                icon: Icons.person,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Password',
                                icon: Icons.lock,
                                obscureText: true,
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildButton(
                                    text: 'Save',
                                    color: Colors.blueAccent,
                                    onPressed: isFormValid && !state.isLoading
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
                                      _configNameController.clear();
                                      _serverIPController.clear();
                                      _userNameController.clear();
                                      _passwordController.clear();
                                      context.read<SetupBloc>().add(const ResetSetup());
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