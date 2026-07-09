import 'package:cloud_firestore/cloud_firestore.dart';

/// Status values for a booking document.
/// scheduled → active (lock begins) → fulfilled / cancelled / expired
enum BookingStatus { scheduled, active, fulfilled, cancelled, expired }

class BookingModel {
  final String bookingId;
  final String boxId;
  final String userId;
  final String userName;

  /// 'evCharger' or 'threePinSocket'
  final String deviceType;

  final BookingStatus status;
  final DateTime createdAt;

  /// The user's intended charging start time (T)
  final DateTime scheduledChargingTime;

  /// Box becomes 'booked' at T - 30 min
  final DateTime lockStartTime;

  /// Booking auto-expires at T + 15 min if no session started
  final DateTime expiresAt;

  final int estimatedDurationMinutes;
  final String notes;

  BookingModel({
    required this.bookingId,
    required this.boxId,
    required this.userId,
    required this.userName,
    required this.deviceType,
    required this.status,
    required this.createdAt,
    required this.scheduledChargingTime,
    required this.lockStartTime,
    required this.expiresAt,
    required this.estimatedDurationMinutes,
    this.notes = '',
  });

  // ─── Computed helpers ───────────────────────────────────────────────────────

  /// True when the 30-min lock window has started (box should be 'booked')
  bool get isLockActive => DateTime.now().isAfter(lockStartTime);

  /// True when the booking has passed its auto-expire deadline
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Minutes remaining until lock window starts (negative = already locked)
  int get minutesUntilLock =>
      lockStartTime.difference(DateTime.now()).inMinutes;

  /// Minutes remaining until the booking expires (negative = already expired)
  int get minutesUntilExpiry =>
      expiresAt.difference(DateTime.now()).inMinutes;

  /// Human-readable lock countdown string
  String get lockCountdown {
    final mins = minutesUntilLock;
    if (mins <= 0) return 'Box is now reserved';
    return 'Locks in ${mins}m';
  }

  // ─── Firestore serialization ────────────────────────────────────────────────

  factory BookingModel.fromFirestore(Map<String, dynamic> data, String id) {
    return BookingModel(
      bookingId: id,
      boxId: data['boxId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      deviceType: data['deviceType'] ?? 'evCharger',
      status: _parseStatus(data['status']),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledChargingTime:
          (data['scheduledChargingTime'] as Timestamp?)?.toDate() ??
              DateTime.now(),
      lockStartTime:
          (data['lockStartTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt:
          (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estimatedDurationMinutes: data['estimatedDurationMinutes'] ?? 60,
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'boxId': boxId,
      'userId': userId,
      'userName': userName,
      'deviceType': deviceType,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduledChargingTime': Timestamp.fromDate(scheduledChargingTime),
      'lockStartTime': Timestamp.fromDate(lockStartTime),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'notes': notes,
    };
  }

  BookingModel copyWith({BookingStatus? status}) {
    return BookingModel(
      bookingId: bookingId,
      boxId: boxId,
      userId: userId,
      userName: userName,
      deviceType: deviceType,
      status: status ?? this.status,
      createdAt: createdAt,
      scheduledChargingTime: scheduledChargingTime,
      lockStartTime: lockStartTime,
      expiresAt: expiresAt,
      estimatedDurationMinutes: estimatedDurationMinutes,
      notes: notes,
    );
  }

  static BookingStatus _parseStatus(String? value) {
    switch (value) {
      case 'active':
        return BookingStatus.active;
      case 'fulfilled':
        return BookingStatus.fulfilled;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'expired':
        return BookingStatus.expired;
      default:
        return BookingStatus.scheduled;
    }
  }
}
