import 'package:flutter/material.dart';

class AuthStateNotifier extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  void markAuthenticated() {
    _isAuthenticated = true;
    notifyListeners();
  }

  void markUnauthenticated() {
    _isAuthenticated = false;
    notifyListeners();
  }
}

final authStateNotifier = AuthStateNotifier();
