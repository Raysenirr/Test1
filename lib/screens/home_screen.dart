import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../widgets/jwt_payload_block.dart';
import '../widgets/masked_token_block.dart';
import '../widgets/profile_block.dart';
import '../widgets/status_block.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль и токены'),
        actions: [
          IconButton(
            onPressed: auth.isLoading
                ? null
                : () {
                    context.read<AuthProvider>().logout();
                  },
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StatusBlock(auth: auth),

          ElevatedButton(
            onPressed: auth.isLoading
                ? null
                : () {
                    context.read<AuthProvider>().refreshTokens();
                  },
            child: const Text('Обновить токены через refresh token'),
          ),

          const SizedBox(height: 16),

          ProfileBlock(profile: auth.profile),

          MaskedTokenBlock(
            title: 'Access Token',
            value: auth.accessToken,
          ),

          MaskedTokenBlock(
            title: 'ID Token',
            value: auth.idToken,
          ),

          MaskedTokenBlock(
            title: 'Refresh Token',
            value: auth.refreshToken,
          ),

          JwtPayloadBlock(
            title: 'Access Token payload',
            token: auth.accessToken,
          ),

          JwtPayloadBlock(
            title: 'ID Token payload',
            token: auth.idToken,
          ),

          if (auth.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              auth.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}