import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/box_service.dart';
import '../services/route_service.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' as math;

class BoxMapScreen extends StatefulWidget {
  const BoxMapScreen({super.key});

  @override
  State<BoxMapScreen> createState() => _BoxMapScreenState();
}

class _BoxMapScreenState extends State<BoxMapScreen> {
  final MapController _mapController = MapController();
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

    FlutterCompass.events?.listen((event) {
      setState(() {
        _heading = event.heading ?? 0;
      });
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
    if (_currentPosition == null) return;

    print("NAVIGATION STARTED");

    final route = await RouteService.getRoute(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      (box['latitude'] as num).toDouble(),
      (box['longitude'] as num).toDouble(),
    );

    print("ROUTE POINTS COUNT: ${route.length}");

    setState(() {
      _routePoints = route;
      _selectedBoxId = box['boxId'];
      _selectedBox = box;
    });
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

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Smart Boxes')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.smart_box_app',
              ),

              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 4,
                    color: Colors.blue,
                  ),
                ],
              ),

              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.person_pin_circle,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),

                  ..._boxes.map((box) {
                    return Marker(
                      point: LatLng(
                        (box['latitude'] as num).toDouble(),
                        (box['longitude'] as num).toDouble(),
                      ),
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.ev_station,
                        color: _selectedBoxId == box['boxId']
                            ? Colors.red
                            : Colors.green,
                        size: 40,
                      ),
                    );
                  }),
                ],
              ),
            ],
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
                                _mapController.move(
                                  LatLng(
                                    (box['latitude'] as num).toDouble(),
                                    (box['longitude'] as num).toDouble(),
                                  ),
                                  18,
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
