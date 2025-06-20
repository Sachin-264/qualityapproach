import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:universal_html/html.dart' as html;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

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
              ..rotateZ(_rotationAnimation.value * 3.141592653589793 / 180),
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.5),
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
  }) : id = const Uuid().v4(),
        nameController = TextEditingController(text: name),
        valueController = TextEditingController(text: exampleValue);

  String get urlParamName {
    String cleanName = name.startsWith('P_') ? name.substring(2) : name;
    return cleanName.replaceAllMapped(RegExp(r'([A-Z])'), (match) => '_${match.group(1)!.toLowerCase()}').toLowerCase();
  }

  String get phpVarName {
    String cleanName = name.startsWith('P_') ? name.substring(2) : name;
    if (cleanName.isEmpty) return '';
    return cleanName[0].toLowerCase() + cleanName.substring(1);
  }

  String get spParamName {
    return name;
  }

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

  ApiConfig({
    required this.connectionStringInput,
    required this.isConnectionStringEncrypted,
    required this.baseUrlPrefix,
    required this.encryptionKey,
    required this.storedProcedureName,
    required this.parameters,
    required this.folderName,
    required this.apiFileName,
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
  final _storedProcedureNameController = TextEditingController(text: 'sp_YourStoredProcedureName');

  bool _isConnectionStringInputEncrypted = false;
  String _internalEncryptionKey = '9qGxCtZw2xAI00D3VLOUNTs+qr50rpfWggluskAhgww=';

  List<ApiParameter> _apiParameters = [];

  bool _isLoading = false;
  late AnimationController _pageFadeController;
  late Animation<double> _pageFadeAnimation;
  final List<AnimationController> _sectionControllers = [];
  final List<Animation<Offset>> _sectionSlideAnimations = [];

  @override
  void initState() {
    super.initState();
    _pageFadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pageFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pageFadeController, curve: Curves.easeInOut),
    );

    for (int i = 0; i < 2; i++) {
      final controller = AnimationController(
        duration: Duration(milliseconds: 800 + i * 200),
        vsync: this,
      );
      _sectionControllers.add(controller);
      _sectionSlideAnimations.add(
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
        ),
      );
      controller.forward();
    }

    _pageFadeController.forward();

    _apiParameters = [
      ApiParameter(name: 'P_UserCode', type: 'String', exampleValue: 'user123'),
      ApiParameter(name: 'P_FromDate', type: 'Date', exampleValue: ''),
    ];
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

  Future<Map<String, dynamic>?> _showSaveDialog() async {
    bool useFolder = false;
    String folderName = '';
    String apiFileName = 'api.php';
    final fileNameController = TextEditingController(text: apiFileName);
    bool includeSecureFunction = true;
    final encryptionKeyController = TextEditingController(text: _internalEncryptionKey);

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
                        labelText: 'Folder Name (e.g., mobileAPI)',
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
                      labelText: 'API File Name (e.g., getSales)',
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
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(
                      'Include `secure/function.php`?',
                      style: GoogleFonts.poppins(),
                    ),
                    trailing: Switch(
                      value: includeSecureFunction,
                      onChanged: (value) => setState(() => includeSecureFunction = value),
                      activeColor: Colors.blue[600],
                    ),
                  ),
                  _AnimatedTextField(
                    controller: encryptionKeyController,
                    label: 'Encryption Key for `secure/function.php`',
                    hintText: 'This key is used for encryption/decryption.',
                    icon: Icons.vpn_key,
                    validator: (value) =>
                    value!.isEmpty ? 'Encryption key is required' : null,
                    onChanged: (value) {
                      _internalEncryptionKey = value;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Note: If using a pre-encrypted connection string, this key MUST match the key used for its original encryption.',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange[800]),
                    textAlign: TextAlign.center,
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
                'includeSecureFunction': includeSecureFunction,
                'encryptionKey': encryptionKeyController.text,
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

  String _generatePhpCode(ApiConfig config) {
    final StringBuffer paramDeclarations = StringBuffer();
    final StringBuffer spCallParams = StringBuffer();
    final StringBuffer bindValues = StringBuffer();

    for (var p in config.parameters) {
      p.updateFromControllers();

      final phpVarName = p.phpVarName;
      final getParamName = p.urlParamName;

      String assignment = '';
      String validation = '';
      String defaultValueForPhp = "''";

      if (p.type == 'Boolean') {
        defaultValueForPhp = p.exampleValue.toLowerCase() == 'true' ? 'true' : 'false';
        assignment = '\$$phpVarName = filter_var(\$_GET[\'$getParamName\'] ?? $defaultValueForPhp, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);';
        validation = 'if (\$$phpVarName === null && !empty(\$_GET[\'$getParamName\'])) { \$errors[] = "Invalid boolean for ${p.name}. Expected \'true\' or \'false\'. Received: \$_GET[\'$getParamName\']"; }';
      } else if (p.type == 'Integer') {
        defaultValueForPhp = p.exampleValue.isEmpty ? '0' : p.exampleValue;
        assignment = '\$$phpVarName = filter_var(\$_GET[\'$getParamName\'] ?? $defaultValueForPhp, FILTER_VALIDATE_INT, FILTER_NULL_ON_FAILURE);';
        validation = 'if (\$$phpVarName === null && !empty(\$_GET[\'$getParamName\'])) { \$errors[] = "Invalid integer for ${p.name}. Received: \$_GET[\'$getParamName\']"; }';
      } else if (p.type == 'Date') {
        assignment = '\$${phpVarName}Raw = \$_GET[\'$getParamName\'] ?? \'${p.exampleValue}\';';
        paramDeclarations.writeln('    $assignment');
        paramDeclarations.writeln('    \$${phpVarName} = convertDateToSQLFormat(\$${phpVarName}Raw);');
        validation = 'if (!\$${phpVarName} && !empty(\$${phpVarName}Raw)) { \$errors[] = "Invalid date format for ${p.name}. Please use DD-MMM-YYYY or YYYY-MM-DD. Received: \$${phpVarName}Raw"; }';
      } else {
        defaultValueForPhp = p.exampleValue.isEmpty ? "''" : "'${p.exampleValue}'";
        assignment = '\$$phpVarName = \$_GET[\'$getParamName\'] ?? $defaultValueForPhp;';
      }

      if (p.type != 'Date') {
        paramDeclarations.writeln('    $assignment');
      }

      if (validation.isNotEmpty) {
        paramDeclarations.writeln('    $validation');
      }

      spCallParams.write('@${p.spParamName} = ?, ');
      bindValues.write('\$$phpVarName, ');
    }

    String finalSpCallParams = spCallParams.toString().replaceAll(RegExp(r', $'), '');
    String finalBindValues = bindValues.toString().replaceAll(RegExp(r', $'), '');

    return """
<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
include './secure/function.php';

\$message = new stdClass();

if (!isset(\$_GET['str']) || empty(\$_GET['str'])) {
    echo json_encode(['status' => 'error', 'message' => 'Connection string (str) parameter is missing.']);
    exit;
}

\$connInput = \$_GET['str'];

if (!str_contains(\$connInput, ':-:')) {
    \$connInput = secured_decrypt(base64_decode(\$connInput));
    if (\$connInput === false) {
        echo json_encode(['status' => 'error', 'message' => 'Failed to decrypt connection string. Check encryption key or format.']);
        exit;
    }
}

\$connVal = explode(':-:', \$connInput);
if (count(\$connVal) != 4) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid connection string format. Expected Server:-:Database:-:User:-:Pass']);
    exit;
}

\$serverName = \$connVal[0];
\$connectionOptions = [
    "Database" => \$connVal[1],
    "Uid" => \$connVal[2],
    "PWD" => \$connVal[3]
];

function convertDateToSQLFormat(\$dateStr) {
    if (empty(\$dateStr)) {
        return null;
    }
    \$date = DateTime::createFromFormat('d-M-Y', \$dateStr);
    if (!\$date) {
        \$date = DateTime::createFromFormat('Y-m-d', \$dateStr);
    }
    return \$date ? \$date->format('Y-m-d') : null;
}

function formatDateOutput(\$dateStr) {
    \$date = DateTime::createFromFormat('Y-m-d H:i:s.u', \$dateStr) ?: DateTime::createFromFormat('Y-m-d', \$dateStr);
    return \$date ? \$date->format('d-M-Y') : \$dateStr;
}

\$errors = [];
${paramDeclarations.toString()}

if (!empty(\$errors)) {
    echo json_encode(['status' => 'error', 'message' => implode(' ', \$errors)]);
    exit;
}

\$storedProc = "${config.storedProcedureName}";

try {
    \$conn = new PDO("sqlsrv:server=\$serverName;Database={\$connectionOptions['Database']}", \$connectionOptions['Uid'], \$connectionOptions['PWD']);
    \$conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    \$spCall = "EXEC \$storedProc $finalSpCallParams";
    
    \$stmt = \$conn->prepare(\$spCall);
    \$stmt->execute([
        $finalBindValues
    ]);

    \$results = \$stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach (\$results as &\$row) {
        foreach (\$row as \$key => &\$val) {
            if (strpos(strtolower(\$key), 'date') !== false && \$val) {
                \$val = formatDateOutput(\$val);
            }
        }
    }

    header('Content-Type: application/json');
    echo json_encode(['status' => 'success', 'data' => \$results]);

} catch (PDOException \$e) {
    echo json_encode(['status' => 'error', 'message' => \$e->getMessage()]);
}
?>
""";
  }

  String _generateSecureFunctionPhpCode(String key) {
    return """
<?php
\$key = '$key';

function secured_encrypt(\$data)
{
    global \$key;
    \$secretKey = md5(\$key);
    \$iv = substr( hash( 'sha256', "aaaabbbbcccccddddeweee" ), 0, 16 );
    \$encryptedText = openssl_encrypt(\$data, 'AES-128-CBC', \$secretKey, OPENSSL_RAW_DATA, \$iv);
    return base64_encode(\$encryptedText);       
}

function secured_decrypt(\$input)
{
    global \$key;
    \$secretKey = md5(\$key);
    \$iv = substr( hash( 'sha256', "aaaabbbbcccccddddeweee" ), 0, 16 );
    \$decryptedText = openssl_decrypt(base64_decode(\$input), 'AES-128-CBC', \$secretKey, OPENSSL_RAW_DATA, \$iv);
    return \$decryptedText;
  
}

if (!function_exists('str_contains')) {
    function str_contains(\$haystack, \$needle): bool {
        if ( is_string(\$haystack) && is_string(\$needle) ) {
            return '' === \$needle || false !== strpos(\$haystack, \$needle);
        } else {
            return false;
        }
    }
}

?>
""";
  }

  String _securedEncrypt(String data, String encryptionKey) {
    final keyBytes = md5.convert(utf8.encode(encryptionKey)).bytes;
    final ivBytes = sha256.convert(utf8.encode("aaaabbbbcccccddddeweee")).bytes.sublist(0, 16);

    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'));
    final iv = encrypt.IV(Uint8List.fromList(ivBytes));

    final encrypted = encrypter.encrypt(data, iv: iv);
    return encrypted.base64;
  }

  String _generateUrl(ApiConfig config) {
    String strParamValue;
    if (config.isConnectionStringEncrypted) {
      strParamValue = config.connectionStringInput;
    } else {
      strParamValue = _securedEncrypt(config.connectionStringInput, config.encryptionKey);
    }

    final folderPath = config.folderName.isEmpty ? '' : '${config.folderName}/';

    final Map<String, String> queryParams = {};
    for (var param in config.parameters) {
      param.updateFromControllers();
      queryParams[param.urlParamName] = param.exampleValue;
    }
    queryParams['str'] = strParamValue;

    final queryString = queryParams.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');

    return '${config.baseUrlPrefix}$folderPath${config.apiFileName}?$queryString';
  }

  void _generateApi() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 1));

      final saveConfig = await _showSaveDialog();
      if (saveConfig != null) {
        final chosenEncryptionKey = saveConfig['encryptionKey'] ?? _internalEncryptionKey;

        final List<ApiParameter> currentParameters = _apiParameters.map((p) {
          p.updateFromControllers();
          return p;
        }).toList();

        final config = ApiConfig(
          connectionStringInput: _connectionStringInputController.text,
          isConnectionStringEncrypted: _isConnectionStringInputEncrypted,
          baseUrlPrefix: _baseUrlPrefixController.text,
          encryptionKey: chosenEncryptionKey,
          storedProcedureName: _storedProcedureNameController.text,
          parameters: currentParameters,
          folderName: saveConfig['folderName'],
          apiFileName: saveConfig['apiFileName'],
        );

        final phpCode = _generatePhpCode(config);
        final secureFunctionPhp = _generateSecureFunctionPhpCode(config.encryptionKey);
        final localhostUrl = _generateUrl(config);

        setState(() => _isLoading = false);

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => CodeDisplayPage(
              phpCode: phpCode,
              localhostUrl: localhostUrl,
              apiFileName: config.apiFileName,
              secureFunctionPhp: secureFunctionPhp,
              includeSecureFunction: saveConfig['includeSecureFunction'],
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
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    required int index,
  }) {
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 8),
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
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue[800],
                  ),
                ),
                const Divider(height: 25, thickness: 1, color: Colors.blueGrey),
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
                    ListTile(
                      title: Text(
                        'Connection String is already encrypted?',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
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
                      label: _isConnectionStringInputEncrypted
                          ? 'Pre-Encrypted Connection String'
                          : 'Database Connection String (Plaintext)',
                      hintText: _isConnectionStringInputEncrypted
                          ? 'Paste your encrypted string here'
                          : 'Server:-:Database:-:User:-:Pass (e.g., Sqllinux.tsnet.in,21457:-:AquaVivaTest:-:myuser:-:mypass)',
                      icon: _isConnectionStringInputEncrypted ? Icons.lock : Icons.vpn_lock,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Connection string is required';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    _AnimatedTextField(
                      controller: _baseUrlPrefixController,
                      label: 'Base URL Prefix',
                      hintText: 'e.g., http://localhost/ or https://yourdomain.com/mobileAPI/',
                      icon: Icons.link,
                      validator: (value) =>
                      value!.isEmpty ? 'Base URL prefix is required' : null,
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
                _buildSectionCard(
                  title: 'Stored Procedure Configuration',
                  index: 1,
                  children: [
                    _AnimatedTextField(
                      controller: _storedProcedureNameController,
                      label: 'Stored Procedure Name',
                      hintText: 'e.g., sp_GetCustomerSalesSummary',
                      icon: Icons.storage,
                      validator: (value) => value!.isEmpty ? 'Stored procedure name is required' : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Stored Procedure Parameters',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    Text(
                      'Parameter names (e.g., UserCode) will become @UserCode in the SP call and user_code in the URL.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
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
                                    Expanded(
                                      child: _AnimatedTextField(
                                        controller: param.nameController,
                                        label: 'Parameter Name (e.g., P_UserCode or UserCode)',
                                        icon: Icons.label,
                                        validator: (value) => value!.isEmpty ? 'Name required' : null,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red[400]),
                                      onPressed: () => _removeParameter(index),
                                      tooltip: 'Remove Parameter',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: param.type,
                                  decoration: InputDecoration(
                                    labelText: 'Data Type',
                                    labelStyle: GoogleFonts.poppins(color: Colors.blue[800]!),
                                    prefixIcon: Icon(Icons.description, color: Colors.blue[600]),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                  items: ['String', 'Integer', 'Date', 'Boolean'].map((String type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(type, style: GoogleFonts.poppins()),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      param.type = newValue!;
                                      if ((newValue == 'Boolean' && param.valueController.text != 'true' && param.valueController.text != 'false') ||
                                          (newValue == 'Integer' && param.valueController.text.isNotEmpty && int.tryParse(param.valueController.text) == null)) {
                                        param.valueController.text = '';
                                      } else if (newValue == 'Date' && param.valueController.text.isNotEmpty) {
                                        try {
                                          DateTime.parse(param.valueController.text);
                                        } catch (e) {
                                          param.valueController.text = '';
                                        }
                                      }
                                    });
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
                                      final DateTime? picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2050),
                                        builder: (context, child) {
                                          return Theme(
                                            data: ThemeData.light().copyWith(
                                              primaryColor: Colors.blue[800],
                                              colorScheme: ColorScheme.light(primary: Colors.blue[800]!),
                                              buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          param.valueController.text = "${picked.day.toString().padLeft(2, '0')}-${_getMonthAbbreviation(picked.month)}-${picked.year}";
                                        });
                                      }
                                    },
                                    validator: (value) {
                                      if (value != null && value.isNotEmpty) {
                                        final regex = RegExp(r'^\d{2}-\w{3}-\d{4}$');
                                        if (!regex.hasMatch(value)) {
                                          return 'Expected DD-MMM-YYYY format';
                                        }
                                      }
                                      return null;
                                    },
                                  )
                                else if (param.type == 'Boolean')
                                  DropdownButtonFormField<String>(
                                    value: param.valueController.text.isEmpty ? 'false' : param.valueController.text,
                                    decoration: InputDecoration(
                                      labelText: 'Example Boolean Value',
                                      labelStyle: GoogleFonts.poppins(color: Colors.blue[800]!),
                                      prefixIcon: Icon(Icons.toggle_on, color: Colors.blue[600]),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                    ),
                                    items: ['true', 'false'].map((String val) {
                                      return DropdownMenuItem<String>(
                                        value: val,
                                        child: Text(val, style: GoogleFonts.poppins()),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        param.valueController.text = newValue!;
                                      });
                                    },
                                  )
                                else
                                  _AnimatedTextField(
                                    controller: param.valueController,
                                    label: 'Example Value',
                                    icon: Icons.code,
                                    keyboardType: param.type == 'Integer' ? TextInputType.number : TextInputType.text,
                                    validator: (value) {
                                      if (param.type == 'Integer' && value != null && value.isNotEmpty && int.tryParse(value) == null) {
                                        return 'Must be an integer';
                                      }
                                      return null;
                                    },
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
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
}

class _AnimatedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? hintText;

  const _AnimatedTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.hintText,
  });

  @override
  __AnimatedTextFieldState createState() => __AnimatedTextFieldState();
}

class __AnimatedTextFieldState extends State<_AnimatedTextField> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.005).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _colorAnimation = ColorTween(
      begin: Colors.grey[100],
      end: Colors.blue[50],
    ).animate(_controller);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_focusNode.hasFocus ? 0.1 : 0.05),
                  blurRadius: _focusNode.hasFocus ? 10 : 5,
                  offset: _focusNode.hasFocus ? const Offset(0, 4) : const Offset(0, 2),
                ),
              ],
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
                suffixIcon: widget.readOnly && widget.onTap != null
                    ? IconButton(
                  icon: Icon(Icons.calendar_month, color: Colors.blue[600]),
                  onPressed: widget.onTap,
                )
                    : null,
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

class CodeDisplayPage extends StatefulWidget {
  final String phpCode;
  final String localhostUrl;
  final String apiFileName;
  final String secureFunctionPhp;
  final bool includeSecureFunction;

  const CodeDisplayPage({
    super.key,
    required this.phpCode,
    required this.localhostUrl,
    required this.apiFileName,
    required this.secureFunctionPhp,
    required this.includeSecureFunction,
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
    _secureFunctionCodeEditController = TextEditingController(text: widget.secureFunctionPhp);
  }

  @override
  void dispose() {
    _controller.dispose();
    _phpCodeEditController.dispose();
    _secureFunctionCodeEditController.dispose();
    super.dispose();
  }

  void _downloadCode(String code, String filename) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Code downloaded as $filename',
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

  void _saveEditedCode(TextEditingController controller, bool isMainApi) {
    setState(() {
      if (isMainApi) {
        _isEditingPhpCode = false;
      } else {
        _isEditingSecureFunctionCode = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${isMainApi ? 'API' : 'Secure function'} code changes saved!',
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch $url'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: 'Generated API Output',
        onBackPress: () => Navigator.pop(context),
      ),
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
                    onToggleEdit: () {
                      setState(() {
                        _isEditingPhpCode = !_isEditingPhpCode;
                      });
                    },
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: _phpCodeEditController.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'API code copied to clipboard!',
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
                    onDownload: () => _downloadCode(_phpCodeEditController.text, widget.apiFileName),
                    onSave: () => _saveEditedCode(_phpCodeEditController, true),
                  ),
                  const SizedBox(height: 16),
                  if (widget.includeSecureFunction)
                    ...[
                      _buildCodeSection(
                        title: 'Generated `secure/function.php` Code',
                        controller: _secureFunctionCodeEditController,
                        isEditing: _isEditingSecureFunctionCode,
                        onToggleEdit: () {
                          setState(() {
                            _isEditingSecureFunctionCode = !_isEditingSecureFunctionCode;
                          });
                        },
                        onCopy: () {
                          Clipboard.setData(ClipboardData(text: _secureFunctionCodeEditController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'secure/function.php code copied to clipboard!',
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
                        onDownload: () => _downloadCode(_secureFunctionCodeEditController.text, 'secure/function.php'),
                        onSave: () => _saveEditedCode(_secureFunctionCodeEditController, false),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blue[100]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Make sure to place `secure/function.php` in a folder named `secure` relative to your main API file, or adjust the `include` path in the generated API code.',
                                style: GoogleFonts.poppins(fontSize: 13, color: Colors.blue[900]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  _buildUrlSection(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeSection({
    required String title,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onToggleEdit,
    required VoidCallback onCopy,
    required VoidCallback onDownload,
    required VoidCallback onSave,
  }) {
    return Container(
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
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue[800],
                  ),
                ),
                IconButton(
                  icon: Icon(isEditing ? Icons.visibility_off : Icons.edit, color: Colors.blue[600]),
                  tooltip: isEditing ? 'Exit Edit Mode' : 'Edit Code',
                  onPressed: onToggleEdit,
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
              child: isEditing
                  ? TextFormField(
                controller: controller,
                style: GoogleFonts.sourceCodePro(fontSize: 14),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              )
                  : Text(
                controller.text,
                style: GoogleFonts.sourceCodePro(fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ShimmerButton(text: 'Copy Code', onPressed: onCopy),
                ShimmerButton(text: 'Download Code', onPressed: onDownload),
                if (isEditing)
                  ShimmerButton(text: 'Save Changes', onPressed: onSave),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlSection(BuildContext context) {
    return Container(
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
              'Example API URL:',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              widget.localhostUrl,
              style: GoogleFonts.sourceCodePro(
                fontSize: 14,
                color: Colors.blue[600],
              ),
            ),
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
                ShimmerButton(
                  text: 'Open URL in Browser',
                  onPressed: () => _launchUrl(widget.localhostUrl),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}