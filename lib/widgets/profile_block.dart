import 'package:flutter/material.dart';

import '../models/user_profile.dart';

class ProfileBlock extends StatelessWidget {
  final UserProfile? profile;

  const ProfileBlock({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Профиль из ID Token',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('ID: ${profile?.subject ?? 'Нет данных'}'),
            Text('Имя: ${profile?.name ?? 'Нет данных'}'),
            Text('Email: ${profile?.email ?? 'Нет данных'}'),
          ],
        ),
      ),
    );
  }
}