import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

class BoxProvisioningScreen extends StatefulWidget {
  const BoxProvisioningScreen({super.key});

  @override
  State<BoxProvisioningScreen> createState() => _BoxProvisioningScreenState();
}

class _BoxProvisioningScreenState extends State<BoxProvisioningScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _manualSsidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _boxIdController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _secretController = TextEditingController();
  final TextEditingController _evRateController = TextEditingController(text: '12.0');
  final TextEditingController _socketRateController = TextEditingController(text: '8.0');
  
  final TextEditingController _registrationIdController = TextEditingController();
  int _currentStep = 1;
  bool _isVerifyingToken = false;
  bool _isManualMode = false;

  List<String> _scannedSSIDs = [];
  String? _selectedSSID;
  bool _isConnectedToBox = false;
  bool _isCheckingConnection = false;
  bool _isManualSsid = false;
  bool _isSubmitting = false;
  bool _isProvisioned = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    // Try to auto-connect on open
    _checkConnection();
  }

  @override
  void dispose() {
    _manualSsidController.dispose();
    _passwordController.dispose();
    _boxIdController.dispose();
    _locationController.dispose();
    _secretController.dispose();
    _evRateController.dispose();
    _socketRateController.dispose();
    _registrationIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        if (mounted && _locationController.text.isEmpty) {
          setState(() {
            _locationController.text = "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting location for prefill: $e');
    }
  }

  Future<void> _checkConnection() async {
    if (_isCheckingConnection) return;
    setState(() {
      _isCheckingConnection = true;
      _isConnectedToBox = false;
    });

    try {
      final response = await http.get(Uri.parse('http://192.168.4.1/scan')).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final List<dynamic> networks = data['networks'] ?? [];
        List<String> ssids = [];
        for (var net in networks) {
          if (net is Map && net.containsKey('ssid')) {
            String s = net['ssid'] ?? '';
            if (s.isNotEmpty && !ssids.contains(s)) {
              ssids.add(s);
            }
          }
        }

        setState(() {
          _scannedSSIDs = ssids;
          _isConnectedToBox = true;
          _isCheckingConnection = false;
          if (ssids.isNotEmpty) {
            _selectedSSID = ssids.first;
            _isManualSsid = false;
          } else {
            _isManualSsid = true;
          }
        });
        _showSnackBar('Successfully connected to Smart Box setup AP!', AppTheme.success);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingConnection = false;
          _isConnectedToBox = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _verifyRegistrationToken() async {
    final token = _registrationIdController.text.trim();
    if (token.isEmpty || token.length != 6) {
      _showSnackBar('Please enter a valid 6-digit Registration ID', AppTheme.error);
      return;
    }

    setState(() => _isVerifyingToken = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final doc = await FirebaseFirestore.instance.collection('provisioningTokens').doc(token).get();
      if (!doc.exists) {
        throw Exception('Invalid Registration ID. Please check and try again.');
      }

      final data = doc.data()!;
      if (data['ownerId'] != user.uid) {
        throw Exception('You are not authorized to provision this box. Owner mismatch.');
      }

      // Valid token! Fill the hidden fields.
      setState(() {
        _boxIdController.text = data['boxId'] ?? '';
        _secretController.text = data['deviceSecret'] ?? '';
        _currentStep = 2;
        _isVerifyingToken = false;
      });
      
      _checkConnection(); // Auto-check connection now that we are on step 2
    } catch (e) {
      setState(() => _isVerifyingToken = false);
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  Future<void> _submitProvisioning() async {
    if (!_formKey.currentState!.validate()) return;

    final ssid = _isManualSsid ? _manualSsidController.text.trim() : _selectedSSID;
    if (ssid == null || ssid.isEmpty) {
      _showSnackBar('Please select or enter a Wi-Fi network SSID.', AppTheme.error);
      return;
    }

    setState(() => _isSubmitting = true);

    final boxId = _boxIdController.text.trim();
    final password = _passwordController.text;
    final secret = _secretController.text.trim();
    final location = _locationController.text.trim();

    try {
      // 1. Post config to ESP32 local server
      final body = {
        'ssid': ssid,
        'password': password,
        'deviceId': boxId,
        'deviceSecret': secret,
        'location': location,
      };

      final response = await http.post(
        Uri.parse('http://192.168.4.1/configure'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw Exception('ESP32 configuration returned status ${response.statusCode}');
      }

      // 2. Register Box in Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Parse coordinates if they exist
        double? lat;
        double? lng;
        if (location.contains(',')) {
          final parts = location.split(',');
          if (parts.length == 2) {
            lat = double.tryParse(parts[0].trim());
            lng = double.tryParse(parts[1].trim());
          }
        }

        if (_isManualMode) {
          await FirebaseFirestore.instance.collection('boxes').doc(boxId).set({
            'boxId': boxId,
            'ownerId': user.uid,
            'location': location,
            'latitude': lat ?? 10.0,
            'longitude': lng ?? 76.0,
            'status': 'available',
            'tariff': {
              'evRate': double.tryParse(_evRateController.text) ?? 12.0,
              'socketRate': double.tryParse(_socketRateController.text) ?? 8.0,
            },
            'isLocked': true,
            'rfidDetected': true,
            'devices': {
              'evCharger': {'isOn': false, 'voltage': 0.0, 'current': 0.0, 'power': 0.0},
              'threePinSocket': {'isOn': false, 'voltage': 0.0, 'current': 0.0, 'power': 0.0},
            },
            'deviceSecret': secret,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          await FirebaseFirestore.instance.collection('boxes').doc(boxId).update({
            'location': location,
            'latitude': lat ?? 10.0,
            'longitude': lng ?? 76.0,
            'status': 'available',
            'deviceSecret': secret,
            'tariff': {
              'evRate': double.tryParse(_evRateController.text) ?? 12.0,
              'socketRate': double.tryParse(_socketRateController.text) ?? 8.0,
            },
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          
          // 3. Delete the provisioning token so it can't be reused
          await FirebaseFirestore.instance.collection('provisioningTokens').doc(_registrationIdController.text.trim()).delete();
        }
      }

      setState(() {
        _isSubmitting = false;
        _isProvisioned = true;
      });

    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnackBar('Provisioning failed: ${e.toString()}', AppTheme.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Provision New Smart Box'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isProvisioned 
            ? _buildSuccessView() 
            : (_currentStep == 1 ? _buildRegistrationStep() : _buildProvisionForm()),
      ),
    );
  }

  Widget _buildRegistrationStep() {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.qr_code_scanner, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Enter Registration ID',
            style: AppTheme.headingMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ask your administrator for the 6-digit Registration ID to begin provisioning your assigned Smart Box.',
            style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _registrationIdController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: AppTheme.inputDecoration(context, labelText: '').copyWith(
              counterText: '',
              hintText: '000000',
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _isVerifyingToken ? null : _verifyRegistrationToken,
            child: _isVerifyingToken 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('VERIFY REGISTRATION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _isManualMode = true;
                _currentStep = 2;
                _secretController.text = 'super-secret-token';
              });
              _checkConnection();
            },
            child: const Text('Manual Setup (Admin Only)', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    ));
  }

  Widget _buildProvisionForm() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AP Connection Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            decoration: AppTheme.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '1. Connect to Box Hotspot',
                      style: AppTheme.headingSmall.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _isCheckingConnection
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _isConnectedToBox ? Icons.check_circle : Icons.warning,
                            color: _isConnectedToBox ? AppTheme.success : AppTheme.error,
                          ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isConnectedToBox
                      ? 'Connected to setup hotspot server. Enter credentials below.'
                      : 'Please connect your mobile device to the Smart Box Wi-Fi hotspot (e.g., SmartBox-Setup-XXXX) via your system settings.',
                  style: AppTheme.bodyMedium.copyWith(
                    color: _isConnectedToBox ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (!_isConnectedToBox)
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _checkConnection,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('CHECK CONNECTION'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLarge),

          // Configuration Form
          Form(
            key: _formKey,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2. Configure Settings',
                    style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),

                  // SSID Field (Dropdown or Manual Input)
                  if (!_isManualSsid) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedSSID,
                      decoration: AppTheme.inputDecoration(
                        context,
                        labelText: 'Wi-Fi Network (SSID)',
                        prefixIcon: Icons.wifi,
                      ),
                      items: [
                        ..._scannedSSIDs.map((ssid) => DropdownMenuItem(
                              value: ssid,
                              child: Text(ssid),
                            )),
                        const DropdownMenuItem(
                          value: '__manual__',
                          child: Text('Enter SSID manually...'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == '__manual__') {
                          setState(() {
                            _isManualSsid = true;
                            _selectedSSID = null;
                          });
                        } else {
                          setState(() {
                            _selectedSSID = val;
                          });
                        }
                      },
                      validator: (value) => value == null ? 'Please select a network' : null,
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _manualSsidController,
                      decoration: AppTheme.inputDecoration(
                        context,
                        labelText: 'Wi-Fi Network Name (SSID)',
                        prefixIcon: Icons.wifi,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.list),
                          onPressed: () {
                            setState(() {
                              _isManualSsid = false;
                              if (_scannedSSIDs.isNotEmpty) {
                                _selectedSSID = _scannedSSIDs.first;
                              }
                            });
                          },
                          tooltip: 'Show scanned list',
                        ),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Please enter a Wi-Fi SSID' : null,
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingMedium),

                  // Wi-Fi Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: AppTheme.inputDecoration(
                      context,
                      labelText: 'Wi-Fi Password',
                      prefixIcon: Icons.lock,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),

                  // Box ID (Read-only from Token or Editable in Manual Mode)
                  TextFormField(
                    controller: _boxIdController,
                    readOnly: !_isManualMode,
                    enabled: _isManualMode,
                    decoration: AppTheme.inputDecoration(
                      context,
                      labelText: _isManualMode ? 'Box ID (Unique identifier)' : 'Box ID (Assigned from Cloud)',
                      prefixIcon: Icons.tag,
                    ),
                    validator: _isManualMode ? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a unique Box ID';
                      }
                      if (value.contains(' ')) {
                        return 'Box ID must not contain spaces';
                      }
                      return null;
                    } : null,
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),

                  // EV Rate Field
                  TextFormField(
                    controller: _evRateController,
                    decoration: AppTheme.inputDecoration(
                      context,
                      labelText: 'EV Charger Rate (₹/kWh)',
                      prefixIcon: Icons.electric_car,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (double.tryParse(value) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),

                  // Socket Rate Field
                  TextFormField(
                    controller: _socketRateController,
                    decoration: AppTheme.inputDecoration(
                      context,
                      labelText: '3-Pin Socket Rate (₹/kWh)',
                      prefixIcon: Icons.electrical_services,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (double.tryParse(value) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),

                  // Location (Prefilled with Lat, Lng)
                  TextFormField(
                    controller: _locationController,
                    decoration: AppTheme.inputDecoration(
                      context,
                      labelText: 'Location (Description or Coords)',
                      prefixIcon: Icons.location_on,
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Please enter location description or coordinates' : null,
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),

                  if (_isManualMode) ...[
                    TextFormField(
                      controller: _secretController,
                      obscureText: true,
                      decoration: AppTheme.inputDecoration(
                        context,
                        labelText: 'Device Secret Token',
                        prefixIcon: Icons.vpn_key,
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Please enter a secret security token' : null,
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                  ] else ...[
                    // Device Secret is now handled silently via the Token
                  ],
                  const SizedBox(height: AppTheme.spacingLarge),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: AppTheme.primaryButtonStyle,
                      onPressed: _isSubmitting ? null : _submitProvisioning,
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'CONFIGURE & PROVISION BOX',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXLarge),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 80,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXLarge),
            Text(
              'Configuration Transmitted!',
              style: AppTheme.headingLarge.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              'The Smart Box has received its configuration and is rebooting to connect to your Wi-Fi network.',
              style: AppTheme.bodyLarge.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              decoration: AppTheme.cardDecoration(context),
              child: const Column(
                children: [
                  Text(
                    'Next Steps:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Disconnect from the setup hotspot.\n'
                    '2. Reconnect your phone to your normal Wi-Fi network.\n'
                    '3. Verify the box is online on your dashboard.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingXXLarge),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: AppTheme.primaryButtonStyle,
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'DONE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
