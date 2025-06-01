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

    String? _selectedApi; // Although set from widget, kept for consistency
    bool _showConfigPanel = false;
    late EditDetailMakerBloc _bloc;
    late AnimationController _animationController;
    late Animation<double> _fadeAnimation;

    @override
    void initState() {
        super.initState();
        print('UI: EditDetailMaker initState: recNo=${widget.recNo}, apiName=${widget.apiName}');
        _reportNameController.text = widget.reportName;
        _reportLabelController.text = widget.reportLabel;
        _apiController.text = widget.apiName;
        _selectedApi = widget.apiName; // Set selected API from widget initial data
        print('UI: Controllers initialized: reportName=${_reportNameController.text}, apiName=${_apiController.text}');

        _bloc = EditDetailMakerBloc(ReportAPIService());

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
            _fieldNameController,
            _fieldLabelController,
            _sequenceController,
            _widthController,
            _decimalPointsController
        ]) {
            controller.addListener(() {
                // This logic can sometimes interfere with user selection,
                // consider removing or making conditional if issues arise.
                if (controller.text.isNotEmpty && controller.selection.baseOffset < controller.text.length) {
                    controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.text.length),
                    );
                }
            });
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
            print('UI: Dispatching LoadPreselectedFields: recNo=${widget.recNo}, apiName=${widget.apiName}');
            _bloc.add(LoadPreselectedFields(widget.recNo, widget.apiName));
        });
    }

    @override
    void dispose() {
        print('UI: EditDetailMaker dispose');
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
        print('UI: Toggling config panel to show.');
        setState(() {
            _showConfigPanel = true;
        });
        _animationController.forward();
    }

    void _returnToFieldSelection() {
        print('UI: Returning to field selection: showConfigPanel=false');
        setState(() {
            _showConfigPanel = false;
        });
        _animationController.reverse(from: 1.0); // Animate fade out
    }

    void _updateFieldConfigControllers(Map<String, dynamic>? field) {
        print('UI: _updateFieldConfigControllers called with field=${field?['Field_name']}');
        if (field == null) {
            // Only clear if controllers actually contain text
            if (_fieldNameController.text.isNotEmpty || _fieldLabelController.text.isNotEmpty) {
                _fieldNameController.clear();
                _fieldLabelController.clear();
                _sequenceController.clear();
                _widthController.clear();
                _decimalPointsController.clear();
                print('UI: Cleared field config controllers (field is null).');
            }
        } else {
            // Update controllers only if the text content is different
            if (_fieldNameController.text != (field['Field_name']?.toString() ?? '')) {
                _fieldNameController.text = field['Field_name']?.toString() ?? '';
            }
            if (_fieldLabelController.text != (field['Field_label']?.toString() ?? '')) {
                _fieldLabelController.text = field['Field_label']?.toString() ?? '';
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
        print('UI: Building EditDetailMaker UI');
        return BlocProvider.value(
            value: _bloc, // Provide the existing bloc instance
            child: Scaffold(
                appBar: AppBarWidget(
                    title: 'Edit Report Details',
                    onBackPress: () {
                        print('UI: AppBar back pressed');
                        Navigator.pop(context, true); // Pass true to indicate a potential refresh is needed
                    },
                ),
                body: BlocListener<EditDetailMakerBloc, EditDetailMakerState>(
                    listener: (context, state) {
                        print('UI: BlocListener: isLoading=${state.isLoading}, error=${state.error}, saveSuccess=${state.saveSuccess}, selectedFields=${state.selectedFields.length}');
                        if (state.error != null) {
                            print('UI: Showing error SnackBar: ${state.error}');
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
                        } else if (state.saveSuccess) {
                            print('UI: Showing success SnackBar');
                            ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(
                                    content: Text('Report and field configurations updated successfully!'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    margin: EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    duration: Duration(seconds: 5),
                                ),
                            );
                            print('UI: Navigating back with refresh indicator');
                            Navigator.pop(context, true); // Indicate success and pop
                        }
                        // Always update field config controllers when currentField in state changes
                        _updateFieldConfigControllers(state.currentField);
                    },
                    child: BlocBuilder<EditDetailMakerBloc, EditDetailMakerState>(
                        builder: (context, state) {
                            print('UI: BlocBuilder: isLoading=${state.isLoading}, fields=${state.fields.length}, selectedFields=${state.selectedFields.length}, preselectedFields=${state.preselectedFields.length}');
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
                                                                            print('UI: Report Name changed: $value');
                                                                            // Note: Report Name/Label are not directly updated in bloc on change here,
                                                                            // only used during the final SaveReport event.
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
                                                                            print('UI: Report Label changed: $value');
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
                                                                        readOnly: true, // API Name should not be editable here
                                                                        onChanged: (value) {
                                                                            print('UI: API Name changed (read-only field): $value');
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
                                                                    text: 'Reset Form', // Clarified button text
                                                                    color: Colors.redAccent,
                                                                    onPressed: () {
                                                                        print('UI: Reset Form button pressed');
                                                                        context.read<EditDetailMakerBloc>().add(ResetFields());
                                                                        // Reset text controllers to initial widget values
                                                                        _reportNameController.text = widget.reportName;
                                                                        _reportLabelController.text = widget.reportLabel;
                                                                        _apiController.text = widget.apiName;
                                                                        setState(() {
                                                                            _selectedApi = widget.apiName; // Redundant, but ensures consistency
                                                                            _showConfigPanel = false; // Collapse config panel
                                                                        });
                                                                        _animationController.reset(); // Reset animation
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
                                                child: () {
                                                    print('UI: Rendering field selection/config card content.');
                                                    if (state.isLoading) {
                                                        print('UI: Showing SubtleLoader');
                                                        return const SubtleLoader();
                                                    }
                                                    if (state.error != null) {
                                                        print('UI: Showing error state: ${state.error}');
                                                        return Center(
                                                            child: Column(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                    Text(
                                                                        'Error loading fields: ${state.error}',
                                                                        style: GoogleFonts.poppins(fontSize: 16, color: Colors.redAccent),
                                                                        textAlign: TextAlign.center,
                                                                    ),
                                                                    const SizedBox(height: 16),
                                                                    _buildButton(
                                                                        text: 'Retry Load Fields',
                                                                        color: Colors.blueAccent,
                                                                        onPressed: () {
                                                                            print('UI: Retry button pressed for field loading.');
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
                                                        print('UI: Showing empty fields message.');
                                                        return Center(
                                                            child: Text(
                                                                'No fields available from the API for this report. Check API response.',
                                                                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                                                                textAlign: TextAlign.center,
                                                            ),
                                                        );
                                                    }
                                                    if (_showConfigPanel) {
                                                        print('UI: Showing field config panel (FadeTransition)');
                                                        return FadeTransition(
                                                            opacity: _fadeAnimation,
                                                            child: _buildFieldConfigPanel(context, state),
                                                        );
                                                    }
                                                    print('UI: Showing field selection panel.');
                                                    return _buildFieldSelection(context, state);
                                                }(), // Self-invoking function
                                            ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                                _buildButton(
                                                    text: 'Save Changes', // Clarified button text
                                                    color: Colors.green,
                                                    onPressed: () {
                                                        print('UI: Save Changes button pressed');
                                                        if (_reportNameController.text.isEmpty ||
                                                            _reportLabelController.text.isEmpty ||
                                                            _selectedApi == null ||
                                                            state.selectedFields.isEmpty) {
                                                            print('UI: Validation failed: showing SnackBar');
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
                                                            return;
                                                        }

                                                        // Ensure current field's sequence number is updated before saving
                                                        // (this should be handled by onUpdateFieldConfig, but a last check is good)
                                                        if (state.currentField != null && _sequenceController.text.isNotEmpty) {
                                                            final parsed = int.tryParse(_sequenceController.text);
                                                            if (parsed != null && parsed > 0 && (state.currentField!['Sequence_no'] != parsed)) {
                                                                print('UI: Final Sequence_no update before save for current field.');
                                                                // Dispatch update and then wait for bloc to process it before saving
                                                                context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Sequence_no', parsed));
                                                            }
                                                        }

                                                        // Add a small delay to ensure the UpdateFieldConfig event is processed
                                                        // before SaveReport is dispatched, if they happen in quick succession.
                                                        // This is a common pattern for UI-triggered updates followed by a major action.
                                                        Future.delayed(const Duration(milliseconds: 100), () {
                                                            print('UI: Dispatching SaveReport event after potential field config update.');
                                                            context.read<EditDetailMakerBloc>().add(SaveReport(
                                                                recNo: widget.recNo,
                                                                reportName: _reportNameController.text,
                                                                reportLabel: _reportLabelController.text,
                                                                apiName: _selectedApi!,
                                                                parameter: 'default', // Using a default parameter string
                                                            ));
                                                        });
                                                    },
                                                    icon: Icons.save,
                                                ),
                                                const SizedBox(width: 12),
                                                // Removed redundant Reset button here as one exists above
                                            ],
                                        ),
                                    ],
                                ),
                            );
                        },
                    ),
                ),
            )
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
        // print('UI: Building TextField: label=$label, readOnly=$readOnly'); // Too verbose
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
        // print('UI: Building Button: text=$text'); // Too verbose
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
        print('UI: Building field selection view. Fields count: ${state.fields.length}, Selected count: ${state.selectedFields.length}');
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
                                    // A field is "selected" if it's in the final selectedFields list
                                    final isSelected = state.selectedFields.any((f) => f['Field_name'] == field);
                                    // A field is "preselected" if it was originally loaded from demo_table2
                                    final isPreselected = state.preselectedFields.any((f) => f['Field_name'] == field);

                                    // Print for debugging each chip's status
                                    // print('UI: Chip: $field, isSelected=$isSelected, isPreselected=$isPreselected');

                                    return FilterChip(
                                        label: Text(
                                            field,
                                            style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                color: isSelected ? Colors.white : Colors.black87,
                                            ),
                                        ),
                                        selected: isSelected, // Based on overall selected status
                                        selectedColor: isPreselected && isSelected // If originally preselected AND still selected
                                            ? Colors.blueAccent // Use blue for original fields that are kept
                                            : isSelected // If newly selected by user (not preselected initially)
                                            ? Colors.green // Use green for new additions
                                            : null, // Not selected
                                        checkmarkColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            side: BorderSide(
                                                color: isPreselected && isSelected
                                                    ? Colors.blueAccent
                                                    : isSelected
                                                    ? Colors.green
                                                    : Colors.grey.shade300,
                                            ),
                                        ),
                                        backgroundColor: Colors.white,
                                        labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        onSelected: (selected) {
                                            print('UI: Chip tapped: field=$field, selected=$selected');
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
                                text: 'Configure Selected Fields', // Clarified button text
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
        print('UI: Building field config panel. Selected fields count: ${state.selectedFields.length}');
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
                                                    // print('UI: Rendering config field list item: ${field['Field_name']}, isSelected=$isSelected'); // Too verbose
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
                                                                            print('UI: Field tapped in list: ${field['Field_name']}');
                                                                            // Before switching current field, ensure current sequence is updated if changed
                                                                            if (state.currentField != null && _sequenceController.text.isNotEmpty) {
                                                                                final parsed = int.tryParse(_sequenceController.text);
                                                                                if (parsed != null && parsed > 0 && (state.currentField!['Sequence_no'] != parsed)) {
                                                                                    context.read<EditDetailMakerBloc>().add(
                                                                                        UpdateFieldConfig('Sequence_no', parsed),
                                                                                    );
                                                                                    print('UI: Updating sequence for previous field (${state.currentField!['Field_name']}) before switching.');
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
                                                                                            print('UI: Deleting field from list: ${field['Field_name']}');
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

    List<Widget> _buildFieldConfigWidgets(BuildContext context, EditDetailMakerState state) {
        print('UI: Building field config widgets for: ${state.currentField!['Field_name']}');
        // Ensure currentField is not null before accessing its properties
        if (state.currentField == null) {
            return []; // Should ideally not happen if currentField is correctly managed
        }
        return [
            _buildTextField(
                controller: _fieldNameController,
                label: 'Field Name',
                icon: Icons.text_fields,
                readOnly: true, // Field name is not editable
                onChanged: (value) { /* Handled by controller.text update */ },
            ),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _fieldLabelController,
                label: 'Field Label',
                icon: Icons.label_outline,
                onChanged: (value) {
                    print('UI: Field Label changed to: $value');
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
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                        print('UI: Sequence No changed to: $parsed');
                        context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Sequence_no', parsed));
                        // Keep controller text updated with parsed value and set cursor to end
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
                    context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('width', parsed));
                },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
                title: Text('Total', style: GoogleFonts.poppins()),
                value: state.currentField!['Total'] ?? false,
                activeColor: Colors.blueAccent,
                onChanged: (value) {
                    print('UI: Total checkbox changed to: $value');
                    context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Total', value!));
                },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
                title: Text('Breakpoint', style: GoogleFonts.poppins()),
                value: state.currentField!['Breakpoint'] ?? false,
                activeColor: Colors.blueAccent,
                onChanged: (value) {
                    print('UI: Breakpoint checkbox changed to: $value');
                    context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('Breakpoint', value!));
                },
            ),
            // Conditional Subtotal checkbox
            if (state.currentField!['Total'] == true) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                    title: Text('Subtotal', style: GoogleFonts.poppins()),
                    value: state.currentField!['SubTotal'] ?? false,
                    activeColor: Colors.blueAccent,
                    onChanged: (value) {
                        print('UI: Subtotal checkbox changed to: $value');
                        context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('SubTotal', value!));
                    },
                ),
            ],
            const SizedBox(height: 16), // Spacing before the new Image checkbox
            // NEW: Image checkbox
            CheckboxListTile(
                title: Text('Image', style: GoogleFonts.poppins()),
                value: state.currentField!['image'] ?? false, // Default to false if null
                activeColor: Colors.blueAccent,
                onChanged: (value) {
                    print('UI: Image checkbox changed to: $value');
                    context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('image', value!));
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
                // Ensure value matches one of the items exactly (case-insensitive conversion to lowercase)
                value: (state.currentField!['num_alignment']?.toString().toLowerCase() ?? 'left')
                    .contains('left') ? 'left' : ((state.currentField!['num_alignment']?.toString().toLowerCase() ?? 'left').contains('center') ? 'center' : 'right'),
                items: const [
                    DropdownMenuItem(value: 'left', child: Text('Left')),
                    DropdownMenuItem(value: 'center', child: Text('Center')),
                    DropdownMenuItem(value: 'right', child: Text('Right')),
                ].map((item) => DropdownMenuItem( // Re-apply GoogleFonts to children
                    value: item.value,
                    child: Text(item.value!, style: GoogleFonts.poppins()),
                )).toList(),
                onChanged: (value) {
                    print('UI: Number Alignment changed to: $value');
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
                    print('UI: Indian Number Format changed to: $value');
                    context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('num_format', value!));
                },
            ),
            // Decimal points should always be available, not conditional on date
            const SizedBox(height: 16),
            _buildTextField(
                controller: _decimalPointsController,
                label: 'Decimal Points',
                icon: Icons.numbers,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                    print('UI: Decimal Points changed to: $value');
                    final parsed = int.tryParse(value);
                    context.read<EditDetailMakerBloc>().add(UpdateFieldConfig(
                        'decimal_points',
                        parsed != null && parsed >= 0 ? parsed : 0,
                    ));
                },
            ),
            if (state.currentField!['Field_name'].toString().toLowerCase().contains('date')) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                    title: Text('Time', style: GoogleFonts.poppins()),
                    value: state.currentField!['time'] ?? false,
                    activeColor: Colors.blueAccent,
                    onChanged: (value) {
                        print('UI: Time checkbox changed to: $value');
                        context.read<EditDetailMakerBloc>().add(UpdateFieldConfig('time', value!));
                    },
                ),
            ],
        ];
    }
}