import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/pagination/cursor_page.dart';
import '../../../../core/utils/result.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/repositories/discovery_repository.dart';

class DiscoveryRemoteDataSource {
  DiscoveryRemoteDataSource(this._client);

  final ApiClient _client;

  Future<Result<CursorPage<UserProfile>>> feed(DiscoveryQuery query) {
    return _client.get(
      ApiPaths.discoveryFeed,
      query: query.toQueryParameters(),
      parser: (data) => CursorPage.fromJson(data, UserProfile.fromJson),
    );
  }

  Future<Result<CursorPage<UserProfile>>> search(DiscoveryQuery query) {
    return _client.get(
      ApiPaths.discoverySearch,
      query: query.toQueryParameters(),
      parser: (data) => CursorPage.fromJson(data, UserProfile.fromJson),
    );
  }
}

class DiscoveryRepositoryImpl implements DiscoveryRepository {
  DiscoveryRepositoryImpl(this._remote);

  final DiscoveryRemoteDataSource _remote;

  @override
  Future<Result<CursorPage<UserProfile>>> feed(DiscoveryQuery query) {
    return _remote.feed(query);
  }

  @override
  Future<Result<CursorPage<UserProfile>>> search(DiscoveryQuery query) {
    return _remote.search(query);
  }
}
