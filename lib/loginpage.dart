import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'complaint_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late AnimationController _fadeController;
  late AnimationController _logoController;
  late AnimationController _titleController;
  late AnimationController _subtitleController;
  late AnimationController _usernameFieldController;
  late AnimationController _passwordFieldController;
  late AnimationController _buttonController;
  late AnimationController _waveController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _logoFade;
  late Animation<double> _logoPulse;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;
  late Animation<double> _usernameFade;
  late Animation<double> _passwordFade;
  late Animation<double> _buttonFade;
  late Animation<double> _waveAnimation;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isButtonHovered = false;
  bool _isForgotPasswordHovered = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _logoController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _titleController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _subtitleController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _usernameFieldController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _passwordFieldController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _buttonController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _waveController = AnimationController(duration: const Duration(seconds: 3), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoPulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOutSine),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOut),
    );
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeOut),
    );
    _usernameFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _usernameFieldController, curve: Curves.easeOut),
    );
    _passwordFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _passwordFieldController, curve: Curves.easeOut),
    );
    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOut),
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );

    _fadeController.forward();
    _logoController.repeat(reverse: true);
    _waveController.repeat();
    _fadeController.addListener(() {
      if (_fadeController.value > 0.3) {
        _titleController.forward();
        Future.delayed(const Duration(milliseconds: 200), () => _subtitleController.forward());
        Future.delayed(const Duration(milliseconds: 400), () => _usernameFieldController.forward());
        Future.delayed(const Duration(milliseconds: 600), () => _passwordFieldController.forward());
        Future.delayed(const Duration(milliseconds: 800), () => _buttonController.forward());
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _logoController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _usernameFieldController.dispose();
    _passwordFieldController.dispose();
    _buttonController.dispose();
    _waveController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Please fill in all fields',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE53E3E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    setState(() {
      _isLoading = false;
    });

    if (_usernameController.text == 'admin' && _passwordController.text == 'moneyshine') {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>  ComplaintPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Invalid username or password',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE53E3E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double maxWidth = kIsWeb ? 600.0 : size.width * 0.9;

    // Dynamic font loading with fallback
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.light().textTheme.copyWith(
        displayLarge: const TextStyle(color: Color(0xFF1E40AF)),
        bodyMedium: const TextStyle(color: Color(0xFF1F2937)),
        labelMedium: const TextStyle(color: Color(0xFF1F2937)),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Animated wave background
          AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(size.width, size.height),
                painter: WavePainter(_waveAnimation.value),
              );
            },
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF3B82F6), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Custom Report Builder Icon
                          FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: _logoPulse,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E40AF),
                                  shape: BoxShape.circle,
                                ),
                                child: CustomPaint(
                                  painter: ReportBuilderIconPainter(),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Title
                          FadeTransition(
                            opacity: _titleFade,
                            child: Text(
                              'Report Builder',
                              style: textTheme.displayLarge?.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Subtitle
                          FadeTransition(
                            opacity: _subtitleFade,
                            child: Text(
                              'Sign in to access your reports',
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Username field
                          FadeTransition(
                            opacity: _usernameFade,
                            child: TextField(
                              controller: _usernameController,
                              focusNode: _usernameFocus,
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                              style: textTheme.bodyMedium,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                labelStyle: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF1E40AF), width: 2),
                                ),
                                prefixIcon: const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF3B82F6),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Password field
                          FadeTransition(
                            opacity: _passwordFade,
                            child: TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              obscureText: _obscurePassword,
                              onSubmitted: (_) => _login(),
                              style: textTheme.bodyMedium,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF1E40AF), width: 2),
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF3B82F6),
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: MouseRegion(
                              cursor: kIsWeb ? SystemMouseCursors.click : MouseCursor.defer,
                              onEnter: (_) => setState(() => _isForgotPasswordHovered = true),
                              onExit: (_) => setState(() => _isForgotPasswordHovered = false),
                              child: TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Forgot password functionality coming soon!',
                                        style: textTheme.bodyMedium?.copyWith(color: Colors.white),
                                      ),
                                      backgroundColor: const Color(0xFF1E40AF),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      margin: const EdgeInsets.all(20),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: _isForgotPasswordHovered ? const Color(0xFF1E40AF) : const Color(0xFF3B82F6),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Login button
                          FadeTransition(
                            opacity: _buttonFade,
                            child: MouseRegion(
                              cursor: kIsWeb ? SystemMouseCursors.click : MouseCursor.defer,
                              onEnter: (_) => setState(() => _isButtonHovered = true),
                              onExit: (_) => setState(() => _isButtonHovered = false),
                              child: GestureDetector(
                                onTap: _isLoading ? null : _login,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E40AF),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1E40AF).withOpacity(_isButtonHovered ? 0.5 : 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  transform: Matrix4.identity()..scale(_isButtonHovered ? 1.02 : 1.0),
                                  child: Center(
                                    child: _isLoading
                                        ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Signing In...',
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                        : Text(
                                      'Sign In',
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Footer
                          Text(
                            '© 2024 MoneyShineInfoCom. All rights reserved.',
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for the Report Builder icon
class ReportBuilderIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw a simplified report chart icon (bar chart with 3 bars)
    final double barWidth = size.width / 8;
    final double spacing = size.width / 10;
    final double maxHeight = size.height * 0.6;

    // Bar 1
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25, size.height * 0.5, barWidth, maxHeight * 0.4),
        const Radius.circular(2),
      ),
      paint,
    );

    // Bar 2
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25 + barWidth + spacing, size.height * 0.3, barWidth, maxHeight * 0.7),
        const Radius.circular(2),
      ),
      paint,
    );

    // Bar 3
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25 + 2 * (barWidth + spacing), size.height * 0.4, barWidth, maxHeight * 0.5),
        const Radius.circular(2),
      ),
      paint,
    );

    // Optional: Add a subtle outline
    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, outlinePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Custom painter for animated wave background
class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6).withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);

    for (double x = 0; x <= size.width; x++) {
      path.lineTo(
        x,
        size.height * 0.7 +
            50 * (sin((x / size.width * 2 * 3.14159) + (animationValue * 2 * 3.14159))),
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Second wave for depth
    final paint2 = Paint()
      ..color = const Color(0xFF60A5FA).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.8);

    for (double x = 0; x <= size.width; x++) {
      path2.lineTo(
        x,
        size.height * 0.8 +
            30 * (sin((x / size.width * 2 * 3.14159) + (animationValue * 2 * 3.14159) + 1)),
      );
    }

    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => oldDelegate.animationValue != animationValue;
}