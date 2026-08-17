import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<Map<String, dynamic>> getCurrentLocationData() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'address': 'Location services are disabled',
          'coordinates': null,
        };
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {
            'address': 'Location permissions are denied',
            'coordinates': null,
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'address': 'Location permissions are permanently denied',
          'coordinates': null,
        };
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      String address;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          address = '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
        } else {
          address = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
        }
      } catch (e) {
        address = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
      }

      return {
        'address': address,
        'coordinates': 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}',
        'accuracy': position.accuracy,
      };
    } catch (e) {
      return {
        'address': 'Unable to get location: ${e.toString()}',
        'coordinates': null,
      };
    }
  }

  static Future<String> getCurrentLocation() async {
    final data = await getCurrentLocationData();
    return data['address'];
  }
}