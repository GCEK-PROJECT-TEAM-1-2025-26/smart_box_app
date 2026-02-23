import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Future<void> _signOut() async {
    // Show confirmation dialog
    final shouldSignOut = await _showSignOutConfirmation();
    if (!shouldSignOut) return;

    setState(() => _isSigningOut = true);
    try {
      final authService = AuthService();
      await authService.signOut();
      // No need for success message as user will be redirected to login screen
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
    // Don't reset _isSigningOut in finally block - let the stream handle redirection
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
                      user?.displayName ?? user?.email?.split('@')[0] ?? 'User',
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

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Box unlocked successfully!'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.lock_open,
                    color: AppTheme.textPrimary,
                  ),
                  label: Text("Unlock Box", style: AppTheme.labelLarge),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
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

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment processed successfully!'),
                        backgroundColor: AppTheme.primaryBlue,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.payment, color: AppTheme.textPrimary),
                  label: Text("Pay Now", style: AppTheme.labelLarge),
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
}
