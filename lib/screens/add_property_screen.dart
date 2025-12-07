// lib/screens/add_property_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb; // Needed for platform check
import 'package:flutter/material.dart';
// NOTE: These are imported to allow the methods to compile, assuming you have the packages
import 'package:image_picker/image_picker.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; 

// --- Cloudinary Config (Copied from reference file) ---
const String CLOUDINARY_CLOUD_NAME = 'dvdfvxphf';
const String CLOUDINARY_UPLOAD_PRESET = 'flutter_upload';
final String CLOUDINARY_URL =
    'https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload';
// ----------------------------------------------------

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController(); 
  final _descriptionController = TextEditingController();
  
  String? _selectedType = 'Apartment'; 

  // --- Image Upload State (Single Image Logic from reference) ---
  File? _imageFile;
  Uint8List? _webImage;
  bool _isLoading = false;
  // Removed location logic/state variables
  // -----------------------------------------------------------

  final List<String> _propertyTypes = [
    'Apartment', 
    'House', 
    'Condo', 
    'Land', 
    'Commercial'
  ];

  // --- Image Picker (Copied from reference file) ---
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

  // --- Cloudinary Upload (Copied from reference file) ---
  Future<String?> _uploadImageToCloudinary() async {
    // Check if an image is selected before proceeding
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
        // Log the error for debugging
        print('Cloudinary Error: ${response.statusCode} - ${response.body}'); 
        return null;
      }
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }

  // --- Submission Logic (Modified to use Cloudinary and Firestore) ---
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
      // 1. Upload Image
      final imageUrl = await _uploadImageToCloudinary();
      if (imageUrl == null) {
        throw Exception('Failed to upload image to Cloudinary.');
      }

      // 2. Prepare Data
      final propertyData = {
        'title': _titleController.text.trim(),
        'address': _addressController.text.trim(),
        'price': int.tryParse(_priceController.text.trim()) ?? 0, 
        'description': _descriptionController.text.trim(),
        'type': _selectedType,
        'imageUrl': imageUrl, // Store the single image URL
        'sellerId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 3. Save to Firestore (Using 'listings' collection)
      await FirebaseFirestore.instance.collection('listings').add(propertyData);

      // 4. Success feedback and navigation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Property Listing created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop();

    } catch (e) {
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

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- UI Build Method (Replaced Image Section with Single Image UI) ---
  @override
  Widget build(BuildContext context) {
    const inputDecoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)), 
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      labelStyle: TextStyle(color: Colors.black54),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Property Listing"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Property Title ---
              TextFormField(
                controller: _titleController,
                decoration: inputDecoration.copyWith(labelText: 'Listing Title', prefixIcon: const Icon(Icons.title)),
                validator: (value) => value!.isEmpty ? 'Please enter a title for your listing' : null,
              ),
              const SizedBox(height: 20),

              // --- 2. Property Type Dropdown ---
              DropdownButtonFormField<String>(
                decoration: inputDecoration.copyWith(labelText: 'Property Type', prefixIcon: const Icon(Icons.category)),
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
                validator: (value) => value == null ? 'Please select a property type' : null,
              ),
              const SizedBox(height: 20),

              // --- 3. Address ---
              TextFormField(
                controller: _addressController,
                decoration: inputDecoration.copyWith(labelText: 'Full Address', prefixIcon: const Icon(Icons.location_on_outlined)),
                validator: (value) => value!.isEmpty ? 'Please enter the property address' : null,
              ),
              const SizedBox(height: 20),

              // --- 4. Price ---
              TextFormField(
                controller: _priceController,
                decoration: inputDecoration.copyWith(labelText: 'Price', prefixIcon: const Icon(Icons.monetization_on), hintText: 'e.g., 5000'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter a price';
                  if (int.tryParse(value) == null || int.parse(value)! <= 0) return 'Price must be a valid positive number';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- 5. Description ---
              TextFormField(
                controller: _descriptionController,
                decoration: inputDecoration.copyWith(labelText: 'Description', prefixIcon: const Icon(Icons.description)),
                maxLines: 4,
                validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
              ),
              
              const SizedBox(height: 30),
              const Divider(color: Colors.black12),
              const SizedBox(height: 20),

              // --- 6. Image Upload UI (From reference file) ---
              Text('Property Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
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
                      child: _imageFile == null && _webImage == null
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
                      label: const Text('Upload Image'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
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