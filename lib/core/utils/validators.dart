class Validators {
  Validators._();

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Please enter a valid email';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) return 'Full name is required';
    if (value.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return null; // Phone is optional
    final phoneRegex = RegExp(r'^\+?[\d\s-]{10,15}$');
    if (!phoneRegex.hasMatch(value)) return 'Please enter a valid phone number';
    return null;
  }

  static String? validateRequired(String? value,
      [String field = 'This field']) {
    if (value == null || value.isEmpty) return '$field is required';
    return null;
  }

  static String? validateNumeric(String? value, [String field = 'This field']) {
    if (value == null || value.isEmpty) return '$field is required';
    if (double.tryParse(value) == null) return 'Please enter a valid number';
    return null;
  }
}
