import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/notifiers/session_notifier.dart';
import '../../../database/providers/database_providers.dart';
import '../../../ui/theme/app_theme_tokens.dart';
import '../../../ui/widgets/app_status_badge.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const String _demoPassword = 'tatuzin123';

  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: 'admin@tatuzin.app');
    _passwordController = TextEditingController(text: _demoPassword);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    await ref.read(appBootstrapProvider.future);

    await ref
        .read(sessionNotifierProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    final session = ref.read(sessionNotifierProvider).asData?.value;
    if (session != null) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final error = ref.read(sessionNotifierProvider.notifier).friendlyError;
    final tokens = context.tatuzinTokens;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[tokens.canvasMuted, tokens.canvas],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: tokens.pagePadding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(TatuzinSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: TatuzinSpacing.md,
                      children: <Widget>[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(TatuzinSpacing.xl),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                tokens.heroStart,
                                tokens.heroEnd,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              tokens.heroRadius,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: TatuzinSpacing.sm,
                            children: <Widget>[
                              const AppStatusBadge(
                                label: 'PDV + ERP + CRM',
                                tone: AppTone.primary,
                              ),
                              Text(
                                'Tatuzin 2.0',
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(color: tokens.heroForeground),
                              ),
                              Text(
                                'Acesse com os perfis demo do backend para operar o PDV, testar o sync e navegar pelo administrativo.',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(
                                  color: tokens.heroForeground.withValues(
                                    alpha: 0.92,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'E-mail'),
                        ),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Senha'),
                        ),
                        if (error != null)
                          Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isSubmitting || sessionState.isLoading
                                ? null
                                : _submit,
                            child: Text(
                              _isSubmitting || sessionState.isLoading
                                  ? 'Entrando...'
                                  : 'Entrar',
                            ),
                          ),
                        ),
                        const Divider(),
                        Text(
                          'Perfis demo',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Senha padrao: tatuzin123',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Wrap(
                          spacing: TatuzinSpacing.xs,
                          runSpacing: TatuzinSpacing.xs,
                          children: <Widget>[
                            _QuickProfileChip(
                              label: 'Admin',
                              email: 'admin@tatuzin.app',
                              onSelected: _fillCredentials,
                            ),
                            _QuickProfileChip(
                              label: 'Manager',
                              email: 'manager@tatuzin.app',
                              onSelected: _fillCredentials,
                            ),
                            _QuickProfileChip(
                              label: 'Seller',
                              email: 'seller@tatuzin.app',
                              onSelected: _fillCredentials,
                            ),
                            _QuickProfileChip(
                              label: 'Cashier',
                              email: 'cashier@tatuzin.app',
                              onSelected: _fillCredentials,
                            ),
                            _QuickProfileChip(
                              label: 'CRM',
                              email: 'crm@tatuzin.app',
                              onSelected: _fillCredentials,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _fillCredentials(String email) {
    _emailController.text = email;
    _passwordController.text = _demoPassword;
  }
}

class _QuickProfileChip extends StatelessWidget {
  const _QuickProfileChip({
    required this.label,
    required this.email,
    required this.onSelected,
  });

  final String label;
  final String email;
  final void Function(String email) onSelected;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.person_outline, size: 18),
      label: Text(label),
      onPressed: () => onSelected(email),
    );
  }
}
