import 'package:cloud_firestore/cloud_firestore.dart';

class CommandModel {
  final String commandId;
  final String boxId;
  final String commandType; // 'unlock', 'device_control'
  final Map<String, dynamic> payload;
  final String status; // 'pending', 'sent_to_esp32', 'completed', 'failed'
  final DateTime createdAt;
  final DateTime? executedAt;
  final String? errorMessage;
  final String userId;

  CommandModel({
    required this.commandId,
    required this.boxId,
    required this.commandType,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.executedAt,
    this.errorMessage,
    required this.userId,
  });

  factory CommandModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CommandModel(
      commandId: id,
      boxId: data['boxId'] ?? '',
      commandType: data['commandType'] ?? '',
      payload: Map<String, dynamic>.from(data['payload'] ?? {}),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      executedAt: (data['executedAt'] as Timestamp?)?.toDate(),
      errorMessage: data['errorMessage'],
      userId: data['userId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'boxId': boxId,
      'commandType': commandType,
      'payload': payload,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'executedAt': executedAt != null ? Timestamp.fromDate(executedAt!) : null,
      'errorMessage': errorMessage,
      'userId': userId,
    };
  }

  CommandModel copyWith({
    String? status,
    DateTime? executedAt,
    String? errorMessage,
  }) {
    return CommandModel(
      commandId: commandId,
      boxId: boxId,
      commandType: commandType,
      payload: payload,
      status: status ?? this.status,
      createdAt: createdAt,
      executedAt: executedAt ?? this.executedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      userId: userId,
    );
  }
}

// Command Types
class CommandType {
  static const String unlock = 'unlock';
  static const String deviceControl = 'device_control';
  static const String lock = 'lock'; // Manual lock command if needed
}

// Command Status
class CommandStatus {
  static const String pending = 'pending';
  static const String sentToEsp32 = 'sent_to_esp32';
  static const String completed = 'completed';
  static const String failed = 'failed';
  static const String timeout = 'timeout';
}

// Device Control Command Payloads
class DeviceControlPayload {
  static Map<String, dynamic> evCharger({required bool turnOn}) {
    return {
      'device': 'evCharger',
      'action': turnOn ? 'turn_on' : 'turn_off',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static Map<String, dynamic> threePinSocket({required bool turnOn}) {
    return {
      'device': 'threePinSocket',
      'action': turnOn ? 'turn_on' : 'turn_off',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

// Unlock Command Payload
class UnlockPayload {
  static Map<String, dynamic> unlock() {
    return {
      'action': 'unlock',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
