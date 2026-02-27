import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('users');

  // Create a new user document in Firestore
  Future<void> createUserDocument(User firebaseUser, String displayName) async {
    try {
      final userDoc = await _usersCollection.doc(firebaseUser.uid).get();

      // Only create if document doesn't exist
      if (!userDoc.exists) {
        await _usersCollection.doc(firebaseUser.uid).set({
          'uid': firebaseUser.uid,
          'email': firebaseUser.email,
          'displayName': displayName,
          'phoneNumber': firebaseUser.phoneNumber,
          'photoURL': firebaseUser.photoURL,
          'isEmailVerified': firebaseUser.emailVerified,
          'walletBalance':
              500.0, // Initial wallet balance - give users ₹500 to start
          'totalUsage': 0.0, // Total electricity usage in kWh
          'totalSpent': 0.0, // Total money spent
          'sessionsCount': 0, // Number of sessions
          'lastActiveAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          // User preferences
          'preferences': {
            'notifications': true,
            'theme': 'system',
            'language': 'en',
          },
          // Usage statistics
          'stats': {
            'totalSessions': 0,
            'totalTimeUsed': 0, // In minutes
            'averageSessionTime': 0, // In minutes
            'favoriteBoxes': [], // List of frequently used box IDs
          },
        });
        print('User document created for ${firebaseUser.email}');
      } else {
        print('User document already exists for ${firebaseUser.email}');
        // Update last active timestamp
        await updateLastActiveAt(firebaseUser.uid);
      }
    } catch (e) {
      print('Error creating user document: $e');
      throw Exception('Failed to create user profile: $e');
    }
  }

  // Get user document
  Future<DocumentSnapshot> getUserDocument(String uid) async {
    try {
      return await _usersCollection.doc(uid).get();
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Get user document as stream
  Stream<DocumentSnapshot> getUserDocumentStream(String uid) {
    return _usersCollection.doc(uid).snapshots();
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _usersCollection.doc(uid).update(data);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Update wallet balance
  Future<void> updateWalletBalance(String uid, double amount) async {
    try {
      await _usersCollection.doc(uid).update({
        'walletBalance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update wallet balance: $e');
    }
  }

  // Update usage statistics
  Future<void> updateUsageStats(
    String uid, {
    required double kwhUsed,
    required double amountSpent,
    required int sessionTimeMinutes,
    String? boxId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _usersCollection.doc(uid);
        final userDoc = await transaction.get(userRef);

        if (userDoc.exists) {
          final currentData = userDoc.data() as Map<String, dynamic>;
          final currentStats =
              currentData['stats'] as Map<String, dynamic>? ?? {};
          final currentSessions = (currentStats['totalSessions'] ?? 0) as int;
          final currentTimeUsed = (currentStats['totalTimeUsed'] ?? 0) as int;
          final favoriteBoxes = List<String>.from(
            currentStats['favoriteBoxes'] ?? [],
          );

          // Calculate new average session time
          final newTotalSessions = currentSessions + 1;
          final newTotalTimeUsed = currentTimeUsed + sessionTimeMinutes;
          final newAverageSessionTime = (newTotalTimeUsed / newTotalSessions)
              .round();

          // Update favorite boxes
          if (boxId != null) {
            if (favoriteBoxes.contains(boxId)) {
              favoriteBoxes.remove(boxId);
            }
            favoriteBoxes.insert(0, boxId);
            // Keep only top 5 favorite boxes
            if (favoriteBoxes.length > 5) {
              favoriteBoxes.removeRange(5, favoriteBoxes.length);
            }
          }

          transaction.update(userRef, {
            'totalUsage': FieldValue.increment(kwhUsed),
            'totalSpent': FieldValue.increment(amountSpent),
            'sessionsCount': FieldValue.increment(1),
            'walletBalance': FieldValue.increment(-amountSpent),
            'lastActiveAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'stats': {
              'totalSessions': newTotalSessions,
              'totalTimeUsed': newTotalTimeUsed,
              'averageSessionTime': newAverageSessionTime,
              'favoriteBoxes': favoriteBoxes,
            },
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to update usage statistics: $e');
    }
  }

  // Update last active timestamp
  Future<void> updateLastActiveAt(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last active: $e');
      // Don't throw here as this is not critical
    }
  }

  // Update user preferences
  Future<void> updateUserPreferences(
    String uid,
    Map<String, dynamic> preferences,
  ) async {
    try {
      await _usersCollection.doc(uid).update({
        'preferences': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update preferences: $e');
    }
  }

  // Check if user exists in Firestore
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get wallet balance
  Future<double> getWalletBalance(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['walletBalance'] ?? 0.0).toDouble();
      }
      return 0.0;
    } catch (e) {
      throw Exception('Failed to get wallet balance: $e');
    }
  }

  // Add money to wallet
  Future<void> addMoneyToWallet(
    String uid,
    double amount,
    String transactionId,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Update user wallet
        final userRef = _usersCollection.doc(uid);
        transaction.update(userRef, {
          'walletBalance': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create wallet transaction record
        final walletTransactionRef = _firestore
            .collection('wallet_transactions')
            .doc(transactionId);

        transaction.set(walletTransactionRef, {
          'uid': uid,
          'amount': amount,
          'type': 'credit',
          'description': 'Wallet recharge',
          'transactionId': transactionId,
          'status': 'completed',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to add money to wallet: $e');
    }
  }

  // Delete user document (for account deletion)
  Future<void> deleteUserDocument(String uid) async {
    try {
      await _usersCollection.doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete user data: $e');
    }
  }
}
