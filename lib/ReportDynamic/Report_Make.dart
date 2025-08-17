import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ReportUtils/Appbar.dart';
import '../ReportUtils/subtleloader.dart';
import 'ReportAPIService.dart';
import 'ReportMakeEdit/EditReportMaker.dart';
import 'Report_MakeBLoc.dart';


class ReportMakerUI extends StatefulWidget {
  const ReportMakerUI({super.key});

  @override
  _ReportMakerUIState createState() => _ReportMakerUIState();
}

class _ReportMakerUIState extends State<ReportMakerUI> with SingleTickerProviderStateMixin {
  final TextEditingController _reportNameController = TextEditingController();
  final TextEditingController _reportLabelController = TextEditingController();
  final TextEditingController _apiController = TextEditingController();
  // NEW: Controller for the unique code
  final TextEditingController _ucodeController = TextEditingController();


  // Controllers for field config panel
  final TextEditingController _fieldNameController = TextEditingController();
  final TextEditingController _fieldLabelController = TextEditingController();
  final TextEditingController _sequenceController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _decimalPointsController = TextEditingController();

  String? _selectedApi;
  bool _showConfigPanel = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Add listeners to maintain cursor position
    for (var controller in [
      _reportNameController,
      _reportLabelController,
      _apiController,
      _ucodeController, // Added new controller
      _fieldNameController,
      _fieldLabelController,
      _sequenceController,
      _widthController,
      _decimalPointsController
    ]) {
      controller.addListener(() {
        if (controller.text.isNotEmpty && controller.selection.baseOffset < controller.text.length) {
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _reportNameController.dispose();
    _reportLabelController.dispose();
    _apiController.dispose();
    _ucodeController.dispose(); // Disposing the new controller
    _fieldNameController.dispose();
    _fieldLabelController.dispose();
    _sequenceController.dispose();
    _widthController.dispose();
    _decimalPointsController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _generateUniqueCode(String reportName) {
    if (reportName.trim().isEmpty) {
      _ucodeController.clear();
      return;
    }
    // Create a URL-friendly, lowercase version of the report name
    final sanitizedName = reportName
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscores
        .replaceAll(RegExp(r'[^a-z0-9_]'), ''); // Remove non-alphanumeric characters except underscore

    // Get current timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Combine them to create a unique code
    setState(() {
      _ucodeController.text = '${sanitizedName}_$timestamp';
    });
    print('UI: Generated Unique Code: ${_ucodeController.text}');
  }


  void _toggleConfigPanel() {
    print('UI: Toggling config panel to show.');
    setState(() {
      _showConfigPanel = true;
    });
    _animationController.forward();
  }

  void _returnToFieldSelection() {
    print('UI: Returning to field selection.');
    setState(() {
      _showConfigPanel = false;
    });
    _animationController.reverse(from: 1.0); // Animate fade out
  }

  void _updateFieldConfigControllers(Map<String, dynamic>? field) {
    if (field == null) {
      if (_fieldNameController.text.isNotEmpty || _fieldLabelController.text.isNotEmpty) {
        _fieldNameController.clear();
        _fieldLabelController.clear();
        _sequenceController.clear();
        _widthController.clear();
        _decimalPointsController.clear();
        print('UI: Cleared field config controllers (field is null).');
      }
    } else {
      if (_fieldNameController.text != (field['Field_name'] ?? '')) {
        _fieldNameController.text = field['Field_name'] ?? '';
      }
      if (_fieldLabelController.text != (field['Field_label'] ?? '')) {
        _fieldLabelController.text = field['Field_label'] ?? '';
      }
      if (_sequenceController.text != (field['Sequence_no']?.toString() ?? '')) {
        _sequenceController.text = field['Sequence_no']?.toString() ?? '';
      }
      if (_widthController.text != (field['width']?.toString() ?? '')) {
        _widthController.text = field['width']?.toString() ?? '';
      }
      if (_decimalPointsController.text != (field['decimal_points']?.toString() ?? '')) {
        _decimalPointsController.text = field['decimal_points']?.toString() ?? '';
      }
      print('UI: Updated field config controllers for ${field['Field_name']}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportMakerBloc(ReportAPIService())..add(LoadApis()),
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Report Maker',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocListener<ReportMakerBloc, ReportMakerState>(
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
              print('UI: Error: ${state.error}');
            } else if (state.saveSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Report and field configurations saved successfully!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: Duration(seconds: 5),
                ),
              );
              _reportNameController.clear();
              _reportLabelController.clear();
              _apiController.clear();
              _ucodeController.clear(); // Clear the new field
              setState(() {
                _selectedApi = null;
                _showConfigPanel = false;
                _apiController.text = ''; // Ensure controller text is clear
              });
              context.read<ReportMakerBloc>().add(ResetFields());
              _animationController.reset(); // Reset animation for next use
              print('UI: Report saved successfully. Fields cleared.');
            }
            // Always update field config controllers when currentField in state changes
            _updateFieldConfigControllers(state.currentField);
          },
          child: BlocBuilder<ReportMakerBloc, ReportMakerState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildButton(
                          text: 'Edit Reports',
                          color: Colors.purpleAccent,
                          onPressed: () {
                            print('UI: Navigating to Edit Reports.');
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const EditReportMaker()),
                            );
                          },
                          icon: Icons.edit,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _reportNameController,
                                    label: 'Report Name',
                                    icon: Icons.description,
                                    onChanged: (value) {
                                      print('UI: Report Name input: $value');
                                      _generateUniqueCode(value); // Auto-generate code
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _reportLabelController,
                                    label: 'Report Label',
                                    icon: Icons.label,
                                    onChanged: (value) {
                                      print('UI: Report Label input: $value');
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    width: 300,
                                    child: Autocomplete<String>(
                                      optionsBuilder: (TextEditingValue textEditingValue) {
                                        if (textEditingValue.text.isEmpty) {
                                          return const Iterable<String>.empty();
                                        }
                                        return state.apis.where((api) => api
                                            .toLowerCase()
                                            .contains(textEditingValue.text.toLowerCase()));
                                      },
                                      onSelected: (String selection) {
                                        setState(() {
                                          _selectedApi = selection;
                                          _apiController.text = selection;
                                          _apiController.selection = TextSelection.fromPosition(
                                            TextPosition(offset: _apiController.text.length),
                                          );
                                        });
                                        context.read<ReportMakerBloc>().add(FetchApiData(selection));
                                        print('UI: API selected: $selection');
                                      },
                                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                        if (controller.text.isEmpty && _apiController.text.isNotEmpty) {
                                          controller.text = _apiController.text;
                                        } else if (controller.text != _apiController.text && controller.text.isNotEmpty) {
                                          _apiController.text = controller.text;
                                        }
                                        return _buildTextField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          label: 'API Name',
                                          icon: Icons.api,
                                          onChanged: (value) {
                                            _apiController.text = value;
                                            print('UI: API Name input: $value');
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
                                                      option,
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
                                ),
                                // NEW: Unique Code Text Field
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _ucodeController,
                                    label: 'Unique Code',
                                    icon: Icons.vpn_key,
                                    readOnly: true, // This field is not user-editable
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildButton(
                                  text: 'Show Fields',
                                  color: Colors.blueAccent,
                                  onPressed: _selectedApi != null
                                      ? () {
                                    print('UI: "Show Fields" button pressed for API: $_selectedApi');
                                    context.read<ReportMakerBloc>().add(FetchApiData(_selectedApi!));
                                  }
                                      : null,
                                  icon: Icons.data_array,
                                ),
                                const SizedBox(width: 12),
                                _buildButton(
                                  text: 'Reset All',
                                  color: Colors.redAccent,
                                  onPressed: () {
                                    _reportNameController.clear();
                                    _reportLabelController.clear();
                                    _apiController.clear();
                                    _ucodeController.clear(); // Clear the new field
                                    setState(() {
                                      _selectedApi = null;
                                      _showConfigPanel = false;
                                    });
                                    context.read<ReportMakerBloc>().add(ResetFields());
                                    _animationController.reset();
                                    print('UI: "Reset All" button pressed. Form cleared.');
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
                      child: Card(
                        color: Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: state.isLoading
                            ? const SubtleLoader()
                            : state.fields.isEmpty && _selectedApi != null
                            ? Center(
                          child: Text(
                            'No fields found for the selected API or API data is empty.',
                            style: GoogleFonts.poppins(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        )
                            : state.fields.isEmpty && _selectedApi == null
                            ? Center(
                          child: Text(
                            'Select an API to load fields.',
                            style: GoogleFonts.poppins(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        )
                            : _showConfigPanel
                            ? FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildFieldConfigPanel(context, state),
                        )
                            : _buildFieldSelection(context, state),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildButton(
                          text: 'Save Report',
                          color: Colors.green,
                          onPressed: () {
                            if (_reportNameController.text.isEmpty ||
                                _reportLabelController.text.isEmpty ||
                                _ucodeController.text.isEmpty || // Added validation for ucode
                                _selectedApi == null ||
                                state.selectedFields.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please fill all report details and select at least one field.'),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              print('UI: Save validation failed.');
                              return;
                            }

                            if (state.currentField != null && _sequenceController.text.isNotEmpty) {
                              final parsed = int.tryParse(_sequenceController.text);
                              if (parsed != null && parsed > 0 && (state.currentField!['Sequence_no'] != parsed)) {
                                print('UI: Final Sequence_no update before save for current field.');
                                context.read<ReportMakerBloc>().add(UpdateFieldConfig('Sequence_no', parsed));
                              }
                            }

                            print('UI: Attempting to save report.');
                            context.read<ReportMakerBloc>().add(SaveReport(
                              reportName: _reportNameController.text,
                              reportLabel: _reportLabelController.text,
                              apiName: _selectedApi!,
                              ucode: _ucodeController.text, // Pass the ucode
                              parameter: 'default',
                            ));
                          },
                          icon: Icons.save,
                        ),
                        const SizedBox(width: 12),
                      ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    String? label,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    IconData? icon,
    bool readOnly = false, // Added readOnly parameter
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      onChanged: onChanged,
      readOnly: readOnly, // Use the parameter here
      style: GoogleFonts.poppins(fontSize: 16, color: readOnly ? Colors.black54 : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22) : null,
        filled: true,
        fillColor: readOnly ? Colors.grey.shade200 : Colors.white.withOpacity(0.9), // Different color when read-only
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

  Widget _buildFieldSelection(BuildContext context, ReportMakerState state) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Fields',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: state.fields.map((field) {
                  final isSelected = state.selectedFields.any((f) => f['Field_name'] == field);
                  return FilterChip(
                    label: Text(
                      field,
                      style: GoogleFonts.poppins(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? Colors.blueAccent : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.blueAccent.withOpacity(0.15),
                    checkmarkColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    onSelected: (selected) {
                      if (selected) {
                        print('UI: Selecting field: $field');
                        context.read<ReportMakerBloc>().add(SelectField(field));
                      } else {
                        print('UI: Deselecting field: $field');
                        context.read<ReportMakerBloc>().add(DeselectField(field));
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          if (state.selectedFields.isNotEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: _buildButton(
                text: 'Configure Selected Fields',
                color: Colors.blueAccent,
                onPressed: _toggleConfigPanel,
                icon: Icons.arrow_forward,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldConfigPanel(BuildContext context, ReportMakerState state) {
    final sortedFields = List<Map<String, dynamic>>.from(state.selectedFields)
      ..sort((a, b) {
        final aSeq = a['Sequence_no'] as int? ?? 9999;
        final bSeq = b['Sequence_no'] as int? ?? 9999;
        return aSeq.compareTo(bSeq);
      });

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: sortedFields.length,
                        itemBuilder: (context, index) {
                          final field = sortedFields[index];
                          final isSelected = state.currentField?['Field_name'] == field['Field_name'];
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: Material(
                                  color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      if (_sequenceController.text.isNotEmpty) {
                                        final parsed = int.tryParse(_sequenceController.text);
                                        if (parsed != null && parsed > 0 && (state.currentField!['Sequence_no'] != parsed)) {
                                          context.read<ReportMakerBloc>().add(
                                            UpdateFieldConfig('Sequence_no', parsed),
                                          );
                                          print('UI: Updating sequence for previous field before switching.');
                                        }
                                      }
                                      context.read<ReportMakerBloc>().add(UpdateCurrentField(field));
                                      print('UI: Switched current field to: ${field['Field_name']}');
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: isSelected
                                                ? Colors.blueAccent
                                                : Colors.grey.shade300,
                                            child: Text(
                                              '${field['Sequence_no'] ?? 'N/A'}',
                                              style: GoogleFonts.poppins(
                                                color: isSelected ? Colors.white : Colors.black87,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              field['Field_name'],
                                              style: GoogleFonts.poppins(
                                                fontSize: 15,
                                                fontWeight:
                                                isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isSelected ? Colors.blueAccent : Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                            onPressed: () {
                                              print('UI: Deleting field from list: ${field['Field_name']}');
                                              context.read<ReportMakerBloc>().add(DeselectField(field['Field_name']));
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (index < sortedFields.length - 1)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Colors.grey.shade300,
                                  indent: 24,
                                  endIndent: 24,
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: ElevatedButton(
                        onPressed: _returnToFieldSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          elevation: 4,
                          shadowColor: Colors.blueAccent.withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Back to Selection',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                color: Colors.grey.shade300,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: state.currentField == null
                      ? Center(
                    child: Text(
                      'Select a field from the left panel to configure its properties.',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  )
                      : ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 600),
                    child: SingleChildScrollView(
                      child: ListView(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        children: _buildFieldConfigWidgets(context, state),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFieldConfigWidgets(BuildContext context, ReportMakerState state) {
    if (state.currentField == null) {
      return [];
    }
    return [
      _buildTextField(
        controller: _fieldNameController,
        label: 'Field Name',
        icon: Icons.text_fields,
        onChanged: (value) {
          print('UI: Field Name changed to: $value');
          context.read<ReportMakerBloc>().add(UpdateFieldConfig('Field_name', value));
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _fieldLabelController,
        label: 'Field Label',
        icon: Icons.label_outline,
        onChanged: (value) {
          print('UI: Field Label changed to: $value');
          context.read<ReportMakerBloc>().add(UpdateFieldConfig('Field_label', value));
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _sequenceController,
        label: 'Sequence No',
        icon: Icons.sort,
        keyboardType: TextInputType.number,
        onChanged: (value) {
          final parsed = int.tryParse(value);
          if (parsed != null && parsed > 0) {
            print('UI: Sequence No changed to: $parsed');
            context.read<ReportMakerBloc>().add(UpdateFieldConfig('Sequence_no', parsed));
            _sequenceController.text = parsed.toString();
            _sequenceController.selection = TextSelection.fromPosition(
              TextPosition(offset: _sequenceController.text.length),
            );
          } else {
            print('UI: Invalid Sequence No input: $value');
          }
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _widthController,
        label: 'Width',
        icon: Icons.width_normal,
        keyboardType: TextInputType.number,
        onChanged: (value) {
          final parsed = int.tryParse(value);
          print('UI: Width changed to: $parsed');
          context.read<ReportMakerBloc>().add(UpdateFieldConfig('width', parsed));
        },
      ),
      const SizedBox(height: 16),
      CheckboxListTile(
        title: Text('Total', style: GoogleFonts.poppins()),
        value: state.currentField!['Total'] ?? false,
        activeColor: Colors.blueAccent,
        onChanged: (value) {
          print('UI: Total changed to: $value');
          context.read<ReportMakerBloc>().add(UpdateFieldConfig('Total', value!));
        },
      ),
      const SizedBox(height: 16),
      CheckboxListTile(
        title: Text('Breakpoint', style: GoogleFonts.poppins()),
        value: state.currentField!['Breakpoint'] ?? false,
        activeColor: Colors.blueAccent,
        onChanged: (value) {
          print('UI: Breakpoint changed to: $value');
          context.read<ReportMakerBloc>().add(UpdateFieldConfig('Breakpoint', value!));
        },
      ),
      if (state.currentField!['Total'] == true) ...[
        const SizedBox(height: 16),
        CheckboxListTile(
          title: Text('Subtotal', style: GoogleFonts.poppins()),
          value: state.currentField!['SubTotal'] ?? false,
          activeColor: Colors.blueAccent,
          onChanged: (value) {
            print('UI: Subtotal changed to: $value');
            context.read<ReportMakerBloc>().add(UpdateFieldConfig('SubTotal', value!));
          },
        ),
      ],
      const SizedBox(height: 16),
      CheckboxListTile(
        title: Text('Image', style: GoogleFonts.poppins()),
        value: state.currentField!['image'] ?? false,
        activeColor: Colors.blueAccent,
        onChanged: (value) {
          print('UI: Image checkbox changed to: $value');
          context.read<ReportMakerBloc>().add(UpdateFieldConfig('image', value!));
        },
      ),
      const Divider(
        color: Colors.grey,
        thickness: 2,
        height: 32,
      ),
      DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Number Alignment',
          labelStyle: GoogleFonts.poppins(),
          filled: true,
          fillColor: Colors.white,
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
        ),
        style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
        value: state.currentField!['num_alignment'] ?? 'left',
        items: ['left', 'center', 'right']
            .map((align) => DropdownMenuItem(value: align, child: Text(align)))
            .toList(),
        onChanged: (value) {
          print('UI: Number Alignment changed to: $value');
          context.read<ReportMakerBloc>().add(UpdateFieldConfig('num_alignment', value!));
        },
        dropdownColor: Colors.white,
      ),
      const SizedBox(height: 16),
      CheckboxListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Indian Number Format', style: GoogleFonts.poppins()),
            Text(
              'Example: 1234555 becomes 12,34,555',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        value: state.currentField!['num_format'] ?? false,
        activeColor: Colors.blueAccent,
        onChanged: (value) {
          print('UI: Indian Number Format changed to: $value');
          context.read<ReportMakerBloc>().add(UpdateFieldConfig('num_format', value!));
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _decimalPointsController,
        label: 'Decimal Points',
        icon: Icons.numbers,
        keyboardType: TextInputType.number,
        onChanged: (value) {
          final parsed = int.tryParse(value);
          print('UI: Decimal Points changed to: $parsed');
          context.read<ReportMakerBloc>().add(UpdateFieldConfig(
              'decimal_points', parsed != null && parsed >= 0 ? parsed : 0));
        },
      ),
      if (state.currentField!['Field_name'].toString().toLowerCase().contains('date')) ...[
        const SizedBox(height: 16),
        CheckboxListTile(
          title: Text('Time', style: GoogleFonts.poppins()),
          value: state.currentField!['time'] ?? false,
          activeColor: Colors.blueAccent,
          onChanged: (value) {
            print('UI: Time changed to: $value');
            context.read<ReportMakerBloc>().add(UpdateFieldConfig('time', value!));
          },
        ),
      ],
    ];
  }
}