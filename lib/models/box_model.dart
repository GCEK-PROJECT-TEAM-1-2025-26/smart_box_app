import 'package:cloud_firestore/cloud_firestore.dart';

class BoxModel {
  final String boxId;
  final String location;
  final bool isLocked;
  final bool rfidDetected;
  final DeviceStatus evCharger;
  final DeviceStatus threePinSocket;
  final DateTime lastUpdated;
  final String status;
  final String? ownerId;
  final Map<String, dynamic> tariff;

  BoxModel({
    required this.boxId,
    required this.location,
    required this.isLocked,
    required this.rfidDetected,
    required this.evCharger,
    required this.threePinSocket,
    required this.lastUpdated,
    required this.status,
    required this.tariff,
    this.ownerId,
  });

  factory BoxModel.fromFirestore(Map<String, dynamic> data) {
    return BoxModel(
      boxId: data['boxId'] ?? '',
      location: data['location'] ?? '',
      isLocked: data['isLocked'] ?? true,
      rfidDetected: data['rfidDetected'] ?? true,
      evCharger: DeviceStatus.fromMap(data['devices']?['evCharger'] ?? {}),
      threePinSocket: DeviceStatus.fromMap(
        data['devices']?['threePinSocket'] ?? {},
      ),
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'available',
      ownerId: data['ownerId'],
      tariff: data['tariff'] ?? {'evRate': 12.0, 'socketRate': 8.0},
    );
  }

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'boxId': boxId,
      'location': location,
      'isLocked': isLocked,
      'rfidDetected': rfidDetected,
      'devices': {
        'evCharger': evCharger.toMap(),
        'threePinSocket': threePinSocket.toMap(),
      },
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'status': status,
      'tariff': tariff,
    };
    if (ownerId != null) {
      data['ownerId'] = ownerId;
    }
    return data;
  }

  BoxModel copyWith({
    String? boxId,
    String? location,
    bool? isLocked,
    bool? rfidDetected,
    DeviceStatus? evCharger,
    DeviceStatus? threePinSocket,
    DateTime? lastUpdated,
    String? status,
    String? ownerId,
    Map<String, dynamic>? tariff,
  }) {
    return BoxModel(
      boxId: boxId ?? this.boxId,
      location: location ?? this.location,
      isLocked: isLocked ?? this.isLocked,
      rfidDetected: rfidDetected ?? this.rfidDetected,
      evCharger: evCharger ?? this.evCharger,
      threePinSocket: threePinSocket ?? this.threePinSocket,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      tariff: tariff ?? this.tariff,
    );
  }
}

class DeviceStatus {
  final bool isOn;
  final double voltage;
  final double current;
  final double power;

  DeviceStatus({
    required this.isOn,
    required this.voltage,
    required this.current,
    required this.power,
  });

  factory DeviceStatus.fromMap(Map<String, dynamic> data) {
    return DeviceStatus(
      isOn: data['isOn'] ?? false,
      voltage: (data['voltage'] ?? 0).toDouble(),
      current: (data['current'] ?? 0).toDouble(),
      power: (data['power'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isOn': isOn,
      'voltage': voltage,
      'current': current,
      'power': power,
    };
  }

  DeviceStatus copyWith({
    bool? isOn,
    double? voltage,
    double? current,
    double? power,
  }) {
    return DeviceStatus(
      isOn: isOn ?? this.isOn,
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
      power: power ?? this.power,
    );
  }
}
