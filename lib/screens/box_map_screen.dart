import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/box_service.dart';
import '../services/booking_service.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' as math;
import 'dart:async';
import '../theme/app_theme.dart';
import 'booking_screen.dart';

class BoxMapScreen extends StatefulWidget {
  const BoxMapScreen({super.key});

  @override
  State<BoxMapScreen> createState() => _BoxMapScreenState();
}

class _BoxMapScreenState extends State<BoxMapScreen> {
  GoogleMapController? _mapController;
  StreamSubscription? _compassSubscription;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;

  Position? _currentPosition;
  List<Map<String, dynamic>> _boxes = [];
  final List<LatLng> _routePoints = [];
  String? _selectedBoxId;

  double _heading = 0;
  Map<String, dynamic>? _selectedBox;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _compassSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _loadBoxes();
    _getCurrentLocation();

    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() {
          _heading = event.heading ?? 0;
        });
      }
    });
  }

  Future<void> _loadBoxes() async {
    final boxes = await BoxService().getAllBoxes();

    if (mounted) {
      setState(() {
        _boxes = boxes;
      });

      _calculateDistances();

      // Run lockout check for each box in parallel
      final bookingService = BookingService();
      for (final box in boxes) {
        bookingService.checkAndApplyLockout(box['boxId'] as String);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) return;

    _currentPosition = await Geolocator.getCurrentPosition();

    setState(() {});

    _calculateDistances();
  }

  void _calculateDistances() {
    if (_currentPosition == null) return;

    for (var box in _boxes) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        (box['latitude'] as num).toDouble(),
        (box['longitude'] as num).toDouble(),
      );

      box['distance'] = distance;
    }

    _boxes.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
    );
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    final matches = _boxes.where((box) {
      final boxId = (box['boxId'] as String).toLowerCase();
      final location = (box['location'] as String? ?? '').toLowerCase();
      return boxId.contains(lowercaseQuery) || location.contains(lowercaseQuery);
    }).toList();

    setState(() {
      _suggestions = matches;
      _showSuggestions = true;
    });
  }

  void _selectBox(Map<String, dynamic> box) {
    setState(() {
      _selectedBoxId = box['boxId'];
      _selectedBox = box;
      _searchController.text = box['boxId'];
      _showSuggestions = false;
      _focusNode.unfocus();
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          (box['latitude'] as num).toDouble(),
          (box['longitude'] as num).toDouble(),
        ),
        17.5,
      ),
    );
  }

  Future<void> _startNavigation(Map<String, dynamic> box) async {
    final lat = (box['latitude'] as num).toDouble();
    final lng = (box['longitude'] as num).toDouble();
    
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  double _calculateBearing(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    double startLatRad = startLat * math.pi / 180;
    double startLngRad = startLng * math.pi / 180;

    double endLatRad = endLat * math.pi / 180;
    double endLngRad = endLng * math.pi / 180;

    double dLng = endLngRad - startLngRad;

    double y = math.sin(dLng) * math.cos(endLatRad);

    double x =
        math.cos(startLatRad) * math.sin(endLatRad) -
        math.sin(startLatRad) * math.cos(endLatRad) * math.cos(dLng);

    double bearing = math.atan2(y, x);

    bearing = bearing * 180 / math.pi;

    return (bearing + 360) % 360;
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
    for (var box in _boxes) {
      final status = box['status'] as String? ?? 'available';
      double hue;
      if (_selectedBoxId == box['boxId']) {
        hue = BitmapDescriptor.hueRed;
      } else if (status == 'booked') {
        hue = BitmapDescriptor.hueOrange; // reserved
      } else if (status == 'in_use') {
        hue = BitmapDescriptor.hueViolet; // in use
      } else {
        hue = BitmapDescriptor.hueGreen; // available
      }
      markers.add(
        Marker(
          markerId: MarkerId(box['boxId']),
          position: LatLng(
            (box['latitude'] as num).toDouble(),
            (box['longitude'] as num).toDouble(),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          onTap: () {
            _selectBox(box);
          },
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final Set<Polyline> polylines = {};
    if (_routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          width: 4,
          color: Colors.blue,
        ),
      );
    }
    return polylines;
  }

  Widget _buildDetailsCard() {
    final box = _selectedBox!;
    final status = box['status'] ?? 'available';
    final isAvailable = status == 'available';

    final evRate = box['tariff']?['evRate'] ?? 12.0;
    final socketRate = box['tariff']?['socketRate'] ?? 8.0;
    final distanceStr = box['distance'] != null
        ? "${((box['distance'] as double) / 1000).toStringAsFixed(2)} km away"
        : null;

    final theme = Theme.of(context);

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: theme.cardTheme.color ?? Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          box['boxId'],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (distanceStr != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            distanceStr,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedBox = null;
                        _selectedBoxId = null;
                        _searchController.clear();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Status Pill & Address
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? AppTheme.success.withValues(alpha: 0.15)
                          : AppTheme.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAvailable ? Icons.check_circle : Icons.offline_bolt,
                          color: isAvailable ? AppTheme.success : AppTheme.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAvailable ? "Available" : "In Use",
                          style: TextStyle(
                            color: isAvailable ? AppTheme.success : AppTheme.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      box['location'] ?? 'No address listed',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tariff Details
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.ev_station, color: Colors.blue, size: 18),
                              SizedBox(width: 4),
                              Text(
                                "EV Charger",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "₹${evRate.toStringAsFixed(2)}/kWh",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.power, color: Colors.teal, size: 18),
                              SizedBox(width: 4),
                              Text(
                                "3-Pin Socket",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "₹${socketRate.toStringAsFixed(2)}/kWh",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _startNavigation(box),
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text("Navigate"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Book Now button (only for available boxes)
                  if ((box['status'] ?? 'available') == 'available')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingScreen(
                                boxId: box['boxId'],
                                boxLocation: box['location'] ?? '',
                                tariff: box['tariff'] as Map<String, dynamic>? ??
                                    {'evRate': 12.0, 'socketRate': 8.0},
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.bookmark_add,
                            color: AppTheme.warning),
                        label: const Text("Book",
                            style: TextStyle(color: AppTheme.warning)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppTheme.warning),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Return the box ID to the selection screen
                        Navigator.of(context).pop(box['boxId']);
                      },
                      icon: const Icon(Icons.flash_on),
                      label: const Text("Proceed"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search box ID or location...',
                hintStyle: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 15,
                ),
                prefixIcon: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.grey),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _suggestions = [];
                            _showSuggestions = false;
                            _selectedBox = null;
                            _selectedBoxId = null;
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          if (_showSuggestions && _suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final box = _suggestions[index];
                  final distance = box['distance'] != null
                      ? "${((box['distance'] as double) / 1000).toStringAsFixed(1)} km"
                      : "";
                  return ListTile(
                    leading: const Icon(Icons.ev_station, color: AppTheme.success),
                    title: Text(
                      box['boxId'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      box['location'] ?? 'No address listed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: distance.isNotEmpty
                        ? Text(
                            distance,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          )
                        : null,
                    onTap: () {
                      _selectBox(box);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: (latLng) {
              setState(() {
                _showSuggestions = false;
                _focusNode.unfocus();
              });
            },
          ),

          if (_selectedBox != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: const [
                    BoxShadow(blurRadius: 5, color: Colors.black26),
                  ],
                ),
                child: Transform.rotate(
                  angle:
                      ((_calculateBearing(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            (_selectedBox!['latitude'] as num).toDouble(),
                            (_selectedBox!['longitude'] as num).toDouble(),
                          ) -
                          _heading) *
                      math.pi /
                      180),
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.blue,
                    size: 40,
                  ),
                ),
              ),
            ),

          if (_selectedBox != null)
            _buildDetailsCard()
          else
            DraggableScrollableSheet(
              initialChildSize: 0.35,
              minChildSize: 0.25,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Nearby Smart Boxes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _boxes.length,
                          itemBuilder: (context, index) {
                            final box = _boxes[index];

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: ListTile(
                                onTap: () {
                                  _selectBox(box);
                                },
                                leading: const Icon(
                                  Icons.ev_station,
                                  color: Colors.green,
                                ),
                                title: Text(box['boxId']),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${((box['distance'] ?? 0) / 1000).toStringAsFixed(2)} km away",
                                    ),
                                    Text("Status: ${box['status']}"),
                                    const SizedBox(height: 4),
                                    Text(
                                      "EV: ₹${box['tariff']?['evRate'] ?? 12.0}/kWh",
                                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                    ),
                                    Text(
                                      "Socket: ₹${box['tariff']?['socketRate'] ?? 8.0}/kWh",
                                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                    ),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    _startNavigation(box);
                                  },
                                  child: const Text("Navigate"),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          _buildSearchBar(),
        ],
      ),
    );
  }
}
