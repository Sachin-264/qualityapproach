import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, radians;
import 'package:universal_html/html.dart' as html;

// Enhanced SubtleLoader with rotation, scale, and glow
class SubtleLoader extends StatefulWidget {
  const SubtleLoader({super.key});

  @override
  _SubtleLoaderState createState() => _SubtleLoaderState();
}

class _SubtleLoaderState extends State<SubtleLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 360).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..scale(_scaleAnimation.value)
              ..rotateZ(radians(_rotationAnimation.value)),
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.5), // Blue glow for the loader
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                strokeWidth: 5,
                backgroundColor: Colors.white10,
              ),
            ),
          );
        },
      ),
    );
  }
}

// Enhanced AppBarWidget with blue theme
class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onBackPress;

  const AppBarWidget({
    super.key,
    required this.title,
    required this.onBackPress,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[800]!, Colors.blue[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: onBackPress,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
      ),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.4),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

// Model for API configuration
class ApiConfig {
  final String server;
  final String database;
  final String username;
  final String password;
  // MODIFIED: StoredProcedure will now hold the full string "EXEC sp_name ?, ?, ?"
  final String storedProcedure;
  final List<String> parameterNames;
  final List<String> hardcodedValues;
  final String folderName;
  final String apiFileName;

  ApiConfig({
    required this.server,
    required this.database,
    required this.username,
    required this.password,
    required this.storedProcedure, // Now includes "EXEC" and "?"s
    required this.parameterNames,
    required this.hardcodedValues,
    required this.folderName,
    required this.apiFileName,
  });
}

// Main API Generator Page
class ApiGeneratorPage extends StatefulWidget {
  const ApiGeneratorPage({super.key});

  @override
  _ApiGeneratorPageState createState() => _ApiGeneratorPageState();
}

class _ApiGeneratorPageState extends State<ApiGeneratorPage> with TickerProviderStateMixin {
  int _currentStep = 0;
  final _dbFormKey = GlobalKey<FormState>();
  final _queryFormKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _databaseController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storedProcedureController = TextEditingController(); // This will hold the full "EXEC sp_name ?, ?, ?"
  final List<TextEditingController> _paramControllers = [];
  bool _isLoading = false;
  int _dynamicParamCount = 0;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final List<AnimationController> _cardControllers = [];
  final List<Animation<Offset>> _cardSlideAnimations = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    for (int i = 0; i < 2; i++) {
      final controller = AnimationController(
        duration: Duration(milliseconds: 800 + i * 200),
        vsync: this,
      );
      _cardControllers.add(controller);
      _cardSlideAnimations.add(
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
        ),
      );
      controller.forward();
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    _serverController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _storedProcedureController.dispose();
    for (var controller in _paramControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _parseStoredProcedure(String query) {
    for (var controller in _paramControllers) {
      controller.dispose();
    }
    _paramControllers.clear();

    final regex = RegExp(r'\?');
    _dynamicParamCount = regex.allMatches(query).length;

    for (int i = 0; i < _dynamicParamCount; i++) {
      _paramControllers.add(TextEditingController());
    }
  }

  Future<Map<String, dynamic>?> _showSaveDialog() async {
    bool useFolder = false;
    String folderName = '';
    String apiFileName = 'api.php';
    final fileNameController = TextEditingController(text: apiFileName);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text(
          'Save API Configuration',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.blue[800],
          ),
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      'Save in folder?',
                      style: GoogleFonts.poppins(),
                    ),
                    trailing: Switch(
                      value: useFolder,
                      onChanged: (value) => setState(() => useFolder = value),
                      activeColor: Colors.blue[600],
                    ),
                  ),
                  if (useFolder)
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Folder Name (e.g., Bestapi)',
                        labelStyle: GoogleFonts.poppins(color: Colors.blue[800]),
                        prefixIcon: Icon(Icons.folder, color: Colors.blue[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) => folderName = value,
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: fileNameController,
                    decoration: InputDecoration(
                      labelText: 'API File Name (e.g., getsaleTarget)',
                      labelStyle: GoogleFonts.poppins(color: Colors.blue[800]),
                      prefixIcon: Icon(Icons.description, color: Colors.blue[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) => value!.isEmpty ? 'File name required' : null,
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.blue[600]),
            ),
          ),
          TextButton(
            onPressed: () {
              if (fileNameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please provide a file name',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.blue[800],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(context, {
                'useFolder': useFolder,
                'folderName': folderName,
                'apiFileName': fileNameController.text.endsWith('.php')
                    ? fileNameController.text
                    : '${fileNameController.text}.php',
              });
            },
            child: Text(
              'Save',
              style: GoogleFonts.poppins(color: Colors.blue[600]),
            ),
          ),
        ],
      ),
    );
    return result;
  }

  // MODIFIED: _generatePhpCode now uses the storedProcedure as is
  String _generatePhpCode(ApiConfig config) {
    // The SQL query should use the storedProcedure string exactly as given by the user,
    // which already contains the 'EXEC sp_name ?, ?, ?' format.
    final sqlQuery = config.storedProcedure;

    // The parameters for execute() are still derived from the dynamic parameter names.
    final executeParams = config.parameterNames.map((param) => '\$$param').join(', ');

    return """
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if (\$_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// Get parameters
${config.parameterNames.map((param) => "\$$param = \$_GET['$param'] ?? null;").join('\n')}

// Log to file
function logToFile(\$message) {
    \$filePath = "log_${config.apiFileName.replaceAll('.php', '')}.txt";
    \$logMessage = "[" . date('Y-m-d H:i:s') . "] " . \$message . PHP_EOL;
    file_put_contents(\$filePath, \$logMessage, FILE_APPEND);
}

logToFile("Received Params - ${config.parameterNames.join(', ')}");

// Database connection
\$server = "${config.server}";
\$database = "${config.database}";
\$user = "${config.username}";
\$password = "${config.password}";

try {
    \$conn = new PDO("sqlsrv:Server=\$server;Database=\$database", \$user, \$password);
    \$conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Execute stored procedure
    \$sql = "${sqlQuery.replaceAll(r'$', r'\$')}"; // Use the full stored procedure string, e
    \$stmt = \$conn->prepare(\$sql);
    \$stmt->execute([$executeParams]); // Pass dynamic parameters here

    \$data = \$stmt->fetchAll(PDO::FETCH_ASSOC);

    if (empty(\$data)) {
        logToFile("No data found");
        echo json_encode(["error" => "No data found"]);
    } else {
        logToFile("Data retrieved successfully");
        echo json_encode(["status" => "success", "data" => \$data]);
    }
} catch (PDOException \$e) {
    \$errorMessage = "Database error: " . \$e->getMessage();
    logToFile(\$errorMessage);
    echo json_encode(["error" => "Database connection failed", "details" => \$e->getMessage()]);
}
?>
""";
  }

  String _generateLocalhostUrl(ApiConfig config) {
    final queryParams = config.parameterNames
        .asMap()
        .entries
        .map((e) => "${e.value}=test${e.key + 1}")
        .join('&');
    final folderPath = config.folderName.isEmpty ? '' : '${config.folderName}/';
    return "http://localhost/$folderPath${config.apiFileName}?$queryParams";
  }

  void _nextStep() async {
    if (_currentStep == 0) {
      if (_dbFormKey.currentState!.validate()) {
        setState(() {
          _currentStep = 1;
        });
      }
    } else if (_currentStep == 1) {
      if (_queryFormKey.currentState!.validate()) {
        setState(() => _isLoading = true);
        await Future.delayed(const Duration(seconds: 2));
        final config = ApiConfig(
          server: _serverController.text,
          database: _databaseController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          // MODIFIED: Pass the full stored procedure text
          storedProcedure: _storedProcedureController.text,
          parameterNames: _paramControllers.map((c) => c.text).toList(),
          hardcodedValues: [],
          folderName: '',
          apiFileName: 'api.php',
        );
        final phpCode = _generatePhpCode(config);
        setState(() => _isLoading = false);

        final saveConfig = await _showSaveDialog();
        if (saveConfig != null) {
          final finalConfig = ApiConfig(
            server: config.server,
            database: config.database,
            username: config.username,
            password: config.password,
            // MODIFIED: Pass the full stored procedure text
            storedProcedure: config.storedProcedure,
            parameterNames: config.parameterNames,
            hardcodedValues: [],
            folderName: saveConfig['folderName'],
            apiFileName: saveConfig['apiFileName'],
          );
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => CodeDisplayPage(
                phpCode: phpCode,
                localhostUrl: _generateLocalhostUrl(finalConfig),
                apiFileName: finalConfig.apiFileName,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = 0.8;
                const end = 1.0;
                const curve = Curves.easeInOut;
                final scaleTween = Tween<double>(begin: begin, end: end).chain(CurveTween(curve: curve));
                final offsetTween = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
                    .chain(CurveTween(curve: curve));
                return ScaleTransition(
                  scale: animation.drive(scaleTween),
                  child: SlideTransition(
                    position: animation.drive(offsetTween),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                );
              },
            ),
          );
        }
      }
    }
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    required int index,
  }) {
    return SlideTransition(
      position: _cardSlideAnimations[index],
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(3, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: 'API Automation Studio',
        onBackPress: () => Navigator.pop(context),
      ),
      body: Container(
        color: Colors.white, // Solid white background
        child: _isLoading
            ? const SubtleLoader()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _currentStep == 0
              ? Form(
            key: _dbFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(
                  title: 'Database Connection',
                  index: 0,
                  children: [
                    _AnimatedTextField(
                      controller: _serverController,
                      label: 'Server (e.g., Sqllinux.tsnet.in,21457)',
                      icon: Icons.dns,
                      validator: (value) =>
                      value!.isEmpty ? 'Server is required' : null,
                    ),
                    const SizedBox(height: 12),
                    _AnimatedTextField(
                      controller: _databaseController,
                      label: 'Database (e.g., AquaVivaTest)',
                      icon: Icons.storage,
                      validator: (value) =>
                      value!.isEmpty ? 'Database is required' : null,
                    ),
                    const SizedBox(height: 12),
                    _AnimatedTextField(
                      controller: _usernameController,
                      label: 'Username',
                      icon: Icons.person,
                      validator: (value) =>
                      value!.isEmpty ? 'Username is required' : null,
                    ),
                    const SizedBox(height: 12),
                    _AnimatedTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock,
                      obscureText: true,
                      validator: (value) =>
                      value!.isEmpty ? 'Password is required' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: ShimmerButton(
                    text: 'Next',
                    onPressed: _nextStep,
                  ),
                ),
              ],
            ),
          )
              : Form(
            key: _queryFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(
                  title: 'API Query',
                  index: 1,
                  children: [
                    // MODIFIED: Updated label to reflect direct input of SP call
                    _AnimatedTextField(
                      controller: _storedProcedureController,
                      label:
                      'Stored Procedure Call (e.g., EXEC sp_GetDetails ?, ?, ?)',
                      icon: Icons.code,
                      validator: (value) => value!.isEmpty ||
                          !value.toLowerCase().startsWith('exec') ||
                          !value.contains('?') // Ensure it has placeholders if dynamic params are expected
                          ? 'Valid EXEC query with \' ? \' placeholders required'
                          : null,
                      onChanged: (value) {
                        setState(() => _parseStoredProcedure(value));
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_paramControllers.isNotEmpty) ...[
                      Text(
                        'Parameters (Enter a name for each \' ? \' below)',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
                      ..._paramControllers.asMap().entries.map((entry) {
                        final index = entry.key;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _AnimatedTextField(
                            controller: entry.value,
                            label: 'Parameter ${index + 1} Name',
                            icon: Icons.input,
                            validator: (value) => value!.isEmpty
                                ? 'Parameter name required'
                                : null,
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: ShimmerButton(
                    text: 'Generate API',
                    onPressed: _nextStep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Animated TextField with icon and minimalist effect
class _AnimatedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _AnimatedTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.validator,
    this.onChanged,
  });

  @override
  __AnimatedTextFieldState createState() => __AnimatedTextFieldState();
}

class __AnimatedTextFieldState extends State<_AnimatedTextField> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.obscureText,
              style: GoogleFonts.poppins(color: Colors.black87),
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: GoogleFonts.poppins(color: Colors.blue[800]!),
                prefixIcon: Icon(widget.icon, color: Colors.blue[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.transparent,
              ),
              validator: widget.validator,
              onChanged: widget.onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

// Shimmer Button with gradient and hover effect
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
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() {}),
      onExit: (_) => setState(() {}),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.blue[800]!,
                    Colors.blueAccent,
                    Colors.blue[800]!,
                  ],
                  stops: [
                    _shimmerAnimation.value > 0 ? _shimmerAnimation.value * 0.5 : 0.0,
                    _shimmerAnimation.value,
                    _shimmerAnimation.value < 0 ? 1.0 + _shimmerAnimation.value : 1.0,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.text,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Page to display generated code and URLs
class CodeDisplayPage extends StatefulWidget {
  final String phpCode;
  final String localhostUrl;
  final String apiFileName;

  const CodeDisplayPage({
    super.key,
    required this.phpCode,
    required this.localhostUrl,
    required this.apiFileName,
  });

  @override
  _CodeDisplayPageState createState() => _CodeDisplayPageState();
}

class _CodeDisplayPageState extends State<CodeDisplayPage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TextEditingController _phpCodeEditController;
  bool _isEditingPhpCode = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();

    _phpCodeEditController = TextEditingController(text: widget.phpCode);
  }

  @override
  void dispose() {
    _controller.dispose();
    _phpCodeEditController.dispose();
    super.dispose();
  }

  void _downloadCode() {
    final bytes = utf8.encode(_phpCodeEditController.text);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = widget.apiFileName;
    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Code downloaded as ${widget.apiFileName}',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.blue[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _saveEditedCode() {
    setState(() {
      _isEditingPhpCode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'PHP code changes saved!',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: 'Generated API Output',
        onBackPress: () => Navigator.pop(context),
      ),
      body: Container(
        color: Colors.white, // Solid white background for CodeDisplayPage
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(3, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Generated PHP Code',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue[800],
                                ),
                              ),
                              IconButton(
                                icon: Icon(_isEditingPhpCode ? Icons.visibility_off : Icons.edit, color: Colors.blue[600]),
                                tooltip: _isEditingPhpCode ? 'Exit Edit Mode' : 'Edit Code',
                                onPressed: () {
                                  setState(() {
                                    _isEditingPhpCode = !_isEditingPhpCode;
                                    // If exiting edit mode, ensure controller text reflects current state
                                    if (!_isEditingPhpCode) {
                                      _phpCodeEditController.text = _phpCodeEditController.text;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100]!,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: _isEditingPhpCode
                                ? TextFormField(
                              controller: _phpCodeEditController,
                              style: GoogleFonts.sourceCodePro(fontSize: 14),
                              maxLines: null, // Allows multiline input
                              keyboardType: TextInputType.multiline,
                              decoration: const InputDecoration(
                                border: InputBorder.none, // Remove default border
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            )
                                : Text(
                              _phpCodeEditController.text, // Display current text even if not in original widget.phpCode
                              style: GoogleFonts.sourceCodePro(fontSize: 14),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ShimmerButton(
                                text: 'Copy Code',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _phpCodeEditController.text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Code copied to clipboard!',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      backgroundColor: Colors.blue[800],
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              ShimmerButton(
                                text: 'Download Code',
                                onPressed: _downloadCode,
                              ),
                              if (_isEditingPhpCode) ...[
                                const SizedBox(width: 16),
                                ShimmerButton(
                                  text: 'Save Changes',
                                  onPressed: _saveEditedCode,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(3, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Generated URL',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Localhost URL:',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.localhostUrl,
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 14,
                              color: Colors.blue[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: ShimmerButton(
                              text: 'Copy URL',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: widget.localhostUrl));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'URL copied to clipboard!',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.blue[800],
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}