import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qualityapproach/ReportUtils/subtleloader.dart';
import '../../../ReportUtils/Appbar.dart';
import '../../ReportAPIService.dart';
import 'EditDetailAdminBloc.dart';
import 'dart:async';
import 'dart:convert';

class EditDetailAdmin extends StatelessWidget {
  final Map<String, dynamic> apiData;

  const EditDetailAdmin({super.key, required this.apiData});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditDetailAdminBloc(ReportAPIService(), apiData)
        ..add(FetchDatabases(
          serverIP: apiData['ServerIP'] ?? '',
          userName: apiData['UserName'] ?? '',
          password: apiData['Password'] ?? '',
        )),
      child: _EditDetailAdminContent(apiData: apiData),
    );
  }
}

class _EditDetailAdminContent extends StatefulWidget {
  final Map<String, dynamic> apiData;

  const _EditDetailAdminContent({required this.apiData});

  @override
  _EditDetailAdminContentState createState() => _EditDetailAdminContentState();
}

class _EditDetailAdminContentState extends State<_EditDetailAdminContent> {
  final Map<int, TextEditingController> _paramControllers = {};
  final TextEditingController _serverIPController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _databaseNameController = TextEditingController();
  final TextEditingController _apiServerURLController = TextEditingController();
  final TextEditingController _apiNameController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _serverIPController.text = widget.apiData['ServerIP'] ?? '';
    _userNameController.text = widget.apiData['UserName'] ?? '';
    _passwordController.text = widget.apiData['Password'] ?? '';
    _databaseNameController.text = widget.apiData['DatabaseName'] ?? '';
    _apiServerURLController.text = widget.apiData['APIServerURl'] ?? '';
    _apiNameController.text = widget.apiData['APIName'] ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        _initializeParameterControllers(context.read<EditDetailAdminBloc>().state.parameters);
      }
    });

    _serverIPController.addListener(() {
      _debouncedUpdate(() {
        context.read<EditDetailAdminBloc>().add(UpdateServerIP(_serverIPController.text));
      });
    });
    _userNameController.addListener(() {
      _debouncedUpdate(() {
        context.read<EditDetailAdminBloc>().add(UpdateUserName(_userNameController.text));
      });
    });
    _passwordController.addListener(() {
      _debouncedUpdate(() {
        context.read<EditDetailAdminBloc>().add(UpdatePassword(_passwordController.text));
      });
    });
    _apiServerURLController.addListener(() {
      _debouncedUpdate(() {
        context.read<EditDetailAdminBloc>().add(UpdateApiServerURL(_apiServerURLController.text));
      });
    });
    _apiNameController.addListener(() {
      _debouncedUpdate(() {
        context.read<EditDetailAdminBloc>().add(UpdateApiName(_apiNameController.text));
      });
    });
  }

  void _initializeParameterControllers(List<Map<String, dynamic>> parameters) {
    for (var i = 0; i < parameters.length; i++) {
      _paramControllers[i] ??= TextEditingController();
      final param = parameters[i];
      String valueToDisplay;

      if (param['config_type'] == 'radio' || param['config_type'] == 'checkbox') {
        valueToDisplay = param['value']?.toString() ?? '';
      } else {
        valueToDisplay = param['display_value_cache']?.toString() ?? param['value']?.toString() ?? '';
      }

      if (_paramControllers[i]!.text != valueToDisplay) {
        _paramControllers[i]!.text = valueToDisplay;
      }
      if (!_paramControllers[i]!.hasListeners) {
        _paramControllers[i]!.addListener(() {
          _debouncedUpdate(() {
            context.read<EditDetailAdminBloc>().add(UpdateParameterValue(i, _paramControllers[i]!.text, _paramControllers[i]!.text));
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _paramControllers.values.forEach((controller) => controller.dispose());
    _serverIPController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _databaseNameController.dispose();
    _apiServerURLController.dispose();
    _apiNameController.dispose();
    super.dispose();
  }

  DateFormat? _inferDateFormat(String dateString) {
    if (dateString.isEmpty) return null;

    final List<String> commonFormats = [
      'dd-MMM-yyyy',
      'yyyy-MM-dd',
      'MM/dd/yyyy',
      'dd/MM/yyyy',
      'MMM dd, yyyy',
    ];

    for (String format in commonFormats) {
      try {
        DateFormat(format).parseStrict(dateString);
        return DateFormat(format);
      } catch (e) {
        // Not this format, try next
      }
    }
    return null;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool obscureText = false,
    bool isSmall = false,
    bool isDateField = false,
    VoidCallback? onTap,
    IconData? suffixIcon,
    VoidCallback? onSuffixIconTap,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      readOnly: isDateField || readOnly,
      onTap: isDateField ? onTap : null,
      style: GoogleFonts.poppins(fontSize: isSmall ? 14 : 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey[700],
          fontSize: isSmall ? 13 : 15,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: isSmall ? 20 : 22) : null,
        suffixIcon: isDateField
            ? Icon(Icons.calendar_today, color: Colors.blueAccent, size: isSmall ? 18 : 20)
            : (suffixIcon != null
            ? IconButton(
          icon: Icon(suffixIcon, color: Colors.blueAccent, size: isSmall ? 18 : 20),
          onPressed: onSuffixIconTap,
        )
            : null),
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
        contentPadding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16, horizontal: isSmall ? 12 : 16),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String label,
    IconData? icon,
  }) {
    return DropdownButtonFormField<String>(
      value: value != null && items.contains(value) ? value : null,
      onChanged: onChanged,
      items: items.isEmpty
          ? [
        const DropdownMenuItem<String>(
          value: null,
          child: Text(
            'No databases available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ]
          : items.map((String database) {
        return DropdownMenuItem<String>(
          value: database,
          child: Text(
            database,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
          ),
        );
      }).toList(),
      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22.0) : null,
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
    required VoidCallback onPressed,
    required IconData icon,
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
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
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

  bool _isDateParameter(String name, String value) {
    final datePattern1 = RegExp(r'^\d{2}-\d{2}-\d{4}$');
    final datePattern2 = RegExp(r'^\d{2}-[A-Za-z]{3}-\d{4}$');
    final datePattern3 = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    return name.toLowerCase().contains('date') || datePattern1.hasMatch(value) || datePattern2.hasMatch(value) || datePattern3.hasMatch(value);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller, int index) async {
    DateTime? initialDate;
    DateFormat? inferredFormat;

    if (controller.text.isNotEmpty) {
      inferredFormat = _inferDateFormat(controller.text);
      if (inferredFormat != null) {
        try {
          initialDate = inferredFormat.parse(controller.text);
        } catch (e) {
          initialDate = DateTime.now();
        }
      }
    }
    initialDate ??= DateTime(2000);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && context.mounted) {
      final DateFormat outputFormat = inferredFormat ?? DateFormat('dd-MMM-yyyy');
      final formattedDate = outputFormat.format(picked);
      controller.text = formattedDate;
      context.read<EditDetailAdminBloc>().add(UpdateParameterValue(index, formattedDate, formattedDate));
    }
  }

  Future<String?> _showFieldLabelDialog(BuildContext context, String paramName, String? currentLabel) async {
    final TextEditingController labelController = TextEditingController(text: currentLabel ?? '');
    String? fieldLabel;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        title: Text(
          'Edit Field Label for ${paramName.toUpperCase()}',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: _buildTextField(
          controller: labelController,
          label: 'Field Label',
          icon: Icons.label,
          isSmall: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              if (labelController.text.trim().isNotEmpty) {
                fieldLabel = labelController.text.trim();
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Field label cannot be empty',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: Text(
              'OK',
              style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    labelController.dispose();
    return fieldLabel;
  }

  void _debouncedUpdate(VoidCallback callback) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), callback);
  }

  List<Widget> _buildParameterRows(EditDetailAdminState state, BuildContext context) {
    final List<Widget> rows = [];
    final List<Map<String, dynamic>> allParamsOrdered = state.parameters;

    for (var i = 0; i < allParamsOrdered.length; i++) {
      final param = allParamsOrdered[i];
      final index = i;

      String valueToDisplay;
      if (param['config_type'] == 'radio' || param['config_type'] == 'checkbox') {
        valueToDisplay = param['value']?.toString() ?? '';
      } else {
        valueToDisplay = param['display_value_cache']?.toString() ?? param['value']?.toString() ?? '';
      }

      _paramControllers[index] ??= TextEditingController(text: valueToDisplay);
      if (_paramControllers[index]!.text != valueToDisplay) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            _paramControllers[index]?.text = valueToDisplay;
          }
        });
      }

      final bool isDate = _isDateParameter(param['name'].toString(), param['value'].toString());
      final String configType = param['config_type'] ?? 'database';

      IconData suffixIcon;
      switch (configType) {
        case 'database':
          suffixIcon = Icons.storage;
          break;
        case 'radio':
          suffixIcon = Icons.radio_button_checked;
          break;
        case 'checkbox':
          suffixIcon = Icons.check_box;
          break;
        default:
          suffixIcon = Icons.settings;
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _paramControllers[index]!,
                        label: param['field_label']?.isNotEmpty ?? false ? param['field_label'] : param['name'],
                        isSmall: true,
                        isDateField: isDate,
                        onTap: isDate ? () => _selectDate(context, _paramControllers[index]!, index) : null,
                        suffixIcon: isDate ? null : suffixIcon,
                        readOnly: !isDate && (configType == 'database' || configType == 'radio' || configType == 'checkbox'),
                        onSuffixIconTap: isDate
                            ? null
                            : () async {
                          final blocState = context.read<EditDetailAdminBloc>().state;
                          final currentParam = blocState.parameters[index];

                          final Map<String, dynamic>? result = await showGeneralDialog<Map<String, dynamic>>(
                            context: context,
                            barrierDismissible: true,
                            barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                            barrierColor: Colors.black54,
                            transitionDuration: const Duration(milliseconds: 200),
                            pageBuilder: (dialogContext, animation, secondaryAnimation) {
                              return _ParameterConfigModal(
                                apiService: context.read<EditDetailAdminBloc>().apiService,
                                paramIndex: index,
                                currentParam: currentParam,
                                serverIP: blocState.serverIP,
                                userName: blocState.userName,
                                password: blocState.password,
                                databaseName: blocState.databaseName,
                              );
                            },
                            transitionBuilder: (context, a1, a2, child) {
                              return ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: a1,
                                  curve: Curves.easeOutBack,
                                ),
                                child: child,
                              );
                            },
                          );

                          if (result != null && context.mounted) {
                            final String newConfigType = result['config_type'];
                            final String? newValue = result['value'];
                            final String? newDisplayLabel = result['display_label'];
                            final String? newMasterTable = result['master_table'];
                            final String? newMasterField = result['master_field'];
                            final String? newDisplayField = result['display_field'];
                            final List<Map<String, dynamic>>? newOptions = result['options'];
                            final List<String>? newSelectedValues = result['selected_values']?.cast<String>();

                            context.read<EditDetailAdminBloc>().add(
                                UpdateParameterConfigType(index, newConfigType));

                            String finalDisplayValueForUI;
                            if (newConfigType == 'radio' || newConfigType == 'checkbox') {
                              finalDisplayValueForUI = newValue ?? '';
                            } else {
                              finalDisplayValueForUI = newDisplayLabel ?? newValue ?? '';
                            }

                            _paramControllers[index]!.text = finalDisplayValueForUI;
                            context.read<EditDetailAdminBloc>().add(UpdateParameterValue(
                              index, newValue ?? '', newDisplayLabel ?? newValue ?? '',
                            ));

                            context.read<EditDetailAdminBloc>().add(UpdateParameterMasterSelection(
                                index, newMasterTable, newMasterField, newDisplayField));

                            if (newOptions != null) {
                              context.read<EditDetailAdminBloc>().add(UpdateParameterOptions(index, newOptions));
                            }
                            if (newSelectedValues != null) {
                              context.read<EditDetailAdminBloc>().add(UpdateParameterSelectedValues(index, newSelectedValues));
                            }
                          }
                        },
                      ),
                    ),
                    if (param['show'] ?? false)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                        onPressed: () async {
                          final fieldLabel = await _showFieldLabelDialog(context, param['name'], param['field_label']);
                          if (fieldLabel != null && context.mounted) {
                            context.read<EditDetailAdminBloc>().add(UpdateParameterFieldLabel(index, fieldLabel));
                          }
                        },
                        tooltip: 'Edit Field Label',
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Mark as Company Name Field',
                child: Radio<int>(
                  value: index,
                  groupValue: state.parameters.indexWhere((p) => (p['is_company_name_field'] as bool?) == true),
                  onChanged: (int? selectedIndex) {
                    if (selectedIndex != null && context.mounted) {
                      context.read<EditDetailAdminBloc>().add(UpdateParameterIsCompanyNameField(selectedIndex));
                    }
                  },
                  activeColor: Colors.deepOrange,
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: param['show'] ?? false,
                onChanged: (value) async {
                  if (value == true) {
                    final fieldLabel = await _showFieldLabelDialog(context, param['name'], param['field_label']);
                    if (fieldLabel != null && context.mounted) {
                      context.read<EditDetailAdminBloc>().add(UpdateParameterFieldLabel(index, fieldLabel));
                      context.read<EditDetailAdminBloc>().add(UpdateParameterShow(index, true));
                    }
                  } else {
                    context.read<EditDetailAdminBloc>().add(UpdateParameterShow(index, false));
                  }
                },
                activeColor: Colors.blueAccent,
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: 'Edit API: ${widget.apiData['APIName']}',
        onBackPress: () => Navigator.pop(context),
      ),
      body: BlocConsumer<EditDetailAdminBloc, EditDetailAdminState>(
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
          } else if (!state.isLoading && state.saveInitiated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Changes saved successfully',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.pop(context, true);
          }
          _initializeParameterControllers(state.parameters);
        },
        builder: (context, state) {
          return Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                  child: Card(
                    color: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit API Configuration',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _serverIPController,
                                  label: 'Server IP',
                                  icon: Icons.dns,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _userNameController,
                                  label: 'Username',
                                  icon: Icons.person,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  icon: Icons.lock,
                                  obscureText: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: state.isLoading && state.availableDatabases.isEmpty
                                    ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                                    child: CircularProgressIndicator(color: Colors.blueAccent),
                                  ),
                                )
                                    : _buildDropdownField(
                                  value: state.databaseName,
                                  items: state.availableDatabases,
                                  onChanged: (value) {
                                    if (value != null) {
                                      _databaseNameController.text = value;
                                      context.read<EditDetailAdminBloc>().add(UpdateDatabaseName(value));
                                    }
                                  },
                                  label: 'Database Name',
                                  icon: Icons.storage,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _apiServerURLController,
                                  label: 'API Server URL',
                                  icon: Icons.link,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _apiNameController,
                                  label: 'API Name',
                                  icon: Icons.api,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.grey, thickness: 1),
                          const SizedBox(height: 10),
                          Text(
                            'Parameters',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (state.parameters.isEmpty)
                            Text(
                              'No parameters available',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            ..._buildParameterRows(state, context),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildButton(
                                text: 'Save',
                                color: Colors.blueAccent,
                                onPressed: state.isLoading
                                    ? () {}
                                    : () {
                                  context.read<EditDetailAdminBloc>().add(SaveChanges());
                                },
                                icon: Icons.save,
                              ),
                              const SizedBox(width: 12),
                              _buildButton(
                                text: 'Cancel',
                                color: Colors.grey,
                                onPressed: state.isLoading
                                    ? () {}
                                    : () => Navigator.pop(context),
                                icon: Icons.cancel,
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          const Divider(color: Colors.grey, thickness: 1),
                          const SizedBox(height: 20),
                          _buildHelpSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (state.isLoading)
                const Center(
                  child: SubtleLoader(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHelpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to configure parameters:',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        _buildHelpRow(
          icon: Icons.visibility,
          label: 'Show/Hide Parameter (Checkbox):',
          description: 'Check this box to make a parameter visible and editable to the end-user. Uncheck to hide it.',
        ),
        _buildHelpRow(
          icon: Icons.edit,
          label: 'Edit Field Label (Pencil Icon):',
          description: 'Click this icon to customize the display name (label) of the parameter that users will see.',
        ),
        _buildHelpRow(
          icon: Icons.radio_button_checked,
          label: 'Mark as Company Name Field (Radio Button):',
          description: 'Select one parameter to be used as the "Company Name" for specific features like linking data across reports. Only one can be selected per API.',
          color: Colors.deepOrange,
        ),
        _buildHelpRow(
          icon: Icons.settings,
          label: 'Configure Parameter Input (Settings Icon):',
          description: 'Click this icon next to the parameter value field to open a detailed configuration dialog. Here, you can define how the user inputs the value for this parameter:',
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpRow(
                icon: Icons.storage,
                label: 'Database Picker (Tab in Dialog):',
                description: 'Link this parameter to a table in your database. Users will get a dropdown/searchable list of values from the specified \'Master Field\' (API Value), with a friendly \'Display Field\' (User Value).',
                isSubItem: true,
              ),
              _buildHelpRow(
                icon: Icons.radio_button_checked,
                label: 'Radio Buttons (Tab in Dialog):',
                description: 'Define a fixed set of options. Users can choose only one value from this set. Provide an \'API Value\' (actual data) and a \'Display Field\' (what the user sees). The API value will be shown in the main parameter field.',
                isSubItem: true,
              ),
              _buildHelpRow(
                icon: Icons.check_box,
                label: 'Checkboxes (Tab in Dialog):',
                description: 'Define a fixed set of options. Users can select multiple values from this set. Provide an \'API Value\' and a \'Display Field\'. The API value(s) will be shown in the main parameter field (e.g., comma-separated).',
                isSubItem: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpRow({
    required IconData icon,
    required String label,
    required String description,
    Color color = Colors.blueAccent,
    bool isSubItem = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.0, left: isSubItem ? 16.0 : 0.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
  List<Map<String, String>> _allFieldData = [];
  final TextEditingController _dbPickerSearchController = TextEditingController();
  String _dbPickerSearchRawText = '';

  final TextEditingController _tableAutocompleteController = TextEditingController();
  final TextEditingController _masterFieldAutocompleteController = TextEditingController();
  final TextEditingController _displayFieldAutocompleteController = TextEditingController();

  // Radio/Checkbox options state
  List<Map<String, String>> _options = [];
  String? _radioSelectedValue;
  List<String> _checkboxSelectedValues = [];

  final TextEditingController _apiValueController = TextEditingController();
  final TextEditingController _displayFieldOptionController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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

    _options = List<Map<String, String>>.from(
        (widget.currentParam['options'] as List?)?.map((e) => Map<String, String>.from(e)) ?? []);

    if (_selectedConfigType == 'radio') {
      _radioSelectedValue = widget.currentParam['value'];
    } else if (_selectedConfigType == 'checkbox') {
      _checkboxSelectedValues = List<String>.from(widget.currentParam['selected_values']?.cast<String>() ?? []);
    }

    if (_selectedConfigType == 'database') {
      _fetchTablesForSelectedDatabase();
    }
  }

  int _configTypeToIndex(String configType) {
    switch (configType) {
      case 'database': return 0;
      case 'radio': return 1;
      case 'checkbox': return 2;
      default: return 0;
    }
  }

  String _indexToConfigType(int index) {
    switch (index) {
      case 0: return 'database';
      case 1: return 'radio';
      case 2: return 'checkbox';
      default: return 'database';
    }
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedConfigType = _indexToConfigType(_tabController.index);
        if (_selectedConfigType == 'database' && _tables.isEmpty && widget.databaseName != null) {
          _fetchTablesForSelectedDatabase();
        }
      });
    }
  }

  @override
  void dispose() {
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
    });
  }

  List<Map<String, String>> get _filteredFieldData {
    if (_dbPickerSearchRawText.isEmpty) {
      return _allFieldData;
    }
    return _allFieldData
        .where((item) => (item['label'] ?? '').toLowerCase().contains(_dbPickerSearchRawText.toLowerCase()))
        .toList();
  }

  Future<void> _fetchTablesForSelectedDatabase() async {
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
        if (widget.currentParam['master_table'] != null && tables.contains(widget.currentParam['master_table'])) {
          _selectedTable = widget.currentParam['master_table'];
          _tableAutocompleteController.text = _selectedTable!;
          _fetchFieldsForTable(_selectedTable!);
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load tables for database "${widget.databaseName}": $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFieldsForTable(String tableName) async {
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

        if (widget.currentParam['master_field'] != null && fields.contains(widget.currentParam['master_field'])) {
          _selectedMasterField = widget.currentParam['master_field'];
          _masterFieldAutocompleteController.text = _selectedMasterField!;
        }

        if (widget.currentParam['display_field'] != null && fields.contains(widget.currentParam['display_field'])) {
          _selectedDisplayField = widget.currentParam['display_field'];
          _displayFieldAutocompleteController.text = _selectedDisplayField!;
        } else if (_selectedMasterField != null) {
          _selectedDisplayField = _selectedMasterField;
          _displayFieldAutocompleteController.text = _selectedMasterField!;
        }

        if (_selectedMasterField != null && _selectedDisplayField != null) {
          _fetchFieldData();
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load fields for table "$tableName": $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFieldData() async {
    if (_selectedTable == null || _selectedMasterField == null || _selectedDisplayField == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _allFieldData = [];
      _dbPickerSearchController.clear();
      _dbPickerSearchRawText = '';
    });

    try {
      // Safely fetch data and ensure each item is a Map<String, dynamic>
      final List<Map<String, dynamic>> rawData = await widget.apiService.fetchPickerData(
        server: widget.serverIP!,
        UID: widget.userName!,
        PWD: widget.password!,
        database: widget.databaseName!,
        masterTable: _selectedTable!,
        masterField: _selectedMasterField!,
        displayField: _selectedDisplayField!,
      );

      final List<Map<String, String>> mappedData = [];
      for (var item in rawData) {
        // Explicitly cast dynamic values to String or provide a default
        final String value = item[_selectedMasterField]?.toString() ?? '';
        final String label = item[_selectedDisplayField]?.toString() ?? '';
        mappedData.add({
          'value': value,
          'label': label,
        });
      }

      setState(() {
        _allFieldData = mappedData;
        _isLoading = false;

        // Populate search controller with initial value if it matches.
        // This logic is for when you open the dialog and the parameter already has a value.
        if (widget.currentParam['config_type'] == 'database' && widget.currentParam['value'] != null && widget.currentParam['value'].toString().isNotEmpty) {
          final String initialParamValue = widget.currentParam['value'].toString();
          final matchedItem = mappedData.firstWhere(
                (item) => item['value'] == initialParamValue,
            orElse: () => {},
          );
          if (matchedItem.isNotEmpty && matchedItem['label'] != null) {
            _dbPickerSearchController.text = matchedItem['label']!;
            _dbPickerSearchRawText = matchedItem['label']!;
          } else {
            // If the initial API value doesn't have a corresponding display label in fetched data,
            // just show the raw API value itself in the search box.
            _dbPickerSearchController.text = initialParamValue;
            _dbPickerSearchRawText = initialParamValue;
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load field data: $e';
        _isLoading = false;
        _allFieldData = [];
      });
    }
  }

  void _addOption() {
    final apiValue = _apiValueController.text.trim();
    final displayField = _displayFieldOptionController.text.trim();
    if (apiValue.isNotEmpty && displayField.isNotEmpty) {
      setState(() {
        _options.add({'label': displayField, 'value': apiValue});
        _apiValueController.clear();
        _displayFieldOptionController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Both API Value and Display Field are required.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _removeOption(int index) {
    setState(() {
      final removedOption = _options.removeAt(index);
      if (_selectedConfigType == 'radio' && _radioSelectedValue == removedOption['value']) {
        _radioSelectedValue = null;
      } else if (_selectedConfigType == 'checkbox' && _checkboxSelectedValues.contains(removedOption['value'])) {
        _checkboxSelectedValues.remove(removedOption['value']);
      }
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
                'Configure Parameter: ${widget.currentParam['name'].toUpperCase()}',
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
                        Navigator.pop(context);
                      },
                      child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.redAccent)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (!context.mounted) return;
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
              fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                // IMPORTANT FIX: Sync the Autocomplete's internal controller with our dedicated controller.
                if (textEditingController.text != _tableAutocompleteController.text) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) textEditingController.text = _tableAutocompleteController.text;
                  });
                }
                return TextFormField(
                  controller: textEditingController, // Use the Autocomplete's provided controller
                  focusNode: focusNode,
                  decoration: _buildDialogTextFieldDecoration(
                    'Select Table',
                    suffixIcon: textEditingController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        textEditingController.clear(); // Clear the UI
                        setState(() { // Update state and associated controllers
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
                    // This listener ensures that _tableAutocompleteController stays updated
                    // even if the user types something not in the options or clears it.
                    _tableAutocompleteController.text = value;
                    if (!_tables.contains(value) && _selectedTable != null && _selectedTable != value) {
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
                setState(() {
                  _selectedTable = selection;
                  _tableAutocompleteController.text = selection; // Update dedicated controller
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
                fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
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
                      _masterFieldAutocompleteController.text = value; // Keep dedicated controller updated
                      if (!_fields.contains(value) && _selectedMasterField != null && _selectedMasterField != value) {
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
                  setState(() {
                    _selectedMasterField = selection;
                    _masterFieldAutocompleteController.text = selection;
                    if (_selectedDisplayField == null || _selectedDisplayField == widget.currentParam['master_field'] || !(_fields.contains(_selectedDisplayField))) {
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
                fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
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
                      _displayFieldAutocompleteController.text = value; // Keep dedicated controller updated
                      if (!_fields.contains(value) && _selectedDisplayField != null && _selectedDisplayField != value) {
                        setState(() {
                          _selectedDisplayField = null;
                          _allFieldData = [];
                        });
                      }
                    },
                  );
                },
                onSelected: (String selection) {
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
                      onPressed: _dbPickerSearchController.clear,
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
                      return ListTile(
                        title: Text(displayLabel ?? '', style: GoogleFonts.poppins()),
                        subtitle: (displayLabel != masterValue && masterValue != null && masterValue.isNotEmpty)
                            ? Text('API Value: ($masterValue)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))
                            : null,
                        onTap: () {
                          if (!context.mounted) return;
                          Navigator.pop(context, {
                            'config_type': 'database',
                            'value': masterValue,
                            'display_label': displayLabel,
                            'master_table': _selectedTable,
                            'master_field': _selectedMasterField,
                            'display_field': _selectedDisplayField,
                            'options': [],
                            'selected_values': [],
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
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  title: Text(option['label']!, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  subtitle: Text('API Value: ${option['value']!}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  leading: isRadio
                      ? Radio<String>(
                    value: option['value']!,
                    groupValue: _radioSelectedValue,
                    onChanged: (String? value) {
                      setState(() {
                        _radioSelectedValue = value;
                      });
                    },
                  )
                      : Checkbox(
                    value: _checkboxSelectedValues.contains(option['value']!),
                    onChanged: (bool? checked) {
                      setState(() {
                        if (checked == true) {
                          _checkboxSelectedValues.add(option['value']!);
                        } else {
                          _checkboxSelectedValues.remove(option['value']!);
                        }
                      });
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _removeOption(index),
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
    String? finalValue;
    String? finalDisplayLabel;
    Map<String, dynamic> result = {
      'config_type': _selectedConfigType,
      'master_table': null,
      'master_field': null,
      'display_field': null,
      'options': _options,
      'selected_values': [],
    };

    if (_selectedConfigType == 'radio') {
      finalValue = _radioSelectedValue;
      finalDisplayLabel = _options.firstWhere((opt) => opt['value'] == finalValue, orElse: () => {})['label'];
      result['selected_values'] = finalValue != null ? [finalValue] : [];
    } else if (_selectedConfigType == 'checkbox') {
      finalValue = _checkboxSelectedValues.join(',');
      finalDisplayLabel = _checkboxSelectedValues.map((val) =>
      _options.firstWhere((opt) => opt['value'] == val, orElse: () => {})['label'] ?? '').join(', ');
      result['selected_values'] = _checkboxSelectedValues;
    } else {
      finalValue = widget.currentParam['value'];
      finalDisplayLabel = widget.currentParam['display_value_cache'];
      result['master_table'] = _selectedTable;
      result['master_field'] = _selectedMasterField;
      result['display_field'] = _selectedDisplayField;
    }

    result['value'] = finalValue;
    result['display_label'] = finalDisplayLabel;
    Navigator.pop(context, result);
  }
}