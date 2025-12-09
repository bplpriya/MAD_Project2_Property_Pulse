// lib/screens/filter_search_screen.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; 

class FilterSearchScreen extends StatefulWidget {
  // UPDATED CALLBACK SIGNATURE: Includes location data
  final Function(String type, int minPrice, int maxPrice, double? lat, double? lng, double radiusKm) onApplyFilters;
  
  final String initialType;
  final int initialMinPrice;
  final int initialMaxPrice;
  final double? initialLat; 
  final double? initialLng; 
  final double initialRadiusKm; 

  const FilterSearchScreen({
    super.key,
    required this.onApplyFilters,
    this.initialType = 'All',
    this.initialMinPrice = 0,
    this.initialMaxPrice = 999999999, 
    this.initialLat,
    this.initialLng,
    this.initialRadiusKm = 5.0, // Default to 5 km radius
  });

  @override
  State<FilterSearchScreen> createState() => _FilterSearchState();
}

class _FilterSearchState extends State<FilterSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  String? _selectedType;
  double? _userLatitude; 
  double? _userLongitude; 
  double _selectedRadiusKm = 5.0; // State for radius
  bool _isLocating = false;

  final List<String> _propertyTypes = [
    'All',
    'Apartment', 
    'House', 
    'Condo', 
    'Land', 
    'Commercial'
  ];
  
  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _minPriceController.text = widget.initialMinPrice.toString();
    _maxPriceController.text = widget.initialMaxPrice.toString(); 
    
    _userLatitude = widget.initialLat;
    _userLongitude = widget.initialLng;
    // Ensure initial radius is handled correctly, defaulting to 5.0 if needed.
    _selectedRadiusKm = widget.initialRadiusKm;
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception('Location permissions are required for proximity filtering.');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low
      );

      if (mounted) {
        setState(() {
          _userLatitude = position.latitude;
          _userLongitude = position.longitude;
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location tagged.')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  void _applyFilters() {
    if (_formKey.currentState!.validate()) {
      final minPrice = int.tryParse(_minPriceController.text) ?? 0;
      final maxPrice = _maxPriceController.text.isEmpty
          ? 999999999
          : int.tryParse(_maxPriceController.text) ?? 999999999; 

      if (minPrice > maxPrice) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minimum price cannot be greater than maximum price.')),
        );
        return;
      }

      // CALL UPDATED CALLBACK
      widget.onApplyFilters(
        _selectedType ?? 'All', 
        minPrice, 
        maxPrice,
        _userLatitude,
        _userLongitude,
        _selectedRadiusKm,
      );
      
      Navigator.pop(context);
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedType = 'All';
      _minPriceController.text = '0';
      _maxPriceController.text = '999999999';
      
      // Reset Location Filters
      _userLatitude = null;
      _userLongitude = null;
      _selectedRadiusKm = 5.0; // Reset to default radius
    });
    
    // CALL UPDATED CALLBACK with null/default values
    widget.onApplyFilters('All', 0, 999999999, null, null, 5.0);
    Navigator.pop(context);
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      prefixIcon: icon != null ? Icon(icon, color: primaryColor) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Listings', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1.0), child: Container(color: Colors.grey.shade200, height: 1.0)),
        actions: [
          TextButton(
            onPressed: _resetFilters,
            child: const Text('Reset', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Property Type Filter (Existing) ---
              Text(
                'Property Type',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                decoration: _inputDecoration('Select Type').copyWith(
                  prefixIcon: Icon(Icons.category, color: primaryColor),
                  labelText: 'Property Type'
                ),
                value: _selectedType,
                items: _propertyTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a type' : null,
              ),
              const SizedBox(height: 30),
              
              // --- 2. Location Radius Filter (NEW Slider UI) ---
              Text(
                'Filter by Location Radius',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 15),
              
              // Use Current Location Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLocating ? null : _getCurrentLocation,
                  icon: _isLocating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(_isLocating 
                      ? 'Locating...' 
                      : (_userLatitude != null ? 'Location Tagged (Lat: ${_userLatitude!.toStringAsFixed(2)})' : 'Use Current GPS Location'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(
                      color: _userLatitude != null ? Colors.green : primaryColor, 
                      width: 1.5
                    ),
                    foregroundColor: _userLatitude != null ? Colors.green : primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Radius Selector (Slider)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Search Radius',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      Text(
                        '${_selectedRadiusKm.toStringAsFixed(0)} km',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor),
                      ),
                    ],
                  ),
                  Slider(
                    value: _selectedRadiusKm,
                    min: 1, // Minimum 1 km
                    max: 50, // Maximum 50 km
                    divisions: 49, // Allows 1 km increments
                    label: '${_selectedRadiusKm.toStringAsFixed(0)} km',
                    onChanged: (double value) {
                      setState(() {
                        _selectedRadiusKm = value;
                      });
                    },
                    activeColor: primaryColor,
                    inactiveColor: primaryColor.withOpacity(0.3),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),

              // --- 3. Price Range Filters (Existing) ---
              Text(
                'Price Range',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 15),
              
              TextFormField(
                controller: _minPriceController,
                decoration: _inputDecoration('Minimum Price'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                    return 'Must be a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _maxPriceController,
                decoration: _inputDecoration('Maximum Price'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                    return 'Must be a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // --- Apply Button (Existing) ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.filter_alt, size: 22),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('Apply Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
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