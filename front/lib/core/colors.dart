import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A1428);
  static const surface = Color(0xFF13223F);
  static const surfaceLight = Color(0xFF1A2E52);
  static const recordingBg = Color(0xFF05070F);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const neutral = Color(0xFF64748B);
  static const lightBackground = Color(0xFFF4F6FA);
  static const lightSurface = Colors.white;
  static const lightTextPrimary = Color(0xFF1E293B);
  static const lightTextSecondary = Color(0xFF64748B);
  static const lightNeutral = Color(0xFFD1D5DB);
  static const accentSuccess = Color(0xFF00E5B0);
  static const accentWarning = Color(0xFFFFB800);
  static const accentDanger = Color(0xFFFF3B6E);
  static const accentBlue = Color(0xFF00B8FF);
  static const waveStart = Color(0xFF00E5B0);
  static const waveEnd = Color(0xFF00B8FF);
  static Color scoreColor(double score) {
    if (score >= 80) return accentSuccess;
    if (score >= 60) return accentWarning;
    return accentDanger;
  }
  static const waveGradient = LinearGradient(
    colors: [waveStart, waveEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const backgroundGradient = LinearGradient(
    colors: [Color(0xFF0D1B3E), Color(0xFF0A1428)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static LinearGradient scoreGradient(double score) => LinearGradient(
    colors: [scoreColor(score), scoreColor(score).withValues(alpha: 0.7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}