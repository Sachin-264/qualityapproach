import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../ReportUtils/Appbar.dart';
import '../../ReportUtils/subtleloader.dart';
import '../ReportAPIService.dart';
import 'EditReportAdmin/EditReportAdmin.dart';
import 'ReportAdminBloc.dart';
import 'package:intl/intl.dart';
import 'dart:async';


class ReportAdminUI extends StatefulWidget {
  const ReportAdminUI({super.key});

  @override
  _ReportAdminUIState createState() => _ReportAdminUIState();
}

class _ReportAdminUIState extends State<ReportAdminUI> {
  final TextEditingController _serverIPController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _databaseNameController = TextEditingController();
  final TextEditingController _apiServerURLController = TextEditingController();
  final TextEditingController _apiNameController = TextEditingController();
  final Map<int, TextEditingController> _paramControllers = {};
  bool _showParameters = false;
  bool _isParsingParameters = false;
  bool _wasLoading = false;
  bool _wasSaving = false;

  late final ReportAdminBloc _bloc;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _bloc = ReportAdminBloc(ReportAPIService());

    _serverIPController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateServerIP(_serverIPController.text));
    }));

    _userNameController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateUserName(_userNameController.text));
    }));

    _passwordController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdatePassword(_passwordController.text));
    }));

    _databaseNameController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateDatabaseName(_databaseNameController.text));
    }));

    _apiServerURLController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateApiServerURL(_apiServerURLController.text));
    }));

    _apiNameController.addListener(() => _debouncedUpdate(() {
      _bloc.add(UpdateApiName(_apiNameController.text));
    }));
  }

  void _debouncedUpdate(VoidCallback callback) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), callback);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _serverIPController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _databaseNameController.dispose();
    _apiServerURLController.dispose();
    _apiNameController.dispose();
    _paramControllers.values.forEach((controller) => controller.dispose());
    _bloc.close();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? label,
    FocusNode? focusNode,
    IconData? icon,
    bool obscureText = false,
    bool isDateField = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      readOnly: isDateField,
      onTap: onTap,
      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w600),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22.0) : null,
        suffixIcon: isDateField ? Icon(Icons.calendar_today, color: Colors.blueAccent, size: 20) : null,
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

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? label,
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
      _bloc.add(UpdateParameterValue(index, formattedDate));
    }
  }

  void _showSummaryDialog(BuildContext context, ReportAdminState state) {
    final uri = Uri.parse(state.apiServerURL);
    final baseUrl = '${uri.scheme}://${uri.host}${uri.path}?';
    final originalParams = uri.queryParameters;
    final queryParams = <String, String>{};
    final changedParams = <String, bool>{};

    for (var param in state.parameters) {
      final name = param['name'].toString();
      final value = param['value'].toString();
      queryParams[name] = value;
      changedParams[name] = originalParams[name] != value;
    }

    final updatedUri = Uri.parse(state.apiServerURL).replace(queryParameters: queryParams);

    final queryParts = state.parameters.asMap().entries.map((entry) {
      final name = entry.value['name'].toString();
      final value = entry.value['value'].toString();
      final changed = changedParams[name] ?? false;
      return {'name': name, 'value': value, 'changed': changed};
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        title: Text(
          'Configuration Summary',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Server IP: ${state.serverIP}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('Username: ${state.userName}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('Password: ${state.password}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('Database Name: ${state.databaseName}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('API Server URL: ${state.apiServerURL}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('API Name: ${state.apiName}', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Text('Updated URL:', style: GoogleFonts.poppins(fontSize: 14)),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                  children: [
                    TextSpan(text: baseUrl),
                    ...queryParts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final param = entry.value;
                      final isLast = index == queryParts.length - 1;
                      return TextSpan(
                        text: '${param['name']}=${param['value']}${isLast ? '' : '&'}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: param['changed'] as bool ? Colors.blueAccent : Colors.black87,
                          fontWeight: param['changed'] as bool ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
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
              Navigator.pop(context);
              setState(() {
                _wasSaving = true;
              });
              _bloc.add(SaveDatabaseServer());
            },
            child: Text(
              'Confirm',
              style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  List<List<Map<String, dynamic>>> _groupParameters(List<Map<String, dynamic>> parameters) {
    final List<List<Map<String, dynamic>>> grouped = [];
    final List<Map<String, dynamic>> remaining = List.from(parameters);
    final datePairNames = ['FromDate', 'ToDate'];

    final datePair = <Map<String, dynamic>>[];
    for (var name in datePairNames) {
      final index = remaining.indexWhere((p) => p['name'] == name);
      if (index != -1) {
        datePair.add(remaining[index]);
        remaining.removeAt(index);
      }
    }
    if (datePair.isNotEmpty) {
      grouped.add(datePair);
    }

    int index = 0;
    while (index < remaining.length) {
      if (index + 1 < remaining.length && index % 3 == 0) {
        grouped.add([remaining[index], remaining[index + 1]]);
        index += 2;
      } else {
        grouped.add([remaining[index]]);
        index += 1;
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _bloc,
      child: Scaffold(
        appBar: AppBarWidget(
          title: 'Database Server Configuration',
          onBackPress: () => Navigator.pop(context),
        ),
        body: BlocConsumer<ReportAdminBloc, ReportAdminState>(
          listenWhen: (previous, current) =>
          previous.error != current.error ||
              previous.isLoading != current.isLoading ||
              previous.parameters.length != current.parameters.length ||
              previous.availableDatabases != current.availableDatabases,
          listener: (context, state) {
            print('Listener triggered: isLoading=${state.isLoading}, error=${state.error}, '
                'databases=${state.availableDatabases.length}, parameters=${state.parameters.length}, '
                'wasSaving=$_wasSaving');
            if (state.error != null) {
              String errorMessage = state.error!;
              if (errorMessage.contains('Failed to fetch databases')) {
                errorMessage = 'Unable to fetch databases. Please check server connection or credentials.';
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    errorMessage,
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 5),
                ),
              );
            } else if (!state.isLoading && _wasSaving && state.error == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Database server saved successfully',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 3),
                ),
              );
              _serverIPController.clear();
              _userNameController.clear();
              _passwordController.clear();
              _databaseNameController.clear();
              _apiServerURLController.clear();
              _apiNameController.clear();
              _paramControllers.clear();
              setState(() {
                _showParameters = false;
                _isParsingParameters = false;
                _wasSaving = false;
              });
              context.read<ReportAdminBloc>().add(ResetAdminState());
            }
            _wasLoading = state.isLoading;
            if (_isParsingParameters && (state.parameters.isNotEmpty || state.error != null)) {
              setState(() {
                _isParsingParameters = false;
              });
            }
            if (!_showParameters) {
              _paramControllers.clear();
              setState(() {
                _isParsingParameters = false;
              });
            }
          },
          buildWhen: (previous, current) =>
          previous.serverIP != current.serverIP ||
              previous.userName != current.userName ||
              previous.password != current.password ||
              previous.databaseName != current.databaseName ||
              previous.availableDatabases != current.availableDatabases ||
              previous.apiServerURL != current.apiServerURL ||
              previous.apiName != current.apiName ||
              previous.parameters != current.parameters ||
              previous.isLoading != current.isLoading,
          builder: (context, state) {
            print('BlocConsumer rebuild: parameters=${state.parameters.length}, '
                'databases=${state.availableDatabases}');
            return Column(
              children: [
                // NEW: Edit Button at the Top
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildButton(
                        text: 'Edit Config',
                        color: Colors.purpleAccent,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const EditReportAdmin()),
                          );
                        },
                        icon: Icons.edit,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
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
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Password',
                                icon: Icons.lock,
                                obscureText: true,
                              ),
                              const SizedBox(height: 16),
                              state.isLoading && state.availableDatabases.isEmpty
                                  ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.blueAccent,
                                ),
                              )
                                  : _buildDropdownField(
                                value: state.databaseName,
                                items: state.availableDatabases,
                                onChanged: (value) {
                                  if (value != null) {
                                    _databaseNameController.text = value;
                                    context.read<ReportAdminBloc>().add(UpdateDatabaseName(value));
                                  }
                                },
                                label: 'Database Name',
                                icon: Icons.storage,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _apiServerURLController,
                                label: 'API Server URL',
                                icon: Icons.link,
                              ),
                              const SizedBox(height: 16),
                              _buildButton(
                                text: _showParameters ? 'Hide Parameters' : 'Show Parameters',
                                color: Colors.green,
                                onPressed: () {
                                  setState(() {
                                    _showParameters = !_showParameters;
                                    if (_showParameters) {
                                      _isParsingParameters = true;
                                      context.read<ReportAdminBloc>().add(ParseParameters());
                                    } else {
                                      _paramControllers.clear();
                                      _apiNameController.clear();
                                      _isParsingParameters = false;
                                      context.read<ReportAdminBloc>().add(UpdateApiName(''));
                                    }
                                  });
                                },
                                icon: _showParameters ? Icons.visibility_off : Icons.visibility,
                              ),
                              const SizedBox(height: 16),
                              if (_showParameters) ...[
                                _buildTextField(
                                  controller: _apiNameController,
                                  label: 'API Name',
                                  icon: Icons.api,
                                ),
                                const SizedBox(height: 20),
                                _isParsingParameters
                                    ? Center(
                                  child: state.parameters.isEmpty && state.error == null
                                      ? Text(
                                    'No parameters found in URL',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                      : const CircularProgressIndicator(
                                    color: Colors.blueAccent,
                                  ),
                                )
                                    : state.parameters.isEmpty && _apiServerURLController.text.isNotEmpty
                                    ? Text(
                                  'No parameters found in URL',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                                    : state.parameters.isEmpty && _apiServerURLController.text.isEmpty
                                    ? Text(
                                  'Enter an API Server URL to load parameters',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                                    : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'URL Parameters',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ..._groupParameters(state.parameters).asMap().entries.map((groupEntry) {
                                      final group = groupEntry.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 16.0),
                                        child: Row(
                                          children: group.asMap().entries.map((paramEntry) {
                                            final paramIndex = state.parameters.indexOf(paramEntry.value);
                                            final param = paramEntry.value;
                                            final isDate = _isDateParameter(param['name'], param['value']);
                                            _paramControllers[paramIndex] ??= TextEditingController(
                                              text: param['value'].toString(),
                                            )..addListener(() {
                                              _debouncedUpdate(() {
                                                context.read<ReportAdminBloc>().add(
                                                  UpdateParameterValue(
                                                    paramIndex,
                                                    _paramControllers[paramIndex]!.text,
                                                  ),
                                                );
                                              });
                                            });
                                            return Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(right: 8.0),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: _buildTextField(
                                                        controller: _paramControllers[paramIndex]!,
                                                        label: param['name'],
                                                        isDateField: isDate,
                                                        onTap: isDate
                                                            ? () => _selectDate(
                                                          context,
                                                          _paramControllers[paramIndex]!,
                                                          paramIndex,
                                                        )
                                                            : null,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Checkbox(
                                                      value: param['show'] ?? false,
                                                      onChanged: (value) {
                                                        context.read<ReportAdminBloc>().add(
                                                          UpdateParameterShow(
                                                            paramIndex,
                                                            value ?? false,
                                                          ),
                                                        );
                                                      },
                                                      activeColor: Colors.blueAccent,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildButton(
                                    text: 'Save',
                                    color: Colors.blueAccent,
                                    onPressed: state.serverIP.isNotEmpty &&
                                        state.userName.isNotEmpty &&
                                        state.password.isNotEmpty &&
                                        state.databaseName.isNotEmpty &&
                                        state.apiServerURL.isNotEmpty &&
                                        (!_showParameters || state.parameters.isEmpty || state.apiName.isNotEmpty) &&
                                        !state.isLoading
                                        ? () => _showSummaryDialog(context, state)
                                        : null,
                                    icon: Icons.save,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildButton(
                                    text: 'Reset',
                                    color: Colors.redAccent,
                                    onPressed: state.isLoading
                                        ? null
                                        : () {
                                      _serverIPController.clear();
                                      _userNameController.clear();
                                      _passwordController.clear();
                                      _databaseNameController.clear();
                                      _apiServerURLController.clear();
                                      _apiNameController.clear();
                                      _paramControllers.clear();
                                      setState(() {
                                        _showParameters = false;
                                        _isParsingParameters = false;
                                      });
                                      context.read<ReportAdminBloc>().add(ResetAdminState());
                                    },
                                    icon: Icons.refresh,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                state.isLoading ? const SubtleLoader() : const SizedBox.shrink(),
              ],
            );
          },
        ),
      ),
    );
  }
}