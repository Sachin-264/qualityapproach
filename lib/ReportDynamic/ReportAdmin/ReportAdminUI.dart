// lib/report_admin_feature/report_admin_ui.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import 'EditReportAdmin/EditReportAdmin.dart';
import 'ReportAdminBloc.dart';
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
  bool _showPassword = false;

  late final ReportAdminBloc _bloc;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _bloc = ReportAdminBloc(ReportAPIService());

    _apiServerURLController.addListener(() => _debouncedUpdate(() => _bloc.add(UpdateApiServerURL(_apiServerURLController.text))));
    _apiNameController.addListener(() => _debouncedUpdate(() => _bloc.add(UpdateApiName(_apiNameController.text))));
  }

  void _debouncedUpdate(VoidCallback callback) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), callback);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _selectedConfigNameController.dispose();
    _serverIPController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _databaseNameController.dispose();
    _apiServerURLController.dispose();
    _apiNameController.dispose();
    _disposeParameterControllers();
    _bloc.close();
    super.dispose();
  }

  void _clearAllControllers() {
    _selectedConfigNameController.clear();
    _serverIPController.clear();
    _userNameController.clear();
    _passwordController.clear();
    _databaseNameController.clear();
    _apiServerURLController.clear();
    _apiNameController.clear();
    _disposeParameterControllers();
  }

  void _disposeParameterControllers() {
    _paramControllers.values.forEach((controller) => controller.dispose());
    _paramControllers.clear();
  }

  void _showSaveConfirmationDialog(BuildContext context, ReportAdminState state) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirm Save', style: GoogleFonts.poppins()),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to save this configuration?', style: GoogleFonts.poppins()),
                const SizedBox(height: 12),
                RichText(text: TextSpan(style: GoogleFonts.poppins(color: Colors.black87), children: [const TextSpan(text: 'API Name: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: state.apiName)])),
                RichText(text: TextSpan(style: GoogleFonts.poppins(color: Colors.black87), children: [const TextSpan(text: 'Server: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: state.serverIP)])),
                RichText(text: TextSpan(style: GoogleFonts.poppins(color: Colors.black87), children: [const TextSpan(text: 'Database: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: state.databaseName)])),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: GoogleFonts.poppins()),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: Text('Save', style: GoogleFonts.poppins(color: Colors.white)),
              onPressed: () {
                context.read<ReportAdminBloc>().add(const SaveDatabaseServer());
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({ required TextEditingController controller, String? label, IconData? icon, bool obscureText = false, bool isSmall = false, Widget? suffixIcon, bool readOnly = false, ValueChanged<String>? onChanged, }) {
    return TextField(onChanged: onChanged, controller: controller, obscureText: obscureText, readOnly: readOnly, style: GoogleFonts.poppins(fontSize: isSmall ? 14 : 16, color: Colors.black87), decoration: InputDecoration(labelText: label, labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: isSmall ? 13 : 15, fontWeight: FontWeight.w600), prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: isSmall ? 20 : 22) : null, suffixIcon: suffixIcon, filled: true, fillColor: readOnly ? Colors.grey[200] : Colors.white.withOpacity(0.9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[500]!, width: 1)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[500]!, width: 1)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)), contentPadding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16, horizontal: isSmall ? 12 : 16)));
  }

  Widget _buildDropdownField({ required String? value, required List<String> items, required ValueChanged<String?>? onChanged, String? label, IconData? icon, }) {
    final bool isEnabled = onChanged != null;
    return DropdownButtonFormField<String>(value: value != null && items.contains(value) ? value : null, onChanged: onChanged, items: items.isEmpty ? [const DropdownMenuItem<String>(value: null, child: Text('No databases available', style: TextStyle(color: Colors.grey)))] : items.map((String database) => DropdownMenuItem<String>(value: database, child: Text(database, style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87)))).toList(), style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87), decoration: InputDecoration(labelText: label, labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600), prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22.0) : null, filled: true, fillColor: isEnabled ? Colors.white.withOpacity(0.9) : Colors.grey[200], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[500]!, width: 1)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[500]!, width: 1)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)), contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16)));
  }

  Widget _buildButton({ required String text, required Color color, required VoidCallback? onPressed, IconData? icon, }) {
    return ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), elevation: 4, shadowColor: color.withOpacity(0.3)), child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)], Text(text, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16))]));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _bloc,
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Create Report',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocConsumer<ReportAdminBloc, ReportAdminState>(
          listenWhen: (prev, curr) => prev.successMessage != curr.successMessage || prev.error != curr.error || prev.selectedConfigId != curr.selectedConfigId,
          listener: (context, state) {
            // Show feedback snackbars
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.successMessage!), backgroundColor: Colors.green));
              _clearAllControllers();
              context.read<ReportAdminBloc>().add(const ResetAdminState());
            }
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!), backgroundColor: Colors.red));
            }
            // Synchronize fixed controllers with the BLoC state
            if (_serverIPController.text != state.serverIP) _serverIPController.text = state.serverIP;
            if (_userNameController.text != state.userName) _userNameController.text = state.userName;
            if (_passwordController.text != state.password) _passwordController.text = state.password;
            if (_databaseNameController.text != state.databaseName) _databaseNameController.text = state.databaseName;
            if (_apiServerURLController.text != state.apiServerURL) _apiServerURLController.text = state.apiServerURL;
            if (_apiNameController.text != state.apiName) _apiNameController.text = state.apiName;
          },
          buildWhen: (prev, curr) => prev != curr,
          builder: (context, state) {
            final bool canSave = state.serverIP.isNotEmpty && state.userName.isNotEmpty && state.password.isNotEmpty && state.databaseName.isNotEmpty && state.apiServerURL.isNotEmpty && state.apiName.isNotEmpty && !state.isLoading;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [_buildButton(text: 'Edit Config', color: Colors.purpleAccent, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditReportAdmin())), icon: Icons.edit)],
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
                              Autocomplete<Map<String, dynamic>>(
                                displayStringForOption: (option) => option['ConfigName'] as String,
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) return state.savedConfigurations;
                                  return state.savedConfigurations.where((option) => (option['ConfigName'] as String? ?? '').toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                },
                                onSelected: (Map<String, dynamic> selection) {
                                  _disposeParameterControllers();
                                  context.read<ReportAdminBloc>().add(SelectSavedConfiguration(selection['ConfigID'].toString()));
                                },
                                fieldViewBuilder: (context, fieldTextEditingController, fieldFocusNode, onFieldSubmitted) {
                                  _selectedConfigNameController.text = fieldTextEditingController.text;
                                  return TextField(controller: fieldTextEditingController, focusNode: fieldFocusNode, style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87), decoration: InputDecoration(labelText: 'Select Existing Configuration', labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600), prefixIcon: const Icon(Icons.search, color: Colors.blueAccent, size: 22), suffixIcon: state.isLoading && state.savedConfigurations.isEmpty ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)) : null, filled: true, fillColor: Colors.white.withOpacity(0.9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)), contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16)));
                                },
                              ),
                              const SizedBox(height: 24),
                              Row(children: [Expanded(child: _buildTextField(controller: _serverIPController, label: 'Server IP', icon: Icons.dns, readOnly: true)), const SizedBox(width: 16), Expanded(child: _buildTextField(controller: _userNameController, label: 'Username', icon: Icons.person, readOnly: true))]),
                              const SizedBox(height: 16),
                              _buildTextField(controller: _passwordController, label: 'Password', icon: Icons.lock, obscureText: !_showPassword, suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off, color: Colors.blueAccent), onPressed: () => setState(() => _showPassword = !_showPassword)), readOnly: true),
                              const SizedBox(height: 16),
                              state.isLoading && state.availableDatabases.isEmpty && state.error == null ? const Center(child: CircularProgressIndicator()) : _buildDropdownField(value: state.databaseName, items: state.availableDatabases, onChanged: null, label: 'Database Name', icon: Icons.storage),
                              const SizedBox(height: 16),
                              _buildTextField(controller: _apiServerURLController, label: 'API Server URL', icon: Icons.link),
                              const SizedBox(height: 16),
                              _buildTextField(controller: _apiNameController, label: 'API Name', icon: Icons.api),
                              const SizedBox(height: 16),
                              _buildButton(text: _showParameters ? 'Hide Parameters' : 'Show Parameters', color: Colors.green, onPressed: () => setState(() => _showParameters = !_showParameters), icon: _showParameters ? Icons.visibility_off : Icons.visibility),
                              if (_showParameters)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('API Parameters', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      const Divider(thickness: 1.5, height: 16),
                                      if (state.parameters.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text('No parameters found in the API URL.', style: GoogleFonts.poppins(color: Colors.grey[600])),
                                        )
                                      else
                                        ...state.parameters.asMap().entries.map((entry) {
                                          int index = entry.key;
                                          Map<String, dynamic> param = entry.value;
                                          String name = param['name'] as String;
                                          String value = param['value'] as String;
                                          _paramControllers[index] ??= TextEditingController();
                                          if (_paramControllers[index]!.text != value) {
                                            _paramControllers[index]!.text = value;
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 12.0),
                                            child: _buildTextField(
                                              controller: _paramControllers[index]!,
                                              label: name,
                                              isSmall: true,
                                              onChanged: (newValue) => _bloc.add(UpdateParameterValue(index, newValue)),
                                            ),
                                          );
                                        }).toList(),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildButton(text: 'Save', color: Colors.blueAccent, onPressed: canSave ? () => _showSaveConfirmationDialog(context, state) : null, icon: Icons.save),
                                  const SizedBox(width: 12),
                                  _buildButton(text: 'Reset', color: Colors.redAccent, onPressed: state.isLoading ? null : () {
                                    _clearAllControllers();
                                    _bloc.add(const ResetAdminState());
                                  }, icon: Icons.refresh),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (state.isLoading) const SubtleLoader(),
              ],
            );
          },
        ),
      ),
    );
  }
}