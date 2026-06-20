import 'package:flutter/material.dart';

class CircuitBackgroundPainter extends CustomPainter {
  final Color color;

  CircuitBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Clean background - no lines drawn as per user request
  }

  @override
  bool shouldRepaint(covariant CircuitBackgroundPainter oldDelegate) {
    return false;
  }
}

class CircuitBackgroundWidget extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final Color color;

  const CircuitBackgroundWidget({
    super.key,
    required this.child,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
