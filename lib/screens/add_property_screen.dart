// lib/screens/add_property_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; // Required for location tagging

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Property detail controllers
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();

  // Location controllers 
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
  String? _selectedType;
  bool _isSaving = false;
  bool _isLocating = false;

  final List<String> _propertyTypes = [
    'Apartment', 
    'House', 
    'Condo', 
    'Land', 
    'Commercial'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  // --- Location Tagging Logic ---
  
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      // 1. Check for location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception('Location permissions are required to tag location.');
        }
      }

      // 2. Fetch position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium
      );

      // 3. Update controllers
      _latitudeController.text = position.latitude.toString();
      _longitudeController.text = position.longitude.toString();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location tagged successfully.')),
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
  
  // --- Form Submission Logic ---

  Future<void> _submitForm() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add a property.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final propertyData = {
        'title': _titleController.text,
        'price': int.parse(_priceController.text),
        'type': _selectedType,
        'address': _addressController.text,
        'description': _descriptionController.text,
        'imageUrl': _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text,
        'sellerId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': double.tryParse(_latitudeController.text), 
        'longitude': double.tryParse(_longitudeController.text),
        'isRemoved': false,
        'flagCount': 0,
      };

      await _firestore.collection('listings').add(propertyData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property added successfully!')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add property: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // --- UI Builder Methods ---

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Property', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1.0), child: Container(color: Colors.grey.shade200, height: 1.0)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // --- Property Details ---
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration('Title', icon: Icons.title),
                validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _priceController,
                decoration: _inputDecoration('Price', icon: Icons.attach_money),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty || int.tryParse(value) == null ? 'Enter a valid price' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: _inputDecoration('Property Type', icon: Icons.category),
                items: _propertyTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) => setState(() => _selectedType = value),
                validator: (value) => value == null ? 'Please select a type' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: _inputDecoration('Address / Location', icon: Icons.location_city),
                validator: (value) => value!.isEmpty ? 'Please enter the address' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration('Description', icon: Icons.description),
                maxLines: 4,
                validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _imageUrlController,
                decoration: _inputDecoration('Image URL (Optional)', icon: Icons.image),
              ),
              const SizedBox(height: 30),

              // --- Location Tagging Section ---
              Text(
                'Location', // UPDATED TITLE
                style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              
              // Grouped Latitude and Longitude Fields
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Latitude Input
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: _inputDecoration('Latitude', icon: Icons.pin_drop),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isNotEmpty && double.tryParse(value) == null ? 'Valid number needed' : null,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Longitude Input
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: _inputDecoration('Longitude', icon: Icons.pin_drop),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isNotEmpty && double.tryParse(value) == null ? 'Valid number needed' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Get Location Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLocating ? null : _getCurrentLocation,
                  icon: _isLocating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: Text(_isLocating ? 'Locating...' : 'Use Current GPS Location',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // --- Submit Button ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submitForm,
                  icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.add_home),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      _isSaving ? 'Adding Property...' : 'Add Property', 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
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