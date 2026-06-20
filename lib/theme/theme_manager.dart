import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class ThemeManager extends ChangeNotifier {
  ThemeManager._internal() {
    // Listen to Firebase Auth state changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _subscribeToUserPreferences(user.uid);
      } else {
        _unsubscribeFromUserPreferences();
        _themeMode = ThemeMode.system;
        notifyListeners();
      }
    });
  }

  static final ThemeManager instance = ThemeManager._internal();

  StreamSubscription? _authSubscription;
  StreamSubscription? _userPrefsSubscription;
  final UserService _userService = UserService();

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void _subscribeToUserPreferences(String uid) {
    _userPrefsSubscription?.cancel();
    _userPrefsSubscription = _userService.getUserDocumentStream(uid).listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final preferences = data?['preferences'] as Map<String, dynamic>?;
        final themeStr = preferences?['theme'] as String?;
        _updateThemeMode(themeStr);
      }
    }, onError: (error) {
      print('Error in user preferences stream: $error');
    });
  }

  void _unsubscribeFromUserPreferences() {
    _userPrefsSubscription?.cancel();
    _userPrefsSubscription = null;
  }

  void _updateThemeMode(String? themeStr) {
    ThemeMode newMode;
    switch (themeStr) {
      case 'light':
        newMode = ThemeMode.light;
        break;
      case 'dark':
        newMode = ThemeMode.dark;
        break;
      case 'system':
      default:
        newMode = ThemeMode.system;
        break;
    }
    if (_themeMode != newMode) {
      _themeMode = newMode;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userPrefsSubscription?.cancel();
    super.dispose();
  }
}
