// lib/.../attendance_view.dart

import 'package:animations/animations.dart';
import 'package:face_livelyness_detection/face_livelyness_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'attendence_bloc.dart';
import 'attendence_result.dart';


// --- THEME DATA (Unchanged) ---
final ThemeData blueTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF0D47A1),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF1976D2),
    secondary: Color(0xFF42A5F5),
    background: Color(0xFFF5F7FA),
    surface: Colors.white,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onBackground: Color(0xFF333333),
    onSurface: Color(0xFF333333),
  ),
  scaffoldBackgroundColor: const Color(0xFFF5F7FA),
  textTheme: GoogleFonts.outfitTextTheme(),
  cardTheme: CardTheme(
    elevation: 4,
    shadowColor: Colors.black.withOpacity(0.05),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);

class AttendanceView extends StatelessWidget {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: blueTheme,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [blueTheme.colorScheme.background, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: PageTransitionSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder:
                    (child, primaryAnimation, secondaryAnimation) {
                  return FadeThroughTransition(
                    animation: primaryAnimation,
                    secondaryAnimation: secondaryAnimation,
                    child: child,
                  );
                },
                // MODIFIED: This now points to the new SuccessView
                child: BlocBuilder<AttendanceBloc, AttendanceState>(
                  builder: (context, state) {
                    if (state is AttendanceSubmissionSuccess) {
                      return SuccessView(
                          key: const ValueKey('success'), state: state);
                    }
                    if (state is AttendanceNameEntry) {
                      return NameEntryForm(
                          key: const ValueKey('nameEntry'), state: state);
                    }
                    if (state is AttendanceSelfieInProgress ||
                        state is AttendanceSubmissionLoading) {
                      return const SpinKitChasingDots(
                        color: Color(0xFF1976D2),
                        size: 60.0,
                        key: ValueKey('loading'),
                      );
                    }
                    if (state is AttendanceSubmissionFailure) {
                      return ErrorDisplay(
                          key: const ValueKey('error'), error: state.error);
                    }
                    return const InitialView(key: ValueKey('initial'));
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- INITIAL VIEW (Now with corrected logic) ---
class InitialView extends StatelessWidget {
  const InitialView({super.key});

  Future<void> _handleCameraCapture(BuildContext context) async {
    final status = await Permission.camera.request();
    if (!context.mounted) return;

    if (status.isGranted) {
      final bloc = context.read<AttendanceBloc>();
      bloc.add(AttendanceSelfieCaptureStarted());

      try {
        final config = FaceLivelynessDetectionConfig(
          steps: [
            FaceLivelynessStepItem(
              step: FaceLivelynessStep.blink,
              title: "Blink Your Eyes",
              isCompleted: false,
            ),
            FaceLivelynessStepItem(
              step: FaceLivelynessStep.smile,
              title: "Smile Naturally",
              isCompleted: false,
            ),
          ],
          startWithInfoScreen: false,
        );

        final String? result =
        await FaceLivelynessDetection.instance.detectLivelyness(
          context,
          config: config,
        );

        if (result != null && result.isNotEmpty) {
          // --- MODIFIED: Pass the current time to the event ---
          bloc.add(AttendanceSelfieCaptureSucceeded(
            imagePath: result,
            captureTime: DateTime.now(), // <-- We now pass the time
          ));
        } else {
          bloc.add(const AttendanceSelfieCaptureFailed(
              error: "Liveness detection was cancelled."));
        }
      } catch (e) {
        bloc.add(AttendanceSelfieCaptureFailed(error: e.toString()));
      }
    } else {
      final error = status.isPermanentlyDenied
          ? "Camera permission is permanently denied. Please enable it in your device settings."
          : "Camera permission was denied.";
      context.read<AttendanceBloc>().add(AttendanceSelfieCaptureFailed(error: error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(
            Icons.verified_user_outlined,
            size: 100,
            color: theme.primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            "Verify Your Identity",
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            "To mark your attendance, we need to quickly verify you're real. Please follow the on-screen instructions.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 40),
          InstructionCard(
            theme: theme,
            title: "You will be asked to:",
            instructions: const ["Blink your eyes", "Smile for the camera"],
          ),
          const Spacer(),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: () => _handleCameraCapture(context),
            child: Text(
              "Begin Verification",
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class InstructionCard extends StatelessWidget {
  final ThemeData theme;
  final String title;
  final List<String> instructions;

  const InstructionCard({
    super.key,
    required this.theme,
    required this.title,
    required this.instructions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...instructions.map(
                (instruction) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 20, color: theme.primaryColor),
                  const SizedBox(width: 12),
                  Text(instruction, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}