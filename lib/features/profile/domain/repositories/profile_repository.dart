import '../../../../core/utils/result.dart';
import '../entities/user_profile.dart';

abstract class ProfileRepository {
  Future<Result<UserProfile>> getMine();
  Future<Result<UserProfile>> getPublic(String userId);
  Future<Result<UserProfile>> updateMine(ProfileUpdate update);
  Future<Result<void>> heartbeat();
}
