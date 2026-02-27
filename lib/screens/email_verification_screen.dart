import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  Timer? _timer;
  bool _isResending = false;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _authService.reloadUser();
      if (_authService.isEmailVerified) {
        timer.cancel();
        if (mounted) {
          // Create Firestore user document now that email is verified
          final user = _authService.currentUser;
          if (user != null) {
            try {
              await _userService.createUserDocument(
                user,
                user.displayName ?? 'User',
              );
            } catch (e) {
              print('Error creating user document: $e');
            }
          }

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    });
  }

  void _startResendCountdown() {
    setState(() {
      _resendCountdown = 60;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _resendCountdown--;
        });
      }

      if (_resendCountdown <= 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _resendVerification() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isResending = true;
    });

    try {
      await _authService.resendVerificationEmail();
      _startResendCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Check your inbox.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _authService.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text('Verify Email', style: AppTheme.headingSmall),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: AppTheme.textPrimary),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Email icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.email_outlined,
                  size: 64,
                  color: AppTheme.primaryBlue,
                ),
              ),

              const SizedBox(height: AppTheme.spacingXLarge),

              // Title
              Text(
                'Verify Your Email',
                style: AppTheme.headingLarge.copyWith(
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppTheme.spacingMedium),

              // Description
              Text(
                'We sent a verification link to:',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppTheme.spacingSmall),

              // Email address
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  userEmail,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: AppTheme.spacingLarge),

              // Instructions
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: [
                    Text(
                      'Check your email and click the verification link to activate your account.',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),
                    Text(
                      'This page will automatically update when verified.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textHint,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLarge),

              // Loading indicator
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: AppTheme.primaryBlue,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                    Text(
                      'Checking verification status...',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXLarge),

              // Resend button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _resendCountdown > 0 || _isResending
                      ? null
                      : _resendVerification,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingMedium,
                    ),
                    side: const BorderSide(color: AppTheme.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                  ),
                  icon: _isResending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryBlue,
                          ),
                        )
                      : const Icon(Icons.refresh, color: AppTheme.primaryBlue),
                  label: Text(
                    _resendCountdown > 0
                        ? 'Resend in ${_resendCountdown}s'
                        : _isResending
                        ? 'Sending...'
                        : 'Resend Verification Email',
                    style: AppTheme.bodyMedium.copyWith(
                      color: _resendCountdown > 0 || _isResending
                          ? AppTheme.textHint
                          : AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingMedium),

              // Sign out button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _signOut,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingMedium,
                    ),
                  ),
                  child: Text(
                    'Sign Out',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
