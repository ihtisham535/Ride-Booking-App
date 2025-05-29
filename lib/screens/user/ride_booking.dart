import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/ride.dart';
import '../../utils/colors.dart';
import '../../utils/styles.dart';
import '../../widgets/ride_card.dart';
import '../common/ride_details.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class RideBookingScreen extends StatefulWidget {
  const RideBookingScreen({super.key});

  @override
  State<RideBookingScreen> createState() => _RideBookingScreenState();
}

class _RideBookingScreenState extends State<RideBookingScreen> with TickerProviderStateMixin {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  bool _isLoading = false;
  bool _locationPermissionGranted = false;
  bool _showBookingForm = false;
  bool _isFetchingLocation = false;

  final String accessToken = 'pk.eyJ1IjoiaWh0aXNoYW0wMTAiLCJhIjoiY21hcnBobmZyMDhldjJvczVsNnY3ZjFrMSJ9.HLDJQJOJlB40kfmi6uZDNA';

  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  LatLng? _userLocation;
  List<LatLng> _routePoints = [];

  final MapController _mapController = MapController();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // Wider bounds for Multan
  static const double minLatitude = 29.5;
  static const double maxLatitude = 30.5;
  static const double minLongitude = 71.0;
  static const double maxLongitude = 72.0;

  // Cache for geocoded locations
  final Map<String, LatLng> _locationCache = {};

  // Updated and validated locations within Multan
  final Map<String, LatLng> multanLocations = {
    'dha multan': LatLng(30.28876, 71.52799), // Precise DHA Multan coordinates
    'model town multan': LatLng(30.24472, 71.50028),
    'multan cantt': LatLng(30.17423, 71.39138),
    'multan airport': LatLng(30.19615, 71.42373),
    'gulgasht multan': LatLng(30.22357, 71.47516),
    'shah rukan-e-alam': LatLng(30.19183, 71.51456),
    'bosan road multan': LatLng(30.22736, 71.47855),
    'wapda town multan': LatLng(30.24458, 71.50939),
    'qasim bela multan': LatLng(30.18040, 71.39118),
    'garden town multan': LatLng(30.16200, 71.39540),
    'shujabad road multan': LatLng(30.07776, 71.39898),
    'old shujabad road': LatLng(30.10399, 71.41727),
    'nishtar road multan': LatLng(30.20370, 71.44615),
    'chowk kumharanwala multan': LatLng(30.21034, 71.51509),
  };

  // Debounce timer for location updates
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _getUserLocation();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      setState(() {
        _locationPermissionGranted = true;
      });
      await _getUserLocation();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permission is required.', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _getUserLocation() async {
    if (_locationPermissionGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_userLocation!, 12.0);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location error: $e', style: GoogleFonts.poppins()),
              backgroundColor: Colors.red[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  String _findClosestLocation(String input) {
    input = input.toLowerCase().replaceAll(' ', ''); // Remove spaces
    double bestScore = 0.0;
    String bestMatch = '';

    int levenshteinDistance(String s1, String s2) {
      if (s1 == s2) return 0;
      if (s1.isEmpty) return s2.length;
      if (s2.isEmpty) return s1.length;

      List<List<int>> dp = List.generate(s1.length + 1, (_) => List<int>.filled(s2.length + 1, 0));
      for (int i = 0; i <= s1.length; i++) dp[i][0] = i;
      for (int j = 0; j <= s2.length; j++) dp[0][j] = j;

      for (int i = 1; i <= s1.length; i++) {
        for (int j = 1; j <= s2.length; j++) {
          int cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
          dp[i][j] = [
            dp[i - 1][j] + 1,
            dp[i][j - 1] + 1,
            dp[i - 1][j - 1] + cost,
          ].reduce((a, b) => a < b ? a : b);
        }
      }
      return dp[s1.length][s2.length];
    }

    for (var key in multanLocations.keys) {
      String normalizedKey = key.replaceAll(' ', '');
      int distance = levenshteinDistance(input, normalizedKey);
      double score = 1 - (distance / max(input.length, normalizedKey.length).toDouble());
      if (score > bestScore && score > 0.3) { // Lowered threshold to 0.3
        bestScore = score;
        bestMatch = key;
      }
    }

    return bestMatch;
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    _locationCache.clear(); // Clear entire cache for each new attempt
    print('Attempting to geocode: $address');

    try {
      String formattedAddress = address.trim().toLowerCase();
      if (!formattedAddress.contains('multan')) {
        formattedAddress += ' multan';
      }
      print('Formatted address: $formattedAddress');

      // Skip API call temporarily, rely on multanLocations
      String lowerAddress = formattedAddress.replaceAll(' ', '');
      for (var entry in multanLocations.entries) {
        String normalizedKey = entry.key.replaceAll(' ', '');
        if (lowerAddress.contains(normalizedKey)) {
          _locationCache[address] = entry.value;
          print('Matched fallback: $address -> ${entry.value}');
          return entry.value;
        }
      }

      String closestMatch = _findClosestLocation(lowerAddress);
      if (closestMatch.isNotEmpty && multanLocations.containsKey(closestMatch)) {
        final location = multanLocations[closestMatch]!;
        _locationCache[address] = location;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Did you mean "$closestMatch"? Using that location.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        print('Fuzzy match: $address -> $location');
        return location;
      }

      final defaultLocation = LatLng(30.1976, 71.4696); // Central Multan
      _locationCache[address] = defaultLocation;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location "$address" not recognized. Defaulting to central Multan.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      print('Defaulting to: $defaultLocation');
      return defaultLocation;

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Geocoding error: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      print('Geocoding error: $e');
      return null;
    }
  }

  LatLng _calculateBoundsCenter(LatLngBounds bounds) {
    final lat = (bounds.southWest.latitude + bounds.northEast.latitude) / 2;
    final lng = (bounds.southWest.longitude + bounds.northEast.longitude) / 2;
    return LatLng(lat, lng);
  }

  double _calculateZoomLevel(LatLngBounds bounds, double mapWidth, double mapHeight) {
    final latDiff = (bounds.northEast.latitude - bounds.southWest.latitude).abs();
    final lngDiff = (bounds.northEast.longitude - bounds.southWest.longitude).abs();
    final zoomLat = (log(180.0 / latDiff) / log(2)) + 1;
    final zoomLng = (log(360.0 / lngDiff) / log(2)) + 1;
    return min(zoomLat, zoomLng).clamp(2.0, 18.0);
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    try {
      final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&access_token=$accessToken';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] == null || data['routes'].isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No route found.', style: GoogleFonts.poppins()),
                backgroundColor: Colors.red[400],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
          return;
        }
        final routes = data['routes'] as List;
        final route = routes[0];
        final coordinates = route['geometry']['coordinates'] as List;
        final newRoutePoints = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
        if (_routePoints != newRoutePoints) {
          setState(() {
            _routePoints = newRoutePoints;
          });
        }
        if (_routePoints.isNotEmpty) {
          final bounds = LatLngBounds.fromPoints(_routePoints);
          final center = _calculateBoundsCenter(bounds);
          final mapWidth = MediaQuery.of(context).size.width;
          final mapHeight = MediaQuery.of(context).size.height * 0.7;
          final zoom = _calculateZoomLevel(bounds, mapWidth, mapHeight);
          _mapController.move(center, zoom);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to fetch route.', style: GoogleFonts.poppins()),
              backgroundColor: Colors.red[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Route fetch error: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchNearbyRiders(LatLng? pickupLocation) async {
    if (pickupLocation == null) return [];
    try {
      final snapshot = await FirebaseFirestore.instance.collection('rider').get();
      final List<Map<String, dynamic>> riders = [];
      final distance = Distance();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final riderLatitude = (data['latitude'] as num?)?.toDouble();
        final riderLongitude = (data['longitude'] as num?)?.toDouble();
        if (riderLatitude == null || riderLongitude == null) continue;
        final riderLocation = LatLng(riderLatitude, riderLongitude);
        final riderDistance = distance.as(LengthUnit.Kilometer, pickupLocation, riderLocation);
        if (riderDistance > 50.0) continue;
        riders.add({
          'id': doc.id,
          'name': data['name']?.toString() ?? 'Unknown Rider',
          'vehicle': data['vehicle']?.toString() ?? 'Unknown Vehicle',
          'plate': data['plate']?.toString() ?? 'N/A',
          'rating': (data['rating'] as num?)?.toDouble() ?? 0.0,
          'distance': riderDistance,
          'location': riderLocation,
        });
      }
      return riders;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching riders: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return [];
    }
  }

  Future<void> _updateLocations(String inputType, String address) async {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    setState(() {
      _isFetchingLocation = true;
    });

    _debounceTimer = Timer(Duration(milliseconds: 500), () async {
      String formattedAddress = address.trim().toLowerCase();
      if (!formattedAddress.contains('multan')) {
        formattedAddress += ' multan';
      }
      _locationCache.clear(); // Clear cache for fresh attempt

      final newLocation = await _geocodeAddress(formattedAddress);

      setState(() {
        if (inputType == 'pickup') {
          _pickupLocation = newLocation ?? _pickupLocation;
        } else if (inputType == 'destination') {
          _destinationLocation = newLocation ?? _destinationLocation;
        }
        _isFetchingLocation = false;
      });

      if (_pickupLocation != null && _destinationLocation != null) {
        await _fetchRoute(_pickupLocation!, _destinationLocation!);
      }
    });
  }

  void _bookRide() async {
    if (_pickupController.text.isEmpty || _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter pickup and destination.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to book a ride.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    await _updateLocations('pickup', _pickupController.text);
    await _updateLocations('destination', _destinationController.text);

    setState(() {
      _isLoading = true;
    });

    final pickupLocation = _pickupLocation;
    if (pickupLocation == null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid pickup location.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final nearbyRiders = await _fetchNearbyRiders(pickupLocation);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        isDismissible: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => AnimatedContainer(
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: RiderSelectionScreen(
                nearbyRiders: nearbyRiders,
                pickupLocation: _pickupController.text,
                destination: _destinationController.text,
              ),
            ),
          ),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pickupController.dispose();
    _destinationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _userLocation ?? const LatLng(30.1976, 71.4696),
                  initialZoom: 12,
                  onMapReady: () {
                    if (_pickupController.text.isNotEmpty) {
                      _updateLocations('pickup', _pickupController.text);
                    }
                    if (_destinationController.text.isNotEmpty) {
                      _updateLocations('destination', _destinationController.text);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}',
                    additionalOptions: {
                      'accessToken': accessToken,
                    },
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 5.0,
                          color: Color(0xFF2196F3).withOpacity(0.8),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_pickupLocation != null)
                        Marker(
                          point: _pickupLocation!,
                          child: Icon(Icons.location_pin, color: Color(0xFF4CAF50), size: 40),
                        ),
                      if (_destinationLocation != null)
                        Marker(
                          point: _destinationLocation!,
                          child: Icon(Icons.flag, color: Color(0xFFF44336), size: 40),
                        ),
                      if (_userLocation != null)
                        Marker(
                          point: _userLocation!,
                          child: Icon(Icons.my_location, color: Color(0xFF9C27B0), size: 40),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  elevation: 4,
                  onPressed: () {
                    if (_userLocation != null) {
                      _mapController.move(_userLocation!, 12.0);
                    }
                  },
                  child: Icon(Icons.my_location, color: Color(0xFF4CAF50)),
                ),
              ),
              AnimatedPositioned(
                duration: Duration(milliseconds: 300),
                bottom: _showBookingForm ? 0 : -screenHeight * 0.4,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Text(
                        'Book Your Ride',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _pickupController,
                        decoration: InputDecoration(
                          labelText: 'Pickup Location',
                          labelStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                          prefixIcon: Icon(Icons.location_on, color: Color(0xFF4CAF50), size: 20),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          suffixIcon: _isFetchingLocation && _pickupController.text.isNotEmpty
                              ? Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          )
                              : null,
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            _updateLocations('pickup', value);
                          }
                        },
                      ),
                      SizedBox(height: 12),
                      TextFormField(
                        controller: _destinationController,
                        decoration: InputDecoration(
                          labelText: 'Destination',
                          labelStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                          prefixIcon: Icon(Icons.flag, color: Color(0xFF4CAF50), size: 20),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          suffixIcon: _isFetchingLocation && _destinationController.text.isNotEmpty
                              ? Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          )
                              : null,
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            _updateLocations('destination', value);
                          }
                        },
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading || _isFetchingLocation ? null : _bookRide,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : Text(
                                'Find Riders',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey[600]),
                            onPressed: () => setState(() => _showBookingForm = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!_showBookingForm)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.directions_car, size: 20),
                    label: Text(
                      'Book a Ride',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    onPressed: () => setState(() => _showBookingForm = true),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}



class RiderSelectionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> nearbyRiders;
  final String pickupLocation;
  final String destination;

  const RiderSelectionScreen({
    super.key,
    required this.nearbyRiders,
    required this.pickupLocation,
    required this.destination,
  });

  @override
  _RiderSelectionScreenState createState() => _RiderSelectionScreenState();
}

class _RiderSelectionScreenState extends State<RiderSelectionScreen> {
  String _sortBy = 'distance';

  List<Map<String, dynamic>> get sortedRiders {
    final riders = List<Map<String, dynamic>>.from(widget.nearbyRiders);
    if (_sortBy == 'rating') {
      riders.sort((a, b) => b['rating'].compareTo(a['rating']));
    } else {
      riders.sort((a, b) => a['distance'].compareTo(b['distance']));
    }
    return riders;
  }

  Future<void> _sendRideRequest(BuildContext context, Map<String, dynamic> rider) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please log in to send a ride request.', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[400],
          ),
        );
        return;
      }

      final ride = Ride(
        id: 'ride_${DateTime.now().millisecondsSinceEpoch}',
        userId: user.uid,
        riderId: rider['id'],
        pickupLocation: widget.pickupLocation,
        destination: widget.destination,
        requestTime: DateTime.now(),
        status: 'requested',
      );

      await FirebaseFirestore.instance.collection('rides').doc(ride.id).set({
        'id': ride.id,
        'userId': ride.userId,
        'riderId': rider['id'],
        'pickupLocation': ride.pickupLocation,
        'destination': ride.destination,
        'requestTime': ride.requestTime.toIso8601String(),
        'status': ride.status,
      });

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RideDetailsScreen(
            ride: ride,
            riderName: rider['name'],
            riderRating: rider['rating'],
            riderVehicle: rider['vehicle'],
            riderPlate: rider['plate'],
          ),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ride request sent to ${rider['name']}.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending ride request: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth * 0.04;  // Adaptive padding
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select a Rider',
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 16 : 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text('${widget.pickupLocation} → ${widget.destination}',
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 10 : 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text('Sort by:',
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _sortBy,
                        icon: Icon(Icons.arrow_drop_down, color: Colors.green),
                        underline: SizedBox(),
                        items: ['distance', 'rating'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value == 'distance' ? 'Distance' : 'Rating',
                              style: GoogleFonts.poppins(fontSize: isSmallScreen ? 12 : 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) setState(() => _sortBy = newValue);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: sortedRiders.isEmpty
                  ? Center(child: Text('No Riders Available', style: GoogleFonts.poppins(fontSize: isSmallScreen ? 18 : 22)))
                  : ListView.builder(
                padding: EdgeInsets.all(padding),
                itemCount: sortedRiders.length,
                itemBuilder: (context, index) {
                  final rider = sortedRiders[index];
                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.symmetric(vertical: padding * 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: isSmallScreen ? 25 : 30,
                            backgroundColor: Colors.green.withOpacity(0.1),
                            child: Icon(Icons.person, size: isSmallScreen ? 30 : 40, color: Colors.green),
                          ),
                          SizedBox(width: padding),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rider['name'], style: GoogleFonts.poppins(fontSize: isSmallScreen ? 14 : 18, fontWeight: FontWeight.w600)),
                                Text('Vehicle: ${rider['vehicle']} (${rider['plate']})',
                                    style: GoogleFonts.poppins(fontSize: isSmallScreen ? 10 : 14)),
                                Row(
                                  children: [
                                    Icon(Icons.star, size: isSmallScreen ? 12 : 16, color: Colors.amber),
                                    SizedBox(width: 4),
                                    Text('${rider['rating'].toStringAsFixed(1)}',
                                        style: GoogleFonts.poppins(fontSize: isSmallScreen ? 10 : 14)),
                                    SizedBox(width: 8),
                                    Icon(Icons.location_on, size: isSmallScreen ? 12 : 16, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text('${rider['distance'].toStringAsFixed(1)} km',
                                        style: GoogleFonts.poppins(fontSize: isSmallScreen ? 10 : 14)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _sendRideRequest(context, rider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Select', style: GoogleFonts.poppins(fontSize: isSmallScreen ? 12 : 14)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
