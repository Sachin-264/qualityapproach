import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../ReportUtils/Appbar.dart';
import '../../ReportAPIService.dart';
import 'EditDetailAdminBloc.dart';
import 'dart:async';

class EditDetailAdmin extends StatefulWidget {
  final Map<String, dynamic> apiData;

  const EditDetailAdmin({super.key, required this.apiData});

  @override
  _EditDetailAdminState createState() => _EditDetailAdminState();
}

class _EditDetailAdminState extends State<EditDetailAdmin> {
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

    // Add listeners for state updates
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool obscureText = false,
    bool isSmall = false,
    bool isDateField = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      readOnly: isDateField,
      onTap: onTap,
      style: GoogleFonts.poppins(fontSize: isSmall ? 14 : 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey[700],
          fontSize: isSmall ? 13 : 15,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: isSmall ? 20 : 22) : null,
        suffixIcon: isDateField ? Icon(Icons.calendar_today, color: Colors.blueAccent, size: isSmall ? 18 : 20) : null,
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
    final datePattern = RegExp(r'^\d{2}-[A-Za-z]{3}-\d{4}$');
    return name.toLowerCase().contains('date') || datePattern.hasMatch(value);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller, int index) async {
    DateTime? initialDate;
    try {
      initialDate = DateFormat('dd-MMM-yyyy').parse(controller.text);
    } catch (e) {
      initialDate = DateTime.now();
    }

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
      final formattedDate = DateFormat('dd-MMM-yyyy').format(picked);
      controller.text = formattedDate;
      context.read<EditDetailAdminBloc>().add(UpdateParameterValue(index, formattedDate));
    }
  }

  void _debouncedUpdate(VoidCallback callback) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), callback);
  }

  List<Widget> _buildParameterRows(List<Map<String, dynamic>> parameters, BuildContext context) {
    final List<Widget> rows = [];
    final dateParams = <Map<String, dynamic>>[];
    final nonDateParams = <Map<String, dynamic>>[];

    // Separate date and non-date parameters
    for (var param in parameters) {
      if (_isDateParameter(param['name'], param['value'])) {
        dateParams.add(param);
      } else {
        nonDateParams.add(param);
      }
    }

    // Handle date parameters (group FromDate and ToDate in one row)
    for (var i = 0; i < dateParams.length; i += 2) {
      final param1 = dateParams[i];
      final param2 = i + 1 < dateParams.length ? dateParams[i + 1] : null;
      final index1 = parameters.indexOf(param1);
      final index2 = param2 != null ? parameters.indexOf(param2) : null;

      _paramControllers[index1] ??= TextEditingController(text: param1['value'].toString())
        ..addListener(() {
          _debouncedUpdate(() {
            context.read<EditDetailAdminBloc>().add(UpdateParameterValue(index1, _paramControllers[index1]!.text));
          });
        });

      if (param2 != null) {
        _paramControllers[index2!] ??= TextEditingController(text: param2['value'].toString())
          ..addListener(() {
            _debouncedUpdate(() {
              context.read<EditDetailAdminBloc>().add(UpdateParameterValue(index2, _paramControllers[index2]!.text));
            });
          });
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _paramControllers[index1]!,
                  label: param1['name'],
                  isSmall: true,
                  isDateField: true,
                  onTap: () => _selectDate(context, _paramControllers[index1]!, index1),
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: param1['show'] ?? false,
                onChanged: (value) {
                  context.read<EditDetailAdminBloc>().add(UpdateParameterShow(index1, value ?? false));
                },
                activeColor: Colors.blueAccent,
              ),
              const SizedBox(width: 16),
              if (param2 != null) ...[
                Expanded(
                  child: _buildTextField(
                    controller: _paramControllers[index2!]!,
                    label: param2['name'],
                    isSmall: true,
                    isDateField: true,
                    onTap: () => _selectDate(context, _paramControllers[index2]!, index2),
                  ),
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: param2['show'] ?? false,
                  onChanged: (value) {
                    context.read<EditDetailAdminBloc>().add(UpdateParameterShow(index2, value ?? false));
                  },
                  activeColor: Colors.blueAccent,
                ),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }

    // Handle non-date parameters (2 per row, then 1, alternating)
    for (var i = 0; i < nonDateParams.length; i++) {
      final param = nonDateParams[i];
      final index = parameters.indexOf(param);

      _paramControllers[index] ??= TextEditingController(text: param['value'].toString())
        ..addListener(() {
          _debouncedUpdate(() {
            context.read<EditDetailAdminBloc>().add(UpdateParameterValue(index, _paramControllers[index]!.text));
          });
        });

      if (i % 3 == 0 && i + 1 < nonDateParams.length) {
        // Two parameters in one row
        final param2 = nonDateParams[i + 1];
        final index2 = parameters.indexOf(param2);

        _paramControllers[index2] ??= TextEditingController(text: param2['value'].toString())
          ..addListener(() {
            _debouncedUpdate(() {
              context.read<EditDetailAdminBloc>().add(UpdateParameterValue(index2, _paramControllers[index2]!.text));
            });
          });

        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _paramControllers[index]!,
                    label: param['name'],
                    isSmall: true,
                  ),
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: param['show'] ?? false,
                  onChanged: (value) {
                    context.read<EditDetailAdminBloc>().add(UpdateParameterShow(index, value ?? false));
                  },
                  activeColor: Colors.blueAccent,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _paramControllers[index2]!,
                    label: param2['name'],
                    isSmall: true,
                  ),
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: param2['show'] ?? false,
                  onChanged: (value) {
                    context.read<EditDetailAdminBloc>().add(UpdateParameterShow(index2, value ?? false));
                  },
                  activeColor: Colors.blueAccent,
                ),
              ],
            ),
          ),
        );
        i++; // Skip the next parameter since it was already processed
      } else {
        // One parameter in a row
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _paramControllers[index]!,
                    label: param['name'],
                    isSmall: true,
                  ),
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: param['show'] ?? false,
                  onChanged: (value) {
                    context.read<EditDetailAdminBloc>().add(UpdateParameterShow(index, value ?? false));
                  },
                  activeColor: Colors.blueAccent,
                ),
              ],
            ),
          ),
        );
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditDetailAdminBloc(ReportAPIService(), widget.apiData)
        ..add(FetchDatabases(
          serverIP: widget.apiData['ServerIP'] ?? '',
          userName: widget.apiData['UserName'] ?? '',
          password: widget.apiData['Password'] ?? '',
        )),
      child: Scaffold(
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
              Navigator.pop(context);
            }
          },
          builder: (context, state) {
            _serverIPController.text = state.serverIP;
            _userNameController.text = state.userName;
            _passwordController.text = state.password;
            _databaseNameController.text = state.databaseName;
            _apiServerURLController.text = state.apiServerURL;
            _apiNameController.text = state.apiName;

            return Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
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
                                    child: CircularProgressIndicator(color: Colors.blueAccent),
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
                              ..._buildParameterRows(state.parameters, context),
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
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icons.cancel,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (state.isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}