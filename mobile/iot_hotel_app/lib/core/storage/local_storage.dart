import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  SharedPreferences? _prefs;
  
  // 加密存储实例，用于存储敏感数据（Token等）
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<SharedPreferences> get _getPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ==================== 普通数据存储（使用SharedPreferences） ====================

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

  // ==================== 敏感数据存储（使用加密存储） ====================

  /// 保存Token到加密存储
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
  }

  /// 从加密存储读取Token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: AppConstants.tokenKey);
  }

  /// 保存Session Token到加密存储
  Future<void> saveSessionToken(String token) async {
    await _secureStorage.write(key: AppConstants.sessionTokenKey, value: token);
  }

  /// 从加密存储读取Session Token
  Future<String?> getSessionToken() async {
    return await _secureStorage.read(key: AppConstants.sessionTokenKey);
  }

  /// 清除所有Token
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.sessionTokenKey);
  }

  /// 清除所有加密数据
  Future<void> clearSecureStorage() async {
    await _secureStorage.deleteAll();
  }

  // ==================== 非敏感配置数据（使用SharedPreferences） ====================

  Future<void> saveUserRole(String role) async {
    await save(AppConstants.userRoleKey, role);
  }

  Future<String?> getUserRole() async {
    return read(AppConstants.userRoleKey);
  }
}
