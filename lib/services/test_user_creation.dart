import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'user_service.dart';

class TestUserCreation {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Test function to verify user creation flow
  Future<void> testUserCreationFlow() async {
    print('🧪 Testing user creation flow...');

    try {
      // Test 1: Check if Firestore is accessible
      print('📊 Testing Firestore connection...');
      await _firestore.collection('test').doc('connection').set({
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'connected',
      });
      await _firestore.collection('test').doc('connection').delete();
      print('✅ Firestore connection successful');

      // Test 2: Check current user status
      User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        print('👤 Current user: ${currentUser.email}');

        // Check if user document exists in Firestore
        DocumentSnapshot userDoc = await _userService.getUserDocument(
          currentUser.uid,
        );
        if (userDoc.exists) {
          print('📄 User document exists in Firestore');
          Map<String, dynamic>? userData =
              userDoc.data() as Map<String, dynamic>?;

          if (userData != null) {
            print('💾 User data structure:');
            print('  - Email: ${userData['email']}');
            print('  - Display Name: ${userData['displayName']}');
            print('  - Wallet Balance: ${userData['walletBalance']}');
            print('  - Total Usage: ${userData['totalUsage']}');
            print('  - Sessions Count: ${userData['sessionsCount']}');
            print('  - Created At: ${userData['createdAt']}');

            // Check preferences
            if (userData['preferences'] != null) {
              print('  - Preferences: ${userData['preferences']}');
            }

            // Check stats
            if (userData['stats'] != null) {
              print('  - Stats: ${userData['stats']}');
            }
          }
        } else {
          print('❌ User document does NOT exist in Firestore');
          print('🔧 Creating user document now...');
          await _userService.createUserDocument(
            currentUser,
            currentUser.displayName ?? 'Test User',
          );
          print('✅ User document created');
        }
      } else {
        print('❌ No user currently signed in');
        print('💡 Please sign in first to test user creation');
      }
    } catch (e) {
      print('❌ Error during testing: $e');
    }
  }

  // Test function specifically for new user registration
  Future<void> testNewUserRegistration(
    String email,
    String password,
    String displayName,
  ) async {
    print('🧪 Testing new user registration...');
    print('📧 Email: $email');
    print('👤 Name: $displayName');

    try {
      // Create new user
      UserCredential? result = await _authService
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
            displayName: displayName,
          );

      if (result?.user != null) {
        print('✅ Firebase Auth user created');

        // Wait a moment for Firestore write to complete
        await Future.delayed(Duration(seconds: 2));

        // Check if Firestore document was created
        DocumentSnapshot userDoc = await _userService.getUserDocument(
          result!.user!.uid,
        );

        if (userDoc.exists) {
          print('✅ Firestore user document created automatically');
          Map<String, dynamic>? userData =
              userDoc.data() as Map<String, dynamic>?;
          print('📊 Created user data: ${userData.toString()}');
        } else {
          print('❌ Firestore user document was NOT created');
        }
      } else {
        print('❌ Failed to create Firebase Auth user');
      }
    } catch (e) {
      print('❌ Error during new user registration test: $e');
    }
  }

  // Test Google Sign-In flow
  Future<void> testGoogleSignInFlow() async {
    print('🧪 Testing Google Sign-In flow...');

    try {
      UserCredential? result = await _authService.signInWithGoogle();

      if (result?.user != null) {
        print('✅ Google Sign-In successful');
        print('👤 User: ${result!.user!.email}');

        // Wait a moment for Firestore write to complete
        await Future.delayed(Duration(seconds: 2));

        // Check if Firestore document exists/was created
        DocumentSnapshot userDoc = await _userService.getUserDocument(
          result.user!.uid,
        );

        if (userDoc.exists) {
          print('✅ Firestore user document exists/created');
          Map<String, dynamic>? userData =
              userDoc.data() as Map<String, dynamic>?;
          print('📊 User data: ${userData.toString()}');
        } else {
          print('❌ Firestore user document was NOT created');
        }
      } else {
        print('❌ Google Sign-In failed');
      }
    } catch (e) {
      print('❌ Error during Google Sign-In test: $e');
    }
  }
}
