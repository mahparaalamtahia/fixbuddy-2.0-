import 'package:flutter/foundation.dart';
import '../services/config_service.dart';

class AdminConfigProvider extends ChangeNotifier {
  final ConfigService _configService = ConfigService();

  Map<String, String> _config = {};
  bool _isLoading = false;
  String? _error;

  Map<String, String> get config => _config;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isChatEnabled => _config['feature_chat_enabled']?.toLowerCase() == 'true';
  bool get isCallEnabled => _config['feature_call_enabled']?.toLowerCase() == 'true';
  bool get isRatingsEnabled =>
      _config['feature_ratings_enabled']?.toLowerCase() == 'true';
  bool get isMaintenanceMode =>
      _config['maintenance_mode']?.toLowerCase() == 'true';
  String get bannerMessage => _config['banner_message'] ?? '';
  String get minAppVersion => _config['min_app_version_android'] ?? '1.0.0';

  AdminConfigProvider() {
    loadConfig();
  }

  Future<void> loadConfig() async {
    _setLoading(true);
    _clearError();
    try {
      final stream = _configService.streamConfig();
      await for (final config in stream) {
        _config = config;
        notifyListeners();
        break;
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateConfig({
    bool? chatEnabled,
    bool? callEnabled,
    bool? ratingsEnabled,
    bool? maintenanceMode,
    String? bannerMessage,
    String? minAppVersion,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      if (chatEnabled != null) {
        await _configService.setConfig('feature_chat_enabled', chatEnabled.toString());
      }
      if (callEnabled != null) {
        await _configService.setConfig('feature_call_enabled', callEnabled.toString());
      }
      if (ratingsEnabled != null) {
        await _configService.setConfig(
            'feature_ratings_enabled', ratingsEnabled.toString());
      }
      if (maintenanceMode != null) {
        await _configService.setConfig(
            'maintenance_mode', maintenanceMode.toString());
      }
      if (bannerMessage != null) {
        await _configService.setConfig('banner_message', bannerMessage);
      }
      if (minAppVersion != null) {
        await _configService.setConfig('min_app_version', minAppVersion);
      }
      await loadConfig();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
