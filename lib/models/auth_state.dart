import 'auth_tokens.dart';
import 'user_profile.dart';

class AuthState {
  final bool isAuthenticated;
  final AuthTokens? tokens;
  final UserProfile? profile;

  const AuthState({
    required this.isAuthenticated,
    required this.tokens,
    required this.profile,
  });

  const AuthState.unauthenticated()
      : isAuthenticated = false,
        tokens = null,
        profile = null;

  const AuthState.authenticated({
    required this.tokens,
    required this.profile,
  }) : isAuthenticated = true;
}