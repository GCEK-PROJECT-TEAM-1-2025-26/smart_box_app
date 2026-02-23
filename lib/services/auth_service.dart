import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Create account with email and password
  Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user profile
      await result.user?.updateDisplayName(displayName);
      await result.user?.reload();

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Check if Google Play Services is available
      await _googleSignIn.signInSilently();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        throw Exception('Google Sign-In was cancelled by user');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _auth.signInWithCredential(credential);
    } on PlatformException catch (e) {
      // Handle platform-specific errors
      switch (e.code) {
        case 'sign_in_failed':
          throw Exception(
            'Google Sign-In configuration error. Please check if:\n'
            '1. SHA-1 fingerprint is added to Firebase\n'
            '2. google-services.json is up to date\n'
            '3. Google Sign-In is enabled in Firebase Auth',
          );
        case 'network_error':
          throw Exception(
            'Network error. Please check your internet connection',
          );
        case 'sign_in_canceled':
          throw Exception('Sign-In was cancelled');
        default:
          throw Exception('Google Sign-In failed: ${e.message}');
      }
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  } // Sign out

  Future<void> signOut() async {
    try {
      // Get the current user to check how they signed in
      final user = _auth.currentUser;
      bool wasGoogleUser = false;

      // Check if this was a Google Sign-In user by looking at provider data
      if (user != null) {
        for (final providerProfile in user.providerData) {
          if (providerProfile.providerId == 'google.com') {
            wasGoogleUser = true;
            break;
          }
        }
      }

      // Always sign out from Firebase Auth first
      await _auth.signOut();

      // Only attempt Google Sign-In logout if the user actually used Google Sign-In
      if (wasGoogleUser) {
        try {
          await _googleSignIn.signOut();
          await _googleSignIn.disconnect();
        } catch (e) {
          // Silently handle Google Sign-In errors since Firebase logout succeeded
          print('Google Sign-In logout error (safe to ignore): $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'invalid-credential':
        return 'The credential is invalid or has expired.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}
