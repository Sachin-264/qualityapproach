import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import 'EditDetailMakerBloc.dart';
import '../ReportAPIService.dart';

class EditDetailMaker extends StatefulWidget {
  final int recNo;
  final String reportName;
  final String reportLabel;
  final String apiName;

  const EditDetailMaker({
    super.key,
    required this.recNo,
    required this.reportName,
    required this.reportLabel,
    required this.apiName,
  });

  @override
  _EditDetailMakerState createState() => _EditDetailMakerState();
}

class _EditDetailMakerState extends State<EditDetailMaker> with SingleTickerProviderStateMixin {
  final TextEditingController _reportNameController = TextEditingController();
  final TextEditingController _reportLabelController = TextEditingController();
  final TextEditingController _apiController = TextEditingController();
  final TextEditingController _fieldNameController = TextEditingController();
  final TextEditingController _fieldLabelController = TextEditingController();
  final TextEditingController _sequenceController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _decimalPointsController = TextEditingController();

  String? _selectedApi;
  bool _showConfigPanel = false;
  late EditDetailMakerBloc _bloc;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    print('EditDetailMaker initState: recNo=${widget.recNo}, apiName=${widget.apiName}');
    _reportNameController.text = widget.reportName;
    _reportLabelController.text = widget.reportLabel;
    _apiController.text = widget.apiName;
    _selectedApi = widget.apiName;
    print('Controllers initialized: reportName=${_reportNameController.text}, apiName=${_apiController.text}');

    _bloc = EditDetailMakerBloc(ReportAPIService());

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    for (var controller in [
      _reportNameController,
      _reportLabelController,
      _apiController,
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('Dispatching LoadPreselectedFields: recNo=${widget.recNo}, apiName=${widget.apiName}');
      _bloc.add(LoadPreselectedFields(widget.recNo, widget.apiName));
    });
  }

  @override
  void dispose() {
    print('EditDetailMaker dispose');
    _reportNameController.dispose();
    _reportLabelController.dispose();
    _apiController.dispose();
    _fieldNameController.dispose();
    _fieldLabelController.dispose();
    _sequenceController.dispose();
    _widthController.dispose();
    _decimalPointsController.dispose();
    _animationController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _toggleConfigPanel() {
    print('Toggling config panel: showConfigPanel=true');
    setState(() {
      _showConfigPanel = true;
    });
    _animationController.forward();
  }

  void _returnToFieldSelection() {
    print('Returning to field selection: showConfigPanel=false');
    setState(() {
      _showConfigPanel = false;
    });
    _animationController.reset();
  }

  void _updateFieldConfigControllers(Map<String, dynamic>? field) {
    print('Updating field config controllers: field=${field?['Field_name']}');
    if (field == null) {
      _fieldNameController.clear();
      _fieldLabelController.clear();
      _sequenceController.clear();
      _widthController.clear();
      _decimalPointsController.clear();
    } else {
      _fieldNameController.text = field['Field_name']?.toString() ?? '';
      _fieldLabelController.text = field['Field_label']?.toString() ?? '';
      _sequenceController.text = field['Sequence_no']?.toString() ?? '';
      _widthController.text = field['width']?.toString() ?? '';
      _decimalPointsController.text = field['decimal_points']?.toString() ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building EditDetailMaker UI');
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Edit Report Details',
          onBackPress: () {
            print('AppBar back pressed');
            Navigator.pop(context, true);
          },
        ),
        body: BlocListener<EditDetailMakerBloc, EditDetailMakerState>(
          listener: (context, state) {
            print('BlocListener: isLoading=${state.isLoading}, error=${state.error}, saveSuccess=${state.saveSuccess}, fields=${state.fields.length}, selectedFields=${state.selectedFields.length}, preselectedFields=${state.preselectedFields.length}');
            if (state.error != null) {
              print('Showing error SnackBar: ${state.error}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: Colors.redAccent,
                ),
              );
            } else if (state.saveSuccess) {
              print('Showing success SnackBar');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report and field configurations updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              print('Navigating back with refresh');
              Navigator.pop(context, true);
            }
            _updateFieldConfigControllers(state.currentField);
          },
          child: BlocBuilder<EditDetailMakerBloc, EditDetailMakerState>(
            builder: (context, state) {
              print('BlocBuilder: isLoading=${state.isLoading}, fields=${state.fields.length}, selectedFields=${state.selectedFields.length}, preselectedFields=${state.preselectedFields.length}');
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
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _reportNameController,
                                    label: 'Report Name',
                                    icon: Icons.description,
                                    onChanged: (value) {
                                      print('Report Name changed: $value');
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
                                      print('Report Label changed: $value');
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _apiController,
                                    label: 'API Name',
                                    icon: Icons.api,
                                    readOnly: true,
                                    onChanged: (value) {
                                      print('API Name changed: $value');
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildButton(
                                  text: 'Reset',
                                  color: Colors.redAccent,
                                  onPressed: () {
                                    print('Reset button pressed');
                                    context.read<EditDetailMakerBloc>().add(ResetFields());
                                    _reportNameController.text = widget.reportName;
                                    _reportLabelController.text = widget.reportLabel;
                                    _apiController.text = widget.apiName;
                                    setState(() {
                                      _selectedApi = widget.apiName;
                                      _showConfigPanel = false;
                                    });
                                    _animationController.reset();
                                  },
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
                        child: () {
                          print('Rendering field selection card: isLoading=${state.isLoading}, fields=${state.fields.length}, preselectedFields=${state.preselectedFields.length}');
                          if (state.isLoading) {
                            print('Showing SubtleLoader');
                            return const SubtleLoader();
                          }
                          if (state.error != null) {
                            print('Showing error state: ${state.error}');
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Error: ${state.error}',
                                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.redAccent),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildButton(
                                    text: 'Retry',
                                    color: Colors.blueAccent,
                                    onPressed: () {
                                      print('Retry button pressed');
                                      context.read<EditDetailMakerBloc>().add(
                                        LoadPreselectedFields(widget.recNo, widget.apiName),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          }
                          if (state.fields.isEmpty) {
                            print('Showing empty fields state');
                            return Center(
                              child: Text(
                                'No fields available.',
                                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                              ),
                            );
                          }
                          if (_showConfigPanel) {
                            print('Showing field config panel');
                            return FadeTransition(
                              opacity: _fadeAnimation,
                              child: _buildFieldConfigPanel(context, state),
                            );
                          }
                          print('Showing field selection');
                          return _buildFieldSelection(context, state);
                        }(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildButton(
                          text: 'Save',
                          color: Colors.green,
                          onPressed: () {
                            print('Save button pressed');
                            if (_reportNameController.text.isEmpty ||
                                _reportLabelController.text.isEmpty ||
                                _selectedApi == null ||
                                state.selectedFields.isEmpty) {
                              print('Validation failed: showing SnackBar');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill all fields and select at least one field.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }

                            if (_sequenceController.text.isNotEmpty) {
                              final parsed = int.tryParse(_sequenceController.text);
                              if (parsed != null && parsed > 0) {
                                print('Updating Sequence_no: $parsed');
                                context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Sequence_no', parsed));
                              }
                            }

                            print('Dispatching SaveReport event');
                            context.read<EditDetailMakerBloc>().add(SaveReport(
                              recNo: widget.recNo,
                              reportName: _reportNameController.text,
                              reportLabel: _reportLabelController.text,
                              apiName: _selectedApi!,
                              parameter: 'default',
                            ));
                          },
                          icon: Icons.save,
                        ),
                        const SizedBox(width: 12),
                        _buildButton(
                          text: 'Reset',
                          color: Colors.redAccent,
                          onPressed: () {
                            print('Reset button (bottom) pressed');
                            context.read<EditDetailMakerBloc>().add(ResetFields());
                            _reportNameController.text = widget.reportName;
                            _reportLabelController.text = widget.reportLabel;
                            _apiController.text = widget.apiName;
                            setState(() {
                              _selectedApi = widget.apiName;
                              _showConfigPanel = false;
                            });
                            _animationController.reset();
                          },
                          icon: Icons.refresh,
                        ),
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
    bool readOnly = false,
  }) {
    print('Building TextField: label=$label, readOnly=$readOnly');
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      onChanged: onChanged,
      readOnly: readOnly,
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

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    print('Building Button: text=$text');
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

  Widget _buildFieldSelection(BuildContext context, EditDetailMakerState state) {
    print('Building field selection: fields=${state.fields.length}, selectedFields=${state.selectedFields.length}, preselectedFields=${state.preselectedFields.length}');
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
                  final isPreselected = state.preselectedFields.any((f) => f['Field_name'] == field);
                  final isUserSelected = state.selectedFields.any((f) => f['Field_name'] == field) && !isPreselected;
                  print('Rendering chip: field=$field, isPreselected=$isPreselected, isUserSelected=$isUserSelected');
                  return FilterChip(
                    label: Text(
                      field,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isPreselected || isUserSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isPreselected || isUserSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isPreselected || isUserSelected,
                    selectedColor: isPreselected ? Colors.blueAccent : Colors.green,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isPreselected ? Colors.blueAccent : isUserSelected ? Colors.green : Colors.grey.shade300,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    onSelected: (selected) {
                      print('Chip selected: field=$field, selected=$selected');
                      if (selected) {
                        context.read<EditDetailMakerBloc>().add(SelectField(field));
                      } else {
                        context.read<EditDetailMakerBloc>().add(DeselectField(field));
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
                text: 'Next',
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

  Widget _buildFieldConfigPanel(BuildContext context, EditDetailMakerState state) {
    print('Building field config panel: selectedFields=${state.selectedFields.length}');
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
                          print('Rendering config field: ${field['Field_name']}, isSelected=$isSelected');
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
                                      print('Field tapped: ${field['Field_name']}');
                                      if (_sequenceController.text.isNotEmpty) {
                                        final parsed = int.tryParse(_sequenceController.text);
                                        if (parsed != null && parsed > 0) {
                                          print('Updating Sequence_no: $parsed');
                                          context.read<EditDetailMakerBloc>().add(
                                            UpdateFieldConfig('Sequence_no', parsed),
                                          );
                                        }
                                      }
                                      context.read<EditDetailMakerBloc>().add(UpdateCurrentField(field));
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: isSelected ? Colors.blueAccent : Colors.grey.shade300,
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
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isSelected ? Colors.blueAccent : Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                            onPressed: () {
                                              print('Delete field: ${field['Field_name']}');
                                              context.read<EditDetailMakerBloc>().add(DeselectField(field['Field_name']));
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
                            const Icon(Icons.add, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Add Field',
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
                      'Select a field to configure',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
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

  List<Widget> _buildFieldConfigWidgets(BuildContext context, EditDetailMakerState state) {
    print('Building field config widgets for: ${state.currentField!['Field_name']}');
    return [
      _buildTextField(
        controller: _fieldNameController,
        label: 'Field Name',
        icon: Icons.text_fields,
        readOnly: true,
        onChanged: (value) {
          print('Field Name changed: $value');
          context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Field_name', value));
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _fieldLabelController,
        label: 'Field Label',
        icon: Icons.label_outline,
        onChanged: (value) {
          print('Field Label changed: $value');
          context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Field_label', value));
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _sequenceController,
        label: 'Sequence No',
        icon: Icons.sort,
        keyboardType: TextInputType.number,
        onChanged: (value) {
          print('Sequence No changed: $value');
          final parsed = int.tryParse(value);
          if (parsed != null && parsed > 0) {
            context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Sequence_no', parsed));
            setState(() {
              _sequenceController.text = parsed.toString();
              _sequenceController.selection = TextSelection.fromPosition(
                TextPosition(offset: _sequenceController.text.length),
              );
            });
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
          print('Width changed: $value');
          final parsed = int.tryParse(value);
          context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('width', parsed));
        },
      ),
      const SizedBox(height: 16),
      CheckboxListTile(
        title: Text('Total', style: GoogleFonts.poppins()),
        value: state.currentField!['Total'] ?? false,
        activeColor: Colors.blueAccent,
        onChanged: (value) {
          print('Total checkbox changed: $value');
          context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Total', value!));
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
        value: state.currentField!['num_alignment']?.toString().toLowerCase() ?? 'left',
        items: [
          DropdownMenuItem(value: 'left', child: Text('Left', style: GoogleFonts.poppins())),
          DropdownMenuItem(value: 'center', child: Text('Center', style: GoogleFonts.poppins())),
          DropdownMenuItem(value: 'right', child: Text('Right', style: GoogleFonts.poppins())),
        ],
        onChanged: (value) {
          print('Number Alignment changed: $value');
          context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('num_alignment', value!));
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
          print('Indian Number Format changed: $value');
          context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('num_format', value!));
        },
      ),
      if (state.currentField!['Field_name'].toString().endsWith('No')) ...[
        const SizedBox(height: 16),
        _buildTextField(
          controller: _decimalPointsController,
          label: 'Decimal Points',
          icon: Icons.numbers,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            print('Decimal Points changed: $value');
            final parsed = int.tryParse(value);
            context.read<EditDetailMakerBloc>().add(UpdateFieldConfig(
                'decimal_points', parsed != null && parsed >= 0 ? parsed : 0));
          },
        ),
      ],
      if (state.currentField!['Field_name'].toString().toLowerCase().contains('date')) ...[
        const SizedBox(height: 16),
        CheckboxListTile(
          title: Text('Time', style: GoogleFonts.poppins()),
          value: state.currentField!['time'] ?? false,
          activeColor: Colors.blueAccent,
          onChanged: (value) {
            print('Time checkbox changed: $value');
            context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('time', value!));
          },
        ),
      ],
    ];
  }
}