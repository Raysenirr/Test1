import 'package:flutter/material.dart';

import '../utils/jwt_utils.dart';

class JwtPayloadBlock extends StatelessWidget {
  final String title;
  final String? token;

  const JwtPayloadBlock({
    super.key,
    required this.title,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    final decoded = JwtUtils.decodePayloadAsPrettyJson(token);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$title\n\n',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              TextSpan(
                text: decoded ?? 'Не удалось декодировать payload',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}