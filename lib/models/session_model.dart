import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String sessionId;
  final String userId;
  final String boxId;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final SessionDeviceData evCharger;
  final SessionDeviceData threePinSocket;
  final double totalCost;
  final String status;

  SessionModel({
    required this.sessionId,
    required this.userId,
    required this.boxId,
    required this.startTime,
    this.endTime,
    required this.isActive,
    required this.evCharger,
    required this.threePinSocket,
    required this.totalCost,
    required this.status,
  });

  factory SessionModel.fromFirestore(Map<String, dynamic> data, String id) {
    return SessionModel(
      sessionId: id,
      userId: data['userId'] ?? '',
      boxId: data['boxId'] ?? '',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? false,
      evCharger: SessionDeviceData.fromMap(data['devices']?['evCharger'] ?? {}),
      threePinSocket: SessionDeviceData.fromMap(
        data['devices']?['threePinSocket'] ?? {},
      ),
      totalCost: (data['totalCost'] ?? 0).toDouble(),
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'boxId': boxId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'isActive': isActive,
      'devices': {
        'evCharger': evCharger.toMap(),
        'threePinSocket': threePinSocket.toMap(),
      },
      'totalCost': totalCost,
      'status': status,
    };
  }

  // Get session duration in minutes
  int get durationInMinutes {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMinutes;
  }

  // Get session duration as formatted string
  String get formattedDuration {
    final duration =
        endTime?.difference(startTime) ?? DateTime.now().difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}

class SessionDeviceData {
  final double totalUsage;
  final double totalCost;

  SessionDeviceData({required this.totalUsage, required this.totalCost});

  factory SessionDeviceData.fromMap(Map<String, dynamic> data) {
    return SessionDeviceData(
      totalUsage: (data['totalUsage'] ?? 0).toDouble(),
      totalCost: (data['totalCost'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'totalUsage': totalUsage, 'totalCost': totalCost};
  }

  SessionDeviceData copyWith({double? totalUsage, double? totalCost}) {
    return SessionDeviceData(
      totalUsage: totalUsage ?? this.totalUsage,
      totalCost: totalCost ?? this.totalCost,
    );
  }
}

class ReadingModel {
  final DateTime timestamp;
  final DeviceReading evCharger;
  final DeviceReading threePinSocket;

  ReadingModel({
    required this.timestamp,
    required this.evCharger,
    required this.threePinSocket,
  });

  factory ReadingModel.fromFirestore(Map<String, dynamic> data) {
    return ReadingModel(
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      evCharger: DeviceReading.fromMap(data['evCharger'] ?? {}),
      threePinSocket: DeviceReading.fromMap(data['threePinSocket'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'evCharger': evCharger.toMap(),
      'threePinSocket': threePinSocket.toMap(),
    };
  }
}

class DeviceReading {
  final double voltage;
  final double current;
  final double power;

  DeviceReading({
    required this.voltage,
    required this.current,
    required this.power,
  });

  factory DeviceReading.fromMap(Map<String, dynamic> data) {
    return DeviceReading(
      voltage: (data['voltage'] ?? 0).toDouble(),
      current: (data['current'] ?? 0).toDouble(),
      power: (data['power'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'voltage': voltage, 'current': current, 'power': power};
  }

  // Calculate energy consumed (kWh) based on power and time
  double calculateEnergy(Duration duration) {
    return (power * duration.inHours) / 1000; // Convert Wh to kWh
  }
}
