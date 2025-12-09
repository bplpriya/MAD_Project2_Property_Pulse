// lib/screens/add_property_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // NEW
import 'package:geolocator/geolocator.dart'; 
import 'package:image_picker/image_picker.dart'; // NEW
import 'dart:io'; // NEW

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance; // NEW Storage instance

  // Property detail controllers
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  // REMOVED: _imageUrlController

  // Location controllers
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
  String? _selectedType;
  File? _selectedImage; // NEW: Holds the selected image file
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
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  // --- Image Picker Logic ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // --- Firebase Upload Logic ---
  Future<String?> _uploadImage(File imageFile, String propertyId) async {
    try {
      final ref = _storage.ref().child('property_images').child('$propertyId.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: ${e.message}')),
      );
      return null;
    }
  }

  // --- Location Tagging Logic (Unchanged) ---
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception('Location permissions are required.');
        }
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);

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

    if (!_formKey.currentState!.validate() || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_selectedImage == null ? 'Please select an image for the property.' : 'Please fix the form errors.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    String? imageUrl;
    
    try {
      // 1. Create a document reference first to get a unique ID
      final newDocRef = _firestore.collection('listings').doc();
      final propertyId = newDocRef.id;

      // 2. Upload image and get URL
      imageUrl = await _uploadImage(_selectedImage!, propertyId);

      if (imageUrl == null) {
        throw Exception("Failed to get image URL after upload.");
      }
      
      // 3. Save property data with the new URL
      final propertyData = {
        'title': _titleController.text,
        'price': int.parse(_priceController.text),
        'type': _selectedType,
        'address': _addressController.text,
        'description': _descriptionController.text,
        'imageUrl': imageUrl, // Using uploaded URL
        'sellerId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': double.tryParse(_latitudeController.text), 
        'longitude': double.tryParse(_longitudeController.text),
        'isRemoved': false,
        'flagCount': 0,
      };

      await newDocRef.set(propertyData);

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

  // --- UI Builder Methods (Unchanged except for Image URL field replacement) ---

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
              const SizedBox(height: 30),
              
              // --- Image Upload Section (Replaced URL Field) ---
              Text(
                'Property Image',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: Text(_selectedImage == null ? 'Select Image from Gallery' : 'Image Selected (Change)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(
                      color: _selectedImage != null ? Colors.green : primaryColor, 
                      width: 1.5
                    ),
                    foregroundColor: _selectedImage != null ? Colors.green : primaryColor,
                  ),
                ),
              ),
              
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 30),

              // --- Location Tagging Section (Unchanged) ---
              Text(
                'Location',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: _inputDecoration('Latitude', icon: Icons.pin_drop),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isNotEmpty && double.tryParse(value) == null ? 'Valid number needed' : null,
                    ),
                  ),
                  const SizedBox(width: 16),

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
                    side: BorderSide(color: primaryColor, width: 1.5),
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