import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Supabase client
// ---------------------------------------------------------------------------

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

// ---------------------------------------------------------------------------
// Auth state stream
// ---------------------------------------------------------------------------

final authStateProvider = StreamProvider<Session?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  yield client.auth.currentSession;
  yield* client.auth.onAuthStateChange.map((e) => e.session);
});

// ---------------------------------------------------------------------------
// Current user
// ---------------------------------------------------------------------------

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});

// ---------------------------------------------------------------------------
// Auth actions
// ---------------------------------------------------------------------------

final authActionsProvider = Provider<AuthActions>(
  (ref) => AuthActions(ref.watch(supabaseClientProvider)),
);

class AuthActions {
  AuthActions(this._client);

  final SupabaseClient _client;

  // Email / password ----------------------------------------------------------

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      _client.auth.signUp(email: email, password: password);

  // Google Sign-In ------------------------------------------------------------

  Future<void> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: '503008906051-k2nkogiv6uv21daun6hlklsetb6do5mo.apps.googleusercontent.com',
    );
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
      accessToken: googleAuth.accessToken,
    );

    // Sync display name and avatar to profiles table
    final user = _client.auth.currentUser;
    if (user != null) {
      final name = googleUser.displayName;
      final avatar = googleUser.photoUrl;
      if (name != null || avatar != null) {
        await _client.from('profiles').upsert({
          'id': user.id,
          'email': user.email ?? googleUser.email,
          'display_name': name,
          'avatar_url': avatar,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  // Sign out ------------------------------------------------------------------

  Future<void> signOut() async {
    // Ignore errors — GoogleSignIn may not have an active session
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email);
}
