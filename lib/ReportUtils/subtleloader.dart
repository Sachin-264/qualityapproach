import 'package:flutter/material.dart';

class SubtleLoader extends StatefulWidget {
  const SubtleLoader({super.key});

  @override
  State<SubtleLoader> createState() => _SubtleLoaderState();
}

class _SubtleLoaderState extends State<SubtleLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 40,
        height: 40,
        child: RotationTransition(
          turns: Tween(begin: 0.0, end: 1.0).animate(_controller),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue[800]!.withOpacity(0.6),
                width: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}