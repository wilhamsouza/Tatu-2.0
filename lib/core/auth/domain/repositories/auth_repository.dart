import '../entities/user_session.dart';

abstract class AuthRepository {
  Future<UserSession?> restore();

  Future<UserSession> login({required String email, required String password});

  Future<UserSession> refresh(UserSession session);

  Future<void> logout();
}
