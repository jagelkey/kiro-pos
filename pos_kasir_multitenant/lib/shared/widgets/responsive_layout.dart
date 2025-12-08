import 'package:flutter/material.dart';
import '../../core/constants/breakpoints.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (Breakpoints.isDesktop(constraints.maxWidth)) {
          return desktop ?? tablet ?? mobile;
        } else if (Breakpoints.isTabletOrLarger(constraints.maxWidth)) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}
