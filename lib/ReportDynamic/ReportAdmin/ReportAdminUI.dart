// lib/report_admin_feature/report_admin_ui.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:qualityapproach/ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import 'EditReportAdmin/EditReportAdmin.dart';
import 'ReportAdminBloc.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class ReportAdminUI extends StatefulWidget {
  const ReportAdminUI({super.key});

  @override
  _ReportAdminUIState createState() => _ReportAdminUIState();
}

class _ReportAdminUIState extends State<ReportAdminUI> {
  // --- Controllers ---
  final TextEditingController _serverIPController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _apiServerURLController = TextEditingController();
  final TextEditingController _apiNameController = TextEditingController();
  final Map<int, TextEditingController> _paramControllers = {};

  // --- State Variables ---
  bool _showPassword = false;
  bool _showParameters = false; // To control the new animated section
  Timer? _debounce;
  late ReportAdminBloc _bloc;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bloc = ReportAdminBloc(ReportAPIService())..add(const FetchSavedConfigurations());
    _setupListeners();
  }

  void _setupListeners() {
    _serverIPController.addListener(() => _debouncedUpdate(() => _bloc.add(UpdateServerIP(_serverIPController.text))));
    _userNameController.addListener(() => _debouncedUpdate(() => _bloc.add(UpdateUserName(_userNameController.text))));
    _passwordController.addListener(() => _debouncedUpdate(() => _bloc.add(UpdatePassword(_passwordController.text))));
    _apiServerURLController.addListener(() => _debouncedUpdate(() => {
      _bloc.add(UpdateApiServerURL(_apiServerURLController.text)),
      if (mounted && Uri.tryParse(_apiServerURLController.text)?.queryParameters.isNotEmpty == true) {
        setState(() { _showParameters = true; })
      }
    }));
    _apiNameController.addListener(() => _debouncedUpdate(() => _bloc.add(UpdateApiName(_apiNameController.text))));
  }

  void _debouncedUpdate(VoidCallback callback) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), callback);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _serverIPController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _apiServerURLController.dispose();
    _apiNameController.dispose();
    _paramControllers.forEach((_, controller) => controller.dispose());
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  // --- START: UI HELPER METHODS ---

  DateFormat? _inferDateFormat(String dateString) {
    if (dateString.isEmpty) return null;
    final List<String> commonFormats = ['dd-MMM-yyyy', 'yyyy-MM-dd', 'MM/dd/yyyy', 'dd/MM/yyyy', 'MMM dd, yyyy'];
    for (String format in commonFormats) { try { DateFormat(format).parseStrict(dateString); return DateFormat(format); } catch (e) { /* Continue */ } }
    return null;
  }

  DateTime _getFinancialYearStart([DateTime? fromDate]) { final now = fromDate ?? DateTime.now(); return DateTime(now.month < 4 ? now.year - 1 : now.year, 4, 1); }
  DateTime _getFinancialYearEnd([DateTime? fromDate]) { final now = fromDate ?? DateTime.now(); return DateTime(now.month < 4 ? now.year : now.year + 1, 3, 31); }
  DateTime _getStartOfMonth([DateTime? fromDate]) { final now = fromDate ?? DateTime.now(); return DateTime(now.year, now.month, 1); }
  DateTime _getEndOfMonth([DateTime? fromDate]) { final now = fromDate ?? DateTime.now(); return DateTime(now.year, now.month + 1, 0); }
  DateTime _getStartOfWeek([DateTime? fromDate]) { final now = fromDate ?? DateTime.now(); return now.subtract(Duration(days: now.weekday - 1)); }
  DateTime _getEndOfWeek([DateTime? fromDate]) { final now = fromDate ?? DateTime.now(); return now.add(Duration(days: DateTime.daysPerWeek - now.weekday)); }

  void _updateDateParameter(DateTime? pickedDate, TextEditingController controller, int index, DateFormat? existingFormat) {
    if (pickedDate != null && mounted) {
      final DateFormat outputFormat = existingFormat ?? DateFormat('dd-MMM-yyyy');
      final formattedDate = outputFormat.format(pickedDate);
      controller.text = formattedDate;
      _bloc.add(UpdateParameterUIValue(index, formattedDate));
    }
  }

  Future<DateTime?> _showAutoDateSelectionDialog(BuildContext context) async {
    return await showDialog<DateTime>(
      context: context,
      builder: (BuildContext dialogContext) {
        Widget buildOption(String title, DateTime date) => ListTile( leading: const Icon(Icons.touch_app_outlined, color: Colors.blueAccent), title: Text(title, style: GoogleFonts.poppins()), onTap: () => Navigator.of(dialogContext).pop(date) );
        final now = DateTime.now();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Select a Predefined Date', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [ buildOption('Current Date', now), const Divider(), buildOption('Start of This Week', _getStartOfWeek(now)), buildOption('End of This Week', _getEndOfWeek(now)), const Divider(), buildOption('Start of This Month', _getStartOfMonth(now)), buildOption('End of This Month', _getEndOfMonth(now)), const Divider(), buildOption('Starting of Financial Year', _getFinancialYearStart(now)), buildOption('Ending of Financial Year', _getFinancialYearEnd(now)), ])),
          actions: [ TextButton(onPressed: () => Navigator.of(dialogContext).pop(null), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600))) ],
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller, int index) async {
    DateTime? initialDate; DateFormat? inferredFormat;
    if (controller.text.isNotEmpty) {
      inferredFormat = _inferDateFormat(controller.text);
      if (inferredFormat != null) { try { initialDate = inferredFormat.parse(controller.text); } catch (e) { initialDate = DateTime.now(); } }
    }
    initialDate ??= DateTime.now();
    final DateTime? picked = await showDatePicker(context: context, initialDate: initialDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    _updateDateParameter(picked, controller, index, inferredFormat);
  }

  Future<String?> _showFieldLabelDialog(BuildContext context, String paramName, String? currentLabel) async {
    final TextEditingController labelController = TextEditingController(text: currentLabel ?? ''); String? fieldLabel;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Edit Label: ${paramName.toUpperCase()}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        content: _buildTextField(controller: labelController, label: 'Field Label', icon: Icons.label_important_outline, isSmall: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600))),
          TextButton(onPressed: () { if (labelController.text.trim().isNotEmpty) { fieldLabel = labelController.text.trim(); Navigator.pop(context); } }, child: Text('OK', style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    labelController.dispose();
    return fieldLabel;
  }

  bool _isDateParameter(String name, String value) {
    final datePattern1 = RegExp(r'^\d{2}-\d{2}-\d{4}$'); final datePattern2 = RegExp(r'^\d{2}-[A-Za-z]{3}-\d{4}$'); final datePattern3 = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    return name.toLowerCase().contains('date') || datePattern1.hasMatch(value) || datePattern2.hasMatch(value) || datePattern3.hasMatch(value);
  }

  // --- END: UI HELPER METHODS ---
  // --- START: WIDGET BUILDER METHODS ---

  Widget _buildSection({required String title, required List<Widget> children, EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0)}) {
    return Padding(padding: padding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)), const SizedBox(height: 16), ...children, ]));
  }

  Widget _buildTextField({ required TextEditingController controller, required String label, IconData? icon, bool obscureText = false, bool isSmall = false, bool isDateField = false, VoidCallback? onTap, VoidCallback? onAutoDateTap, IconData? suffixIconData, VoidCallback? onSuffixIconTap, bool readOnly = false }) {
    return TextField(
      controller: controller, obscureText: obscureText, readOnly: readOnly || isDateField, onTap: onTap, style: GoogleFonts.poppins(fontSize: isSmall ? 14 : 16, color: Colors.black87),
      decoration: InputDecoration(
          labelText: label, labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: isSmall ? 13 : 15, fontWeight: FontWeight.normal),
          prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: isSmall ? 20 : 22) : null,
          suffixIcon: isDateField ? Row(mainAxisSize: MainAxisSize.min, children: [ IconButton(icon: const Icon(Icons.auto_awesome, color: Colors.orangeAccent), tooltip: 'Select Predefined Date', onPressed: onAutoDateTap), IconButton(icon: const Icon(Icons.calendar_today, color: Colors.blueAccent), tooltip: 'Pick Date from Calendar', onPressed: onTap), ]) : (suffixIconData != null ? IconButton(icon: Icon(suffixIconData, color: Colors.blueAccent), onPressed: onSuffixIconTap) : null),
          filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
          contentPadding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16, horizontal: isSmall ? 12 : 16)
      ),
    );
  }

  Widget _buildDropdownField({ required String? value, required List<String> items, required ValueChanged<String?>? onChanged, String? label, IconData? icon }) {
    return DropdownButtonFormField<String>(
      value: value != null && items.contains(value) ? value : null, onChanged: onChanged,
      items: items.isEmpty ? [const DropdownMenuItem<String>(value: null, child: Text('No databases found', style: TextStyle(color: Colors.grey)))] : items.map((String database) => DropdownMenuItem<String>(value: database, child: Text(database, style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87)))).toList(),
      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
          labelText: label, labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontWeight: FontWeight.normal),
          prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22.0) : null,
          filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16)
      ),
    );
  }

  List<Widget> _buildParameterRows(ReportAdminState state, BuildContext context) {
    final allParamsOrdered = state.parameters;
    if (allParamsOrdered.isEmpty) { return [Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: Center(child: Text("Enter an API URL to see parameters here.", style: GoogleFonts.poppins(color: Colors.grey[600]))))]; }

    List<Widget> rows = [];
    for (var i = 0; i < allParamsOrdered.length; i++) {
      final param = allParamsOrdered[i]; final index = i; _paramControllers.putIfAbsent(index, () => TextEditingController());
      final paramController = _paramControllers[index]!;
      String textToDisplayInField = param['value']?.toString() ?? '';
      if (paramController.text != textToDisplayInField) {
        paramController.text = textToDisplayInField; paramController.selection = TextSelection.fromPosition(TextPosition(offset: paramController.text.length));
      }

      if (!paramController.hasListeners) { paramController.addListener(() => _debouncedUpdate(() { if (mounted && i < _bloc.state.parameters.length && _bloc.state.parameters[i]['value']?.toString() != paramController.text) { _bloc.add(UpdateParameterUIValue(i, paramController.text)); } })); }

      final isDate = _isDateParameter(param['name'].toString(), param['value'].toString());
      final configType = param['config_type'] ?? 'database';
      IconData suffixIcon = Icons.settings;
      switch (configType) { case 'database': suffixIcon = Icons.storage_rounded; break; case 'radio': suffixIcon = Icons.radio_button_checked_rounded; break; case 'checkbox': suffixIcon = Icons.check_box_rounded; break; }

      rows.add( Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(children: [
          Expanded(child: Row(children: [
            Expanded(child: _buildTextField(
              controller: paramController, label: (param['field_label']?.toString().isNotEmpty == true) ? param['field_label']!.toString() : (param['name']?.toString() ?? 'Unnamed'),
              isSmall: true, isDateField: isDate, readOnly: isDate, onTap: isDate ? () => _selectDate(context, paramController, index) : null,
              onAutoDateTap: isDate ? () async { final pickedDate = await _showAutoDateSelectionDialog(context); _updateDateParameter(pickedDate, paramController, index, _inferDateFormat(paramController.text)); } : null,
              suffixIconData: isDate ? null : suffixIcon,
              onSuffixIconTap: isDate ? null : () async {
                final blocState = _bloc.state; final currentParam = blocState.parameters[index];
                final result = await showGeneralDialog<Map<String, dynamic>>(
                  context: context, barrierDismissible: true, barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                  pageBuilder: (dialogContext, _, __) => _ParameterConfigModal(
                    apiService: _bloc.apiService, paramIndex: index, currentParam: currentParam,
                    serverIP: blocState.serverIP, userName: blocState.userName, password: blocState.password, databaseName: blocState.databaseName,
                  ),
                );
                if (result != null && mounted) { _bloc.add(UpdateParameterFromModal( index: index, newConfigType: result['config_type'], newValue: result['value'], newDisplayLabel: result['display_label'], newMasterTable: result['master_table'], newMasterField: result['master_field'], newDisplayField: result['display_field'], newOptions: (result['options'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList(), newSelectedValues: result['selected_values']?.cast<String>(), )); }
              },
            )),
            if (param['show'] ?? false) IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20), onPressed: () async { final fieldLabel = await _showFieldLabelDialog(context, param['name'], param['field_label']); if (fieldLabel != null && mounted) _bloc.add(UpdateParameterFieldLabel(index, fieldLabel)); }, tooltip: 'Edit Field Label'),
          ])),
          const SizedBox(width: 8),
          Tooltip(message: 'Mark as Company Name Field', child: Radio<int>( value: index, groupValue: state.parameters.indexWhere((p) => (p['is_company_name_field'] as bool?) == true), onChanged: (int? selectedIndex) { if (selectedIndex != null) _bloc.add(UpdateParameterIsCompanyNameField(selectedIndex)); }, activeColor: Colors.deepOrange, )),
          const SizedBox(width: 8),
          Tooltip(message: 'Show this field to the user', child: Checkbox(
            value: param['show'] ?? false,
            onChanged: (value) async {
              if (value == true) { final fieldLabel = await _showFieldLabelDialog(context, param['name'], param['field_label']); if (fieldLabel != null && mounted) { _bloc.add(UpdateParameterFieldLabel(index, fieldLabel)); _bloc.add(UpdateParameterShow(index, true)); }
              } else { _bloc.add(UpdateParameterShow(index, false)); }
            },
            activeColor: Colors.blueAccent,
          )),
        ]),
      ),
      );
    }
    return rows;
  }

  // --- END: WIDGET BUILDER METHODS ---

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: Colors.white,
        // CHANGE 1: Replaced the old AppBar with your new custom AppBar
        appBar: AppBar(
          title: Text('Report Maker', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 6, bottom: 6),
              child: ElevatedButton.icon(
                icon: Icon(Icons.edit, color: Colors.blue.shade800, size: 20),
                label: Text( "Edit Reports", style: GoogleFonts.poppins( color: Colors.blue.shade800, fontWeight: FontWeight.w600, ), ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditReportAdmin())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade800,
                  shape: const StadiumBorder(),
                  elevation: 2,
                ),
              ),
            ),
          ],
          elevation: 4,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[800]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        persistentFooterButtons: [ BlocBuilder<ReportAdminBloc, ReportAdminState>( builder: (context, state) {
          final canSave = state.serverIP.isNotEmpty && state.userName.isNotEmpty && state.databaseName.isNotEmpty && state.apiServerURL.isNotEmpty && state.apiName.isNotEmpty && !state.isLoading;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton.icon(icon: const Icon(Icons.refresh_rounded, color: Colors.white), label: Text("Reset", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[600], padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: state.isLoading ? null : () => _bloc.add(const ResetAdminState())),
              const SizedBox(width: 12),
              ElevatedButton.icon(icon: const Icon(Icons.save_alt_rounded, color: Colors.white), label: Text("Save", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: canSave ? Colors.blueAccent : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: canSave ? () => _bloc.add(const SaveDatabaseServer()) : null),
            ]),
          );
        }, ) ],
        body: BlocConsumer<ReportAdminBloc, ReportAdminState>(
          listener: (context, state) {
            if (state.successMessage != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.successMessage!), backgroundColor: Colors.green.shade600)); _bloc.add(const ResetAdminState()); }
            if (state.error != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!), backgroundColor: Colors.red.shade600)); }
            if (_serverIPController.text != state.serverIP) _serverIPController.text = state.serverIP;
            if (_userNameController.text != state.userName) _userNameController.text = state.userName;
            if (_passwordController.text != state.password) _passwordController.text = state.password;
            if (_apiServerURLController.text != state.apiServerURL) _apiServerURLController.text = state.apiServerURL;
            if (_apiNameController.text != state.apiName) _apiNameController.text = state.apiName;
          },
          builder: (context, state) {
            return Stack(
              children: [
                ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 80), // Space for footer buttons
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      // CHANGE 2: Removed the old Edit button from here
                      child: Autocomplete<Map<String, dynamic>>(
                        displayStringForOption: (option) => option['ConfigName'] as String? ?? '',
                        optionsBuilder: (TextEditingValue textEditingValue) { if (textEditingValue.text.isEmpty) return state.savedConfigurations; return state.savedConfigurations.where((option) => (option['ConfigName'] as String? ?? '').toLowerCase().contains(textEditingValue.text.toLowerCase())); },
                        onSelected: (Map<String, dynamic> selection) { FocusScope.of(context).unfocus(); _bloc.add(SelectSavedConfiguration(selection['ConfigID'].toString())); },
                        fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(controller: controller, focusNode: focusNode, style: GoogleFonts.poppins(), decoration: InputDecoration(hintText: 'Load Existing Configuration...', prefixIcon: const Icon(Icons.search, color: Colors.blueAccent), filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)))),
                      ),
                    ),
                    const Divider(height: 1),
                    _buildSection(title: 'Connection Details', children: [ Row(children: [ Expanded(child: _buildTextField(controller: _serverIPController, label: 'Server IP', icon: Icons.dns_rounded)), const SizedBox(width: 16), Expanded(child: _buildTextField(controller: _userNameController, label: 'Username', icon: Icons.person_outline_rounded)) ]), const SizedBox(height: 16), _buildTextField(controller: _passwordController, label: 'Password', icon: Icons.lock_outline_rounded, obscureText: !_showPassword, suffixIconData: _showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, onSuffixIconTap: () => setState(() => _showPassword = !_showPassword)), const SizedBox(height: 16), _buildDropdownField(value: state.databaseName, items: state.availableDatabases, onChanged: (value) { if (value != null) _bloc.add(UpdateDatabaseName(value)); }, label: 'Database Name', icon: Icons.storage_rounded), ]),
                    const Divider(height: 1),
                    _buildSection(title: 'API Endpoint', children: [ _buildTextField(controller: _apiServerURLController, label: 'API Server URL', icon: Icons.link_rounded), const SizedBox(height: 16), _buildTextField(controller: _apiNameController, label: 'API / Report Name', icon: Icons.api_rounded), ]),
                    const Divider(height: 1),
                    InkWell(
                      onTap: () => setState(() {
                        _showParameters = !_showParameters;
                        if (_showParameters) { SchedulerBinding.instance.addPostFrameCallback((_) { if (_scrollController.hasClients) { _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); } }); }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text("Parameters", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)), AnimatedRotation(turns: _showParameters ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: const Icon(Icons.expand_more_rounded, color: Colors.grey)), ]),
                      ),
                    ),
                    AnimatedSize( duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, child: _showParameters ? Padding( padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: Column(children: _buildParameterRows(state, context)), ) : const SizedBox.shrink(), ),
                    const Divider(height: 1),
                    _buildSection(title: 'Configuration Help', children: [ _buildHelpRow(icon: Icons.visibility_outlined, label: 'Show/Hide Parameter (Checkbox):', description: 'Check this box to make a parameter visible and editable to the end-user. Uncheck to hide it.'), _buildHelpRow(icon: Icons.edit_outlined, label: 'Edit Field Label (Pencil Icon):', description: 'Click this icon to customize the display name (label) of the parameter that users will see.'), _buildHelpRow(icon: Icons.radio_button_checked_outlined, label: 'Mark as Company Name Field (Radio Button):', description: 'Select one parameter to be used as the "Company Name". Only one can be selected.', color: Colors.deepOrange), _buildHelpRow(icon: Icons.settings_outlined, label: 'Configure Parameter Input (Settings Icon):', description: 'Click this icon to define how the user inputs the value (e.g., from a database list, radio buttons, or checkboxes).'), ])
                  ],
                ),
                // CHANGE 3: This loader now correctly handles all async operations
                if (state.isLoading) const SubtleLoader(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHelpRow({ required IconData icon, required String label, required String description, Color color = Colors.blueAccent}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [ Icon(icon, color: color, size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)), Text(description, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])), ])), ]), );
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