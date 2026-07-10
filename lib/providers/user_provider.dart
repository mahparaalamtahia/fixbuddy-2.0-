import 'package:flutter/foundation.dart';
import '../services/profile_service.dart';
import '../models/profile_model.dart';

class UserProvider extends ChangeNotifier {
  final ProfileService _profileService = ProfileService();

  List<ProfileModel> _users = [];
  bool _isLoading = false;
  String? _error;

  List<ProfileModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  UserProvider() {
    loadUsers();
  }

  Future<void> loadUsers() async {
    _setLoading(true);
    _clearError();
    try {
      final data = await _profileService.getWorkerProfiles();
      _users = data;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deactivateUser(String uid) async {
    _setLoading(true);
    _clearError();
    try {
      await _profileService.updateProfile(uid, {'is_active': false});
      await loadUsers();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteUser(String uid) async {
    _setLoading(true);
    _clearError();
    try {
      await _profileService.updateProfile(uid, {'is_active': false});
      await loadUsers();
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
