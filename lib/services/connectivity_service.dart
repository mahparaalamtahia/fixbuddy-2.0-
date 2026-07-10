import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Stream<bool> get connectivityStream {
    return _connectivity.onConnectivityChanged.map((result) {
      final hasInternet = !result.contains(ConnectivityResult.none);
      _isOnline = hasInternet;
      return hasInternet;
    });
  }

  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    return _isOnline;
  }

  Future<void> initialize() async {
    await checkConnectivity();
  }
}
