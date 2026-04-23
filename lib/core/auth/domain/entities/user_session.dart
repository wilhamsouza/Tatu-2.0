import '../../../device_identity/domain/entities/device_registration.dart';
import '../../../sync/domain/entities/sync_status_snapshot.dart';
import '../../../tenancy/domain/entities/company_context.dart';
import 'app_user.dart';
import 'auth_token_pair.dart';

class UserSession {
  const UserSession({
    required this.user,
    required this.tokens,
    required this.companyContext,
    required this.deviceRegistration,
    required this.signedInAt,
    required this.syncStatus,
  });

  final AppUser user;
  final AuthTokenPair tokens;
  final CompanyContext companyContext;
  final DeviceRegistration deviceRegistration;
  final DateTime signedInAt;
  final SyncStatusSnapshot syncStatus;

  UserSession copyWith({
    AuthTokenPair? tokens,
    SyncStatusSnapshot? syncStatus,
  }) {
    return UserSession(
      user: user,
      tokens: tokens ?? this.tokens,
      companyContext: companyContext,
      deviceRegistration: deviceRegistration,
      signedInAt: signedInAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
