import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppMode {
  guest,
  customer,
  reception,
  manager,
  system,
}

int roleToLevel(String? role) {
  switch (role) {
    case 'admin':
    case 'system': return 4;
    case 'manager': return 3;
    case 'staff':
    case 'receptionist': return 2;
    case 'user': return 1;
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
    AppMode initialMode;
    switch (role) {
      case 'admin':
      case 'system': initialMode = AppMode.system; break;
      case 'manager': initialMode = AppMode.manager; break;
      case 'staff':
      case 'receptionist': initialMode = AppMode.reception; break;
      case 'user': initialMode = AppMode.customer; break;
      default: initialMode = AppMode.guest;
    }
    state = AuthState(
      isAuthenticated: true,
      isInitialized: true,
      token: token,
      userId: userId,
      username: username,
      role: role,
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
