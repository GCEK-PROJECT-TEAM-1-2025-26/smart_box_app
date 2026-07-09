import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _bookingsCollection = 'bookings';
  static const String _boxesCollection = 'boxes';

  // ─── Create a booking ───────────────────────────────────────────────────────

  /// Creates a booking for [boxId]. The box status is set to 'booked' when the
  /// lock window starts (client-side via [checkAndApplyLockout]).
  ///
  /// Returns the new booking ID or throws on failure / conflict.
  Future<String> createBooking({
    required String boxId,
    required String userId,
    required String userName,
    required String deviceType,
    required DateTime scheduledChargingTime,
    required int estimatedDurationMinutes,
    String notes = '',
  }) async {
    // Enforce max 3-hour advance booking
    final now = DateTime.now();
    final diff = scheduledChargingTime.difference(now);
    if (diff.isNegative) {
      throw Exception('Cannot book a slot in the past.');
    }
    if (diff.inMinutes > 180) {
      throw Exception('Bookings can only be made up to 3 hours in advance.');
    }

    // Check box is currently available or that there is no conflicting booking
    final conflict = await _hasConflictingBooking(boxId, scheduledChargingTime);
    if (conflict) {
      throw Exception('This box is already reserved for that time slot.');
    }

    final lockStartTime =
        scheduledChargingTime.subtract(const Duration(minutes: 30));
    final expiresAt =
        scheduledChargingTime.add(const Duration(minutes: 15));

    final booking = BookingModel(
      bookingId: '',
      boxId: boxId,
      userId: userId,
      userName: userName,
      deviceType: deviceType,
      status: BookingStatus.scheduled,
      createdAt: now,
      scheduledChargingTime: scheduledChargingTime,
      lockStartTime: lockStartTime,
      expiresAt: expiresAt,
      estimatedDurationMinutes: estimatedDurationMinutes,
      notes: notes,
    );

    final batch = _firestore.batch();

    // 1. Create the booking document
    final bookingRef = _firestore.collection(_bookingsCollection).doc();
    batch.set(bookingRef, booking.toFirestore());

    // 2. Write bookingId back onto the box doc
    final boxRef = _firestore.collection(_boxesCollection).doc(boxId);
    batch.update(boxRef, {
      'currentBookingId': bookingRef.id,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return bookingRef.id;
  }

  // ─── Cancel ─────────────────────────────────────────────────────────────────

  Future<void> cancelBooking(String bookingId, String boxId) async {
    final batch = _firestore.batch();

    batch.update(
      _firestore.collection(_bookingsCollection).doc(bookingId),
      {'status': BookingStatus.cancelled.name},
    );

    batch.update(_firestore.collection(_boxesCollection).doc(boxId), {
      'status': 'available',
      'currentBookingId': FieldValue.delete(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ─── Fulfill (session started by the booking user) ──────────────────────────

  Future<void> fulfillBooking(String bookingId, String boxId) async {
    await _firestore
        .collection(_bookingsCollection)
        .doc(bookingId)
        .update({'status': BookingStatus.fulfilled.name});
    // Box status transitions to 'in_use' via SessionService / BoxService
  }

  // ─── Expire (auto-release when no-show) ─────────────────────────────────────

  Future<void> expireBooking(String bookingId, String boxId) async {
    final batch = _firestore.batch();

    batch.update(
      _firestore.collection(_bookingsCollection).doc(bookingId),
      {'status': BookingStatus.expired.name},
    );

    batch.update(_firestore.collection(_boxesCollection).doc(boxId), {
      'status': 'available',
      'currentBookingId': FieldValue.delete(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ─── Lockout checker (called client-side from map / box detail screens) ──────

  /// Checks whether any pending booking for [boxId] has entered its lock window.
  /// If so, updates the box status to 'booked' in Firestore.
  /// Also auto-expires bookings whose expiresAt has passed.
  Future<void> checkAndApplyLockout(String boxId) async {
    try {
      final now = DateTime.now();

      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('boxId', isEqualTo: boxId)
          .where('status', whereIn: [
            BookingStatus.scheduled.name,
            BookingStatus.active.name
          ])
          .get();

      for (final doc in snapshot.docs) {
        final booking = BookingModel.fromFirestore(doc.data(), doc.id);

        if (now.isAfter(booking.expiresAt)) {
          // Auto-expire no-shows
          await expireBooking(booking.bookingId, boxId);
        } else if (now.isAfter(booking.lockStartTime) &&
            booking.status == BookingStatus.scheduled) {
          // Activate lock window
          final batch = _firestore.batch();
          batch.update(
            _firestore.collection(_bookingsCollection).doc(booking.bookingId),
            {'status': BookingStatus.active.name},
          );
          batch.update(_firestore.collection(_boxesCollection).doc(boxId), {
            'status': 'booked',
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          await batch.commit();
        }
      }
    } catch (e) {
      // Non-critical: silently log
      print('BookingService.checkAndApplyLockout error: $e');
    }
  }

  // ─── Streams ─────────────────────────────────────────────────────────────────

  /// Stream of the active/scheduled booking for a specific box (for owner dashboard).
  Stream<BookingModel?> getActiveBookingForBox(String boxId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('boxId', isEqualTo: boxId)
        .where('status', whereIn: [
          BookingStatus.scheduled.name,
          BookingStatus.active.name,
        ])
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final doc = snap.docs.first;
          return BookingModel.fromFirestore(doc.data(), doc.id);
        });
  }

  /// Stream of all bookings for the current user, newest first.
  Stream<List<BookingModel>> getMyBookings(String userId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('scheduledChargingTime', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// Gets the active booking for the current user on a specific box.
  Future<BookingModel?> getMyActiveBookingForBox(
      String boxId, String userId) async {
    final snap = await _firestore
        .collection(_bookingsCollection)
        .where('boxId', isEqualTo: boxId)
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: [
          BookingStatus.scheduled.name,
          BookingStatus.active.name,
        ])
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return BookingModel.fromFirestore(snap.docs.first.data(), snap.docs.first.id);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Future<bool> _hasConflictingBooking(
      String boxId, DateTime scheduledTime) async {
    // Consider any active/scheduled booking within ±2 hours a conflict
    final windowStart =
        scheduledTime.subtract(const Duration(hours: 2));
    final windowEnd = scheduledTime.add(const Duration(hours: 2));

    final snap = await _firestore
        .collection(_bookingsCollection)
        .where('boxId', isEqualTo: boxId)
        .where('status', whereIn: [
          BookingStatus.scheduled.name,
          BookingStatus.active.name,
        ])
        .where('scheduledChargingTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart))
        .where('scheduledChargingTime',
            isLessThanOrEqualTo: Timestamp.fromDate(windowEnd))
        .get();

    return snap.docs.isNotEmpty;
  }

  /// Convenience: get the current Firebase user's display name.
  static Future<String> getCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Unknown';
    return user.displayName ?? user.email?.split('@').first ?? 'User';
  }
}
