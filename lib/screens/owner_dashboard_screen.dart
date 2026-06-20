import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/box_service.dart';
import '../services/session_service.dart';
import '../models/box_model.dart';
import '../models/session_model.dart';
import 'box_selection_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final String boxId;

  const OwnerDashboardScreen({super.key, required this.boxId});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final BoxService _boxService = BoxService();
  final SessionService _sessionService = SessionService();

  BoxModel? _currentBox;
  SessionModel? _activeSession;
  double _totalRevenue = 0.0;
  List<SessionModel> _recentSessions = [];

  bool _isForceStopping = false;
  bool _isLockingToggle = false;
  bool _isEvToggle = false;
  bool _isP3Toggle = false;

  @override
  void initState() {
    super.initState();
    _listenToBoxAndRevenue();
  }

  void _listenToBoxAndRevenue() {
    // 1. Listen to box status
    _boxService.getBoxStatus(widget.boxId).listen((box) {
      if (mounted) {
        setState(() {
          _currentBox = box;
        });
      }
    });

    // 2. Listen to active session on this box
    _sessionService.getActiveSessionForBox(widget.boxId).listen((session) {
      if (mounted) {
        setState(() {
          _activeSession = session;
        });
      }
    });

    // 3. Listen to box total revenue
    _sessionService.getBoxTotalRevenue(widget.boxId).listen((revenue) {
      if (mounted) {
        setState(() {
          _totalRevenue = revenue;
        });
      }
    });

    // 4. Listen to recent sessions
    _sessionService.getBoxSessions(widget.boxId).listen((sessions) {
      if (mounted) {
        setState(() {
          _recentSessions = sessions.where((s) => !s.isActive).toList();
        });
      }
    });
  }

  Future<void> _forceStopSession() async {
    if (_activeSession == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force Stop Session', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to FORCE STOP the active session? This will immediately cut power and end the billing session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Force Stop'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isForceStopping = true);

    try {
      await _sessionService.forceStopSession(_activeSession!.sessionId, widget.boxId);
      _showSnackBar('Session force stopped successfully!', AppTheme.success);
    } catch (e) {
      _showSnackBar('Error force stopping session: $e', AppTheme.error);
    } finally {
      if (mounted) {
        setState(() => _isForceStopping = false);
      }
    }
  }

  Future<void> _toggleLock() async {
    if (_currentBox == null) return;
    setState(() => _isLockingToggle = true);

    try {
      final newLockState = !_currentBox!.isLocked;
      await _boxService.updateLockStatus(newLockState, widget.boxId);
      _showSnackBar(
        newLockState ? 'Box locked successfully!' : 'Box unlocked successfully!',
        AppTheme.success,
      );
    } catch (e) {
      _showSnackBar('Error toggling lock: $e', AppTheme.error);
    } finally {
      if (mounted) {
        setState(() => _isLockingToggle = false);
      }
    }
  }

  Future<void> _toggleDevice(String deviceType, bool currentOn) async {
    if (_currentBox == null) return;

    if (deviceType == 'evCharger') {
      setState(() => _isEvToggle = true);
    } else {
      setState(() => _isP3Toggle = true);
    }

    try {
      final newStatus = DeviceStatus(
        isOn: !currentOn,
        voltage: !currentOn ? 230.0 : 0.0,
        current: !currentOn ? (deviceType == 'evCharger' ? 16.0 : 5.0) : 0.0,
        power: !currentOn ? (deviceType == 'evCharger' ? 3680.0 : 1150.0) : 0.0,
      );
      await _boxService.updateDeviceStatus(deviceType, newStatus, widget.boxId);
      _showSnackBar(
        '${deviceType == 'evCharger' ? 'EV Charger' : '3-Pin Socket'} turned ${!currentOn ? 'ON' : 'OFF'}',
        AppTheme.success,
      );
    } catch (e) {
      _showSnackBar('Error toggling device: $e', AppTheme.error);
    } finally {
      if (mounted) {
        setState(() {
          _isEvToggle = false;
          _isP3Toggle = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = _currentBox?.isLocked ?? true;
    final rfidDetected = _currentBox?.rfidDetected ?? false;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const BoxSelectionScreen()),
            );
          },
        ),
        title: const Text('Owner Dashboard'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: _currentBox == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(seconds: 1));
                _listenToBoxAndRevenue();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Box Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spacingLarge),
                      decoration: AppTheme.cardDecoration(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _currentBox!.boxId.toUpperCase(),
                                style: AppTheme.headingMedium.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (_currentBox!.status == 'available'
                                          ? AppTheme.success
                                          : AppTheme.warning)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _currentBox!.status == 'available'
                                        ? AppTheme.success
                                        : AppTheme.warning,
                                  ),
                                ),
                                child: Text(
                                  _currentBox!.status.toUpperCase(),
                                  style: AppTheme.bodySmall.copyWith(
                                    color: _currentBox!.status == 'available'
                                        ? AppTheme.success
                                        : AppTheme.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                _currentBox!.location,
                                style: AppTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLarge),

                    // Earnings Display Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spacingLarge),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryBlue, AppTheme.primaryBlueDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.monetization_on, color: Colors.white, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'TOTAL REVENUE MADE',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '₹${_totalRevenue.toStringAsFixed(2)}',
                            style: AppTheme.headingLarge.copyWith(
                              fontSize: 36,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'All-time earnings from EV and Socket sessions',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLarge),

                    // Active User Session Card
                    if (_activeSession != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.spacingLarge),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(color: AppTheme.warning, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bolt, color: AppTheme.warning, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'ACTIVE USER SESSION',
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'User: ${_activeSession!.userId}',
                              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Started: ${_activeSession!.startTime.hour}:${_activeSession!.startTime.minute.toString().padLeft(2, '0')}',
                              style: AppTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Accrued Cost: ₹${_activeSession!.totalCost.toStringAsFixed(2)}',
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.error,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  ),
                                ),
                                onPressed: _isForceStopping ? null : _forceStopSession,
                                icon: _isForceStopping
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.stop),
                                label: const Text('FORCE STOP SESSION'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLarge),
                    ],

                    // Quick Hardware / Maintenance Controls
                    Text(
                      'Maintenance Controls',
                      style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),

                    // Lock/Unlock Box
                    Card(
                      child: ListTile(
                        leading: Icon(
                          isLocked ? Icons.lock : Icons.lock_open,
                          color: isLocked ? AppTheme.error : AppTheme.success,
                        ),
                        title: Text('Cabinet Door Status: ${isLocked ? 'Locked' : 'Unlocked'}'),
                        subtitle: Text('RFID Card: ${rfidDetected ? 'Detected' : 'Not Detected'}'),
                        trailing: _isLockingToggle
                            ? const CircularProgressIndicator()
                            : Switch(
                                value: !isLocked,
                                onChanged: (val) => _toggleLock(),
                                activeColor: AppTheme.success,
                                inactiveThumbColor: AppTheme.error,
                              ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),

                    // EV Relay toggle
                    Card(
                      child: ListTile(
                        leading: Icon(
                          _currentBox!.evCharger.isOn ? Icons.ev_station : Icons.ev_station_outlined,
                          color: _currentBox!.evCharger.isOn ? AppTheme.success : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: const Text('EV Charger Socket Relay'),
                        subtitle: Text(
                          _currentBox!.evCharger.isOn
                              ? 'ON (${_currentBox!.evCharger.power} W)'
                              : 'OFF',
                        ),
                        trailing: _isEvToggle
                            ? const CircularProgressIndicator()
                            : Switch(
                                value: _currentBox!.evCharger.isOn,
                                onChanged: (val) => _toggleDevice('evCharger', _currentBox!.evCharger.isOn),
                                activeColor: AppTheme.success,
                              ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),

                    // 3-Pin Relay toggle
                    Card(
                      child: ListTile(
                        leading: Icon(
                          _currentBox!.threePinSocket.isOn ? Icons.power : Icons.power_outlined,
                          color: _currentBox!.threePinSocket.isOn ? AppTheme.success : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: const Text('3-Pin Socket Relay'),
                        subtitle: Text(
                          _currentBox!.threePinSocket.isOn
                              ? 'ON (${_currentBox!.threePinSocket.power} W)'
                              : 'OFF',
                        ),
                        trailing: _isP3Toggle
                            ? const CircularProgressIndicator()
                            : Switch(
                                value: _currentBox!.threePinSocket.isOn,
                                onChanged: (val) => _toggleDevice('threePinSocket', _currentBox!.threePinSocket.isOn),
                                activeColor: AppTheme.success,
                              ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLarge),

                    // Recent Completed Sessions list
                    if (_recentSessions.isNotEmpty) ...[
                      Text(
                        'Recent Box Activity',
                        style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppTheme.spacingMedium),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentSessions.length,
                        itemBuilder: (context, index) {
                          final session = _recentSessions[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.history),
                              title: Text('Session ID: ${session.sessionId.substring(0, 8)}...'),
                              subtitle: Text(
                                'Spent: ₹${session.totalCost.toStringAsFixed(2)} | Duration: ${session.formattedDuration}',
                              ),
                              trailing: Text(
                                session.status.toUpperCase(),
                                style: TextStyle(
                                  color: session.status == 'completed'
                                      ? AppTheme.success
                                      : AppTheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
