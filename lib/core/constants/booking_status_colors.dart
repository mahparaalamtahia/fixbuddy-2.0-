import 'package:flutter/material.dart';
import 'app_colors.dart';

class BookingStatusColors {
  BookingStatusColors._();

  static const Map<String, Color> statusColors = {
    'pending': AppColors.bookingPending,
    'confirmed': AppColors.bookingConfirmed,
    'in_progress': AppColors.bookingInProgress,
    'completed': AppColors.bookingCompleted,
    'cancelled': AppColors.bookingCancelled,
    'declined': AppColors.bookingDeclined,
  };

  static Color getColor(String status) {
    return statusColors[status] ?? AppColors.textSecondary;
  }

  static String getLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'declined':
        return 'Declined';
      default:
        return status;
    }
  }

  static IconData getIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'in_progress':
        return Icons.engineering;
      case 'completed':
        return Icons.verified;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'declined':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }
}
