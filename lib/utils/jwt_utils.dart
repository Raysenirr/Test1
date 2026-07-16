import 'dart:convert';

class JwtUtils {
  static String? decodePayloadAsPrettyJson(String? token) {
    final payload = decodePayload(token);

    if (payload == null) {
      return null;
    }

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(payload);
  }

  static Map<String, dynamic>? decodePayload(String? token) {
    if (token == null || token.isEmpty) {
      return null;
    }

    final parts = token.split('.');

    if (parts.length != 3) {
      return null;
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decodedBytes = base64Url.decode(normalized);
      final decodedString = utf8.decode(decodedBytes);
      final decodedJson = jsonDecode(decodedString);

      if (decodedJson is! Map<String, dynamic>) {
        return null;
      }

      return decodedJson;
    } catch (_) {
      return null;
    }
  }
}