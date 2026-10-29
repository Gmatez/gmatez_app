import 'package:firebase_auth/firebase_auth.dart';
import 'package:gmatez_app/core/firebase/firebase_phone_auth_service.dart';

/// Test double for [FirebasePhoneAuthService]. The real plugin has no
/// Firebase app initialized under `flutter test`, so any widget test that
/// exercises the phone-auth screens must override
/// `firebasePhoneAuthServiceProvider` with this instead.
class FakeFirebasePhoneAuthService implements FirebasePhoneAuthService {
  FakeFirebasePhoneAuthService({
    this.verificationId = 'fake-verification-id',
    this.autoVerifyCredential,
    this.failWith,
  });

  /// The id handed to `onCodeSent` (manual-entry path).
  final String verificationId;

  /// When set, `startVerification` calls `onAutoVerified` instead of
  /// `onCodeSent` — simulating Android's silent auto-verification.
  final PhoneAuthCredential? autoVerifyCredential;

  /// When set, `startVerification` calls `onFailed` instead.
  final FirebaseAuthException? failWith;

  int startVerificationCalls = 0;
  int signOutCalls = 0;
  String? lastSignInIdToken = 'fake-id-token';
  Object? signInError;

  @override
  Future<void> startVerification({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException error) onFailed,
    int? forceResendingToken,
  }) async {
    startVerificationCalls += 1;
    final failure = failWith;
    final autoCredential = autoVerifyCredential;
    if (failure != null) {
      onFailed(failure);
    } else if (autoCredential != null) {
      onAutoVerified(autoCredential);
    } else {
      onCodeSent(verificationId, null);
    }
  }

  @override
  PhoneAuthCredential credentialFor({
    required String verificationId,
    required String smsCode,
  }) {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  @override
  Future<String> signInAndGetIdToken(PhoneAuthCredential credential) async {
    final error = signInError;
    if (error != null) {
      throw error;
    }
    return lastSignInIdToken ?? 'fake-id-token';
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}
