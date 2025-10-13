import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationPicker extends StatefulWidget {
  final LatLng? initialPosition;
  const LocationPicker({super.key, this.initialPosition});

  @override
  _LocationPickerState createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  String _currentAddress = '';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  bool _isLoadingSuggestions = false;
  bool _isLoadingLocation = false;
  Timer? _debounce;

  static const String _googleApiKey = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _currentPosition = widget.initialPosition;
      _getAddressFromLatLng(_currentPosition!);
    } else {
      // Immediately try to get current location when screen loads
      _checkLocationPermission();
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      print('Checking location permission...');

      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('Location services enabled: $serviceEnabled');

      if (!serviceEnabled) {
        if (Platform.isIOS) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are disabled. Please enable them in Settings > Privacy & Security > Location Services.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are disabled. Please enable them in your device settings.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      print('Initial permission status: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('Permission after request: $permission');

        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied. Please grant location permission to use this feature.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (Platform.isIOS) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission permanently denied. Please enable it in Settings > Privacy & Security > Location Services > Flock Business.',
              ),
              duration: Duration(seconds: 6),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission permanently denied. Please enable it in your device settings.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // If we have permission, get current location
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await _getCurrentLocation();
      }
    } catch (e) {
      print('Error checking location permission: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking location permission: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your current location...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Use different accuracy settings for iOS vs Android
      LocationAccuracy accuracy =
          Platform.isIOS ? LocationAccuracy.best : LocationAccuracy.high;

      print('Platform: ${Platform.isIOS ? "iOS" : "Android"}');
      print('Using accuracy: $accuracy');

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: const Duration(seconds: 15), // Add timeout for iOS
      );

      print('Position obtained: ${position.latitude}, ${position.longitude}');

      LatLng newPosition = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = newPosition;
        _isSearching = false;
        _searchController.clear();
        _suggestions = [];
        _isLoadingLocation = false;
      });

      // Animate camera to current location with a slight delay to ensure map is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 15),
        );
      });

      await _getAddressFromLatLng(newPosition);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location obtained successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });

      String errorMessage = 'Unable to get current location';

      if (e.toString().contains('timeout')) {
        errorMessage = 'Location request timed out. Please try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage =
            'Location permission denied. Please check your settings.';
      } else if (Platform.isIOS) {
        errorMessage =
            'Location services may be disabled. Please check Settings > Privacy & Security > Location Services.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${position.latitude},${position.longitude}'
        '&key=$_googleApiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          setState(() {
            _currentAddress = data['results'][0]['formatted_address'];
          });
        } else {
          setState(() {
            _currentAddress = 'Unknown address';
          });
        }
      }
    } catch (e) {
      print('Error getting address: $e');
      setState(() {
        _currentAddress = 'Error fetching address';
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$query'
        '&key=$_googleApiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          await _fetchPlaceDetails(predictions);
        } else {
          setState(() {
            _suggestions = [];
            _isLoadingSuggestions = false;
          });
        }
      }
    } catch (e) {
      print('Error searching places: $e');
      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
    }
  }

  Future<void> _fetchPlaceDetails(List predictions) async {
    List<Map<String, dynamic>> newSuggestions = [];

    for (var prediction in predictions.take(5)) {
      try {
        final detailUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=${prediction['place_id']}'
          '&fields=name,formatted_address,geometry'
          '&key=$_googleApiKey',
        );

        final detailResponse = await http.get(detailUrl);
        if (detailResponse.statusCode == 200) {
          final detailData = json.decode(detailResponse.body);
          if (detailData['status'] == 'OK' && detailData['result'] != null) {
            final result = detailData['result'];

            // Safely extract values with null checks
            final name = result['name']?.toString() ?? 'Unknown Location';
            final address =
                result['formatted_address']?.toString() ?? 'Unknown Address';
            final geometry = result['geometry'];

            if (geometry != null && geometry['location'] != null) {
              final location = geometry['location'];
              final lat = location['lat'];
              final lng = location['lng'];

              if (lat != null && lng != null) {
                newSuggestions.add({
                  'name': name,
                  'address': address,
                  'lat':
                      lat is double
                          ? lat
                          : double.tryParse(lat.toString()) ?? 0.0,
                  'lng':
                      lng is double
                          ? lng
                          : double.tryParse(lng.toString()) ?? 0.0,
                });
              }
            }
          }
        }
      } catch (e) {
        print('Error fetching place details: $e');
      }
    }

    setState(() {
      _suggestions = newSuggestions;
      _isLoadingSuggestions = false;
    });
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    setState(() {
      _isSearching = value.isNotEmpty;
    });

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (value.isNotEmpty) {
        _searchPlaces(value);
      } else {
        setState(() {
          _suggestions = [];
          _isLoadingSuggestions = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Location',
          style:
              Theme.of(context).appBarTheme.titleTextStyle ??
              TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.my_location,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target:
                  widget.initialPosition ??
                  _currentPosition ??
                  const LatLng(
                    37.7749,
                    -122.4194,
                  ), // Default to San Francisco for better UX
              zoom: 10,
            ),
            markers:
                _currentPosition != null
                    ? {
                      Marker(
                        markerId: const MarkerId('selected-location'),
                        position: _currentPosition!,
                      ),
                    }
                    : {},
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              if (widget.initialPosition != null) {
                // Add a small delay for iOS to ensure map is properly initialized
                Future.delayed(const Duration(milliseconds: 300), () {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(widget.initialPosition!, 15),
                  );
                });
              } else if (_currentPosition != null) {
                // If we already have current position, animate to it
                Future.delayed(const Duration(milliseconds: 300), () {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentPosition!, 15),
                  );
                });
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled:
                false, // This will hide the default zoom controls (+ and - buttons)
            onTap: (LatLng position) async {
              setState(() {
                _currentPosition = position;
                _isSearching = false;
                _searchController.clear();
                _suggestions = [];
              });
              await _getAddressFromLatLng(position);
            },
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(5)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.search,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          onPressed: () {
                            if (_searchController.text.isNotEmpty) {
                              _searchPlaces(_searchController.text);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Search for a place...",
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            hintStyle: TextStyle(
                              color: Theme.of(context).hintColor,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: _onSearchChanged,
                          onTap: () {
                            if (_searchController.text.isNotEmpty) {
                              setState(() {
                                _isSearching = true;
                              });
                            }
                          },
                        ),
                      ),
                      if (_isSearching)
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(5),
                              bottomRight: Radius.circular(5),
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Theme.of(context).iconTheme.color,
                            ),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _suggestions = [];
                                _isSearching = false;
                                _isLoadingSuggestions = false;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                  if (_isSearching && _isLoadingSuggestions)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
          if (_isSearching)
            Positioned(
              top: 70,
              left: 10,
              right: 10,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Add "Use Current Location" option with better styling
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 28,
                        ),
                        title: const Text(
                          'Use Current Location',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        subtitle:
                            _isLoadingLocation
                                ? const Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blue,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Getting your location...',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ],
                                )
                                : Text(
                                  _currentAddress.isNotEmpty
                                      ? _currentAddress
                                      : 'Tap to get your current location',
                                  style: TextStyle(
                                    color: Colors.blue.withOpacity(0.8),
                                  ),
                                ),
                        onTap: () async {
                          await _getCurrentLocation();
                          setState(() {
                            _searchController.clear();
                            _suggestions = [];
                            _isSearching = false;
                          });
                        },
                      ),
                    ),
                    // Existing suggestions
                    ..._suggestions.asMap().entries.map((entry) {
                      int index = entry.key;
                      var suggestion = entry.value;
                      return ListTile(
                        leading: const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                        ),
                        title: Text(
                          suggestion['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          suggestion['address']?.toString() ??
                              'Unknown Address',
                        ),
                        onTap: () {
                          _searchController.text =
                              suggestion['name']?.toString() ?? '';
                          setState(() {
                            _currentPosition = LatLng(
                              suggestion['lat'] is double
                                  ? suggestion['lat']
                                  : double.tryParse(
                                        suggestion['lat'].toString(),
                                      ) ??
                                      0.0,
                              suggestion['lng'] is double
                                  ? suggestion['lng']
                                  : double.tryParse(
                                        suggestion['lng'].toString(),
                                      ) ??
                                      0.0,
                            );
                            _currentAddress =
                                suggestion['address']?.toString() ?? '';
                            _suggestions = [];
                            _isSearching = false;
                          });
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(_currentPosition!, 15),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: ElevatedButton(
              onPressed: () {
                if (_currentPosition != null) {
                  Navigator.pop(context, {
                    'address': _currentAddress,
                    'lat': _currentPosition!.latitude,
                    'lng': _currentPosition!.longitude,
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a location')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(255, 130, 16, 1),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                'Confirm Location',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
