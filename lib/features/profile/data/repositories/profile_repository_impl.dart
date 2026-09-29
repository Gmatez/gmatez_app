import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._client);

  final ApiClient _client;

  Future<Result<UserProfile>> getMine() {
    return _client.get(
      ApiPaths.profilesMe,
      parser: (data) => UserProfile.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Result<UserProfile>> getPublic(String userId) {
    return _client.get(
      ApiPaths.user(userId),
      parser: (data) => UserProfile.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Result<UserProfile>> updateMine(ProfileUpdate update) {
    return _client.patch(
      ApiPaths.profilesMe,
      body: update.toJson(),
      parser: (data) => UserProfile.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Result<void>> heartbeat() {
    return _client.post(ApiPaths.usersHeartbeat, parser: (_) {});
  }
}

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<Result<UserProfile>> getMine() => _remote.getMine();

  @override
  Future<Result<UserProfile>> getPublic(String userId) =>
      _remote.getPublic(userId);

  @override
  Future<Result<UserProfile>> updateMine(ProfileUpdate update) {
    return _remote.updateMine(update);
  }

  @override
  Future<Result<void>> heartbeat() => _remote.heartbeat();
}
