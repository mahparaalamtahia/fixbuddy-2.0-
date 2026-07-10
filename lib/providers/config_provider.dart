import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/config_service.dart';
import '../models/app_config_model.dart';

final configServiceProvider = Provider<ConfigService>((ref) => ConfigService());

final allConfigProvider = FutureProvider<List<AppConfigModel>>((ref) async {
  final configService = ref.watch(configServiceProvider);
  return await configService.getAllConfig();
});

final configMapProvider = FutureProvider<Map<String, String>>((ref) async {
  final configService = ref.watch(configServiceProvider);
  return await configService.getConfigMap();
});

final configValueProvider =
    FutureProvider.family<String?, String>((ref, key) async {
  final configService = ref.watch(configServiceProvider);
  return await configService.getValue(key);
});

final configStreamProvider = StreamProvider<Map<String, String>>((ref) {
  final configService = ref.watch(configServiceProvider);
  return configService.streamConfig();
});
