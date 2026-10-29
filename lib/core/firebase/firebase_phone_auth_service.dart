import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper over [FirebaseAuth]'s phone-auth callback API so the rest of
/// the app depends on an injectable interface rather than the static
/// `FirebaseAuth.instance` singleton (and so widget tests can fake it instead
/// of touching the real plugin, which has no app initialized under
/// `flutter test`).
///
/// Firebase owns sending and checking the SMS code entirely client-side; this
/// service only gets as far as a verified [PhoneAuthCredential] and the
/// resulting Firebase ID token. The backend is the one that decides whether
/// that token is good enough to issue a session.
class FirebasePhoneAuthService {
  Future<void> startVerification({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException error) onFailed,
    int? forceResendingToken,
  }) {
    return FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
      verificationCompleted: onAutoVerified,
      verificationFailed: onFailed,
      codeSent: (verificationId, resendToken) =>
          onCodeSent(verificationId, resendToken),
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  PhoneAuthCredential credentialFor({
    required String verificationId,
    required String smsCode,
  }) {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  Future<String> signInAndGetIdToken(PhoneAuthCredential credential) async {
    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    final idToken = await userCredential.user?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'Could not obtain a verification token.',
      );
    }
    return idToken;
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();
}
