import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ReportUtils/Appbar.dart';
import '../ReportUtils/subtleloader.dart';
import 'ReportAPIService.dart';
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
  final TextEditingController _reportTypeController = TextEditingController();
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
  }

  @override
  void dispose() {
    _reportNameController.dispose();
    _reportLabelController.dispose();
    _apiController.dispose();
    _reportTypeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleConfigPanel() {
    setState(() {
      _showConfigPanel = true;
    });
    _animationController.forward();
  }

  void _returnToFieldSelection() {
    setState(() {
      _showConfigPanel = false;
    });
    _animationController.reset();
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
        body: BlocBuilder<ReportMakerBloc, ReportMakerState>(
          builder: (context, state) {
            _reportTypeController.text = state.reportType;
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
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _reportLabelController,
                                  label: 'Report Label',
                                  icon: Icons.label,
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
                                      return state.apis.where((api) => api
                                          .toLowerCase()
                                          .contains(textEditingValue.text.toLowerCase()));
                                    },
                                    onSelected: (String selection) {
                                      setState(() {
                                        _selectedApi = selection;
                                        _apiController.text = selection;
                                      });
                                      context.read<ReportMakerBloc>().add(FetchApiData(selection));
                                    },
                                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                      _apiController.text = controller.text;
                                      return _buildTextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        label: 'API Name',
                                        icon: Icons.api,
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
                              const SizedBox(width: 16),
                              Expanded(
                                child: SizedBox(
                                  width: 300,
                                  child: DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      labelText: 'Report Type',
                                      labelStyle: GoogleFonts.poppins(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
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
                                    value: state.reportType,
                                    items: ['Detailed', 'Summary']
                                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                                        .toList(),
                                    onChanged: (value) {
                                      context.read<ReportMakerBloc>().add(UpdateReportType(value!));
                                    },
                                    dropdownColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildButton(
                                text: 'Show',
                                color: Colors.blueAccent,
                                onPressed: _selectedApi != null
                                    ? () => context
                                    .read<ReportMakerBloc>()
                                    .add(FetchApiData(_selectedApi!))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              _buildButton(
                                text: 'Reset',
                                color: Colors.redAccent,
                                onPressed: () {
                                  _reportNameController.clear();
                                  _reportLabelController.clear();
                                  _apiController.clear();
                                  _reportTypeController.clear();
                                  setState(() {
                                    _selectedApi = null;
                                    _showConfigPanel = false;
                                    _apiController.text = '';
                                  });
                                  context.read<ReportMakerBloc>().add(ResetFields());
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
                      child: state.isLoading
                          ? const SubtleLoader()
                          : state.fields.isEmpty
                          ? const Center(child: Text('Select an API to load fields'))
                          : _showConfigPanel
                          ? FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildFieldConfigPanel(context, state),
                      )
                          : _buildFieldSelection(context, state),
                    ),
                  ),
                ],
              ),
            );
          },
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
  }) {
    return Focus(
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(isFocused ? 1.02 : 1.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(isFocused ? 0.4 : 0.2),
                  blurRadius: isFocused ? 10 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              onChanged: onChanged,
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                prefixIcon: icon != null
                    ? Icon(icon, color: Colors.blueAccent, size: 22)
                    : null,
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
            ),
          );
        },
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
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
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
                        context.read<ReportMakerBloc>().add(SelectField(field));
                      } else {
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

  Widget _buildFieldConfigPanel(BuildContext context, ReportMakerState state) {
    final sortedFields = List<Map<String, dynamic>>.from(state.selectedFields)
      ..sort((a, b) {
        final aSeq = a['Sequence_no'] as int? ?? 9999;
        final bSeq = b['Sequence_no'] as int? ?? 9999;
        return aSeq.compareTo(bSeq);
      });
    return Row(
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
                                context.read<ReportMakerBloc>().add(UpdateCurrentField(field));
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

                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.blueAccent, size: 24),
                  onPressed: _returnToFieldSelection,
                  tooltip: 'Add more fields',
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
                  children: [
                    _buildTextField(
                      controller: TextEditingController(
                          text: state.currentField!['Field_name']),
                      label: 'Field Name',
                      icon: Icons.text_fields,
                      onChanged: (value) {
                        context
                            .read<ReportMakerBloc>()
                            .add(UpdateFieldConfig('Field_name', value));
                      },
                    ),
                    const SizedBox(height: 30),
                    _buildTextField(
                      controller: TextEditingController(
                          text: state.currentField!['Field_label']),
                      label: 'Field Label',
                      icon: Icons.label_outline,
                      onChanged: (value) {
                        context
                            .read<ReportMakerBloc>()
                            .add(UpdateFieldConfig('Field_label', value));
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: TextEditingController(
                          text: state.currentField!['Sequence_no']?.toString() ?? ''),
                      label: 'Sequence No',
                      icon: Icons.sort,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (value.isEmpty || parsed == null || parsed <= 0) {
                          context
                              .read<ReportMakerBloc>()
                              .add(UpdateFieldConfig('Sequence_no', null));
                        } else {
                          context
                              .read<ReportMakerBloc>()
                              .add(UpdateFieldConfig('Sequence_no', parsed));
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: TextEditingController(
                          text: state.currentField!['width'].toString()),
                      label: 'Width',
                      icon: Icons.width_normal,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        context.read<ReportMakerBloc>().add(UpdateFieldConfig(
                            'width', int.tryParse(value) ?? 100));
                      },
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: Text('Total', style: GoogleFonts.poppins()),
                      value: state.currentField!['Total'],
                      activeColor: Colors.blueAccent,
                      onChanged: (value) {
                        context
                            .read<ReportMakerBloc>()
                            .add(UpdateFieldConfig('Total', value!));
                      },
                    ),
                    const Divider(
                      color: Colors.grey,
                      thickness: 2,
                      height: 32,
                    ),
                    if (state.reportType == 'Summary') ...[
                      CheckboxListTile(
                        title: Text('Group By', style: GoogleFonts.poppins()),
                        value: state.currentField!['Group_by'],
                        activeColor: Colors.blueAccent,
                        onChanged: (value) {
                          context
                              .read<ReportMakerBloc>()
                              .add(UpdateFieldConfig('Group_by', value!));
                        },
                      ),
                      if (state.currentField!['Group_by']) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 300,
                          child: _buildSelectAutocomplete(
                            label: 'Group By Fields',
                            selectedItems:
                            (state.currentField!['groupjson'] as String).isNotEmpty
                                ? (state.currentField!['groupjson'] as String)
                                .split(',')
                                : [],
                            items: state.fields,
                            isMultiSelect: true,
                            onChanged: (selected) {
                              context.read<ReportMakerBloc>().add(UpdateFieldConfig(
                                  'groupjson', selected.join(',')));
                            },
                          ),
                        ),
                      ],
                    ],
                    CheckboxListTile(
                      title: Text('Filter', style: GoogleFonts.poppins()),
                      value: state.currentField!['Filter'],
                      activeColor: Colors.blueAccent,
                      onChanged: (value) {
                        context
                            .read<ReportMakerBloc>()
                            .add(UpdateFieldConfig('Filter', value!));
                      },
                    ),
                    if (state.currentField!['Filter']) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 300,
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Filter Operator',
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
                          value: (state.currentField!['filterJson'] as String).isNotEmpty
                              ? (state.currentField!['filterJson'] as String).split(':').first
                              : '=',
                          items: ['=', '>', '<', '>=', '<=', '!=']
                              .map((op) => DropdownMenuItem(value: op, child: Text(op)))
                              .toList(),
                          onChanged: (value) {
                            final currentFilter = state.currentField!['filterJson'] as String;
                            final filterField = currentFilter.contains(':')
                                ? currentFilter.split(':').last
                                : '';
                            context.read<ReportMakerBloc>().add(UpdateFieldConfig(
                                'filterJson', '$value:$filterField'));
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 300,
                        child: _buildSelectAutocomplete(
                          label: 'Filter Field',
                          selectedItems:
                          (state.currentField!['filterJson'] as String).isNotEmpty &&
                              (state.currentField!['filterJson'] as String).contains(':')
                              ? [(state.currentField!['filterJson'] as String).split(':').last]
                              : [],
                          items: state.fields,
                          isMultiSelect: false,
                          onChanged: (selected) {
                            final currentFilter = state.currentField!['filterJson'] as String;
                            final operator = currentFilter.contains(':')
                                ? currentFilter.split(':').first
                                : '=';
                            context.read<ReportMakerBloc>().add(UpdateFieldConfig(
                                'filterJson', '$operator:${selected.isNotEmpty ? selected.first : ''}'));
                          },
                        ),
                      ),
                    ],
                    CheckboxListTile(
                      title: Text('Order By', style: GoogleFonts.poppins()),
                      value: state.currentField!['orderby'],
                      activeColor: Colors.blueAccent,
                      onChanged: (value) {
                        context
                            .read<ReportMakerBloc>()
                            .add(UpdateFieldConfig('orderby', value!));
                      },
                    ),
                    if (state.currentField!['orderby']) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 300,
                        child: _buildSelectAutocomplete(
                          label: 'Order By Fields',
                          selectedItems:
                          (state.currentField!['orderjson'] as String).isNotEmpty
                              ? (state.currentField!['orderjson'] as String).split(',')
                              : [],
                          items: state.fields,
                          isMultiSelect: true,
                          onChanged: (selected) {
                            context.read<ReportMakerBloc>().add(UpdateFieldConfig(
                                'orderjson', selected.join(',')));
                          },
                        ),
                      ),
                    ],
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
                      value: state.currentField!['num_alignment'],
                      items: ['left', 'center', 'right']
                          .map((align) => DropdownMenuItem(value: align, child: Text(align)))
                          .toList(),
                      onChanged: (value) {
                        context
                            .read<ReportMakerBloc>()
                            .add(UpdateFieldConfig('num_alignment', value!));
                      },
                      dropdownColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    if (state.currentField!['Field_name'].toString().endsWith('No')) ...[
                      _buildTextField(
                        controller: TextEditingController(
                            text: state.currentField!['decimal_points']?.toString() ?? ''),
                        label: 'Decimal Points',
                        icon: Icons.numbers,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          context.read<ReportMakerBloc>().add(UpdateFieldConfig(
                              'decimal_points', parsed != null && parsed >= 0 ? parsed : 0));
                        },
                      ),
                    ],
                    if (state.currentField!['Field_name'].toString().toLowerCase().contains('date')) ...[
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: Text('Time', style: GoogleFonts.poppins()),
                        value: state.currentField!['time'],
                        activeColor: Colors.blueAccent,
                        onChanged: (value) {
                          context
                              .read<ReportMakerBloc>()
                              .add(UpdateFieldConfig('time', value!));
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: Text('Number Format', style: GoogleFonts.poppins()),
                      value: state.currentField!['num_format'],
                      activeColor: Colors.blueAccent,
                      onChanged: (value) {
                        context
                            .read<ReportMakerBloc>()
                            .add(UpdateFieldConfig('num_format', value!));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectAutocomplete({
    required String label,
    required List<String> selectedItems,
    required List<String> items,
    required Function(List<String>) onChanged,
    required bool isMultiSelect,
  }) {
    final TextEditingController controller = TextEditingController();
    final List<String> localSelectedItems = List.from(selectedItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMultiSelect && localSelectedItems.isNotEmpty) ...[
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: localSelectedItems.map((item) {
              return Chip(
                label: Text(
                  item,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.blueAccent,
                  ),
                ),
                backgroundColor: Colors.blueAccent.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.blueAccent),
                ),
                deleteIcon: const Icon(Icons.cancel, size: 18, color: Colors.blueAccent),
                onDeleted: () {
                  final updatedItems = List<String>.from(localSelectedItems)..remove(item);
                  onChanged(updatedItems);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            return items
                .where((item) =>
            item.toLowerCase().contains(textEditingValue.text.toLowerCase()) &&
                (isMultiSelect ? !localSelectedItems.contains(item) : true))
                .toList();
          },
          onSelected: (String selection) {
            if (isMultiSelect) {
              final updatedItems = [...localSelectedItems, selection];
              onChanged(updatedItems);
              controller.clear();
            } else {
              onChanged([selection]);
              controller.text = selection;
            }
          },
          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
            if (!isMultiSelect) {
              textEditingController.text = localSelectedItems.isNotEmpty ? localSelectedItems.first : '';
            }
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
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
              onChanged: (value) {
                if (!isMultiSelect && value.isEmpty) {
                  onChanged([]);
                  controller.text = '';
                }
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
      ],
    );
  }
}