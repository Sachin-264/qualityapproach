// lib/ReportDynamic/ReportGenerator/ReportUI.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../ReportDashboard/DashboardBloc/preselectedreportloader.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import 'ReportMainUI.dart';
import 'Reportbloc.dart';

class ReportUI extends StatefulWidget {
  final Map<String, dynamic>? reportToPreload;
  final Map<String, String>? initialParameters;

  const ReportUI({
    super.key,
    this.reportToPreload,
    this.initialParameters,
  });

  @override
  _ReportUIState createState() => _ReportUIState();
}

class _ReportUIState extends State<ReportUI> {
  final TextEditingController _reportLabelDisplayController = TextEditingController();
  Map<String, dynamic>? _selectedReport;
  final Map<String, TextEditingController> _paramControllers = {};
  final Map<String, FocusNode> _paramFocusNodes = {};

  final List<DateFormat> _dateFormatsToTry = [
    DateFormat('dd-MM-yyyy'),
    DateFormat('dd-MMM-yyyy'),
    DateFormat('yyyy-MM-dd'),
  ];

  bool get _isPreloadedMode => widget.reportToPreload != null;

  @override
  void initState() {
    super.initState();
    if (_isPreloadedMode) {
      _selectedReport = widget.reportToPreload;
      _reportLabelDisplayController.text = _selectedReport?['Report_label'] ?? 'Preloaded Report';
    }
  }

  @override
  void dispose() {
    _reportLabelDisplayController.dispose();
    _paramControllers.forEach((_, controller) => controller.dispose());
    _paramControllers.clear();
    _paramFocusNodes.forEach((_, focusNode) => focusNode.dispose());
    _paramFocusNodes.clear();
    super.dispose();
  }

  void _handlePrimaryAction(BuildContext context, ReportState state) {
    if (_selectedReport == null) return;
    final bloc = context.read<ReportBlocGenerate>();
    debugPrint('\n=============================================\n==== "${_isPreloadedMode ? "APPLY FILTERS" : "SHOW"}" CLICKED ====\nReport: ${_selectedReport!['Report_label']}\n--- CURRENT PARAMETER VALUES ---\n${state.userParameterValues.entries.map((e) => '  ${e.key}: "${e.value}"').join('\n')}\n=============================================\n');
    if (!context.mounted) return;
    if (_isPreloadedMode) {
      Navigator.pop(context, true);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreSelectedReportLoader(
            reportDefinition: _selectedReport!,
            apiService: ReportAPIService(),
            initialParameters: state.userParameterValues,
          ),
        ),
      );
    }
  }

  (DateTime?, DateFormat?) _parseDateSmartly(String dateString) {
    if (dateString.isEmpty) return (null, null);
    for (var format in _dateFormatsToTry) {
      try {
        final dateTime = format.parseStrict(dateString);
        return (dateTime, format);
      } catch (e) {
        // continue
      }
    }
    return (null, null);
  }

  Widget _buildTextField({
    required TextEditingController controller, String? label, FocusNode? focusNode, Function(String)? onChanged,
    IconData? icon, bool readOnly = false, VoidCallback? onTap, TextInputType? keyboardType,
    bool enableClearButton = false, VoidCallback? onClear,
  }) {
    return TextField(
      controller: controller, focusNode: focusNode, onChanged: onChanged, readOnly: readOnly, onTap: onTap,
      keyboardType: keyboardType, style: GoogleFonts.poppins(fontSize: 16, color: readOnly ? Colors.grey[600] : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22) : null,
        suffixIcon: enableClearButton && controller.text.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear, color: Colors.grey),
          onPressed: () { controller.clear(); onClear?.call(); onChanged?.call(''); },
        ) : null,
        filled: true, fillColor: readOnly ? Colors.grey[200] : Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[500]!, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[500]!, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }

  Widget _buildButton({
    required String text, required Color color, required VoidCallback? onPressed, IconData? icon,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), elevation: 4, shadowColor: color.withOpacity(0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
          Text(text, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        ],
      ),
    );
  }

  void _resetAllFields(BuildContext context) {
    debugPrint('UI: _resetAllFields called.');
    final bloc = context.read<ReportBlocGenerate>();
    if (_isPreloadedMode) {
      for (var param in bloc.state.selectedApiParameters) {
        final paramName = param['name'].toString();
        final defaultValue = param['default_value']?.toString() ?? '';
        bloc.add(UpdateParameter(paramName, defaultValue));
      }
    } else {
      _reportLabelDisplayController.clear();
      setState(() { _selectedReport = null; });
      _paramControllers.forEach((_, c) => c.dispose());
      _paramControllers.clear();
      _paramFocusNodes.forEach((_, f) => f.dispose());
      _paramFocusNodes.clear();
      bloc.add(ResetReports());
    }
  }

  Widget _buildRadioParameter({ required Map<String, dynamic> param, required String currentValue, required ValueChanged<String> onChanged }) {
    final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : param['name'];
    final List<Map<String, String>> options = List<Map<String, String>>.from((param['options'] as List?)?.map((e) => Map<String, String>.from(e ?? {})) ?? []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(paramLabel, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[700])),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[500]!, width: 1)),
        child: Column(children: options.map((option) => RadioListTile<String>(title: Text(option['label']!, style: GoogleFonts.poppins(fontSize: 14)), value: option['value']!, groupValue: currentValue, onChanged: (v) { if (v != null) onChanged(v); }, contentPadding: EdgeInsets.zero, dense: true, activeColor: Colors.blueAccent)).toList()),
      )
    ]);
  }

  Widget _buildCheckboxParameter({ required Map<String, dynamic> param, required String currentValue, required ValueChanged<String> onChanged }) {
    final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : param['name'];
    final List<Map<String, String>> options = List<Map<String, String>>.from((param['options'] as List?)?.map((e) => Map<String, String>.from(e ?? {})) ?? []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(paramLabel, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[700])),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[500]!, width: 1)),
        child: Column(children: options.map((option) => CheckboxListTile(title: Text(option['label']!, style: GoogleFonts.poppins(fontSize: 14)), value: currentValue == option['value'], onChanged: (isChecked) => onChanged(isChecked == true ? option['value']! : ''), contentPadding: EdgeInsets.zero, dense: true, activeColor: Colors.blueAccent, controlAffinity: ListTileControlAffinity.leading)).toList()),
      )
    ]);
  }

  // =========================================================================
  // == START: NEW ADVANCED DIALOG FOR DATABASE TRANSFER
  // =========================================================================
  void _showTransferDialog(BuildContext context) {
    final bloc = context.read<ReportBlocGenerate>();
    final currentState = bloc.state;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Transfer Report', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: _TransferDialogContent(
            apiService: bloc.apiService,
            reportMetadata: _selectedReport!,
            fieldConfigs: currentState.fieldConfigs,
          ),
        );
      },
    );
  }
  // =========================================================================
  // == END: NEW DIALOG
  // =========================================================================


  @override
  Widget build(BuildContext context) {
    if (!_isPreloadedMode) {
      return BlocProvider(
        create: (context) => ReportBlocGenerate(ReportAPIService())..add(LoadReports()),
        child: _buildContent(context),
      );
    }
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(title: _isPreloadedMode ? 'Filter Report' : 'Report Selection', onBackPress: () => Navigator.pop(context)),
    body: BlocListener<ReportBlocGenerate, ReportState>(
    listener: (context, state) {
    // --- Handle Error Message ---
    if (state.error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(state.error!),
    backgroundColor: Colors.redAccent,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    // MODIFICATION: Use addPostFrameCallback to clear the error.
    // This ensures the message is cleared only AFTER the current frame has finished building,
    // preventing race conditions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<ReportBlocGenerate>().emit(state.copyWith(error: null));
    });
    }

    // --- Handle Success Message ---
    if (state.successMessage != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(state.successMessage!),
    backgroundColor: Colors.green,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    // MODIFICATION: Use addPostFrameCallback here as well for consistency and reliability.
    WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<ReportBlocGenerate>().emit(state.copyWith(successMessage: null));
    });
    }
          if (state.successMessage != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.successMessage!), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); WidgetsBinding.instance.addPostFrameCallback((_) { context.read<ReportBlocGenerate>().emit(state.copyWith(successMessage: null)); }); }
        },
        child: BlocBuilder<ReportBlocGenerate, ReportState>(
          builder: (context, state) {
            String? clientApiName;
            final bool isReportSelected = _selectedReport != null;
            final bool areFieldConfigsLoaded = state.fieldConfigs.isNotEmpty;

            if (isReportSelected) {
              clientApiName = _selectedReport!['API_name']?.toString();
            }
            final bool isClientApiNameValid = clientApiName != null && clientApiName.isNotEmpty;
            final bool canDeploy = isReportSelected && areFieldConfigsLoaded && isClientApiNameValid;

            final textInputParams = state.selectedApiParameters.where((p) { final configType = p['config_type']?.toString().toLowerCase() ?? ''; return p['show'] == true && !['radio', 'checkbox'].contains(configType); }).toList();
            for (var param in textInputParams) {
              final paramName = param['name'].toString();
              if (!_paramControllers.containsKey(paramName)) { _paramControllers[paramName] = TextEditingController(); _paramFocusNodes[paramName] = FocusNode(); }
              final isPicker = (param['config_type']?.toString().toLowerCase() == 'database') && (param['master_table']?.toString().isNotEmpty == true);
              final currentApiValue = state.userParameterValues[paramName] ?? '';
              String displayValue = currentApiValue;
              if (isPicker && state.pickerOptions.containsKey(paramName) && currentApiValue.isNotEmpty) { displayValue = state.pickerOptions[paramName]!.firstWhere((o) => o['value'] == currentApiValue, orElse: () => {'label': currentApiValue})['label']!; }
              if (_paramControllers[paramName]!.text != displayValue) { _paramControllers[paramName]!.text = displayValue; }
            }

            final Widget reportSelectionWidget;
            if (_isPreloadedMode) {
              reportSelectionWidget = _buildTextField(controller: _reportLabelDisplayController, label: 'Report Name', readOnly: true, icon: Icons.label_important);
            } else {
              reportSelectionWidget = Autocomplete<Map<String, dynamic>>(
                initialValue: TextEditingValue(text: _reportLabelDisplayController.text),
                optionsBuilder: (textEditingValue) { if (textEditingValue.text.isEmpty && _selectedReport != null) { WidgetsBinding.instance.addPostFrameCallback((_) { _resetAllFields(context); }); } return state.reports.where((r) => r['Report_label'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase())).toList()..sort((a, b) => (a['Report_label']?.toString() ?? '').compareTo(b['Report_label']?.toString() ?? '')); },
                displayStringForOption: (option) => option['Report_label'],
                onSelected: (selection) {
                  final bloc = context.read<ReportBlocGenerate>();
                  bloc.add(ResetReports());
                  setState(() {
                    _selectedReport = selection;
                    _reportLabelDisplayController.text = selection['Report_label'];
                  });

                  final actionsRaw = selection['actions_config'];
                  List<Map<String, dynamic>> actionsConfig = [];
                  if (actionsRaw is List) {
                    actionsConfig = List.from(actionsRaw);
                  } else if (actionsRaw is String && actionsRaw.isNotEmpty) {
                    try { actionsConfig = List.from(jsonDecode(actionsRaw)); } catch (e) {
                      debugPrint('Error decoding actions_config from selection: $e');
                    }
                  }
                  final includePdfFooter = selection['pdf_footer_datetime'] == true;

                  bloc.add(FetchApiDetails(
                    selection['API_name'],
                    actionsConfig,
                    includePdfFooterDateTimeFromReportMetadata: includePdfFooter,
                    reportSelectionPayload: selection,
                  ));
                },
                fieldViewBuilder: (c, tc, fn, ofs) => _buildTextField(controller: tc, focusNode: fn, label: 'Report Label', icon: Icons.label, enableClearButton: true, onClear: () { _resetAllFields(context); tc.clear(); }, onChanged: (v) { _reportLabelDisplayController.text = v; if (v.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) { _resetAllFields(context); }); }),
                optionsViewBuilder: (c, onSel, opts) => Align(alignment: Alignment.topLeft, child: Material(elevation: 4, child: SizedBox(width: 300, height: opts.length > 5 ? 250 : null, child: ListView.builder(itemCount: opts.length, itemBuilder: (ctx, i) => ListTile(title: Text(opts.elementAt(i)['Report_label']), onTap: () => onSel(opts.elementAt(i))))))),
              );
            }

            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Card(
                        color: Colors.white, elevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              reportSelectionWidget,
                              const SizedBox(height: 20),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 12.0,
                                  runSpacing: 12.0,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    _buildButton(text: _isPreloadedMode ? 'Apply Filters' : 'Show', color: Colors.blueAccent, onPressed: _selectedReport != null ? () => _handlePrimaryAction(context, state) : null, icon: _isPreloadedMode ? Icons.check_circle_outline : Icons.visibility),
                                    if (!_isPreloadedMode) ...[
                                      _buildButton(
                                          text: 'Send to Client',
                                          color: Colors.purple,
                                          onPressed: canDeploy ? () {
                                            debugPrint('UI: "Send to Client" clicked. Dispatching DeployReportToClient event.');
                                            context.read<ReportBlocGenerate>().add(
                                              DeployReportToClient(
                                                reportMetadata: _selectedReport!,
                                                fieldConfigs: state.fieldConfigs,
                                                clientApiName: clientApiName!,
                                              ),
                                            );
                                          } : null,
                                          icon: Icons.cloud_upload
                                      ),
                                      _buildButton(
                                        text: 'Transfer',
                                        color: Colors.teal,
                                        onPressed: canDeploy ? () => _showTransferDialog(context) : null,
                                        icon: Icons.sync_alt,
                                      ),
                                    ],
                                    _buildButton(text: 'Reset', color: Colors.redAccent, onPressed: () => _resetAllFields(context), icon: Icons.refresh),
                                  ],
                                ),
                              ),
                              if (state.selectedApiParameters.isNotEmpty) ...[
                                const Divider(height: 40),
                                Text('Parameters', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
                                const SizedBox(height: 16),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: state.selectedApiParameters.where((param) => param['show'] == true).map((param) {
                                        final paramName = param['name'].toString();
                                        final paramLabel = param['field_label']?.isNotEmpty == true ? param['field_label'] : paramName;
                                        final configType = param['config_type']?.toString().toLowerCase() ?? '';
                                        final isDatabasePicker = (configType == 'database') && (param['master_table']?.toString().isNotEmpty == true);
                                        final isDateField = (configType == 'date') || (configType != 'radio' && configType != 'checkbox' && !isDatabasePicker && paramName.toLowerCase().contains('date') && state.userParameterValues.containsKey(paramName) && state.userParameterValues[paramName]!.isNotEmpty && _parseDateSmartly(state.userParameterValues[paramName]!).$1 != null);

                                        if (configType == 'radio') {
                                          return Padding(padding: const EdgeInsets.only(bottom: 16.0), child: _buildRadioParameter(param: param, currentValue: state.userParameterValues[paramName] ?? '', onChanged: (newValue) { context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, newValue)); }));
                                        }
                                        if (configType == 'checkbox') {
                                          return Padding(padding: const EdgeInsets.only(bottom: 16.0), child: _buildCheckboxParameter(param: param, currentValue: state.userParameterValues[paramName] ?? '', onChanged: (newValue) { context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, newValue)); }));
                                        }
                                        if (isDatabasePicker) {
                                          final controller = _paramControllers[paramName]!;
                                          return Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Autocomplete<Map<String, String>>(optionsBuilder: (v) { if (!state.pickerOptions.containsKey(paramName) && state.serverIP != null) { context.read<ReportBlocGenerate>().add(FetchPickerOptions(paramName: paramName, serverIP: state.serverIP!, userName: state.userName!, password: state.password!, databaseName: state.databaseName!, masterTable: param['master_table'].toString(), masterField: param['master_field'].toString(), displayField: param['display_field'].toString())); } final opts = state.pickerOptions[paramName] ?? []; return v.text.isEmpty ? opts : opts.where((o) => o['label']!.toLowerCase().contains(v.text.toLowerCase())); }, displayStringForOption: (o) => o['label']!, onSelected: (s) { controller.text = s['label']!; context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, s['value']!)); }, fieldViewBuilder: (c, tc, fn, ofs) { if (tc.text != controller.text) { tc.text = controller.text; } return _buildTextField(controller: tc, focusNode: fn, label: paramLabel, enableClearButton: true, onClear: () { tc.clear(); context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, '')); }, onChanged: (val) => context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, val))); }, optionsViewBuilder: (c, onSel, opts) => Align(alignment: Alignment.topLeft, child: Material(elevation: 4, child: SizedBox(width: 300, height: opts.length > 5 ? 250 : null, child: ListView.builder(itemCount: opts.length, itemBuilder: (ctx, i) => ListTile(title: Text(opts.elementAt(i)['label']!), onTap: () => onSel(opts.elementAt(i)))))))));
                                        }
                                        if (isDateField) {
                                          final controller = _paramControllers[paramName]!;
                                          return Padding(padding: const EdgeInsets.only(bottom: 16.0), child: _buildTextField(label: paramLabel, controller: controller, icon: Icons.calendar_today, readOnly: true, enableClearButton: true, onClear: () { controller.clear(); context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, '')); },
                                              onTap: () async {
                                                final parseResult = _parseDateSmartly(controller.text);
                                                final DateFormat detectedFormat = parseResult.$2 ?? _dateFormatsToTry.first;
                                                final pickedDate = await showDatePicker(context: context, initialDate: parseResult.$1 ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100), builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Colors.blueAccent, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black87), dialogBackgroundColor: Colors.white, textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.blueAccent, textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600)))), child: child!));
                                                if (pickedDate != null) {
                                                  final formattedDate = detectedFormat.format(pickedDate);
                                                  context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, formattedDate));
                                                }
                                              }
                                          ));
                                        }
                                        return Padding(padding: const EdgeInsets.only(bottom: 16.0), child: _buildTextField(controller: _paramControllers[paramName]!, focusNode: _paramFocusNodes[paramName]!, label: paramLabel, icon: Icons.text_fields, enableClearButton: true, onClear: () { _paramControllers[paramName]!.clear(); context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, '')); }, onChanged: (value) => context.read<ReportBlocGenerate>().add(UpdateParameter(paramName, value))));
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.isLoading) const Positioned.fill(child: SubtleLoader()),
                if (state.reports.isEmpty && !state.isLoading && !_isPreloadedMode) const Center(child: Text('No reports available.')),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TransferDialogContent extends StatefulWidget {
  final ReportAPIService apiService;
  final Map<String, dynamic> reportMetadata;
  final List<Map<String, dynamic>> fieldConfigs;

  const _TransferDialogContent({
    required this.apiService,
    required this.reportMetadata,
    required this.fieldConfigs,
  });

  @override
  __TransferDialogContentState createState() => __TransferDialogContentState();
}

class __TransferDialogContentState extends State<_TransferDialogContent> {
  bool _isLoadingApis = true;
  List<Map<String, dynamic>> _availableApis = [];
  Map<String, dynamic>? _selectedApi;

  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isFetchingDatabases = false;
  List<String> _databaseList = [];
  String? _selectedDatabase;

  bool _isTransferring = false;
  String? _error;
  Timer? _errorClearTimer;

  @override
  void initState() {
    super.initState();
    _loadApiConnections();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _errorClearTimer?.cancel();
    super.dispose();
  }

  void _setError(String message) {
    setState(() => _error = message);
    _errorClearTimer?.cancel();
    _errorClearTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _error = null);
    });
  }

  Future<void> _loadApiConnections() async {
    try {
      final allApiNames = await widget.apiService.getAvailableApis();
      final List<Map<String, dynamic>> fullDetails = [];
      for (var name in allApiNames) {
        final details = await widget.apiService.getApiDetails(name);
        details['APIName'] = name;
        fullDetails.add(details);
      }
      final filteredApis = fullDetails.where((details) => details['IsDashboard'] != true).toList();
      if (mounted) setState(() { _availableApis = filteredApis; _isLoadingApis = false; });
    } catch (e) {
      if (mounted) { setState(() => _isLoadingApis = false); _setError("Failed to load connections: $e"); }
    }
  }

  Future<void> _fetchDatabases() async {
    if (_serverController.text.isEmpty || _userController.text.isEmpty) {
      _setError("Server IP and User Name are required.");
      return;
    }
    setState(() { _isFetchingDatabases = true; _databaseList = []; _selectedDatabase = null; _error = null; });
    try {
      final databases = await widget.apiService.fetchDatabases(
        serverIP: _serverController.text, userName: _userController.text, password: _passwordController.text,
      );
      if (mounted) setState(() { _databaseList = databases; _isFetchingDatabases = false; });
    } catch (e) {
      if (mounted) { setState(() => _isFetchingDatabases = false); _setError("Error fetching databases: $e"); }
    }
  }

  void _startTransfer() {
    setState(() => _isTransferring = true);
    context.read<ReportBlocGenerate>().add(TransferReportToDatabase(
      reportMetadata: widget.reportMetadata,
      fieldConfigs: widget.fieldConfigs,
      targetServerIP: _serverController.text,
      targetUserName: _userController.text,
      targetPassword: _passwordController.text,
      targetDatabaseName: _selectedDatabase!,
    ));
  }

  Widget _buildSectionTitle(String number, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.teal,
            child: Text(number, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: GoogleFonts.poppins(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(),
          prefixIcon: Icon(icon, color: Colors.grey[700], size: 20),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReportBlocGenerate, ReportState>(
      listener: (context, state) {
        if (state.successMessage != null && _isTransferring) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.successMessage!),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
          setState(() => _isTransferring = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<ReportBlocGenerate>().emit(state.copyWith(successMessage: null));
            Navigator.of(context).pop();
          });
        } else if (state.error != null && _isTransferring) {
          setState(() {
            _isTransferring = false;
            _error = state.error;
          });
          _errorClearTimer?.cancel();
          _errorClearTimer = Timer(const Duration(seconds: 6), () {
            if (mounted) setState(() => _error = null);
          });
        }
      },
      child: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('1', 'Select a Destination Connection'),
                if (_isLoadingApis)
                  const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                else
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedApi,
                    hint: Text('Select a saved connection...', style: GoogleFonts.poppins()),
                    isExpanded: true,
                    items: _availableApis.map((apiDetails) => DropdownMenuItem(
                      value: apiDetails,
                      child: Text(apiDetails['APIName'] ?? 'Unknown', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedApi = value;
                        _serverController.text = value?['serverIP'] ?? '';
                        _userController.text = value?['userName'] ?? '';
                        _passwordController.text = value?['password'] ?? '';
                        _databaseList = [];
                        _selectedDatabase = null;
                        _error = null;
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),

                const Divider(height: 32),

                _buildSectionTitle('2', 'Verify Credentials & Fetch Databases'),
                _buildModernTextField(controller: _serverController, label: "Server IP", icon: Icons.dns_outlined),
                _buildModernTextField(controller: _userController, label: "User Name", icon: Icons.person_outline),
                _buildModernTextField(controller: _passwordController, label: "Password", icon: Icons.password_outlined, obscureText: true),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isFetchingDatabases ? null : _fetchDatabases,
                    icon: _isFetchingDatabases
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_sync_outlined),
                    label: Text("Fetch Databases", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const Divider(height: 32),

                _buildSectionTitle('3', 'Select Target Database'),
                if (_isFetchingDatabases) const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Fetching...")))
                else if (_databaseList.isEmpty) const Center(child: Text("No databases found.", style: TextStyle(color: Colors.grey)))
                else
                  DropdownButtonFormField<String>(
                    value: _selectedDatabase,
                    hint: Text('Select target database...', style: GoogleFonts.poppins()),
                    isExpanded: true,
                    items: _databaseList.map((db) => DropdownMenuItem(value: db, child: Text(db, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (value) => setState(() => _selectedDatabase = value),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _error != null ? 70 : 0,
                  child: _error != null
                      ? Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                      ],
                    ),
                  )
                      : const SizedBox.shrink(),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isTransferring ? null : () => Navigator.of(context).pop(),
                        child: Text("Cancel", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: _isTransferring
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded),
                        label: Text(_isTransferring ? 'Transferring...' : 'Confirm Transfer', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        onPressed: (_selectedDatabase == null || _isTransferring) ? null : _startTransfer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}