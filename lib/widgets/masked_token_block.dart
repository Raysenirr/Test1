import 'package:flutter/material.dart';

import '../utils/token_masker.dart';

class MaskedTokenBlock extends StatelessWidget {
  final String title;
  final String? value;

  const MaskedTokenBlock({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final maskedValue = TokenMasker.mask(value);

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
                text: maskedValue,
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