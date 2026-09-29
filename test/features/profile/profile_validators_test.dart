import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/features/profile/domain/validators/profile_validators.dart';

void main() {
  test('display name follows backend length rules', () {
    expect(ProfileValidators.displayName('A'), isNotNull);
    expect(ProfileValidators.displayName('Alice'), isNull);
    expect(ProfileValidators.displayName('x' * 41), isNotNull);
  });

  test('bio cannot exceed 280 characters', () {
    expect(ProfileValidators.bio('ok'), isNull);
    expect(ProfileValidators.bio('x' * 281), isNotNull);
  });

  test('language and country codes are optional but constrained', () {
    expect(ProfileValidators.language(''), isNull);
    expect(ProfileValidators.language('en'), isNull);
    expect(ProfileValidators.language('!!'), isNotNull);
    expect(ProfileValidators.country('US'), isNull);
    expect(ProfileValidators.country('USA'), isNotNull);
  });

  test('avatar URL must be http(s)', () {
    expect(ProfileValidators.avatarUrl(''), isNull);
    expect(ProfileValidators.avatarUrl('https://example.com/a.png'), isNull);
    expect(ProfileValidators.avatarUrl('javascript:alert(1)'), isNotNull);
  });
}
