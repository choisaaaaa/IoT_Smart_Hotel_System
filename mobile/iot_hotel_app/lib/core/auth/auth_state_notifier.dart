import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppMode {
  guest,
  customer,
  reception,
  manager,
  system,
}

class AppRoles {
  static const String systemAdmin = 'system_admin';
  static const String hotelAdmin = 'hotel_admin';
  static const String staff = 'staff';
  static const String customer = 'customer';

  static String normalize(String? role) {
    if (role == null) return customer;
    final r = role.trim().toLowerCase();
    switch (r) {
      case 'system':
      case 'systemadmin':
      case 'sys_admin':
      case 'super_admin':
      case 'platform_admin':
        return systemAdmin;
      case 'admin':
      case 'manager':
      case 'hotelmanager':
      case 'hotel_admin':
        return hotelAdmin;
      case 'staff':
      case 'receptionist':
      case 'reception':
      case 'front_desk':
      case 'frontdesk':
        return staff;
      case 'user':
      case 'customer':
      case 'guest':
        return customer;
      default:
        return r;
    }
  }

  static String displayName(String role) {
    switch (role) {
      case systemAdmin: return '系统管理员';
      case hotelAdmin: return '酒店管理员';
      case staff: return '前台员工';
      case customer: return '顾客';
      default: return role;
    }
  }
}

int roleToLevel(String? role) {
  final normalized = AppRoles.normalize(role);
  switch (normalized) {
    case AppRoles.systemAdmin: return 4;
    case AppRoles.hotelAdmin: return 3;
    case AppRoles.staff: return 2;
    case AppRoles.customer: return 1;
    default: return 0;
  }
}

class AuthState {
  final bool isAuthenticated;
  final bool isInitialized;
  final String? token;
  final String? userId;
  final String? username;
  final String? role;
  final String? phone;
  final String? uid;
  final AppMode currentMode;

  const AuthState({
    this.isAuthenticated = false,
    this.isInitialized = false,
    this.token,
    this.userId,
    this.username,
    this.role,
    this.phone,
    this.uid,
    this.currentMode = AppMode.guest,
  });

  int get roleLevel => roleToLevel(role);

  bool canSwitchTo(AppMode mode) {
    if (!isAuthenticated) return mode == AppMode.guest;
    switch (mode) {
      case AppMode.guest: return true;
      case AppMode.customer: return roleLevel >= 1;
      case AppMode.reception: return roleLevel >= 2;
      case AppMode.manager: return roleLevel >= 3;
      case AppMode.system: return roleLevel >= 4;
    }
  }

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isInitialized,
    String? token,
    String? userId,
    String? username,
    String? role,
    String? phone,
    String? uid,
    AppMode? currentMode,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isInitialized: isInitialized ?? this.isInitialized,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      uid: uid ?? this.uid,
      currentMode: currentMode ?? this.currentMode,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(const AuthState());

  void setAuth({
    required String token,
    required String userId,
    required String username,
    required String role,
    String? phone,
    String? uid,
  }) {
    final normalizedRole = AppRoles.normalize(role);
    AppMode initialMode;
    switch (normalizedRole) {
      case AppRoles.systemAdmin: initialMode = AppMode.system; break;
      case AppRoles.hotelAdmin: initialMode = AppMode.manager; break;
      case AppRoles.staff: initialMode = AppMode.reception; break;
      case AppRoles.customer: initialMode = AppMode.customer; break;
      default: initialMode = AppMode.guest;
    }
    state = AuthState(
      isAuthenticated: true,
      isInitialized: true,
      token: token,
      userId: userId,
      username: username,
      role: normalizedRole,
      phone: phone,
      uid: uid,
      currentMode: initialMode,
    );
  }

  void markInitialized() {
    state = state.copyWith(isInitialized: true);
  }

  void switchMode(AppMode mode) {
    if (state.canSwitchTo(mode)) {
      state = state.copyWith(currentMode: mode);
    }
  }

  void clearAuth() {
    state = const AuthState(isInitialized: true);
  }
}

final authStateNotifier = AuthStateNotifier();
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) => authStateNotifier);
