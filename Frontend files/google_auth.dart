import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Singleton instance to avoid repeated instantiation.
final GoogleSignIn _googleSignIn = GoogleSignIn();

/// Signs the user in via Google OAuth and returns the authenticated
/// Firebase [User], or [null] if the user cancels the flow.
///
/// Throws a [FirebaseAuthException] if authentication fails.
Future<User?> signInWithGoogle() async {
  try {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      // User dismissed the sign-in dialog.
      return null;
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final String? accessToken = googleAuth.accessToken;
    final String? idToken = googleAuth.idToken;

    if (accessToken == null || idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-auth-token',
        message: 'Google sign-in did not return the required auth tokens.',
      );
    }

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );

    final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    return userCredential.user;
  } on FirebaseAuthException {
    rethrow;
  } catch (e, stackTrace) {
    throw FirebaseAuthException(
      code: 'google-sign-in-failed',
      message: 'An unexpected error occurred during Google sign-in: $e',
    );
  }
}
