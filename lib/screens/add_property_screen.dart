// lib/screens/add_property_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; 
import 'package:geolocator/geolocator.dart'; // REQUIRED for location tagging
import '../models/property_model.dart';

// --- Cloudinary Config ---
const String CLOUDINARY_CLOUD_NAME = 'dvdfvxphf';
const String CLOUDINARY_UPLOAD_PRESET = 'flutter_upload';
final String CLOUDINARY_URL =
    'https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  // Property detail controllers
  final _titleController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController(); 
  final _descriptionController = TextEditingController();
  
  // NEW LOCATION CONTROLLERS
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
  String? _selectedType = 'Apartment'; 

  File? _imageFile;
  Uint8List? _webImage;
  bool _isLoading = false;
  bool _isLocating = false; // NEW state for GPS locator

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
    _addressController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose(); // Dispose location controllers
    _longitudeController.dispose(); // Dispose location controllers
    super.dispose();
  }

  // --- LOCATION TAGGING LOGIC ---
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

      if (mounted) {
        setState(() {
          _latitudeController.text = position.latitude.toString();
          _longitudeController.text = position.longitude.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location tagged successfully.')),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  // --- IMAGE PICKER & CLOUDINARY UPLOAD LOGIC (Unchanged) ---
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      setState(() => _webImage = bytes);
    } else {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<String?> _uploadImageToCloudinary() async {
    if (_imageFile == null && _webImage == null) return null;
    
    try {
      final request = http.MultipartRequest('POST', Uri.parse(CLOUDINARY_URL));
      request.fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET;

      if (kIsWeb && _webImage != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _webImage!,
            filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      } else if (!kIsWeb && _imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('file', _imageFile!.path));
      } else {
        return null;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['secure_url'];
      } else {
        print('Cloudinary Error: ${response.statusCode} - ${response.body}'); 
        return null;
      }
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }

  // --- SUBMISSION LOGIC (Updated to include location) ---
  void _submitProperty() async {
    if (_imageFile == null && _webImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a property image.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Upload image
      final imageUrl = await _uploadImageToCloudinary();
      if (imageUrl == null) {
        throw Exception('Failed to upload image to Cloudinary.');
      }
      
      // 2. Safely parse location fields (Handle empty string to null conversion)
      final double? parsedLat = _latitudeController.text.trim().isEmpty 
          ? null 
          : double.tryParse(_latitudeController.text);
          
      final double? parsedLng = _longitudeController.text.trim().isEmpty 
          ? null 
          : double.tryParse(_longitudeController.text);

      // 3. Create model and submit to Firestore
      // NOTE: We assume PropertyModel.toMap() handles the null/default fields (isRemoved, flagCount)
      final newPropertyData = {
        'id': '',
        'title': _titleController.text.trim(),
        'address': _addressController.text.trim(),
        'type': _selectedType!,
        'price': int.tryParse(_priceController.text.trim()) ?? 0, 
        'description': _descriptionController.text.trim(),
        'imageUrl': imageUrl, 
        'sellerId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'timestamp': Timestamp.now(),
        // ADDED LOCATION DATA
        'latitude': parsedLat, 
        'longitude': parsedLng,
        'isRemoved': false,
        'flagCount': 0,
      };

      await FirebaseFirestore.instance.collection('listings').add(newPropertyData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_titleController.text} listed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop();
      }

    } catch (e) {
      // Log the error for debugging
      print('SUBMISSION FAILED: $e'); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save property: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI Builder Methods ---

  InputDecoration _customInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)), 
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      labelStyle: const TextStyle(color: Colors.black54),
      prefixIcon: icon != null ? Icon(icon, color: Theme.of(context).colorScheme.primary) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Property Listing"),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Property Details Fields ---
              TextFormField(
                controller: _titleController,
                decoration: _customInputDecoration('Listing Title', icon: Icons.title),
                validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                decoration: _customInputDecoration('Property Type', icon: Icons.category),
                value: _selectedType,
                items: _propertyTypes.map((String type) {
                  return DropdownMenuItem<String>(value: type, child: Text(type));
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedType = newValue);
                },
                validator: (value) => value == null ? 'Please select a type' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _addressController,
                decoration: _customInputDecoration('Full Address', icon: Icons.location_on_outlined),
                validator: (value) => value!.isEmpty ? 'Please enter the address' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _priceController,
                decoration: _customInputDecoration('Price', icon: Icons.monetization_on),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter a price';
                  if (int.tryParse(value) == null || int.parse(value)! <= 0) return 'Price must be a valid positive number';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _descriptionController,
                decoration: _customInputDecoration('Description', icon: Icons.description),
                maxLines: 4,
                validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
              ),
              
              const SizedBox(height: 30),
              const Divider(color: Colors.black12),
              const SizedBox(height: 20),

              // --- Image Section ---
              Text('Property Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 15),
              
              Center(
                child: Column(
                  children: [
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: (_imageFile == null && _webImage == null)
                          ? const Center(child: Text('No image selected.', style: TextStyle(color: Colors.grey)))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.memory(_webImage!, fit: BoxFit.cover)
                                  : Image.file(_imageFile!, fit: BoxFit.cover),
                            ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: Text((_imageFile != null || _webImage != null) ? 'Change Image' : 'Upload Image'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              const Divider(color: Colors.black12),
              const SizedBox(height: 20),

              // --- Location Tagging Section ---
              Text('Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 15),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: _customInputDecoration('Latitude', icon: Icons.pin_drop),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isNotEmpty && double.tryParse(value) == null ? 'Valid number needed' : null,
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: _customInputDecoration('Longitude', icon: Icons.pin_drop),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isNotEmpty && double.tryParse(value) == null ? 'Valid number needed' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLocating ? null : _getCurrentLocation,
                  icon: _isLocating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: Text(_isLocating ? 'Locating...' : 'Use Current GPS Location',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 40),
              
              // --- Submit Button ---
              ElevatedButton(
                onPressed: _isLoading ? null : _submitProperty,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: Colors.green.shade600, 
                  foregroundColor: Colors.white, 
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Listing',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}