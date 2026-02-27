import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();

  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isEditing = false;
  bool _notificationsEnabled = true;
  String _selectedTheme = 'system';
  String _selectedLanguage = 'en';

  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final userDoc = await _userService.getUserDocument(user.uid);
        if (userDoc.exists) {
          final userData = UserModel.fromMap(
            userDoc.data() as Map<String, dynamic>,
          );
          setState(() {
            _currentUser = userData;
            _displayNameController.text = userData.displayName;
            _phoneController.text = userData.phoneNumber ?? '';
            _notificationsEnabled = userData.preferences.notifications;
            _selectedTheme = userData.preferences.theme;
            _selectedLanguage = userData.preferences.language;
          });
        }
      } catch (e) {
        _showSnackBar('Error loading profile data: $e');
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _authService.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update Firebase Auth profile
      await user.updateDisplayName(_displayNameController.text.trim());

      // Update Firestore profile
      await _userService.updateUserProfile(user.uid, {
        'displayName': _displayNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'preferences': {
          'notifications': _notificationsEnabled,
          'theme': _selectedTheme,
          'language': _selectedLanguage,
        },
      });

      setState(() {
        _isEditing = false;
      });

      _showSnackBar('Profile updated successfully!');
      await _loadUserData(); // Reload data
    } catch (e) {
      _showSnackBar('Error updating profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
    });
    _loadUserData(); // Reset fields to original values
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelEditing,
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _isLoading ? null : _updateProfile,
            ),
          ],
        ],
      ),
      body: _currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Picture Section
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _currentUser!.photoURL != null
                                ? NetworkImage(_currentUser!.photoURL!)
                                : null,
                            child: _currentUser!.photoURL == null
                                ? const Icon(Icons.person, size: 50)
                                : null,
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    // TODO: Implement photo picker
                                    _showSnackBar('Photo picker coming soon!');
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Account Information Section
                    _buildSectionTitle('Account Information'),
                    const SizedBox(height: 16),

                    // Email (read-only)
                    _buildInfoCard(
                      'Email',
                      _currentUser!.email,
                      Icons.email,
                      isEditable: false,
                    ),

                    const SizedBox(height: 12),

                    // Display Name
                    _isEditing
                        ? _buildEditableField(
                            'Display Name',
                            _displayNameController,
                            Icons.person,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Display name is required';
                              }
                              return null;
                            },
                          )
                        : _buildInfoCard(
                            'Display Name',
                            _currentUser!.displayName,
                            Icons.person,
                          ),

                    const SizedBox(height: 12),

                    // Phone Number
                    _isEditing
                        ? _buildEditableField(
                            'Phone Number',
                            _phoneController,
                            Icons.phone,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (!RegExp(
                                  r'^\+?[\d\s\-\(\)]+$',
                                ).hasMatch(value.trim())) {
                                  return 'Please enter a valid phone number';
                                }
                              }
                              return null;
                            },
                          )
                        : _buildInfoCard(
                            'Phone Number',
                            _currentUser!.phoneNumber?.isEmpty == false
                                ? _currentUser!.phoneNumber!
                                : 'Not set',
                            Icons.phone,
                          ),

                    const SizedBox(height: 32),

                    // Preferences Section
                    _buildSectionTitle('Preferences'),
                    const SizedBox(height: 16),

                    // Notifications
                    _buildPreferenceCard(
                      'Notifications',
                      'Receive app notifications',
                      Icons.notifications,
                      Switch(
                        value: _notificationsEnabled,
                        onChanged: _isEditing
                            ? (value) =>
                                  setState(() => _notificationsEnabled = value)
                            : null,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Theme
                    _buildPreferenceCard(
                      'Theme',
                      'App appearance',
                      Icons.palette,
                      _isEditing
                          ? DropdownButton<String>(
                              value: _selectedTheme,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedTheme = value);
                                }
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: 'light',
                                  child: Text('Light'),
                                ),
                                DropdownMenuItem(
                                  value: 'dark',
                                  child: Text('Dark'),
                                ),
                                DropdownMenuItem(
                                  value: 'system',
                                  child: Text('System'),
                                ),
                              ],
                            )
                          : Text(
                              _selectedTheme.replaceFirst(
                                _selectedTheme[0],
                                _selectedTheme[0].toUpperCase(),
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                    ),

                    const SizedBox(height: 12),

                    // Language
                    _buildPreferenceCard(
                      'Language',
                      'App language',
                      Icons.language,
                      _isEditing
                          ? DropdownButton<String>(
                              value: _selectedLanguage,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedLanguage = value);
                                }
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: 'en',
                                  child: Text('English'),
                                ),
                                DropdownMenuItem(
                                  value: 'hi',
                                  child: Text('Hindi'),
                                ),
                                DropdownMenuItem(
                                  value: 'es',
                                  child: Text('Spanish'),
                                ),
                              ],
                            )
                          : Text(
                              _selectedLanguage == 'en'
                                  ? 'English'
                                  : _selectedLanguage == 'hi'
                                  ? 'Hindi'
                                  : 'Spanish',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                    ),

                    const SizedBox(height: 32),

                    // Statistics Section
                    _buildSectionTitle('Statistics'),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Sessions',
                            _currentUser!.stats.totalSessions.toString(),
                            Icons.history,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Total Usage',
                            '${_currentUser!.totalUsage.toStringAsFixed(2)} kWh',
                            Icons.electric_bolt,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Wallet Balance',
                            '₹${_currentUser!.walletBalance.toStringAsFixed(2)}',
                            Icons.account_balance_wallet,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Total Spent',
                            '₹${_currentUser!.totalSpent.toStringAsFixed(2)}',
                            Icons.payment,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Save Button (when editing)
                    if (_isEditing)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _updateProfile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Save Changes'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon, {
    bool isEditable = true,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
        trailing: isEditable ? const Icon(Icons.chevron_right) : null,
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildPreferenceCard(
    String title,
    String subtitle,
    IconData icon,
    Widget trailing,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
