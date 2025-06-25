// lib/ReportDynamic/ReportGenerator/ReportUI.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../ReportDashboard/DashboardBloc/preselectedreportloader.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import 'ReportMainUI.dart';
import 'Reportbloc.dart';

class ReportUI extends StatefulWidget {
  // Can be in one of two modes:
  // 1. Selection Mode: reportToPreload is null. User selects a report.
  // 2. Filter Mode: reportToPreload is provided. User filters an existing report.
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
      // In filter mode, we just set the local state.
      // The BLoC is already alive and correctly configured from ReportMainUI.
      _selectedReport = widget.reportToPreload;
      _reportLabelDisplayController.text = _selectedReport?['Report_label'] ?? 'Preloaded Report';
    } else {
      // In selection mode, we create a new BLoC.
      // This is wrapped in a BlocProvider later in the build method.
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
      // In selection mode, we now navigate to the PreSelectedReportLoader
      // to handle the initial data fetch cleanly.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreSelectedReportLoader(
            reportDefinition: _selectedReport!,
            apiService: ReportAPIService(), // Or however you get this
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
      style: GoogleFonts.poppins(fontSize: 16, color: readOnly ? Colors.grey[600] : Colors.black87),
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
            onClear?.call();
            onChanged?.call('');
          },
        )
            : null,
        filled: true,
        fillColor: readOnly ? Colors.grey[200] : Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[500]!, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[500]!, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
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

  @override
  Widget build(BuildContext context) {
    // If in selection mode, create a new BLoC.
    // If in filter mode, it will use the one provided by ReportMainUI.
    if (!_isPreloadedMode) {
      return BlocProvider(
        create: (context) => ReportBlocGenerate(ReportAPIService())..add(LoadReports()),
        child: _buildContent(context),
      );
    }
    // If in filter mode, just build the content.
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(title: _isPreloadedMode ? 'Filter Report' : 'Report Selection', onBackPress: () => Navigator.pop(context)),
      body: BlocListener<ReportBlocGenerate, ReportState>(
        listener: (context, state) {
          if (state.error != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); WidgetsBinding.instance.addPostFrameCallback((_) { context.read<ReportBlocGenerate>().emit(state.copyWith(error: null)); }); }
          if (state.successMessage != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.successMessage!), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); WidgetsBinding.instance.addPostFrameCallback((_) { context.read<ReportBlocGenerate>().emit(state.copyWith(successMessage: null)); }); }
        },
        child: BlocBuilder<ReportBlocGenerate, ReportState>(
          builder: (context, state) {
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
                onSelected: (selection) { final bloc = context.read<ReportBlocGenerate>(); bloc.add(ResetReports()); setState(() { _selectedReport = selection; _reportLabelDisplayController.text = selection['Report_label']; }); final actionsRaw = selection['actions_config']; List<Map<String, dynamic>> actionsConfig = []; if (actionsRaw is List) { actionsConfig = List.from(actionsRaw); } else if (actionsRaw is String && actionsRaw.isNotEmpty) { try { actionsConfig = List.from(jsonDecode(actionsRaw)); } catch (e) {} } final includePdfFooter = selection['pdf_footer_datetime'] == true; bloc.add(FetchApiDetails(selection['API_name'], actionsConfig, includePdfFooterDateTimeFromReportMetadata: includePdfFooter)); WidgetsBinding.instance.addPostFrameCallback((_) { bloc.add(FetchFieldConfigs(selection['RecNo'].toString(), selection['API_name'], selection['Report_label'], dynamicApiParams: bloc.state.userParameterValues)); }); },
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
                      Expanded(
                        child: Card(
                          color: Colors.white,
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                reportSelectionWidget,
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _buildButton(text: _isPreloadedMode ? 'Apply Filters' : 'Show', color: Colors.blueAccent, onPressed: _selectedReport != null ? () => _handlePrimaryAction(context, state) : null, icon: _isPreloadedMode ? Icons.check_circle_outline : Icons.visibility),
                                    if (!_isPreloadedMode) ...[
                                      const SizedBox(width: 12),
                                      _buildButton(text: 'Send to Client', color: Colors.purple, onPressed: _selectedReport != null && state.fieldConfigs.isNotEmpty ? () {} : null, icon: Icons.cloud_upload),
                                    ],
                                    const SizedBox(width: 12),
                                    _buildButton(text: 'Reset', color: Colors.redAccent, onPressed: () => _resetAllFields(context), icon: Icons.refresh),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                if (state.selectedApiParameters.isNotEmpty) ...[
                                  Text('Parameters', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 10),
                                  Expanded(
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