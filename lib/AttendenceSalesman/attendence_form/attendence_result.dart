// lib/.../attendance_result_views.dart

import 'dart:io';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qualityapproach/AttendenceSalesman/attendence_form/tracker_view.dart';
import 'attendence_bloc.dart';

// --- WIDGET 1: Name Entry Form (Unchanged) ---
class NameEntryForm extends StatefulWidget {
  final AttendanceNameEntry state;
  const NameEntryForm({super.key, required this.state});
  @override
  State<NameEntryForm> createState() => _NameEntryFormState();
}

class _NameEntryFormState extends State<NameEntryForm> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedTime =
    DateFormat('d MMMM, yyyy  •  hh:mm a').format(widget.state.captureTime);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Verification Complete",
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "Please confirm your details below.",
                style:
                theme.textTheme.bodyLarge?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 32),
              CircleAvatar(
                radius: 80,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: CircleAvatar(
                    radius: 75,
                    backgroundImage:
                    FileImage(File(widget.state.imagePath))),
              ),
              const SizedBox(height: 16),
              Text(
                "Captured on: $formattedTime",
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Enter Your Full Name",
                        prefixIcon: Icon(Icons.person_outline,
                            color: theme.primaryColor),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: theme.primaryColor, width: 2)),
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          context.read<AttendanceBloc>().add(
                              AttendanceSubmitted(
                                  salesmanName: _nameController.text.trim()));
                        }
                      },
                      child: Text("Submit Attendance",
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
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
}


// --- WIDGET 2: FULLY REDESIGNED AND REALIGNED SUCCESS VIEW ---
class SuccessView extends StatefulWidget {
  final AttendanceSubmissionSuccess state;
  const SuccessView({super.key, required this.state});

  @override
  State<SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<SuccessView> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<Offset> _buttonSlideAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _scaleAnimation = CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut));
    _contentSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)));
    _buttonSlideAnimation = Tween<Offset>(begin: const Offset(0, 2), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));

    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _confettiController.play());
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Main content with robust layout
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // This Expanded widget is the key to the new, robust layout.
                  // It pushes the button to the bottom and centers the content.
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.green.withOpacity(0.15), blurRadius: 20, spreadRadius: 5),
                                ]
                            ),
                            child: Icon(Icons.check_rounded, color: Colors.green.shade600, size: 80),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeTransition(
                          opacity: _animationController,
                          child: SlideTransition(
                            position: _contentSlideAnimation,
                            child: Column(
                              children: [
                                Text(
                                  "Attendance Marked!",
                                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                ),
                                const SizedBox(height: 32),
                                Container(
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 4),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, spreadRadius: 2)
                                      ]
                                  ),
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundImage: FileImage(File(widget.state.imagePath)),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  widget.state.salesmanName,
                                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat('d MMMM, yyyy  •  hh:mm a').format(widget.state.submissionTime),
                                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Animated button cleanly positioned at the bottom
                  SlideTransition(
                    position: _buttonSlideAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary, Colors.blue.shade700],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.transparent,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shadowColor: Colors.transparent,
                        ),
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => TrackerPage(salesmanName: widget.state.salesmanName, imagePath: widget.state.imagePath)),
                                (route) => false,
                          );
                        },
                        child: Text(
                          "Start Tracking",
                          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24), // Bottom margin
                ],
              ),
            ),
          ),

          // Confetti remains on top
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          ),
        ],
      ),
    );
  }
}


// --- WIDGET 3: Error Display (Unchanged) ---
class ErrorDisplay extends StatelessWidget {
  final String error;
  const ErrorDisplay({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool isPermissionError = error.contains("permanently denied");

    return Card(
      margin: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded, color: Colors.red[700], size: 60),
            const SizedBox(height: 16),
            Text("An Error Occurred",
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.red[900])),
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: Colors.black54, height: 1.5)),
            const SizedBox(height: 24),
            if (isPermissionError) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings),
                label: const Text("Open Settings"),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.read<AttendanceBloc>().add(AttendanceReset()),
              icon: const Icon(Icons.refresh),
              label: Text("Try Again",
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}