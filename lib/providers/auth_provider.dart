import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  firebase_auth.User? _currentUser;
  app_user.User? _userDocument;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  firebase_auth.User? get currentUser => _currentUser;
  app_user.User? get userDocument => _userDocument;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((user) async {
      _currentUser = user;
      if (user != null) {
        await _loadUserDocument(user.uid);
      } else {
        _userDocument = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserDocument(String uid) async {
    try {
      _userDocument = await _authService.getUserDocument(uid);
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Sign in
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      final credential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return credential != null;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign up
  Future<bool> signUp({
    required String email,
    required String password,
    required String tenantId,
    String? displayName,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      final credential = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
        tenantId: tenantId,
        displayName: displayName,
      );
      
      return credential != null;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _setLoading(true);
      await _authService.signOut();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Refresh user document
  Future<void> refreshUserDocument() async {
    if (_currentUser != null) {
      await _loadUserDocument(_currentUser!.uid);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
}
