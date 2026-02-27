import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _sessionsCollection = 'sessions';
  static const String _readingsSubcollection = 'readings';

  // Create new session
  Future<String> startSession(String userId, String boxId) async {
    try {
      final session = SessionModel(
        sessionId: '',
        userId: userId,
        boxId: boxId,
        startTime: DateTime.now(),
        isActive: true,
        evCharger: SessionDeviceData(totalUsage: 0, totalCost: 0),
        threePinSocket: SessionDeviceData(totalUsage: 0, totalCost: 0),
        totalCost: 0,
        status: 'active',
      );

      final docRef = await _firestore
          .collection(_sessionsCollection)
          .add(session.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to start session: $e');
    }
  }

  // Get active session for user
  Stream<SessionModel?> getActiveSession(String userId) {
    return _firestore
        .collection(_sessionsCollection)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            return SessionModel.fromFirestore(doc.data(), doc.id);
          }
          return null;
        });
  }

  // Get active session once
  Future<SessionModel?> getActiveSessionOnce(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_sessionsCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return SessionModel.fromFirestore(doc.data(), doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get active session: $e');
    }
  }

  // End session
  Future<void> endSession(String sessionId, double totalCost) async {
    try {
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'endTime': Timestamp.now(),
        'isActive': false,
        'totalCost': totalCost,
        'status': 'completed',
      });
    } catch (e) {
      throw Exception('Failed to end session: $e');
    }
  }

  // Add reading to session
  Future<void> addReading(String sessionId, ReadingModel reading) async {
    try {
      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .collection(_readingsSubcollection)
          .add(reading.toFirestore());
    } catch (e) {
      throw Exception('Failed to add reading: $e');
    }
  }

  // Update session device usage
  Future<void> updateSessionUsage(
    String sessionId,
    String deviceType,
    double usage,
    double cost,
  ) async {
    try {
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'devices.$deviceType.totalUsage': usage,
        'devices.$deviceType.totalCost': cost,
      });
    } catch (e) {
      throw Exception('Failed to update session usage: $e');
    }
  }

  // Update total session cost
  Future<void> updateSessionTotalCost(
    String sessionId,
    double totalCost,
  ) async {
    try {
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'totalCost': totalCost,
      });
    } catch (e) {
      throw Exception('Failed to update session total cost: $e');
    }
  }

  // Get session readings
  Stream<List<ReadingModel>> getSessionReadings(String sessionId) {
    return _firestore
        .collection(_sessionsCollection)
        .doc(sessionId)
        .collection(_readingsSubcollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ReadingModel.fromFirestore(doc.data()))
              .toList();
        });
  }

  // Get user session history
  Stream<List<SessionModel>> getUserSessions(String userId) {
    return _firestore
        .collection(_sessionsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .limit(50) // Limit to last 50 sessions
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SessionModel.fromFirestore(doc.data(), doc.id))
              .toList();
        });
  }

  // Calculate session cost based on device usage
  double calculateSessionCost(
    SessionDeviceData evData,
    SessionDeviceData socketData,
  ) {
    // Define pricing (can be moved to a config file later)
    const double evRate = 12.0; // ₹12 per kWh for EV
    const double socketRate = 8.0; // ₹8 per kWh for 3-pin socket

    return (evData.totalUsage * evRate) + (socketData.totalUsage * socketRate);
  }
}
