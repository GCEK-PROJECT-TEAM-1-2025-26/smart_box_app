import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/box_service.dart';
import '../services/session_service.dart';
import '../services/user_service.dart';
import '../models/box_model.dart';
import '../models/session_model.dart';
import '../models/command_model.dart';
import '../widgets/meter_card.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isSigningOut = false;

  // Services
  final BoxService _boxService = BoxService();
  final SessionService _sessionService = SessionService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  // Session and Box state
  SessionModel? _activeSession;
  BoxModel? _currentBox;
  Timer? _readingTimer;

  // UI state
  bool _isStartingSession = false;
  bool _isStoppingSession = false;
  bool _isUnlockingBox = false;

  // Current session readings (for real-time display)
  double _currentEvUsage = 0.0;
  double _currentSocketUsage = 0.0;
  double _currentEvCost = 0.0;
  double _currentSocketCost = 0.0;

  // User data
  double _walletBalance = 500.0; // Default initial value

  // Tariff rates
  static const double evRate = 12.0; // ₹12 per kWh
  static const double socketRate = 8.0; // ₹8 per kWh

  @override
  void initState() {
    super.initState();
    _initializeBox();
    _listenToStreams();
    _loadUserData();
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    super.dispose();
  }

  void _initializeBox() async {
    try {
      await _boxService.initializeBox();
    } catch (e) {
      print('Error initializing box: $e');
    }
  }

  void _listenToStreams() {
    final user = _authService.currentUser;
    if (user != null) {
      // Listen to box status
      _boxService.getBoxStatus().listen((box) {
        setState(() {
          _currentBox = box;
        });
      });

      // Listen to active session
      _sessionService.getActiveSession(user.uid).listen((session) {
        setState(() {
          _activeSession = session;
        });

        if (session != null && _readingTimer == null) {
          _startReadingTimer();
        } else if (session == null && _readingTimer != null) {
          _stopReadingTimer();
        }
      });
    }
  }

  void _loadUserData() {
    final user = _authService.currentUser;
    if (user != null) {
      print('DEBUG: Loading user data for UID: ${user.uid}');
      _userService.getUserDocumentStream(user.uid).listen((userDoc) {
        print('DEBUG: User document exists: ${userDoc.exists}');
        if (userDoc.exists && mounted) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final walletBalance = (userData['walletBalance'] ?? 500.0).toDouble();
          print('DEBUG: Wallet balance from DB: $walletBalance');
          setState(() {
            _walletBalance = walletBalance;
          });
        } else if (!userDoc.exists) {
          print('DEBUG: User document does not exist, creating one...');
          _userService
              .createUserDocument(user, user.displayName ?? 'User')
              .then((_) {
                print('DEBUG: User document created successfully');
              })
              .catchError((error) {
                print('DEBUG: Error creating user document: $error');
              });
        }
      });
    } else {
      print('DEBUG: No current user found');
    }
  }

  void _startReadingTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_activeSession != null && _currentBox != null) {
        final evReading = DeviceReading(
          voltage: _currentBox!.evCharger.isOn ? 230.0 : 0.0,
          current: _currentBox!.evCharger.isOn ? 16.0 : 0.0,
          power: _currentBox!.evCharger.isOn ? 3680.0 : 0.0,
        );

        final socketReading = DeviceReading(
          voltage: _currentBox!.threePinSocket.isOn ? 230.0 : 0.0,
          current: _currentBox!.threePinSocket.isOn ? 5.0 : 0.0,
          power: _currentBox!.threePinSocket.isOn ? 1150.0 : 0.0,
        );

        const duration = Duration(seconds: 5);
        final evUsageIncrement = evReading.calculateEnergy(duration);
        final socketUsageIncrement = socketReading.calculateEnergy(duration);

        setState(() {
          _currentEvUsage += evUsageIncrement;
          _currentSocketUsage += socketUsageIncrement;
          _currentEvCost = _currentEvUsage * evRate;
          _currentSocketCost = _currentSocketUsage * socketRate;
        });

        try {
          await _sessionService.updateSessionUsage(
            _activeSession!.sessionId,
            'evCharger',
            _currentEvUsage,
            _currentEvCost,
          );

          await _sessionService.updateSessionUsage(
            _activeSession!.sessionId,
            'threePinSocket',
            _currentSocketUsage,
            _currentSocketCost,
          );

          await _sessionService.updateSessionTotalCost(
            _activeSession!.sessionId,
            _currentEvCost + _currentSocketCost,
          );

          final reading = ReadingModel(
            timestamp: DateTime.now(),
            evCharger: evReading,
            threePinSocket: socketReading,
          );

          await _sessionService.addReading(_activeSession!.sessionId, reading);
        } catch (e) {
          print('Error updating session: $e');
        }
      }
    });
  }

  void _stopReadingTimer() {
    _readingTimer?.cancel();
    _readingTimer = null;

    setState(() {
      _currentEvUsage = 0.0;
      _currentSocketUsage = 0.0;
      _currentEvCost = 0.0;
      _currentSocketCost = 0.0;
    });
  }

  Future<void> _unlockBox() async {
    setState(() {
      _isUnlockingBox = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final commandId = await _boxService.sendUnlockCommand(user.uid);

      _boxService.getCommandStatus(commandId).listen((command) {
        if (command != null) {
          if (command.status == CommandStatus.completed) {
            _showSnackBar('Box unlocked successfully!', AppTheme.success);
          } else if (command.status == CommandStatus.failed) {
            _showSnackBar(
              'Failed to unlock box: ${command.errorMessage ?? 'Unknown error'}',
              AppTheme.error,
            );
          }
        }
      });

      _showSnackBar('Unlock command sent...', AppTheme.primaryBlue);
    } catch (e) {
      _showSnackBar(
        'Error sending unlock command: ${e.toString().replaceAll('Exception: ', '')}',
        AppTheme.error,
      );
    } finally {
      setState(() {
        _isUnlockingBox = false;
      });
    }
  }

  Future<void> _startSession() async {
    setState(() {
      _isStartingSession = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      if (_currentBox?.isLocked != false) {
        throw Exception('Box must be unlocked first');
      }

      await _sessionService.startSession(user.uid, _currentBox!.boxId);
      await _boxService.updateBoxStatus('in_use');

      _showSnackBar('Session started!', AppTheme.success);
    } catch (e) {
      _showSnackBar(
        'Error starting session: ${e.toString().replaceAll('Exception: ', '')}',
        AppTheme.error,
      );
    } finally {
      setState(() {
        _isStartingSession = false;
      });
    }
  }

  Future<void> _stopSession() async {
    setState(() {
      _isStoppingSession = true;
    });

    try {
      final canStop = await _boxService.canStopSession();
      if (!canStop) {
        throw Exception(
          'Cannot stop session. Please lock the box and place RFID card inside.',
        );
      }

      if (_activeSession != null) {
        final totalCost = _currentEvCost + _currentSocketCost;

        await _sessionService.endSession(_activeSession!.sessionId, totalCost);
        await _boxService.updateBoxStatus('available');

        await _toggleDevice('evCharger', false);
        await _toggleDevice('threePinSocket', false);

        _showSnackBar(
          'Session ended! Total cost: ₹${totalCost.toStringAsFixed(2)}',
          AppTheme.success,
        );
      }
    } catch (e) {
      _showSnackBar(
        'Error stopping session: ${e.toString().replaceAll('Exception: ', '')}',
        AppTheme.error,
      );
    } finally {
      setState(() {
        _isStoppingSession = false;
      });
    }
  }

  Future<void> _toggleDevice(String deviceType, bool turnOn) async {
    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final commandId = await _boxService.sendDeviceControlCommand(
        user.uid,
        deviceType,
        turnOn,
      );

      final deviceName = deviceType == 'evCharger'
          ? 'EV Charger'
          : '3-Pin Socket';
      _showSnackBar('${deviceName} command sent...', AppTheme.primaryBlue);

      _boxService.getCommandStatus(commandId).listen((command) {
        if (command != null) {
          if (command.status == CommandStatus.completed) {
            _showSnackBar(
              '$deviceName ${turnOn ? 'turned ON' : 'turned OFF'}',
              turnOn ? AppTheme.success : AppTheme.warning,
            );
          } else if (command.status == CommandStatus.failed) {
            _showSnackBar(
              'Failed to control $deviceName: ${command.errorMessage ?? 'Unknown error'}',
              AppTheme.error,
            );
          }
        }
      });
    } catch (e) {
      _showSnackBar(
        'Error sending device command: ${e.toString().replaceAll('Exception: ', '')}',
        AppTheme.error,
      );
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatSessionDuration() {
    if (_activeSession == null) return '00:00';

    final duration = DateTime.now().difference(_activeSession!.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _signOut() async {
    final shouldSignOut = await _showSignOutConfirmation();
    if (!shouldSignOut) return;

    setState(() => _isSigningOut = true);

    try {
      _readingTimer?.cancel();
      _readingTimer = null;
      await _authService.signOut();
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Error signing out: ${e.toString().replaceAll('Exception: ', '')}',
          AppTheme.error,
        );
        setState(() => _isSigningOut = false);
      }
    }
  }

  Future<bool> _showSignOutConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              title: Text('Sign Out', style: AppTheme.headingSmall),
              content: Text(
                'Are you sure you want to sign out?',
                style: AppTheme.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Sign Out',
                    style: AppTheme.labelLarge.copyWith(color: AppTheme.error),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    final hasActiveSession = _activeSession != null;
    final isBoxLocked = _currentBox?.isLocked ?? true;
    final rfidDetected = _currentBox?.rfidDetected ?? false;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text("Dashboard", style: AppTheme.headingSmall),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        actions: [
          // Wallet Balance in App Bar (only place where wallet is shown)
          Container(
            margin: const EdgeInsets.only(right: AppTheme.spacingMedium),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSmall,
              vertical: AppTheme.spacingXSmall,
            ),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              border: Border.all(color: AppTheme.success, width: 1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: AppTheme.success,
                  size: 16,
                ),
                const SizedBox(width: AppTheme.spacingXSmall),
                Text(
                  "₹${_walletBalance.toStringAsFixed(2)}",
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _isSigningOut
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryBlue,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.person,
                        color: AppTheme.textPrimary,
                      ),
                      tooltip: 'Profile',
                    ),
                    IconButton(
                      onPressed: _signOut,
                      icon: const Icon(
                        Icons.logout,
                        color: AppTheme.textPrimary,
                      ),
                      tooltip: 'Sign Out',
                    ),
                  ],
                ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: AppTheme.bodyMedium),
                    const SizedBox(height: AppTheme.spacingXSmall),
                    Text(
                      user.displayName ?? user.email?.split('@')[0] ?? 'User',
                      style: AppTheme.headingMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // Tariff Rates Info ONLY (no wallet card here)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMedium),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    border: Border.all(color: AppTheme.success),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_offer,
                            color: AppTheme.success,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacingSmall),
                          Text(
                            'Tariff Rates',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingXSmall),
                      Text(
                        'EV: ₹${evRate.toStringAsFixed(0)}/kWh',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Socket: ₹${socketRate.toStringAsFixed(0)}/kWh',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // Box Status Indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                decoration: BoxDecoration(
                  color: isBoxLocked
                      ? AppTheme.error.withValues(alpha: 0.1)
                      : AppTheme.success.withValues(alpha: 0.1),
                  border: Border.all(
                    color: isBoxLocked ? AppTheme.error : AppTheme.success,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  children: [
                    Icon(
                      isBoxLocked ? Icons.lock : Icons.lock_open,
                      color: isBoxLocked ? AppTheme.error : AppTheme.success,
                    ),
                    const SizedBox(width: AppTheme.spacingSmall),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Box Status: ${isBoxLocked ? 'Locked' : 'Unlocked'}',
                            style: AppTheme.bodyMedium.copyWith(
                              color: isBoxLocked
                                  ? AppTheme.error
                                  : AppTheme.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'RFID: ${rfidDetected ? 'Detected' : 'Not Detected'}',
                            style: AppTheme.bodySmall.copyWith(
                              color: rfidDetected
                                  ? AppTheme.success
                                  : AppTheme.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // Current Session Display (if active)
              if (hasActiveSession) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingLarge),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    border: Border.all(color: AppTheme.primaryBlue, width: 2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_circle_filled,
                            color: AppTheme.primaryBlue,
                            size: 24,
                          ),
                          const SizedBox(width: AppTheme.spacingSmall),
                          Text(
                            'Session Active',
                            style: AppTheme.headingSmall.copyWith(
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingMedium),
                      Text(
                        _formatSessionDuration(),
                        style: AppTheme.headingLarge.copyWith(
                          fontSize: 36,
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSmall),
                      Text(
                        'Current Cost: ₹${(_currentEvCost + _currentSocketCost).toStringAsFixed(2)}',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLarge),

                // Current Session Usage
                MeterCard(
                  title: "Current Session - 3 Pin Socket",
                  value: "${_currentSocketUsage.toStringAsFixed(3)} kWh",
                  cost: "₹${_currentSocketCost.toStringAsFixed(2)}",
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                MeterCard(
                  title: "Current Session - EV Charger",
                  value: "${_currentEvUsage.toStringAsFixed(3)} kWh",
                  cost: "₹${_currentEvCost.toStringAsFixed(2)}",
                ),
                const SizedBox(height: AppTheme.spacingLarge),

                // Device Control Buttons (when session is active)
                if (_currentBox != null) ...[
                  // EV Charger Control
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () => _toggleDevice(
                        'evCharger',
                        !_currentBox!.evCharger.isOn,
                      ),
                      icon: Icon(
                        _currentBox!.evCharger.isOn
                            ? Icons.ev_station
                            : Icons.ev_station_outlined,
                        color: AppTheme.textPrimary,
                      ),
                      label: Text(
                        _currentBox!.evCharger.isOn
                            ? "EV Charger ON"
                            : "Turn ON EV Charger",
                        style: AppTheme.labelLarge,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentBox!.evCharger.isOn
                            ? AppTheme.success
                            : AppTheme.primaryBlue,
                        foregroundColor: AppTheme.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),

                  // 3-Pin Socket Control
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () => _toggleDevice(
                        'threePinSocket',
                        !_currentBox!.threePinSocket.isOn,
                      ),
                      icon: Icon(
                        _currentBox!.threePinSocket.isOn
                            ? Icons.power
                            : Icons.power_outlined,
                        color: AppTheme.textPrimary,
                      ),
                      label: Text(
                        _currentBox!.threePinSocket.isOn
                            ? "3-Pin Socket ON"
                            : "Turn ON 3-Pin Socket",
                        style: AppTheme.labelLarge,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentBox!.threePinSocket.isOn
                            ? AppTheme.success
                            : AppTheme.primaryBlue,
                        foregroundColor: AppTheme.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLarge),
                ],
              ],

              // Main Action Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _getMainButtonAction(),
                  icon: Icon(_getMainButtonIcon(), color: AppTheme.textPrimary),
                  label: Text(_getMainButtonText(), style: AppTheme.labelLarge),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getMainButtonColor(),
                    foregroundColor: AppTheme.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingMedium),

              // Recharge Wallet Button (when no active session)
              if (!hasActiveSession)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showSnackBar(
                        'Wallet recharge feature coming soon!',
                        AppTheme.primaryBlue,
                      );
                    },
                    icon: const Icon(Icons.add, color: AppTheme.textPrimary),
                    label: Text("Recharge Wallet", style: AppTheme.labelLarge),
                    style: AppTheme.primaryButtonStyle,
                  ),
                ),

              const SizedBox(height: AppTheme.spacingLarge),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for main action button
  VoidCallback? _getMainButtonAction() {
    if (_isStartingSession || _isStoppingSession || _isUnlockingBox)
      return null;

    if (_activeSession != null) {
      return _stopSession;
    } else if (!isBoxLocked) {
      // Only allow starting a session when box is actually unlocked
      return _startSession;
    } else {
      // When locked, tapping main button should send unlock command
      return _unlockBox;
    }
  }

  IconData _getMainButtonIcon() {
    if (_activeSession != null) {
      return Icons.stop;
    } else if (!isBoxLocked) {
      return Icons.play_arrow;
    } else {
      return Icons.lock_open;
    }
  }

  String _getMainButtonText() {
    if (_isStoppingSession) return 'Stopping Session...';
    if (_isStartingSession) return 'Starting Session...';
    if (_isUnlockingBox) return 'Unlocking Box...';

    if (_activeSession != null) {
      return 'Stop Session';
    } else if (!isBoxLocked) {
      return 'Start Session';
    } else {
      return 'Unlock Box';
    }
  }

  Color _getMainButtonColor() {
    if (_activeSession != null) {
      return AppTheme.error;
    } else if (!isBoxLocked) {
      return AppTheme.success;
    } else {
      return AppTheme.primaryBlue;
    }
  }

  bool get isBoxLocked => _currentBox?.isLocked ?? true;
}
