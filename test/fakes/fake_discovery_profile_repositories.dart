import 'package:gmatez_app/core/pagination/cursor_page.dart';
import 'package:gmatez_app/core/utils/result.dart';
import 'package:gmatez_app/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:gmatez_app/features/profile/domain/entities/user_profile.dart';
import 'package:gmatez_app/features/profile/domain/repositories/profile_repository.dart';

class FakeDiscoveryRepository implements DiscoveryRepository {
  FakeDiscoveryRepository({this.feedResult, this.searchResult});

  Result<CursorPage<UserProfile>>? feedResult;
  Result<CursorPage<UserProfile>>? searchResult;
  int feedCalls = 0;
  int searchCalls = 0;
  DiscoveryQuery? lastQuery;

  static final sampleUsers = [
    UserProfile(
      userId: 'user-2',
      displayName: 'Bob',
      bio: 'Say hello',
      gender: 'MALE',
      language: 'en',
      ratePerMinuteCents: 100,
      online: true,
      availableForCall: true,
    ),
    UserProfile(
      userId: 'user-3',
      displayName: 'Carol',
      bio: 'Night chats',
      gender: 'FEMALE',
      language: 'es',
      ratePerMinuteCents: 120,
      online: false,
      availableForCall: false,
    ),
  ];

  @override
  Future<Result<CursorPage<UserProfile>>> feed(DiscoveryQuery query) async {
    feedCalls += 1;
    lastQuery = query;
    return feedResult ??
        Success(CursorPage(items: sampleUsers, nextCursor: null));
  }

  @override
  Future<Result<CursorPage<UserProfile>>> search(DiscoveryQuery query) async {
    searchCalls += 1;
    lastQuery = query;
    return searchResult ??
        Success(
          CursorPage(
            items: sampleUsers
                .where(
                  (user) => user.displayName.toLowerCase().contains(
                    (query.search ?? '').toLowerCase(),
                  ),
                )
                .toList(),
          ),
        );
  }
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.mine, this.publicProfile, this.updateResult});

  UserProfile? mine;
  UserProfile? publicProfile;
  Result<UserProfile>? updateResult;
  int updateCalls = 0;
  ProfileUpdate? lastUpdate;

  static const sampleMine = UserProfile(
    userId: 'user-1',
    displayName: 'Alice',
    bio: 'Available for calls',
    gender: 'FEMALE',
    language: 'en',
    country: 'US',
    isDiscoverable: true,
    ratePerMinuteCents: 150,
    online: true,
    availableForCall: true,
  );

  @override
  Future<Result<UserProfile>> getMine() async {
    return Success(mine ?? sampleMine);
  }

  @override
  Future<Result<UserProfile>> getPublic(String userId) async {
    return Success(
      publicProfile ??
          UserProfile(
            userId: userId,
            displayName: 'Bob',
            bio: 'Say hello',
            gender: 'MALE',
            ratePerMinuteCents: 100,
            online: true,
            availableForCall: true,
          ),
    );
  }

  @override
  Future<Result<UserProfile>> updateMine(ProfileUpdate update) async {
    updateCalls += 1;
    lastUpdate = update;
    return updateResult ??
        Success(
          UserProfile(
            userId: sampleMine.userId,
            displayName: update.displayName ?? sampleMine.displayName,
            bio: update.bio ?? sampleMine.bio,
            gender: update.gender ?? sampleMine.gender,
            country: update.country ?? sampleMine.country,
            language: update.language ?? sampleMine.language,
            avatarUrl: update.avatarUrl ?? sampleMine.avatarUrl,
            isDiscoverable: update.isDiscoverable ?? sampleMine.isDiscoverable,
            ratePerMinuteCents:
                update.ratePerMinuteCents ?? sampleMine.ratePerMinuteCents,
            online: true,
            availableForCall: true,
          ),
        );
  }

  @override
  Future<Result<void>> heartbeat() async => const Success(null);
}
