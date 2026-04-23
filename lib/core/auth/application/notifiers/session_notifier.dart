import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/demo_auth_repository.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';

final sessionNotifierProvider =
    AsyncNotifierProvider<SessionNotifier, UserSession?>(SessionNotifier.new);

class SessionNotifier extends AsyncNotifier<UserSession?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<UserSession?> build() {
    return _repository.restore();
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.login(email: email, password: password),
    );
  }

  Future<void> refreshSession() async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.refresh(current));
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncData(null);
  }

  String? get friendlyError {
    final error = state.error;
    if (error == null) {
      return null;
    }
    if (error is AuthException) {
      return error.message;
    }
    return error.toString();
  }
}
