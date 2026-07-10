import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/utils/storage_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize local storage first so any providers that read it during
  // app startup won't access an uninitialized `_prefs`.
  await StorageHelper.init();

  await dotenv.load();

  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    publishableKey: SupabaseConfig.anonKey,
  );


  runApp(const ProviderScope(child: FixBuddyApp()));
}
