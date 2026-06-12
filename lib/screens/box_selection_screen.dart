import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/box_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class BoxSelectionScreen extends StatefulWidget {
  const BoxSelectionScreen({super.key});

  @override
  State<BoxSelectionScreen> createState() => _BoxSelectionScreenState();
}

class _BoxSelectionScreenState extends State<BoxSelectionScreen> {
  final TextEditingController _boxIdController = TextEditingController();
  MobileScannerController? mobileScannerController;
  bool _isScanning = false;
  bool _isLoading = false;
  String? _scannedBoxId;
  List<Map<String, dynamic>> _boxes = [];

  @override
  void initState() {
    super.initState();
    _loadBoxes();
  }

  @override
  void dispose() {
    _boxIdController.dispose();
    mobileScannerController?.dispose();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to scan QR codes'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _validateAndAccessBox(String boxId) async {
    if (boxId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or scan a Box ID')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final boxService = BoxService();
      final isValid = await boxService.validateBoxId(boxId);

      if (isValid) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DashboardScreen(boxId: boxId),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Box ID not found or invalid'),
              backgroundColor: AppTheme.error,
            ),
          );
          setState(() => _scannedBoxId = null);
          if (_isScanning) {
            mobileScannerController?.start();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _logout() {
    FirebaseAuth.instance.signOut();
  }

  Future<void> _loadBoxes() async {
    final boxes = await BoxService().getAllBoxes();

    if (mounted) {
      setState(() {
        _boxes = boxes;
      });
    }
  }

  Future<void> _openGoogleMaps(double latitude, double longitude) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        title: const Text('Select Smart Box'),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: _isScanning ? _buildQRScanner() : _buildManualEntry(),
    );
  }

  Widget _buildQRScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: MobileScannerController(
            detectionSpeed: DetectionSpeed.noDuplicates,
            returnImage: false,
          ),
          onDetect: (capture) {
            if (_scannedBoxId == null) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final scannedBoxId = barcodes.first.rawValue;
                if (scannedBoxId != null && scannedBoxId.isNotEmpty) {
                  setState(() => _scannedBoxId = scannedBoxId);
                  _validateAndAccessBox(scannedBoxId);
                }
              }
            }
          },
        ),
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Point camera at Box QR code',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              setState(() {
                _isScanning = false;
                _scannedBoxId = null;
              });
            },
            icon: const Icon(Icons.keyboard),
            label: const Text('Enter Box ID Manually'),
          ),
        ),
      ],
    );
  }

  Widget _buildManualEntry() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.qr_code_2,
                  size: 80,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Access Your Smart Box',
                style: AppTheme.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Scan a QR code or enter the Box ID',
                style: AppTheme.bodyMedium.copyWith(color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _boxIdController,
                decoration: InputDecoration(
                  hintText: 'e.g., box_001',
                  labelText: 'Box ID',
                  prefixIcon: const Icon(
                    Icons.tag,
                    color: AppTheme.primaryBlue,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryBlue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                ),
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () =>
                            _validateAndAccessBox(_boxIdController.text.trim()),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Access Box'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          await _requestCameraPermission();
                          if (mounted) {
                            setState(() => _isScanning = true);
                          }
                        },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Code'),
                ),
              ),
              const SizedBox(height: 30),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Nearby Smart Boxes', style: AppTheme.headingSmall),
              ),
              const SizedBox(height: 16),
              Column(
                children: _boxes.map((box) {
                  return Card(
                    color: AppTheme.surfaceDark,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                      ),
                      title: Text(box['boxId'], style: AppTheme.bodyMedium),
                      subtitle: Text(
                        'Smart Box Location',
                        style: AppTheme.bodySmall,
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          _openGoogleMaps(
                            (box['latitude'] as num).toDouble(),
                            (box['longitude'] as num).toDouble(),
                          );
                        },
                        child: const Text('Navigate'),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
