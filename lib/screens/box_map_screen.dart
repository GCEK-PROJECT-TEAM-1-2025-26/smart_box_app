import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/box_service.dart';
import '../services/route_service.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' as math;
import 'dart:async';

class BoxMapScreen extends StatefulWidget {
  const BoxMapScreen({super.key});

  @override
  State<BoxMapScreen> createState() => _BoxMapScreenState();
}

class _BoxMapScreenState extends State<BoxMapScreen> {
  GoogleMapController? _mapController;
  StreamSubscription? _compassSubscription;

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
  Position? _currentPosition;
  List<Map<String, dynamic>> _boxes = [];
  List<LatLng> _routePoints = [];
  String? _selectedBoxId;

  double _heading = 0;
  Map<String, dynamic>? _selectedBox;

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

    print("BOXES LOADED: $boxes");

    if (mounted) {
      setState(() {
        _boxes = boxes;
      });

      _calculateDistances();
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
      markers.add(
        Marker(
          markerId: MarkerId(box['boxId']),
          position: LatLng(
            (box['latitude'] as num).toDouble(),
            (box['longitude'] as num).toDouble(),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _selectedBoxId == box['boxId']
                ? BitmapDescriptor.hueRed
                : BitmapDescriptor.hueGreen,
          ),
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

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Smart Boxes')),
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
            zoomControlsEnabled: true,
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),

          if (_selectedBox != null)
            Positioned(
              top: 100,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
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

          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.25,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    LatLng(
                                      (box['latitude'] as num).toDouble(),
                                      (box['longitude'] as num).toDouble(),
                                    ),
                                    18.0,
                                  ),
                                );
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
        ],
      ),
    );
  }
}
