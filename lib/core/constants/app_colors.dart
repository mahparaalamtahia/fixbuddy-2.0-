import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF5E92F3);
  static const Color primaryDark = Color(0xFF003C8F);

  // Secondary palette
  static const Color secondary = Color(0xFFF9A825);
  static const Color secondaryLight = Color(0xFFFFD95A);
  static const Color secondaryDark = Color(0xFFC17900);

  // Neutral
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);

  // Text
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);

  // Booking status colors
  static const Color bookingPending = Color(0xFFFFA726);
  static const Color bookingConfirmed = Color(0xFF42A5F5);
  static const Color bookingInProgress = Color(0xFF66BB6A);
  static const Color bookingCompleted = Color(0xFF26A69A);
  static const Color bookingCancelled = Color(0xFFEF5350);
  static const Color bookingDeclined = Color(0xFFBDBDBD);
}
