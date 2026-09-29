import '../../../../core/pagination/cursor_page.dart';
import '../../../../core/utils/result.dart';
import '../../../profile/domain/entities/user_profile.dart';

class DiscoveryQuery {
  const DiscoveryQuery({
    this.limit = 20,
    this.cursor,
    this.search,
    this.language,
    this.onlineOnly = false,
    this.callType,
  });

  final int limit;
  final String? cursor;
  final String? search;
  final String? language;
  final bool onlineOnly;
  final String? callType;

  Map<String, dynamic> toQueryParameters() {
    return {
      'limit': limit,
      if (cursor != null && cursor!.isNotEmpty) 'cursor': cursor,
      if (search != null && search!.trim().length >= 2) 'q': search!.trim(),
      if (language != null && language!.isNotEmpty) 'language': language,
      if (onlineOnly) 'online': true,
      if (callType != null && callType!.isNotEmpty) 'callType': callType,
    };
  }
}

abstract class DiscoveryRepository {
  Future<Result<CursorPage<UserProfile>>> feed(DiscoveryQuery query);
  Future<Result<CursorPage<UserProfile>>> search(DiscoveryQuery query);
}
