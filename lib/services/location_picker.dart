// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geocoding/geocoding.dart';
//
// // --- 1. THE RESULT MODEL ---
// class LocationResult {
//   final String name;
//   final double lat;
//   final double lng;
//
//   LocationResult({
//     required this.name,
//     required this.lat,
//     required this.lng,
//   });
//
//   @override
//   String toString() => 'LocationResult(name: $name, lat: $lat, lng: $lng)';
// }
//
// // --- 2. THE ENTRY POINT SERVICE ---
// class LocationPicker {
//   static Future<LocationResult?> pick(BuildContext context) async {
//     return await showModalBottomSheet<LocationResult>(
//       context: context,
//       isScrollControlled: true, // Allows full screen
//       useSafeArea: true, // Prevents overlapping with notches
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (context) => const LocationPickerWidget(),
//     );
//   }
// }
//
// // --- 3. THE UI WIDGET ---
// class LocationPickerWidget extends StatefulWidget {
//   const LocationPickerWidget({Key? key}) : super(key: key);
//
//   @override
//   State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
// }
//
// class _LocationPickerWidgetState extends State<LocationPickerWidget> {
//   GoogleMapController? _mapController;
//
//   // Default to a central location (e.g., San Francisco)
//   LatLng _currentCenter = const LatLng(37.7749, -122.4194);
//   String _currentAddress = "Loading...";
//   bool _isMoving = false;
//
//   final TextEditingController _searchController = TextEditingController();
//
//   void _onMapCreated(GoogleMapController controller) {
//     _mapController = controller;
//     _updateAddress(_currentCenter);
//   }
//
//   void _onCameraMove(CameraPosition position) {
//     setState(() {
//       _isMoving = true;
//       _currentCenter = position.target;
//     });
//   }
//
//   void _onCameraIdle() async {
//     setState(() {
//       _isMoving = false;
//     });
//     await _updateAddress(_currentCenter);
//   }
//
//   Future<void> _updateAddress(LatLng target) async {
//     setState(() {
//       _currentAddress = "Fetching address...";
//     });
//     try {
//       List<Placemark> placemarks = await placemarkFromCoordinates(
//         target.latitude,
//         target.longitude,
//       );
//       if (placemarks.isNotEmpty) {
//         final place = placemarks.first;
//         setState(() {
//           _currentAddress = '${place.street}, ${place.locality}, ${place.country}';
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _currentAddress = "Unknown location";
//       });
//     }
//   }
//
//   void _confirmLocation() {
//     // Return the result via context.pop
//     Navigator.of(context).pop(
//       LocationResult(
//         name: _currentAddress,
//         lat: _currentCenter.latitude,
//         lng: _currentCenter.longitude,
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _searchController.dispose();
//     _mapController?.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Use a FractionallySizedBox or Container with MediaQuery height for full screen
//     return SizedBox(
//       height: MediaQuery.of(context).size.height * 0.95, // 95% of screen height
//       child: Column(
//         children: [
//           // Drag Handle
//           Center(
//             child: Container(
//               margin: const EdgeInsets.only(top: 12, bottom: 8),
//               width: 40,
//               height: 5,
//               decoration: BoxDecoration(
//                 color: Colors.grey[300],
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//           ),
//
//           // Search Bar
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//             child: TextField(
//               controller: _searchController,
//               decoration: InputDecoration(
//                 hintText: 'Search location...',
//                 prefixIcon: const Icon(Icons.search),
//                 filled: true,
//                 fillColor: Colors.grey[200],
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide.none,
//                 ),
//               ),
//               onSubmitted: (value) {
//                 // TODO: Implement Places API search and move camera
//                 // e.g., _mapController?.animateCamera(CameraUpdate.newLatLng(searchedLatLng));
//               },
//             ),
//           ),
//
//           // Map Area
//           Expanded(
//             child: Stack(
//               children: [
//                 GoogleMap(
//                   onMapCreated: _onMapCreated,
//                   initialCameraPosition: CameraPosition(
//                     target: _currentCenter,
//                     zoom: 15,
//                   ),
//                   onCameraMove: _onCameraMove,
//                   onCameraIdle: _onCameraIdle,
//                   myLocationEnabled: true,
//                   myLocationButtonEnabled: true,
//                   zoomControlsEnabled: false,
//                 ),
//
//                 // Center Fixed Pin
//                 Center(
//                   child: Padding(
//                     // Offset by half the icon height so the bottom tip points to the center
//                     padding: const EdgeInsets.only(bottom: 35.0),
//                     child: AnimatedContainer(
//                       duration: const Duration(milliseconds: 200),
//                       transform: Matrix4.translationValues(0, _isMoving ? -15 : 0, 0),
//                       child: const Icon(
//                         Icons.location_on,
//                         size: 50,
//                         color: Colors.red,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Bottom Confirmation Area
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
//               ],
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 Text(
//                   "Selected Location",
//                   style: TextStyle(color: Colors.grey[600], fontSize: 12),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   _currentAddress,
//                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 16),
//                 ElevatedButton(
//                   onPressed: _isMoving ? null : _confirmLocation,
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   child: const Text('Confirm Location', style: TextStyle(fontSize: 16)),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

// --- 1. THE RESULT MODEL ---
class LocationResult {
  final String name;
  final double lat;
  final double lng;

  LocationResult({
    required this.name,
    required this.lat,
    required this.lng,
  });

  @override
  String toString() => 'LocationResult(name: $name, lat: $lat, lng: $lng)';
}

// --- 2. THE ENTRY POINT SERVICE ---
class LocationPicker {
  static Future<LocationResult?> pick(BuildContext context) async {
    return await showModalBottomSheet<LocationResult>(
      context: context,
      isScrollControlled: true, // Allows full screen
      useSafeArea: true, // Prevents overlapping with notches
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const LocationPickerWidget(),
    );
  }
}

// --- 3. THE UI WIDGET ---
class LocationPickerWidget extends StatefulWidget {
  const LocationPickerWidget({Key? key}) : super(key: key);

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Default to a central location (e.g., San Francisco)
  LatLng _currentCenter = const LatLng(37.7749, -122.4194);
  String _currentAddress = "Loading...";
  bool _isMoving = false;

  // Debounce timer to simulate onCameraIdle in flutter_map
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _updateAddress(_currentCenter);
  }

  // Simulates onCameraMove & onCameraIdle via debouncing
  void _onPositionChanged(MapCamera position, bool hasGesture) {
    if (!_isMoving) {
      setState(() {
        _isMoving = true;
      });
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isMoving = false;
          _currentCenter = position.center;
        });
        _updateAddress(position.center);
      }
    });
  }

  // Free reverse geocoding via platform native geocoder (no API keys)
  Future<void> _updateAddress(LatLng target) async {
    setState(() {
      _currentAddress = "Fetching address...";
    });
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        target.latitude,
        target.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          // Construct an address string safely
          final street = place.street ?? '';
          final locality = place.locality ?? place.subLocality ?? '';
          final country = place.country ?? '';
          _currentAddress = [street, locality, country]
              .where((s) => s.isNotEmpty)
              .join(', ');
        });
      } else {
        setState(() {
          _currentAddress = "Unknown location";
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = "Unknown location";
      });
    }
  }

  // Free forward geocoding/search using OpenStreetMap's Nominatim API
  Future<void> _searchAndMove(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _currentAddress = "Searching...";
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=1',
      );

      // Nominatim requires a valid User-Agent header
      final response = await http.get(url, headers: {
        'User-Agent': 'FlutterFreeLocationPicker/1.0',
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final double lat = double.parse(data[0]['lat']);
          final double lon = double.parse(data[0]['lon']);
          final newTarget = LatLng(lat, lon);

          _mapController.move(newTarget, 15.0);
          // Address update will trigger automatically via _onPositionChanged
          return;
        }
      }
      setState(() {
        _currentAddress = "Location not found";
      });
    } catch (e) {
      setState(() {
        _currentAddress = "Search error";
      });
    }
  }

  void _confirmLocation() {
    Navigator.of(context).pop(
      LocationResult(
        name: _currentAddress,
        lat: _currentCenter.latitude,
        lng: _currentCenter.longitude,
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.95,
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search location...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _searchAndMove,
            ),
          ),

          // Map Area
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: 15.0,
                    onPositionChanged: _onPositionChanged,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app', // Replace with your app package
                    ),
                    // Optional OSM attribution watermark
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                        ),
                      ],
                    ),
                  ],
                ),

                // Center Fixed Pin
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 35.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.translationValues(
                          0, _isMoving ? -15 : 0, 0),
                      child: const Icon(
                        Icons.location_on,
                        size: 50,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Confirmation Area
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Selected Location",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentAddress,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isMoving ? null : _confirmLocation,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Confirm Location',
                      style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}