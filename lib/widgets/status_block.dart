import 'package:flutter/material.dart';

import '../auth/auth_provider.dart';
import '../utils/date_time_utils.dart';

class StatusBlock extends StatelessWidget {
  final AuthProvider auth;

  const StatusBlock({
    super.key,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    final scopeText = auth.scopes?.join(' ') ?? 'Нет данных';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Состояние',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Статус авторизации: ${auth.authorizationStatus}'),
            Text('Token Type: ${auth.tokenType ?? 'Нет данных'}'),
            Text('Scope: $scopeText'),
            Text(
              'Осталось до истечения Access Token: '
              '${auth.expiresIn?.toString() ?? 'Нет данных'} секунд',
            ),
            Text(
              'Access Token истекает: '
              '${DateTimeUtils.format(auth.accessTokenExpiration)}',
            ),
            const Text('Refresh Token истекает: недоступно'),
            Text(
              'Последнее обновление токенов: '
              '${DateTimeUtils.format(auth.lastTokenRefreshTime)}',
            ),
          ],
        ),
      ),
    );
  }
}