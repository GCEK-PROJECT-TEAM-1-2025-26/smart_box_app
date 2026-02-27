import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Force account picker every time
    forceCodeForRefreshToken: true,
  );
  final UserService _userService = UserService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if current user's email is verified
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // Auth state changes stream
  Stream<User?> get authStateChanges =>
      _auth.authStateChanges(); // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Reload user to get latest verification status
      await result.user?.reload();

      // Check if email is verified
      if (result.user != null && !result.user!.emailVerified) {
        // Sign out the unverified user
        await signOut();
        throw Exception(
          'Please verify your email before signing in. Check your inbox for the verification link.',
        );
      } // Update last active timestamp for verified users
      if (result.user != null) {
        // Create Firestore user document for verified users (if not exists)
        await _userService.createUserDocument(
          result.user!,
          result.user!.displayName ?? 'User',
        );
        await _userService.updateLastActiveAt(result.user!.uid);
      }

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

      // Send email verification immediately after account creation
      if (result.user != null) {
        await result.user!.sendEmailVerification();
        // Don't create Firestore document until email is verified
        // We'll create it after verification during sign-in
      }

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // First sign out any existing Google account to force account selection
      await _googleSignIn.signOut();

      // Trigger the authentication flow (this will show account picker)
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
      ); // Sign in to Firebase with the Google credential
      UserCredential result = await _auth.signInWithCredential(credential);

      // Create Firestore user document for new Google users
      if (result.user != null) {
        await _userService.createUserDocument(
          result.user!,
          result.user!.displayName ?? googleUser.displayName ?? 'User',
        );
      }

      return result;
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
      // Sign out from Google Sign-In first (if user signed in with Google)
      try {
        final GoogleSignInAccount? currentGoogleUser =
            _googleSignIn.currentUser;
        if (currentGoogleUser != null) {
          await _googleSignIn.signOut();
          await _googleSignIn.disconnect();
        }
      } catch (e) {
        // Ignore Google Sign-In errors, continue with Firebase logout
        print('Google Sign-In logout warning (continuing): $e');
      }

      // Then sign out from Firebase Auth
      await _auth.signOut();

      // Wait a moment to ensure the auth state change propagates
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify that the user is actually signed out
      if (_auth.currentUser != null) {
        throw Exception('Sign out verification failed');
      }
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Update user profile (Firebase Auth)
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = currentUser;
      if (user != null) {
        if (displayName != null) {
          await user.updateDisplayName(displayName);
        }
        if (photoURL != null) {
          await user.updatePhotoURL(photoURL);
        }
        await user.reload();
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      } else if (user?.emailVerified == true) {
        throw Exception('Email is already verified');
      } else {
        throw Exception('No user found');
      }
    } catch (e) {
      throw Exception('Failed to send verification email: $e');
    }
  }

  // Reload user to check verification status
  Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
    } catch (e) {
      throw Exception('Failed to reload user: $e');
    }
  }

  // Resend verification email
  Future<void> resendVerificationEmail() async {
    try {
      final user = currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      } else if (user?.emailVerified == true) {
        throw Exception('Email is already verified');
      } else {
        throw Exception('No user found');
      }
    } catch (e) {
      throw Exception('Failed to resend verification email: $e');
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
