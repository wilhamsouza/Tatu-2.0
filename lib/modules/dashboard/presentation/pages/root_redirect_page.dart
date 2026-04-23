import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/application/notifiers/session_notifier.dart';
import '../../../../core/database/providers/database_providers.dart';

class RootRedirectPage extends ConsumerWidget {
  const RootRedirectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);
    final session = ref.watch(sessionNotifierProvider);

    return Scaffold(
      body: Center(
        child: bootstrap.when(
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => Text('Falha ao inicializar: $error'),
          data: (_) {
            if (session.isLoading) {
              return const CircularProgressIndicator();
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) {
                return;
              }
              context.go(
                session.asData?.value == null ? '/login' : '/dashboard',
              );
            });

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
