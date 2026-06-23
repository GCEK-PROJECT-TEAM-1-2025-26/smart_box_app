import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteService {
  static Future<List<LatLng>> getRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '$startLng,$startLat;'
        '$endLng,$endLat'
        '?overview=full&geometries=geojson';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final coordinates = data['routes'][0]['geometry']['coordinates'];

      return coordinates.map<LatLng>((coord) {
        return LatLng(coord[1].toDouble(), coord[0].toDouble());
      }).toList();
    }

    return [];
  }
}
