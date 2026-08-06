import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:veil/export.dart'; // adjust if needed

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthState {
  final User? user;
  final bool isLoading;
  final String? errorMessage;

  AuthState({this.user, this.isLoading = false, this.errorMessage});

  AuthState copyWith({User? user, bool? isLoading, String? errorMessage}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  Timer? _errorTimer;
  StreamSubscription? _authSubscription;

  AuthNotifier(this._authService)
    : super(AuthState(user: _authService.currentUser)) {
    _authSubscription = _authService.authStateChanges.listen((user) {
      if (mounted) {
        state = state.copyWith(user: user, isLoading: false);
      }
    });
  }

  void _setError(String? message) {
    _errorTimer?.cancel();
    _errorTimer = null;
    if (message == null) {
      state = state.copyWith(errorMessage: null);
      return;
    }
    state = state.copyWith(errorMessage: message);
    _errorTimer = Timer(const Duration(seconds: 5), () {
      if (state.errorMessage == message) {
        state = state.copyWith(errorMessage: null);
      }
      _errorTimer = null;
    });
  }

  String _parseAuthException(dynamic error) {
    if (error is SocketException) return '📡 No internet connection.';
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      final code = error.statusCode;
      if (msg.contains('invalid email'))
        return '✉️ Please enter a valid email.';
      if (msg.contains('weak password'))
        return '🔒 Password must be at least 6 characters.';
      if (msg.contains('invalid login credentials') || code == '400') {
        return '❌ Invalid email or password.';
      }
      if (msg.contains('already registered'))
        return '👤 Email already registered.';
      if (code == '429') return '⏳ Too many attempts. Wait a moment.';
      return '🔐 Auth error: ${error.message}';
    }
    return '⚠️ Something went wrong.';
  }

  // ---- Login ----
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    _errorTimer?.cancel();
    try {
      final user = await _authService.signInWithEmail(email, password);
      if (user != null) {
        state = state.copyWith(user: user, isLoading: false);
        _setError(null);
        return true;
      } else {
        state = state.copyWith(isLoading: false);
        _setError('❌ Invalid credentials.');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _setError(_parseAuthException(e));
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'veil://reset-password',
      );
      state = state.copyWith(isLoading: false);
      _setError('✅ Password reset email sent.');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _setError(_parseAuthException(e));
      return false;
    }
  }

  // ---- Sign Up ----
  // ---- Sign Up (creates user, sends confirmation email) ----
  Future<bool> signUp(String email, String password, String username) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _authService.signUpWithEmail(
        email,
        password,
        username,
      );
      if (user != null) {
        // User created – they need to confirm email
        // Store credentials for later use (if needed)
        state = state.copyWith(isLoading: false);
        _setError(null);
        return true;
      } else {
        state = state.copyWith(isLoading: false);
        _setError('❌ Sign-up failed.');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _setError(_parseAuthException(e));
      return false;
    }
  }

  // ---- Verify OTP (confirms email and signs in) ----
  Future<bool> verifyOtpAndSignIn({
    required String email,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.signup, // confirms email
      );
      if (response.session != null) {
        // User is now signed in
        state = state.copyWith(user: response.session!.user, isLoading: false);
        _setError(null);
        return true;
      } else {
        state = state.copyWith(isLoading: false);
        _setError('❌ Verification failed.');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _setError(_parseAuthException(e));
      return false;
    }
  }

  // ---- Resend Confirmation Email ----
  Future<void> resendConfirmation(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      state = state.copyWith(isLoading: false);
      _setError('✅ New confirmation email sent.');
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _setError(_parseAuthException(e));
    }
  }

  // ---- Sign Out ----
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    _errorTimer?.cancel();
    await _authService.signOut();
    state = state.copyWith(user: null, isLoading: false);
    _setError(null);
  }

  // ---- Send OTP (no user created) ----
  Future<bool> sendOtp(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false, // prevents user creation
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _setError(_parseAuthException(e));
      return false;
    }
  }

  // ---- Verify OTP and then sign up ----
  Future<bool> verifyOtpAndSignUp({
    required String email,
    required String password,
    required String username,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. Verify OTP
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.signup,
      );

      // 2. If successful, create the user
      final user = await _authService.signUpWithEmail(
        email,
        password,
        username,
      );
      if (user == null) {
        state = state.copyWith(isLoading: false);
        _setError('❌ Sign-up failed.');
        return false;
      }

      state = state.copyWith(user: user, isLoading: false);
      _setError(null);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _setError(_parseAuthException(e));
      return false;
    }
  }

  // ---- Resend OTP ----
  Future<void> resendOtp(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
      state = state.copyWith(isLoading: false);
      _setError('✅ New OTP sent.');
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _setError(_parseAuthException(e));
    }
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
