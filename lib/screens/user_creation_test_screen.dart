import 'package:flutter/material.dart';
import '../services/test_user_creation.dart';

class UserCreationTestScreen extends StatefulWidget {
  const UserCreationTestScreen({super.key});

  @override
  State<UserCreationTestScreen> createState() => _UserCreationTestScreenState();
}

class _UserCreationTestScreenState extends State<UserCreationTestScreen> {
  final TestUserCreation _testService = TestUserCreation();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String _testResults = '';
  bool _isLoading = false;

  void _updateResults(String result) {
    setState(() {
      _testResults += '$result\n';
    });
  }

  Future<void> _runGeneralTest() async {
    setState(() {
      _isLoading = true;
      _testResults = '';
    });

    try {
      await _testService.testUserCreationFlow();
    } catch (e) {
      _updateResults('Error: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _runRegistrationTest() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() {
      _isLoading = true;
      _testResults = '';
    });

    try {
      await _testService.testNewUserRegistration(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );
    } catch (e) {
      _updateResults('Error: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _runGoogleSignInTest() async {
    setState(() {
      _isLoading = true;
      _testResults = '';
    });

    try {
      await _testService.testGoogleSignInFlow();
    } catch (e) {
      _updateResults('Error: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Creation Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Firestore User Creation',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // General test button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _runGeneralTest,
              icon: const Icon(Icons.science),
              label: const Text('Test Current User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            // Registration test form
            const Text(
              'Test New User Registration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _runRegistrationTest,
              icon: const Icon(Icons.person_add),
              label: const Text('Test Registration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // Google Sign-In test
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _runGoogleSignInTest,
              icon: const Icon(Icons.login),
              label: const Text('Test Google Sign-In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // Results display
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 10),
                            Text('Running tests...'),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _testResults.isEmpty
                              ? 'Test results will appear here...'
                              : _testResults,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: _testResults.contains('❌')
                                ? Colors.red
                                : _testResults.contains('✅')
                                ? Colors.green
                                : Colors.black,
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _testResults = '';
                });
              },
              child: const Text('Clear Results'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
