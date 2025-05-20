import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ReportUtils/Appbar.dart';
import '../ReportUtils/subtleloader.dart';
import 'dynamic_detail_bloc.dart';

class DynamicDetail extends StatefulWidget {
  final String recNo;

  const DynamicDetail({super.key, required this.recNo});

  @override
  _DynamicDetailState createState() => _DynamicDetailState();
}

class _DynamicDetailState extends State<DynamicDetail> {
  final _formKey = GlobalKey<FormState>();
  Map<String, TextEditingController> controllers = {};
  int? editingIndex;

  @override
  void dispose() {
    controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = AppBar().preferredSize.height + MediaQuery.of(context).padding.top;
    final availableHeight = screenHeight - appBarHeight - 16; // Subtract padding

    return BlocProvider(
      create: (context) => DynamicDetailBloc()..add(FetchFormFields(widget.recNo)),
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBarWidget(
          title: 'Purchase Request Form',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocBuilder<DynamicDetailBloc, DynamicDetailState>(
          builder: (context, state) {
            if (state is DynamicDetailLoading) {
              return const Center(child: SubtleLoader());
            } else if (state is DynamicDetailLoaded) {
              final sortedFields = List<Map<String, dynamic>>.from(state.fields)
                ..sort((a, b) => int.parse(a['SequenceNo']).compareTo(int.parse(b['SequenceNo'])));

              final generalFields = sortedFields
                  .takeWhile((field) => field['MultiLine'] == 'N')
                  .toList();
              final itemFields = sortedFields
                  .skipWhile((field) => field['MultiLine'] == 'N')
                  .takeWhile((field) => field['MultiLine'] == 'Y')
                  .toList();
              final otherFields = sortedFields
                  .skipWhile((field) => field['MultiLine'] == 'N')
                  .skipWhile((field) => field['MultiLine'] == 'Y')
                  .where((field) => field['MultiLine'] == 'N')
                  .toList();

              controllers = {
                for (var field in sortedFields)
                  field['Label'] ?? '': controllers[field['Label']] ?? TextEditingController()
              };

              return SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (generalFields.isNotEmpty)
                      _buildSection(
                        context,
                        'General Details',
                        generalFields,
                        state.autocompleteOptions,
                        state.formData,
                        height: availableHeight * 0.40, // 40% of available height
                      ),
                    if (itemFields.isNotEmpty)
                      _buildItemSection(
                        context,
                        'Item Details',
                        itemFields,
                        state.autocompleteOptions,
                        state.tableData,
                        height: availableHeight * 0.50, // 50% of available height
                      ),
                    if (otherFields.isNotEmpty)
                      _buildSection(
                        context,
                        'Other Details',
                        otherFields,
                        state.autocompleteOptions,
                        state.formData,
                        height: availableHeight * 0.10, // 10% of available height
                      ),
                    const SizedBox(height: 8),
                    _buildFormButtons(context, state),
                  ],
                ),
              );
            } else if (state is DynamicDetailError) {
              return Center(
                child: Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade400, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          state.message,
                          style: GoogleFonts.poppins(
                            color: Colors.red.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                          label: Text('Retry', style: GoogleFonts.poppins(fontSize: 12)),
                          onPressed: () => context.read<DynamicDetailBloc>().add(FetchFormFields(widget.recNo)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildSection(
      BuildContext context,
      String title,
      List<Map<String, dynamic>> fields,
      Map<String, List<String>> autocompleteOptions,
      Map<String, String> formData, {
        required double height,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSingleColumn = screenWidth < 600;

    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(title),
            SizedBox(
              height: height, // Apply specified height
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(
                    (fields.length / 2).ceil(),
                        (index) {
                      final startIndex = index * 2;
                      final field1 = startIndex < fields.length ? fields[startIndex] : null;
                      final field2 = startIndex + 1 < fields.length ? fields[startIndex + 1] : null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            if (field1 != null)
                              Expanded(
                                child: _buildFormField(
                                  context,
                                  field1,
                                  autocompleteOptions,
                                  formData: formData,
                                ),
                              ),
                            if (field2 != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildFormField(
                                  context,
                                  field2,
                                  autocompleteOptions,
                                  formData: formData,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemSection(
      BuildContext context,
      String title,
      List<Map<String, dynamic>> fields,
      Map<String, List<String>> autocompleteOptions,
      List<Map<String, String>> tableData, {
        required double height,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(title),
            SizedBox(
              height: height, // Apply specified height
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...fields.map((field) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: _buildFormField(context, field, autocompleteOptions, isTableForm: true),
                            )),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: Icon(
                                    editingIndex == null ? Icons.add : Icons.edit,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    editingIndex == null ? 'Add Item' : 'Update Item',
                                    style: GoogleFonts.poppins(fontSize: 11),
                                  ),
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      final rowData = <String, String>{};
                                      for (var field in fields) {
                                        final label = field['Label'] ?? '';
                                        rowData[label] = controllers[label]!.text;
                                      }
                                      if (editingIndex == null) {
                                        context.read<DynamicDetailBloc>().add(AddTableRow(rowData));
                                      } else {
                                        context.read<DynamicDetailBloc>().add(EditTableRow(editingIndex!, rowData));
                                        setState(() => editingIndex = null);
                                      }
                                      _formKey.currentState!.reset();
                                      controllers.forEach((key, controller) {
                                        if (fields.any((field) => field['Label'] == key)) {
                                          controller.clear();
                                        }
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.cancel, size: 14, color: Colors.white),
                                  label: Text('Cancel Item', style: GoogleFonts.poppins(fontSize: 11)),
                                  onPressed: () {
                                    _formKey.currentState!.reset();
                                    controllers.forEach((key, controller) {
                                      if (fields.any((field) => field['Label'] == key)) {
                                        controller.clear();
                                      }
                                    });
                                    setState(() => editingIndex = null);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Item List',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          tableData.isEmpty
                              ? Center(
                            child: Text(
                              'No items added',
                              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          )
                              : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 12,
                              dataRowHeight: 40,
                              headingRowHeight: 40,
                              headingRowColor: WidgetStatePropertyAll(Colors.blue.shade50),
                              columns: [
                                DataColumn(
                                  label: Text('S.No', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                                ),
                                DataColumn(
                                  label: Text('Item Name', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                                ),
                                DataColumn(
                                  label: Text('Actions', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                                ),
                              ],
                              rows: tableData.asMap().entries.map((entry) {
                                final index = entry.key;
                                final row = entry.value;
                                return DataRow(
                                  color: WidgetStatePropertyAll(index % 2 == 0 ? Colors.white : Colors.grey.shade50),
                                  cells: [
                                    DataCell(Text('${index + 1}', style: GoogleFonts.poppins(fontSize: 12))),
                                    DataCell(Text(row['ITEM NAME'] ?? '', style: GoogleFonts.poppins(fontSize: 12))),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit, color: Colors.blue.shade700, size: 16),
                                          onPressed: () {
                                            setState(() {
                                              editingIndex = index;
                                              fields.forEach((field) {
                                                final label = field['Label'] ?? '';
                                                controllers[label]!.text = row[label] ?? '';
                                              });
                                            });
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete, color: Colors.red.shade400, size: 16),
                                          onPressed: () {
                                            context.read<DynamicDetailBloc>().add(DeleteTableRow(index));
                                          },
                                        ),
                                      ],
                                    )),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormButtons(BuildContext context, DynamicDetailLoaded state) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.save, size: 14, color: Colors.white),
                label: Text('Save', style: GoogleFonts.poppins(fontSize: 11)),
                onPressed: () {
                  final formData = <String, String>{};
                  for (var field in state.fields.where((f) => f['MultiLine'] != 'Y')) {
                    final label = field['Label'] ?? '';
                    formData[label] = controllers[label]?.text ?? '';
                  }
                  context.read<DynamicDetailBloc>().add(SaveForm(formData, state.tableData));
                },
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.refresh, size: 14, color: Colors.white),
                label: Text('Reset', style: GoogleFonts.poppins(fontSize: 11)),
                onPressed: () {
                  controllers.forEach((_, controller) => controller.clear());
                  _formKey.currentState?.reset();
                  context.read<DynamicDetailBloc>().add(ResetForm());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(Icons.category, color: Colors.blue.shade700, size: 16),
          const SizedBox(width: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: Divider(thickness: 1, color: Colors.blue.shade100)),
        ],
      ),
    );
  }

  Widget _buildFormField(
      BuildContext context,
      Map<String, dynamic> field,
      Map<String, List<String>> autocompleteOptions, {
        bool isTableForm = false,
        Map<String, String> formData = const {},
      }) {
    final label = field['Label'] ?? '';
    final fieldName = field['FieldName'] ?? '';
    final isFromMaster = field['FromMaster'] == 'YES';
    final masterField = field['MasterField'] ?? '';
    final isDateField = fieldName.toUpperCase().contains('DATE') || label.toUpperCase().contains('DATE');
    final isRemarks = fieldName.toUpperCase().contains('REMARKS') || label.toUpperCase().contains('REMARKS');
    final isAutocomplete = masterField.isNotEmpty &&
        [
          'BRACHNAME',
          'ITEMNAME',
          'OURITEMNO',
          'BRANDNAME',
          'POTYPE',
          'DEPTNAME',
          'PRNAME',
          'COSTCENTERNAME',
          'SUBCOSTCENTER',
        ].contains(masterField.toUpperCase());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          isAutocomplete
              ? Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              final options = autocompleteOptions[masterField] ?? [];
              if (textEditingValue.text.isEmpty) {
                return options;
              }
              return options.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              if (isTableForm) {
                controllers[label] = controller;
              } else {
                controller.text = formData[label] ?? '';
                controller.addListener(() {
                  formData[label] = controller.text;
                });
              }
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: _buildInputDecoration(label, isAutocomplete, isDateField, isRemarks),
                validator: isTableForm ? (value) => value!.isEmpty ? 'Required' : null : null,
                style: GoogleFonts.poppins(fontSize: 12),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150, maxWidth: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text(
                              option,
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          )
              : isDateField
              ? TextFormField(
            controller: isTableForm ? controllers[label] : null,
            readOnly: true,
            decoration: _buildInputDecoration(label, false, true, isRemarks),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Colors.blue.shade700,
                        onPrimary: Colors.white,
                        onSurface: Colors.blue.shade900,
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                final controller = isTableForm ? controllers[label] : TextEditingController();
                controller!.text = date.toIso8601String().split('T')[0];
                if (!isTableForm) {
                  formData[label] = controller.text;
                  controller.dispose();
                }
              }
            },
            validator: isTableForm ? (value) => value!.isEmpty ? 'Required' : null : null,
            style: GoogleFonts.poppins(fontSize: 12),
          )
              : isFromMaster
              ? DropdownButtonFormField<String>(
            decoration: _buildInputDecoration(label, false, false, isRemarks),
            items: [], // TODO: Fetch from MasterTableName
            onChanged: (value) {
              if (!isTableForm) {
                formData[label] = value ?? '';
              }
            },
            value: formData[label]?.isNotEmpty == true ? formData[label] : null,
            validator: isTableForm ? (value) => value == null ? 'Required' : null : null,
            style: GoogleFonts.poppins(fontSize: 12),
          )
              : TextFormField(
            controller: isTableForm ? controllers[label] : null,
            maxLines: isRemarks ? 3 : 1,
            decoration: _buildInputDecoration(label, false, false, isRemarks),
            validator: isTableForm ? (value) => value!.isEmpty ? 'Required' : null : null,
            onChanged: (value) {
              if (!isTableForm) {
                formData[label] = value;
              }
            },
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, bool isAutocomplete, bool isDateField, bool isRemarks) {
    return InputDecoration(
      prefixIcon: Icon(
        isAutocomplete
            ? Icons.search
            : isDateField
            ? Icons.calendar_today
            : isRemarks
            ? Icons.text_fields
            : Icons.input,
        color: Colors.blue.shade400,
        size: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.blue.shade100),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.blue.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.blue.shade700, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color:Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.2),
      ),
      filled: true,
      fillColor: isRemarks ? Colors.grey.shade50 : Colors.white,
      hintText: 'Enter $label',
      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}