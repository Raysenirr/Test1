class TokenMasker {
  static String mask(String? token) {
    if (token == null || token.isEmpty) {
      return 'Нет данных';
    }

    if (token.length <= 20) {
      return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
    }

    final start = token.substring(0, 12);
    final end = token.substring(token.length - 12);

    return '$start...$end';
  }
}