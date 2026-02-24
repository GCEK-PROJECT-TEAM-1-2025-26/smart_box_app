import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/meter_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isSigningOut = false;
  double walletBalance =
      250.75; // Mock wallet balance - will be replaced with real data later
  // Timer related variables
  bool _isBoxUnlocked = false;
  Timer? _usageTimer;
  int _elapsedSeconds = 0;
  double _currentCost = 0.0;
  static const double _costPerSecond = 0.05; // ₹0.05 per second

  // Device control variables
  bool _isEvChargerOn = false;
  bool _is3PinSocketOn = false;
  @override
  void dispose() {
    // Cancel timer and clean up resources
    _usageTimer?.cancel();
    _usageTimer = null;
    super.dispose();
  }

  void _startUsageTimer() {
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
        _currentCost = _elapsedSeconds * _costPerSecond;
      });
    });
  }

  void _stopUsageTimer() {
    _usageTimer?.cancel();
    setState(() {
      _isBoxUnlocked = false;
      _isEvChargerOn = false;
      _is3PinSocketOn = false;
      // Reset for next use
      _elapsedSeconds = 0;
      _currentCost = 0.0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Box locked! Total cost: ₹${_currentCost.toStringAsFixed(2)}',
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleEvCharger() {
    setState(() {
      _isEvChargerOn = !_isEvChargerOn;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'EV Charger ${_isEvChargerOn ? 'turned ON' : 'turned OFF'}',
        ),
        backgroundColor: _isEvChargerOn ? AppTheme.success : AppTheme.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // TODO: Send command to Firebase/ESP32
    print('EV Charger: ${_isEvChargerOn ? 'ON' : 'OFF'}');
  }

  void _toggle3PinSocket() {
    setState(() {
      _is3PinSocketOn = !_is3PinSocketOn;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '3-Pin Socket ${_is3PinSocketOn ? 'turned ON' : 'turned OFF'}',
        ),
        backgroundColor: _is3PinSocketOn ? AppTheme.success : AppTheme.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // TODO: Send command to Firebase/ESP32
    print('3-Pin Socket: ${_is3PinSocketOn ? 'ON' : 'OFF'}');
  }

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _signOut() async {
    // Show confirmation dialog
    final shouldSignOut = await _showSignOutConfirmation();
    if (!shouldSignOut) return;

    setState(() => _isSigningOut = true);

    try {
      // Clean up timer before signing out
      _usageTimer?.cancel();
      _usageTimer = null;

      // Reset all state variables
      _isBoxUnlocked = false;
      _elapsedSeconds = 0;
      _currentCost = 0.0;

      final authService = AuthService();
      await authService.signOut();

      // The AuthWrapper will handle the redirect automatically
      // Don't set _isSigningOut to false here
    } catch (e) {
      // Only show error message if sign out actually fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error signing out: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
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

    // If user becomes null during logout, show loading
    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    double units3Pin = 2.4;
    double unitsEV = 5.8;
    double amount = (units3Pin * 8) + (unitsEV * 12);
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text("Dashboard", style: AppTheme.headingSmall),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        actions: [
          // Wallet Balance in App Bar
          Container(
            margin: const EdgeInsets.only(right: AppTheme.spacingMedium),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSmall,
              vertical: AppTheme.spacingXSmall,
            ),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
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
                  "₹${walletBalance.toStringAsFixed(2)}",
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
              : IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, color: AppTheme.textPrimary),
                  tooltip: 'Sign Out',
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

              // Usage Cards
              MeterCard(title: "3 Pin Plug Usage", value: "$units3Pin kWh"),
              const SizedBox(height: AppTheme.spacingLarge),
              MeterCard(title: "EV Fast Charger Usage", value: "$unitsEV kWh"),
              const SizedBox(height: AppTheme.spacingXLarge),

              // Total Amount
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Column(
                  children: [
                    Text(
                      "Total Amount",
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),
                    Text(
                      "₹${amount.toStringAsFixed(2)}",
                      style: AppTheme.headingLarge.copyWith(fontSize: 32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXLarge),

              // Timer Display (shown when box is unlocked)
              if (_isBoxUnlocked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingLarge),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    border: Border.all(color: AppTheme.warning, width: 2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer,
                            color: AppTheme.warning,
                            size: 24,
                          ),
                          const SizedBox(width: AppTheme.spacingSmall),
                          Text(
                            'Box is Unlocked',
                            style: AppTheme.headingSmall.copyWith(
                              color: AppTheme.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingMedium),
                      Text(
                        _formatTime(_elapsedSeconds),
                        style: AppTheme.headingLarge.copyWith(
                          fontSize: 36,
                          color: AppTheme.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSmall),
                      Text(
                        'Current Cost: ₹${_currentCost.toStringAsFixed(2)}',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLarge),
              ], // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isBoxUnlocked
                      ? null
                      : () {
                          setState(() {
                            _isBoxUnlocked = true;
                            _elapsedSeconds = 0;
                            _currentCost = 0.0;
                            // Reset device states when unlocking
                            _isEvChargerOn = false;
                            _is3PinSocketOn = false;
                          });
                          _startUsageTimer();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Box unlocked! You can now control devices.',
                              ),
                              backgroundColor: AppTheme.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  icon: Icon(
                    _isBoxUnlocked ? Icons.lock : Icons.lock_open,
                    color: AppTheme.textPrimary,
                  ),
                  label: Text(
                    _isBoxUnlocked ? "Box Unlocked" : "Unlock Box",
                    style: AppTheme.labelLarge,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isBoxUnlocked
                        ? AppTheme.textHint
                        : AppTheme.success,
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

              // Device Control Buttons (shown when box is unlocked)
              if (_isBoxUnlocked) ...[
                // EV Charger Control
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _toggleEvCharger,
                    icon: Icon(
                      _isEvChargerOn
                          ? Icons.ev_station
                          : Icons.ev_station_outlined,
                      color: AppTheme.textPrimary,
                    ),
                    label: Text(
                      _isEvChargerOn ? "EV Charger ON" : "Turn ON EV Charger",
                      style: AppTheme.labelLarge,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEvChargerOn
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
                    onPressed: _toggle3PinSocket,
                    icon: Icon(
                      _is3PinSocketOn ? Icons.power : Icons.power_outlined,
                      color: AppTheme.textPrimary,
                    ),
                    label: Text(
                      _is3PinSocketOn
                          ? "3-Pin Socket ON"
                          : "Turn ON 3-Pin Socket",
                      style: AppTheme.labelLarge,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _is3PinSocketOn
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
              ],

              // Stop Timer Button (shown when box is unlocked)
              if (_isBoxUnlocked)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _stopUsageTimer,
                    icon: const Icon(Icons.stop, color: AppTheme.textPrimary),
                    label: Text("Stop & Lock Box", style: AppTheme.labelLarge),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
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

              // Recharge Wallet Button (shown when box is locked)
              if (!_isBoxUnlocked) ...[
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Wallet recharge feature coming soon!'),
                          backgroundColor: AppTheme.primaryBlue,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, color: AppTheme.textPrimary),
                    label: Text("Recharge Wallet", style: AppTheme.labelLarge),
                    style: AppTheme.primaryButtonStyle,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacingLarge),
            ],
          ),
        ),
      ),
    );
  }
}
