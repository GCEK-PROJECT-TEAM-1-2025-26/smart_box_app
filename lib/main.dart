import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/email_verification_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Box App',
      theme: AppTheme.themeData,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundDark,
            body: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            ),
          );
        }

        // Handle errors in the auth stream
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundDark,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: AppTheme.error, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Authentication Error',
                    style: AppTheme.headingMedium.copyWith(
                      color: AppTheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Please restart the app', style: AppTheme.bodyMedium),
                ],
              ),
            ),
          );
        } // User is signed in and verified
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          // Additional check to ensure user is valid
          if (user.uid.isNotEmpty) {
            // Check if email is verified
            if (user.emailVerified) {
              return const DashboardScreen();
            } else {
              // Email is not verified, show verification screen
              return const EmailVerificationScreen();
            }
          }
        }

        // User is not signed in or user data is invalid
        return const LoginScreen();
      },
    );
  }
}
