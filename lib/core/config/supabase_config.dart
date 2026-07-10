import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get projectUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'YOUR_SUPABASE_PROJECT_URL';
  static String get anonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'YOUR_SUPABASE_ANON_KEY';
}
