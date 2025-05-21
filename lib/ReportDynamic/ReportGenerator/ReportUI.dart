import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import 'ReportMainUI.dart';
import 'Reportbloc.dart';

class ReportUI extends StatefulWidget {
  const ReportUI({super.key});

  @override
  _ReportUIState createState() => _ReportUIState();
}

class _ReportUIState extends State<ReportUI> {
  final TextEditingController _reportLabelController = TextEditingController();
  Map<String, dynamic>? _selectedReport;
  final Map<String, TextEditingController> _paramControllers = {};

  @override
  void dispose() {
    _reportLabelController.dispose();
    _paramControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? label,
    FocusNode? focusNode,
    Function(String)? onChanged,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
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

  Widget _buildDateField({
    required String paramName,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: paramName,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
        prefixIcon: const Icon(Icons.calendar_today, color: Colors.blueAccent, size: 22),
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportBlocGenerate(ReportAPIService())..add(LoadReports()),
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Report Selection',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocListener<ReportBlocGenerate, ReportState>(
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          child: BlocBuilder<ReportBlocGenerate, ReportState>(
            builder: (context, state) {
              // Update parameter controllers based on selected API parameters
              if (state.selectedApiParameters.isNotEmpty) {
                for (var param in state.selectedApiParameters) {
                  if (param['show'] == true && !_paramControllers.containsKey(param['name'])) {
                    _paramControllers[param['name']] = TextEditingController(text: param['value'].toString());
                  }
                }
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Card(
                      color: Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              child: Autocomplete<Map<String, dynamic>>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<Map<String, dynamic>>.empty();
                                  }
                                  return state.reports.where((report) => report['Report_label']
                                      .toString()
                                      .toLowerCase()
                                      .contains(textEditingValue.text.toLowerCase()));
                                },
                                displayStringForOption: (Map<String, dynamic> option) => option['Report_label'],
                                onSelected: (Map<String, dynamic> selection) {
                                  setState(() {
                                    _selectedReport = selection;
                                    _reportLabelController.text = selection['Report_label'];
                                    _paramControllers.clear(); // Clear previous controllers
                                  });
                                  context.read<ReportBlocGenerate>().add(
                                    FetchApiDetails(selection['API_name']),
                                  );
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return _buildTextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    label: 'Report Label',
                                    icon: Icons.label,
                                    onChanged: (value) {
                                      print('Report Label input: $value');
                                    },
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4,
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: 300,
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          padding: const EdgeInsets.all(8),
                                          itemCount: options.length,
                                          itemBuilder: (context, index) {
                                            final option = options.elementAt(index);
                                            return ListTile(
                                              title: Text(
                                                option['Report_label'],
                                                style: GoogleFonts.poppins(fontSize: 14),
                                              ),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Display input fields for parameters with show: true
                            if (state.selectedApiParameters.isNotEmpty) ...[
                              Text(
                                'Parameters',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),
                              ...state.selectedApiParameters.where((param) => param['show'] == true).map((param) {
                                final paramName = param['name'];
                                final isDateField = paramName.toLowerCase().contains('date');
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: isDateField
                                      ? _buildDateField(
                                    paramName: paramName,
                                    controller: _paramControllers[paramName]!,
                                    onTap: () async {
                                      final initialDate = DateTime.tryParse(
                                        _paramControllers[paramName]!.text,
                                      ) ??
                                          DateTime.now();
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: initialDate,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (pickedDate != null) {
                                        final formattedDate = DateFormat('dd-MMM-yyyy').format(pickedDate);
                                        _paramControllers[paramName]!.text = formattedDate;
                                        context.read<ReportBlocGenerate>().add(
                                          UpdateParameter(paramName, formattedDate),
                                        );
                                      }
                                    },
                                  )
                                      : _buildTextField(
                                    controller: _paramControllers[paramName]!,
                                    label: paramName,
                                    icon: Icons.text_fields,
                                    onChanged: (value) {
                                      context.read<ReportBlocGenerate>().add(
                                        UpdateParameter(paramName, value),
                                      );
                                    },
                                  ),
                                );
                              }),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildButton(
                                  text: 'Show',
                                  color: Colors.blueAccent,
                                  onPressed: _selectedReport != null
                                      ? () async {
                                    final bloc = context.read<ReportBlocGenerate>();
                                    final recNo = _selectedReport!['RecNo'].toString();
                                    final apiName = _selectedReport!['API_name'].toString();
                                    final reportLabel = _selectedReport!['Report_label'].toString();
                                    print(
                                        'Navigating to ReportMainUI: recNo=$recNo, apiName=$apiName, reportLabel=$reportLabel');
                                    bloc.add(FetchFieldConfigs(recNo, apiName, reportLabel));
                                    // Wait for the state to update
                                    await bloc.stream.firstWhere((state) => !state.isLoading);
                                    if (context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BlocProvider.value(
                                            value: bloc,
                                            child: ReportMainUI(
                                              recNo: recNo,
                                              apiName: apiName,
                                              reportLabel: reportLabel,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                      : null,
                                  icon: Icons.visibility,
                                ),
                                const SizedBox(width: 12),
                                _buildButton(
                                  text: 'Reset',
                                  color: Colors.redAccent,
                                  onPressed: () {
                                    _reportLabelController.clear();
                                    _paramControllers.clear();
                                    setState(() {
                                      _selectedReport = null;
                                    });
                                    context.read<ReportBlocGenerate>().add(ResetReports());
                                  },
                                  icon: Icons.refresh,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: state.isLoading
                          ? const SubtleLoader()
                          : state.reports.isEmpty
                          ? const Center(child: Text('No reports available'))
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}