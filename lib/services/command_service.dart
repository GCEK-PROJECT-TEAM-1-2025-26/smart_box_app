import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/command_model.dart';

class CommandService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _commandsCollection = 'commands';

  // Send unlock command to ESP32
  Future<String> sendUnlockCommand(String boxId, String userId) async {
    try {
      final command = CommandModel(
        commandId: '',
        boxId: boxId,
        commandType: CommandType.unlock,
        payload: UnlockPayload.unlock(),
        status: CommandStatus.pending,
        createdAt: DateTime.now(),
        userId: userId,
      );

      final docRef = await _firestore
          .collection(_commandsCollection)
          .add(command.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to send unlock command: $e');
    }
  }

  // Send device control command to ESP32
  Future<String> sendDeviceControlCommand(
    String boxId,
    String userId,
    String device,
    bool turnOn,
  ) async {
    try {
      Map<String, dynamic> payload;

      if (device == 'evCharger') {
        payload = DeviceControlPayload.evCharger(turnOn: turnOn);
      } else if (device == 'threePinSocket') {
        payload = DeviceControlPayload.threePinSocket(turnOn: turnOn);
      } else {
        throw Exception('Unknown device type: $device');
      }

      final command = CommandModel(
        commandId: '',
        boxId: boxId,
        commandType: CommandType.deviceControl,
        payload: payload,
        status: CommandStatus.pending,
        createdAt: DateTime.now(),
        userId: userId,
      );

      final docRef = await _firestore
          .collection(_commandsCollection)
          .add(command.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to send device control command: $e');
    }
  }

  // Get pending commands for ESP32 to read
  Stream<List<CommandModel>> getPendingCommands(String boxId) {
    return _firestore
        .collection(_commandsCollection)
        .where('boxId', isEqualTo: boxId)
        .where('status', isEqualTo: CommandStatus.pending)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CommandModel.fromFirestore(doc.data(), doc.id))
              .toList();
        });
  }

  // Update command status (ESP32 calls this)
  Future<void> updateCommandStatus(
    String commandId,
    String status, {
    String? errorMessage,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'executedAt': Timestamp.now(),
      };

      if (errorMessage != null) {
        updateData['errorMessage'] = errorMessage;
      }

      await _firestore
          .collection(_commandsCollection)
          .doc(commandId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update command status: $e');
    }
  }

  // Mark command as sent to ESP32 (optional intermediate step)
  Future<void> markCommandAsSent(String commandId) async {
    try {
      await _firestore.collection(_commandsCollection).doc(commandId).update({
        'status': CommandStatus.sentToEsp32,
      });
    } catch (e) {
      throw Exception('Failed to mark command as sent: $e');
    }
  }

  // Get command by ID
  Future<CommandModel?> getCommand(String commandId) async {
    try {
      final doc = await _firestore
          .collection(_commandsCollection)
          .doc(commandId)
          .get();

      if (doc.exists && doc.data() != null) {
        return CommandModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get command: $e');
    }
  }

  // Listen to command status updates for UI feedback
  Stream<CommandModel?> getCommandStatus(String commandId) {
    return _firestore
        .collection(_commandsCollection)
        .doc(commandId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return CommandModel.fromFirestore(doc.data()!, doc.id);
          }
          return null;
        });
  }

  // Clean up old commands (optional - for maintenance)
  Future<void> cleanupOldCommands({int daysOld = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      final oldCommands = await _firestore
          .collection(_commandsCollection)
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in oldCommands.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to cleanup old commands: $e');
    }
  }

  // Get user's command history
  Stream<List<CommandModel>> getUserCommands(String userId) {
    return _firestore
        .collection(_commandsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CommandModel.fromFirestore(doc.data(), doc.id))
              .toList();
        });
  }
}
