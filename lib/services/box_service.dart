import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/box_model.dart';
import '../models/command_model.dart';
import 'command_service.dart';

class BoxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CommandService _commandService = CommandService();
  static const String _boxCollection = 'boxes';
  static const String _defaultBoxId = 'box_001'; // Default box for this app

  /// Validate if the box ID exists (for QR code and manual entry)
  Future<bool> validateBoxId(String boxId) async {
    try {
      final boxDoc = await _firestore
          .collection(_boxCollection)
          .doc(boxId)
          .get();
      return boxDoc.exists;
    } catch (e) {
      print('Error validating box ID: $e');
      return false;
    }
  }

  /// Get box owned by the user (returns the first matching box model, if any)
  Future<BoxModel?> getOwnedBox(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_boxCollection)
          .where('ownerId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return BoxModel.fromFirestore(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error querying owned box: $e');
      return null;
    }
  }

  // Get box status stream
  Stream<BoxModel?> getBoxStatus([String? boxId]) {
    final id = boxId ?? _defaultBoxId;
    print('DEBUG: getBoxStatus - requesting boxId: $id');
    return _firestore.collection(_boxCollection).doc(id).snapshots().map((
      snapshot,
    ) {
      print(
        'DEBUG: getBoxStatus snapshot - boxId: $id, exists: ${snapshot.exists}',
      );
      if (snapshot.exists && snapshot.data() != null) {
        print('DEBUG: getBoxStatus - found data for $id');
        return BoxModel.fromFirestore(snapshot.data()!);
      }
      print('DEBUG: getBoxStatus - NO data for $id');
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
      print('DEBUG: Initializing box: $id');

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

      // Use merge: true to preserve ESP32 updates, but ensure all fields exist
      await _firestore
          .collection(_boxCollection)
          .doc(id)
          .set(box.toFirestore(), SetOptions(merge: true));

      print('DEBUG: Box $id initialized successfully');
    } catch (e) {
      print('DEBUG: Error initializing box: $e');
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
      print(
        'DEBUG: sendUnlockCommand - boxId parameter: $boxId, using id: $id',
      );

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
