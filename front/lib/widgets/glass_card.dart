import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final double blur;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.margin,
    this.borderColor,
    this.blur = 12,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final surfaceColor = cs.surface;
    final surfaceHighColor = isDark
        ? const Color(0xFF1A2E52)
        : const Color(0xFFE8EEF7);
    final defaultBorder = borderColor ??
        (isDark
            ? const Color(0xFF1A2E52).withValues(alpha: 0.5)
            : const Color(0xFFD0DCF0).withValues(alpha: 0.8));

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: padding ?? const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: isDark ? 0.85 : 0.92),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: defaultBorder, width: 1),
                gradient: LinearGradient(
                  colors: [
                    surfaceHighColor.withValues(alpha: isDark ? 0.4 : 0.5),
                    surfaceColor.withValues(alpha: isDark ? 0.6 : 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const GlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? AppColors.accentSuccess;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: btnColor,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: btnColor.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
