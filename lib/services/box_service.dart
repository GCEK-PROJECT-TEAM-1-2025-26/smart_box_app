import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/box_model.dart';
import '../models/command_model.dart';
import 'command_service.dart';

class BoxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CommandService _commandService = CommandService();
  static const String _boxCollection = 'boxes';
  static const String _defaultBoxId = 'box_001'; // Default box for this app

  // Get box status stream
  Stream<BoxModel?> getBoxStatus([String? boxId]) {
    final id = boxId ?? _defaultBoxId;
    return _firestore.collection(_boxCollection).doc(id).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists && snapshot.data() != null) {
        return BoxModel.fromFirestore(snapshot.data()!);
      }
      return null;
    });
  }

  // Get box status once
  Future<BoxModel?> getBoxStatusOnce([String? boxId]) async {
    try {
      final id = boxId ?? _defaultBoxId;
      final snapshot = await _firestore
          .collection(_boxCollection)
          .doc(id)
          .get();

      if (snapshot.exists && snapshot.data() != null) {
        return BoxModel.fromFirestore(snapshot.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get box status: $e');
    }
  }

  // Update box lock status
  Future<void> updateLockStatus(bool isLocked, [String? boxId]) async {
    try {
      final id = boxId ?? _defaultBoxId;
      await _firestore.collection(_boxCollection).doc(id).update({
        'isLocked': isLocked,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update lock status: $e');
    }
  }

  // Update RFID status
  Future<void> updateRfidStatus(bool rfidDetected, [String? boxId]) async {
    try {
      final id = boxId ?? _defaultBoxId;
      await _firestore.collection(_boxCollection).doc(id).update({
        'rfidDetected': rfidDetected,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update RFID status: $e');
    }
  }

  // Update device status
  Future<void> updateDeviceStatus(
    String deviceType,
    DeviceStatus deviceStatus, [
    String? boxId,
  ]) async {
    try {
      final id = boxId ?? _defaultBoxId;
      await _firestore.collection(_boxCollection).doc(id).update({
        'devices.$deviceType': deviceStatus.toMap(),
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update device status: $e');
    }
  }

  // Update box status (for session management)
  Future<void> updateBoxStatus(String status, [String? boxId]) async {
    try {
      final id = boxId ?? _defaultBoxId;
      await _firestore.collection(_boxCollection).doc(id).update({
        'status': status,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update box status: $e');
    }
  }

  // Initialize box (for setup)
  Future<void> initializeBox([String? boxId, String? location]) async {
    try {
      final id = boxId ?? _defaultBoxId;
      final box = BoxModel(
        boxId: id,
        location: location ?? 'Smart Box Location',
        isLocked: true,
        rfidDetected: true,
        evCharger: DeviceStatus(isOn: false, voltage: 0, current: 0, power: 0),
        threePinSocket: DeviceStatus(
          isOn: false,
          voltage: 0,
          current: 0,
          power: 0,
        ),
        lastUpdated: DateTime.now(),
        status: 'available',
      );

      await _firestore
          .collection(_boxCollection)
          .doc(id)
          .set(box.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to initialize box: $e');
    }
  }

  // Check if box can be unlocked (RFID present and box available)
  Future<bool> canUnlockBox([String? boxId]) async {
    try {
      final box = await getBoxStatusOnce(boxId);
      return box != null &&
          box.rfidDetected &&
          box.isLocked &&
          box.status == 'available';
    } catch (e) {
      return false;
    }
  }

  // Send unlock command (command-driven approach)
  Future<String> sendUnlockCommand(String userId, [String? boxId]) async {
    try {
      final id = boxId ?? _defaultBoxId;

      // Check if box can be unlocked first
      final canUnlock = await canUnlockBox(id);
      if (!canUnlock) {
        throw Exception(
          'Cannot unlock box. RFID not detected or box not available.',
        );
      }

      // Send command to ESP32 via commands collection
      final commandId = await _commandService.sendUnlockCommand(id, userId);
      return commandId;
    } catch (e) {
      throw Exception('Failed to send unlock command: $e');
    }
  }

  // Send device control command (command-driven approach)
  Future<String> sendDeviceControlCommand(
    String userId,
    String deviceType,
    bool turnOn, [
    String? boxId,
  ]) async {
    try {
      final id = boxId ?? _defaultBoxId;

      // Send command to ESP32 via commands collection
      final commandId = await _commandService.sendDeviceControlCommand(
        id,
        userId,
        deviceType,
        turnOn,
      );
      return commandId;
    } catch (e) {
      throw Exception('Failed to send device control command: $e');
    }
  }

  // Listen to command status for UI feedback
  Stream<CommandModel?> getCommandStatus(String commandId) {
    return _commandService.getCommandStatus(commandId);
  }

  // Check if session can be stopped (RFID present and box locked)
  Future<bool> canStopSession([String? boxId]) async {
    try {
      final box = await getBoxStatusOnce(boxId);
      return box != null && box.rfidDetected && box.isLocked;
    } catch (e) {
      return false;
    }
  }
}
