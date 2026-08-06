import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ---- Stream of auth state changes ----
  Stream<User?> get authStateChanges =>
      _supabase.auth.onAuthStateChange.map((event) => event.session?.user);

  // ---- Current user (if any) ----
  User? get currentUser => _supabase.auth.currentUser;

  // ---- Email/Password Sign In ----
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user;
    } catch (e) {
      rethrow;
    }
  }

  // ---- Email/Password Sign Up ----
  Future<User?> signUpWithEmail(
    String email,
    String password,
    String username,
  ) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      return response.user;
    } catch (e) {
      rethrow;
    }
  }

  // ---- Magic Link (optional) ----
  Future<void> sendMagicLink(String email) async {
    await _supabase.auth.signInWithOtp(
      email: email,
      emailRedirectTo: 'veil://login-callback', // optional
    );
  }

  // ---- Google Sign‑In (optional) ----
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://login-callback/',
    );
  }

  // ---- Sign Out ----
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // ---- Reset Password (optional) ----
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }
}
