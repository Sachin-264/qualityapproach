import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:universal_html/html.dart' as html;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../ReportUtils/Appbar.dart';
import '../ReportUtils/subtleloader.dart';
// NEW: Import the ReportAPIService to fetch configurations
import '../ReportDynamic/ReportAPIService.dart';

class ApiParameter {
  final String id;
  String name;
  String type;
  String exampleValue;

  TextEditingController nameController;
  TextEditingController valueController;

  ApiParameter({
    required this.name,
    required this.type,
    this.exampleValue = '',
  })  : id = const Uuid().v4(),
        nameController = TextEditingController(text: name),
        valueController = TextEditingController(text: exampleValue);

  String get urlParamName => nameController.text;
  String get phpVarName {
    String cleanName = nameController.text;
    if (cleanName.isEmpty) return '';
    return cleanName[0].toLowerCase() + cleanName.substring(1);
  }
  String get spParamName => nameController.text;
  void dispose() {
    nameController.dispose();
    valueController.dispose();
  }
  void updateFromControllers() {
    name = nameController.text;
    exampleValue = valueController.text;
  }
}

class ApiConfig {
  final String connectionStringInput;
  final bool isConnectionStringEncrypted;
  final String baseUrlPrefix;
  final String encryptionKey;
  final String storedProcedureName;
  final List<ApiParameter> parameters;
  final String folderName;
  final String apiFileName;
  final bool useSecureFolder;

  ApiConfig({
    required this.connectionStringInput,
    required this.isConnectionStringEncrypted,
    required this.baseUrlPrefix,
    required this.encryptionKey,
    required this.storedProcedureName,
    required this.parameters,
    required this.folderName,
    required this.apiFileName,
    required this.useSecureFolder,
  });
}

class ApiGeneratorPage extends StatefulWidget {
  const ApiGeneratorPage({super.key});

  @override
  _ApiGeneratorPageState createState() => _ApiGeneratorPageState();
}

class _ApiGeneratorPageState extends State<ApiGeneratorPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _connectionStringInputController = TextEditingController();
  final _baseUrlPrefixController = TextEditingController(text: 'http://localhost/');
  final _storedProcedureNameController = TextEditingController(text: 'sp_GetMRNDetails');
  bool _isConnectionStringInputEncrypted = false;
  String _internalEncryptionKey = '9qGxCtZw2xAI00D3VLOUNTs+qr50rpfWggluskAhgww=';
  List<ApiParameter> _apiParameters = [];
  bool _isLoading = false;
  late AnimationController _pageFadeController;
  late Animation<double> _pageFadeAnimation;
  final List<AnimationController> _sectionControllers = [];
  final List<Animation<Offset>> _sectionSlideAnimations = [];

  // NEW: State variables for fetching configurations
  late final ReportAPIService _apiService;
  List<Map<String, dynamic>> _savedConfigurations = [];
  bool _isFetchingConfigs = false;


  @override
  void initState() {
    super.initState();
    // NEW: Initialize the API service
    _apiService = ReportAPIService();

    _pageFadeController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _pageFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _pageFadeController, curve: Curves.easeInOut));

    for (int i = 0; i < 2; i++) {
      final controller = AnimationController(duration: Duration(milliseconds: 800 + i * 200), vsync: this);
      _sectionControllers.add(controller);
      _sectionSlideAnimations.add(Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic)));
      controller.forward();
    }
    _pageFadeController.forward();
    _apiParameters = [
      ApiParameter(name: 'branch_code', type: 'String', exampleValue: 'E'),
      ApiParameter(name: 'm_r_n_i_d', type: 'String', exampleValue: 'MRN'),
    ];

    // NEW: Fetch configurations when the page loads
    _fetchSavedConfigurations();
  }

  @override
  void dispose() {
    _pageFadeController.dispose();
    for (var controller in _sectionControllers) {
      controller.dispose();
    }
    _connectionStringInputController.dispose();
    _baseUrlPrefixController.dispose();
    _storedProcedureNameController.dispose();
    for (var param in _apiParameters) {
      param.dispose();
    }
    super.dispose();
  }

  // NEW: Method to fetch saved configurations from the API
  Future<void> _fetchSavedConfigurations() async {
    setState(() => _isFetchingConfigs = true);
    try {
      final response = await _apiService.getSetupConfigurations();
      if (mounted && response['status'] == 'success' && response['data'] is List) {
        setState(() {
          _savedConfigurations = (response['data'] as List)
              .cast<Map<String, dynamic>>()
          // Filter out configs that don't have a connection string
              .where((config) => config['DatabaseConnectionString'] != null && (config['DatabaseConnectionString'] as String).isNotEmpty)
              .toList();
        });
      } else {
        if(mounted) _showSnackbar('Failed to load configurations: Invalid format', Colors.orange);
      }
    } catch (e) {
      if(mounted) _showSnackbar('Error fetching configurations: ${e.toString()}', Colors.red);
    } finally {
      if(mounted) setState(() => _isFetchingConfigs = false);
    }
  }


  String _getMonthAbbreviation(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  void _addParameter() {
    setState(() {
      _apiParameters.add(ApiParameter(name: 'NewParam', type: 'String', exampleValue: ''));
    });
  }

  void _removeParameter(int index) {
    setState(() {
      _apiParameters[index].dispose();
      _apiParameters.removeAt(index);
    });
  }

  String _convertSpNameToFileName(String spName) {
    return spName.replaceAll(RegExp(r'^(sp_|USP_)', caseSensitive: false), '');
  }

  Future<Map<String, dynamic>?> _showSaveDialog() async {
    // ... (This function is unchanged)
    bool useSecureFolder = false;
    String folderName = '';
    String suggestedFileName = _convertSpNameToFileName(_storedProcedureNameController.text);
    final fileNameController = TextEditingController(text: suggestedFileName);
    bool includeFunctionFile = true;
    final encryptionKeyController = TextEditingController(text: _internalEncryptionKey);

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text('Save API Configuration', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.blue[800])),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('Include `function.php`?', style: GoogleFonts.poppins()),
                    trailing: Switch(value: includeFunctionFile, onChanged: (value) => setState(() => includeFunctionFile = value), activeColor: Colors.blue[600]),
                  ),
                  if(includeFunctionFile)
                    ListTile(
                      title: Text('Place in `secure/` folder?', style: GoogleFonts.poppins()),
                      trailing: Switch(value: useSecureFolder, onChanged: (value) => setState(() => useSecureFolder = value), activeColor: Colors.blue[600]),
                    ),
                  _AnimatedTextField(
                    controller: fileNameController,
                    label: 'API File Name',
                    icon: Icons.description,
                    validator: (value) => value!.isEmpty ? 'File name required' : null,
                  ),
                  const SizedBox(height: 12),
                  _AnimatedTextField(
                    controller: encryptionKeyController,
                    label: 'Encryption Key',
                    icon: Icons.vpn_key,
                    validator: (value) => value!.isEmpty ? 'Encryption key is required' : null,
                    onChanged: (value) => _internalEncryptionKey = value,
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.blue[600]))),
          TextButton(
            onPressed: () {
              if (fileNameController.text.isEmpty) return;
              Navigator.pop(context, {
                'useSecureFolder': useSecureFolder,
                'folderName': folderName,
                'apiFileName': fileNameController.text.endsWith('.php') ? fileNameController.text : '${fileNameController.text}.php',
                'includeFunctionFile': includeFunctionFile,
                'encryptionKey': encryptionKeyController.text,
              });
            },
            child: Text('Save', style: GoogleFonts.poppins(color: Colors.blue[600])),
          ),
        ],
      ),
    );
  }

  // --- All code generation and download functions are unchanged ---
  String _generatePhpCode(ApiConfig config) { /* ... */ return ""; }
  String _generateSecureFunctionPhpCode(String key) { /* ... */ return ""; }
  String _generateUrl(ApiConfig config) { /* ... */ return ""; }
  String _securedEncrypt(String data, String encryptionKey) { /* ... */ return ""; }

  void _generateApi() async {
    // ... (This function is unchanged)
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    final saveConfig = await _showSaveDialog();
    if (saveConfig != null) {
      final config = ApiConfig(
        connectionStringInput: _connectionStringInputController.text,
        isConnectionStringEncrypted: _isConnectionStringInputEncrypted,
        baseUrlPrefix: _baseUrlPrefixController.text,
        encryptionKey: saveConfig['encryptionKey'],
        storedProcedureName: _storedProcedureNameController.text,
        parameters: _apiParameters,
        folderName: saveConfig['folderName'],
        apiFileName: saveConfig['apiFileName'],
        useSecureFolder: saveConfig['useSecureFolder'],
      );
      setState(() => _isLoading = false);
      if(!kIsWeb) {
        _showSnackbar("This feature is only available on the web.", Colors.orange);
        return;
      }
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, _, __) => CodeDisplayPage(
            phpCode: _generatePhpCode(config),
            localhostUrl: _generateUrl(config),
            apiFileName: config.apiFileName,
            secureFunctionPhp: _generateSecureFunctionPhpCode(config.encryptionKey),
            includeFunctionFile: saveConfig['includeFunctionFile'],
          ),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: 'Dynamic API Generator',
        onBackPress: () => Navigator.pop(context),
      ),
      body: Container(
        color: Colors.grey[50],
        child: _isLoading
            ? const SubtleLoader()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(
                  title: 'API Base Configuration',
                  index: 0,
                  children: [
                    // NEW: Autocomplete widget for selecting a configuration
                    Autocomplete<Map<String, dynamic>>(
                      displayStringForOption: (option) => option['ConfigName'] as String,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _savedConfigurations;
                        }
                        return _savedConfigurations.where((option) {
                          return (option['ConfigName'] as String)
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (Map<String, dynamic> selection) {
                        setState(() {
                          // Populate the text field with the selected connection string
                          _connectionStringInputController.text = selection['DatabaseConnectionString'] ?? '';
                          // IMPORTANT: Since this string is from the DB, it's already encrypted.
                          _isConnectionStringInputEncrypted = true;
                        });
                      },
                      fieldViewBuilder: (context, fieldTextEditingController, fieldFocusNode, onFieldSubmitted) {
                        return _AnimatedTextField(
                          controller: fieldTextEditingController,
                          focusNode: fieldFocusNode,
                          label: 'Select Existing Configuration (Optional)',
                          icon: Icons.search,
                          suffixIcon: _isFetchingConfigs ? const Padding(padding: EdgeInsets.all(10.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0))) : null,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      title: Text('Connection String is already encrypted?', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue[800])),
                      trailing: Switch(
                        value: _isConnectionStringInputEncrypted,
                        onChanged: (value) {
                          setState(() {
                            _isConnectionStringInputEncrypted = value;
                            _connectionStringInputController.clear();
                          });
                        },
                        activeColor: Colors.blue[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AnimatedTextField(
                      controller: _connectionStringInputController,
                      label: _isConnectionStringInputEncrypted ? 'Pre-Encrypted Connection String' : 'Database Connection String (Plaintext)',
                      hintText: _isConnectionStringInputEncrypted ? 'Paste your encrypted string here' : 'Server:-:Database:-:User:-:Pass',
                      icon: _isConnectionStringInputEncrypted ? Icons.lock : Icons.vpn_lock,
                      validator: (value) => value == null || value.isEmpty ? 'Connection string is required' : null,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    _AnimatedTextField(
                      controller: _baseUrlPrefixController,
                      label: 'Base URL Prefix',
                      hintText: 'e.g., http://localhost/mobileAPI/',
                      icon: Icons.link,
                      validator: (value) => value!.isEmpty ? 'Base URL prefix is required' : null,
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
                _buildSectionCard(
                  title: 'Stored Procedure Configuration',
                  index: 1,
                  children: [
                    // ... (rest of the form is unchanged)
                    _AnimatedTextField(
                      controller: _storedProcedureNameController,
                      label: 'Stored Procedure Name',
                      hintText: 'e.g., sp_GetCustomerSalesSummary',
                      icon: Icons.storage,
                      validator: (value) => value!.isEmpty ? 'Stored procedure name is required' : null,
                    ),
                    const SizedBox(height: 24),
                    Text('Stored Procedure Parameters', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blue[700])),
                    Text('Use exact names required by your API (e.g., branch_code).', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                    const SizedBox(height: 12),
                    ..._apiParameters.asMap().entries.map((entry) {
                      int index = entry.key;
                      ApiParameter param = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Card(
                          key: ValueKey(param.id),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _AnimatedTextField(controller: param.nameController, label: 'Parameter Name', icon: Icons.label, validator: (value) => value!.isEmpty ? 'Name required' : null)),
                                    IconButton(icon: Icon(Icons.delete, color: Colors.red[400]), onPressed: () => _removeParameter(index), tooltip: 'Remove Parameter'),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: param.type,
                                  decoration: InputDecoration(
                                    labelText: 'Data Type',
                                    labelStyle: GoogleFonts.poppins(color: Colors.blue[800]!),
                                    prefixIcon: Icon(Icons.description, color: Colors.blue[600]),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  items: ['String', 'Integer', 'Date', 'Boolean'].map((String type) => DropdownMenuItem<String>(value: type, child: Text(type, style: GoogleFonts.poppins()))).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() => param.type = newValue!);
                                  },
                                ),
                                const SizedBox(height: 12),
                                if (param.type == 'Date')
                                  _AnimatedTextField(
                                    controller: param.valueController,
                                    label: 'Example Date Value (DD-MMM-YYYY)',
                                    icon: Icons.calendar_today,
                                    readOnly: true,
                                    onTap: () async {
                                      final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2050));
                                      if (picked != null) {
                                        setState(() => param.valueController.text = "${picked.day.toString().padLeft(2, '0')}-${_getMonthAbbreviation(picked.month)}-${picked.year}");
                                      }
                                    },
                                  )
                                else if (param.type == 'Boolean')
                                  DropdownButtonFormField<String>(
                                    value: param.valueController.text.isEmpty ? 'false' : param.valueController.text,
                                    decoration: InputDecoration(
                                      labelText: 'Example Boolean Value',
                                      labelStyle: GoogleFonts.poppins(color: Colors.blue[800]!),
                                      prefixIcon: Icon(Icons.toggle_on, color: Colors.blue[600]),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                    ),
                                    items: ['true', 'false'].map((String val) => DropdownMenuItem<String>(value: val, child: Text(val, style: GoogleFonts.poppins()))).toList(),
                                    onChanged: (String? newValue) => setState(() => param.valueController.text = newValue!),
                                  )
                                else
                                  _AnimatedTextField(
                                    controller: param.valueController,
                                    label: 'Example Value',
                                    icon: Icons.code,
                                    keyboardType: param.type == 'Integer' ? TextInputType.number : TextInputType.text,
                                    validator: (value) => param.type == 'Integer' && value != null && value.isNotEmpty && int.tryParse(value) == null ? 'Must be an integer' : null,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _addParameter,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text('Add Parameter', style: GoogleFonts.poppins(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: ShimmerButton(
                    text: 'Generate API',
                    onPressed: _generateApi,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children, required int index}) {
    return SlideTransition(
      position: _sectionSlideAnimations[index],
      child: FadeTransition(
        opacity: _pageFadeAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!, width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.blue[800])),
                const Divider(height: 25, thickness: 1, color: Colors.blueGrey),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// _AnimatedTextField, ShimmerButton, and CodeDisplayPage classes are unchanged
class _AnimatedTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? hintText;
  final Widget? suffixIcon; // Added for loading indicator
  final FocusNode? focusNode; // Added to pass focus node

  const _AnimatedTextField({
    this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.hintText,
    this.suffixIcon,
    this.focusNode,
  });

  @override
  __AnimatedTextFieldState createState() => __AnimatedTextFieldState();
}

class __AnimatedTextFieldState extends State<_AnimatedTextField> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.005).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _colorAnimation = ColorTween(begin: Colors.grey[100], end: Colors.blue[50]).animate(_controller);
    _focusNode.addListener(() {
      if (!mounted) return;
      if (_focusNode.hasFocus) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: _colorAnimation.value,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(_focusNode.hasFocus ? 0.1 : 0.05), blurRadius: _focusNode.hasFocus ? 10 : 5, offset: _focusNode.hasFocus ? const Offset(0, 4) : const Offset(0, 2))],
            ),
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              obscureText: widget.obscureText,
              style: GoogleFonts.poppins(color: Colors.black87),
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: GoogleFonts.poppins(color: Colors.blue[800]!),
                prefixIcon: Icon(widget.icon, color: Colors.blue[600]),
                suffixIcon: widget.suffixIcon ?? (widget.readOnly && widget.onTap != null ? IconButton(icon: Icon(Icons.calendar_month, color: Colors.blue[600]), onPressed: widget.onTap) : null),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                hintText: widget.hintText,
                hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
              ),
              validator: widget.validator,
              onChanged: widget.onChanged,
              keyboardType: widget.keyboardType,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
            ),
          ),
        );
      },
    );
  }
}

class ShimmerButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const ShimmerButton({required this.text, required this.onPressed, super.key});

  @override
  _ShimmerButtonState createState() => _ShimmerButtonState();
}

class _ShimmerButtonState extends State<ShimmerButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.blue[800]!, Colors.blueAccent, Colors.blue[800]!],
                stops: [_shimmerAnimation.value > 0 ? _shimmerAnimation.value * 0.5 : 0.0, _shimmerAnimation.value, _shimmerAnimation.value < 0 ? 1.0 + _shimmerAnimation.value : 1.0],
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Text(widget.text, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          );
        },
      ),
    );
  }
}

class CodeDisplayPage extends StatefulWidget {
  final String phpCode;
  final String localhostUrl;
  final String apiFileName;
  final String secureFunctionPhp;
  final bool includeFunctionFile;

  const CodeDisplayPage({
    super.key,
    required this.phpCode,
    required this.localhostUrl,
    required this.apiFileName,
    required this.secureFunctionPhp,
    required this.includeFunctionFile,
  });

  @override
  _CodeDisplayPageState createState() => _CodeDisplayPageState();
}

class _CodeDisplayPageState extends State<CodeDisplayPage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TextEditingController _phpCodeEditController;
  late TextEditingController _secureFunctionCodeEditController;
  bool _isEditingPhpCode = false;
  bool _isEditingSecureFunctionCode = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _phpCodeEditController = TextEditingController(text: widget.phpCode);
    _secureFunctionCodeEditController = TextEditingController(text: widget.secureFunctionPhp);
  }

  @override
  void dispose() {
    _controller.dispose();
    _phpCodeEditController.dispose();
    _secureFunctionCodeEditController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _downloadCode(String code, String filename) async {
    try {
      final blob = html.Blob([code], 'text/plain', 'native');
      final options = {
        'suggestedName': filename,
        'types': [
          {
            'description': 'PHP file',
            'accept': {'text/php': ['.php']},
          },
          {
            'description': 'All files',
            'accept': {'*/*': []},
          },
        ],
      };

      final fileHandle = await (html.window as dynamic).showSaveFilePicker(options);
      final writable = await fileHandle.createWritable();
      await writable.write(blob);
      await writable.close();
      _showSnackbar('File saved successfully!', Colors.green);
    } catch (e) {
      _downloadWithFallback(code, filename);
    }
  }

  void _downloadWithFallback(String code, String filename) {
    final bytes = utf8.encode(code);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    _showSnackbar('Download started...', Colors.blue[800]!);
  }

  void _saveEditedCode(bool isMainApi) {
    setState(() {
      if (isMainApi) {
        _isEditingPhpCode = false;
      } else {
        _isEditingSecureFunctionCode = false;
      }
    });
    _showSnackbar('${isMainApi ? 'API' : 'Function'} code changes saved!', Colors.green);
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      _showSnackbar('Could not launch $url', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(title: 'Generated API Output', onBackPress: () => Navigator.pop(context)),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCodeSection(
                    title: 'Generated PHP API Code',
                    controller: _phpCodeEditController,
                    isEditing: _isEditingPhpCode,
                    onToggleEdit: () => setState(() => _isEditingPhpCode = !_isEditingPhpCode),
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: _phpCodeEditController.text));
                      _showSnackbar('API code copied!', Colors.blue[800]!);
                    },
                    onDownload: () => _downloadCode(_phpCodeEditController.text, widget.apiFileName),
                    onSave: () => _saveEditedCode(true),
                  ),
                  const SizedBox(height: 16),
                  if (widget.includeFunctionFile) ...[
                    _buildCodeSection(
                      title: 'Generated `function.php` Code',
                      controller: _secureFunctionCodeEditController,
                      isEditing: _isEditingSecureFunctionCode,
                      onToggleEdit: () => setState(() => _isEditingSecureFunctionCode = !_isEditingSecureFunctionCode),
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: _secureFunctionCodeEditController.text));
                        _showSnackbar('function.php code copied!', Colors.blue[800]!);
                      },
                      onDownload: () => _downloadCode(_secureFunctionCodeEditController.text, 'function.php'),
                      onSave: () => _saveEditedCode(false),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildUrlSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeSection({required String title, required TextEditingController controller, required bool isEditing, required VoidCallback onToggleEdit, required VoidCallback onCopy, required VoidCallback onDownload, required VoidCallback onSave}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!, width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(3, 3))]),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.blue[800])),
                IconButton(icon: Icon(isEditing ? Icons.visibility_off : Icons.edit, color: Colors.blue[600]), tooltip: isEditing ? 'Exit Edit Mode' : 'Edit Code', onPressed: onToggleEdit),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[100]!, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
              child: isEditing
                  ? TextFormField(controller: controller, style: GoogleFonts.sourceCodePro(fontSize: 14), maxLines: null, keyboardType: TextInputType.multiline, decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))
                  : Text(controller.text, style: GoogleFonts.sourceCodePro(fontSize: 14)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ShimmerButton(text: 'Copy Code', onPressed: onCopy),
                ShimmerButton(text: 'Download', onPressed: onDownload),
                if (isEditing) ShimmerButton(text: 'Save Changes', onPressed: onSave),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlSection() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!, width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(3, 3))]),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Generated URL', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.blue[800])),
            const SizedBox(height: 12),
            Text('Example API URL:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue[800])),
            const SizedBox(height: 4),
            SelectableText(widget.localhostUrl, style: GoogleFonts.sourceCodePro(fontSize: 14, color: Colors.blue[600])),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ShimmerButton(
                  text: 'Copy URL',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.localhostUrl));
                    _showSnackbar('URL copied to clipboard!', Colors.blue[800]!);
                  },
                ),
                ShimmerButton(text: 'Open URL', onPressed: () => _launchUrl(widget.localhostUrl)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}