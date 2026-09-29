import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/core/pagination/cursor_page.dart';
import 'package:gmatez_app/features/profile/domain/entities/user_profile.dart';

void main() {
  test('parses a discovery item with missing optional fields', () {
    final profile = UserProfile.fromJson({
      'userId': 'abc',
      'displayName': 'Bob',
      'online': true,
      'availableForCall': true,
    });
    expect(profile.userId, 'abc');
    expect(profile.displayName, 'Bob');
    expect(profile.bio, isEmpty);
    expect(profile.language, isNull);
    expect(profile.online, isTrue);
  });

  test('parses a nested public profile payload', () {
    final profile = UserProfile.fromJson({
      'id': 'user-9',
      'online': false,
      'availableForCall': false,
      'profile': {
        'displayName': 'Eve',
        'bio': 'Hello',
        'gender': 'FEMALE',
        'ratePerMinuteCents': 90,
      },
    });
    expect(profile.userId, 'user-9');
    expect(profile.displayName, 'Eve');
    expect(profile.ratePerMinuteCents, 90);
    expect(profile.availableForCall, isFalse);
  });

  test('parses cursor pages and empty lists', () {
    final page = CursorPage.fromJson({
      'items': [
        {'userId': '1', 'displayName': 'A'},
      ],
      'nextCursor': 'cursor-1',
    }, UserProfile.fromJson);
    expect(page.items.single.displayName, 'A');
    expect(page.hasMore, isTrue);

    final empty = CursorPage.fromJson({
      'items': <dynamic>[],
      'nextCursor': null,
    }, UserProfile.fromJson);
    expect(empty.items, isEmpty);
    expect(empty.hasMore, isFalse);
  });
}
