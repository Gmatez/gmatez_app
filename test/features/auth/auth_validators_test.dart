import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/features/auth/domain/validators/auth_validators.dart';

void main() {
  test('rejects empty email', () {
    expect(EmailValidator.validate(''), isNotNull);
  });

  test('accepts a normal email', () {
    expect(EmailValidator.validate('alice@example.com'), isNull);
  });

  test('enforces backend password minimum', () {
    expect(PasswordValidator.validate('short'), isNotNull);
    expect(PasswordValidator.validate('ChangeMe123!'), isNull);
  });

  test('requires a 6-digit OTP', () {
    expect(OtpValidator.validate('12'), isNotNull);
    expect(OtpValidator.validate('123456'), isNull);
  });
}
