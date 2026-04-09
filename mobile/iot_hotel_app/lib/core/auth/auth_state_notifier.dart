import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final bool isAuthenticated;
  final String? token;
  final String? userId;
  final String? username;
  final String? role;
  final String? phone;
  final String? uid;

  const AuthState({
    this.isAuthenticated = false,
    this.token,
    this.userId,
    this.username,
    this.role,
    this.phone,
    this.uid,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? token,
    String? userId,
    String? username,
    String? role,
    String? phone,
    String? uid,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      uid: uid ?? this.uid,
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
    state = AuthState(
      isAuthenticated: true,
      token: token,
      userId: userId,
      username: username,
      role: role,
      phone: phone,
      uid: uid,
    );
  }

  void clearAuth() {
    state = const AuthState();
  }
}

final authStateNotifier = AuthStateNotifier();
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) => authStateNotifier);
