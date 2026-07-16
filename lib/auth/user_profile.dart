import 'dart:convert';

class UserProfile {
  final String? subject;
  final String? name;
  final String? preferredUsername;
  final String? email;
  final Map<String, dynamic> claims;

  const UserProfile({
    required this.subject,
    required this.name,
    required this.preferredUsername,
    required this.email,
    required this.claims,
  });

  factory UserProfile.fromIdToken(String idToken) {
    final parts = idToken.split('.');

    if (parts.length != 3) {
      throw Exception('ID token имеет неверный формат');
    }

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decodedBytes = base64Url.decode(normalized);
    final decodedString = utf8.decode(decodedBytes);
    final decodedJson = jsonDecode(decodedString);

    if (decodedJson is! Map<String, dynamic>) {
      throw Exception('Не удалось прочитать payload ID token');
    }

    return UserProfile.fromClaims(decodedJson);
  }

  factory UserProfile.fromClaims(Map<String, dynamic> claims) {
    return UserProfile(
      subject: _readString(claims, [
        'sub',
        'subject',
        'user_id',
        'id',
      ]),
      name: _readString(claims, [
        'name',
        'full_name',
        'display_name',
      ]),
      preferredUsername: _readString(claims, [
        'preferred_username',
        'username',
        'login',
        'user_name',
        'nickname',
      ]),
      email: _readString(claims, [
        'email',
        'mail',
      ]),
      claims: claims,
    );
  }

  static String? _readString(
    Map<String, dynamic> claims,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = claims[key];

      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }

    return null;
  }
}