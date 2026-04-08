import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _getPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> save(String key, String value) async {
    final prefs = await _getPrefs;
    await prefs.setString(key, value);
  }

  Future<String?> read(String key) async {
    final prefs = await _getPrefs;
    return prefs.getString(key);
  }

  Future<void> remove(String key) async {
    final prefs = await _getPrefs;
    await prefs.remove(key);
  }

  Future<bool> contains(String key) async {
    final prefs = await _getPrefs;
    return prefs.containsKey(key);
  }

  Future<void> clearAll() async {
    final prefs = await _getPrefs;
    await prefs.clear();
  }

  Future<void> saveToken(String token) async {
    await save(AppConstants.tokenKey, token);
  }

  Future<String?> getToken() async {
    return read(AppConstants.tokenKey);
  }

  Future<void> saveSessionToken(String token) async {
    await save(AppConstants.sessionTokenKey, token);
  }

  Future<String?> getSessionToken() async {
    return read(AppConstants.sessionTokenKey);
  }

  Future<void> clearTokens() async {
    await remove(AppConstants.tokenKey);
    await remove(AppConstants.sessionTokenKey);
  }
}
