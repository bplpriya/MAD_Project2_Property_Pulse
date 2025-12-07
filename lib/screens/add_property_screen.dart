// lib/screens/add_property_screen.dart

import 'package:flutter/material.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  // Form Key for validation
  final _formKey = GlobalKey<FormState>();

  // Text Controllers for form fields
  final _titleController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController(); // Stored as integer
  final _descriptionController = TextEditingController();
  
  // State for the selected property type
  String? _selectedType = 'Apartment'; 

  // List of property types for the dropdown
  final List<String> _propertyTypes = [
    'Apartment', 
    'House', 
    'Condo', 
    'Land', 
    'Commercial'
  ];

  // Helper function for the submission logic (Currently placeholder)
  void _submitProperty() {
    if (_formKey.currentState!.validate()) {
      // Form is valid, proceed with submission logic
      
      final propertyData = {
        'title': _titleController.text.trim(),
        'address': _addressController.text.trim(),
        // Renamed key to 'price' and parsing as int
        'price': int.tryParse(_priceController.text.trim()) ?? 0, 
        'description': _descriptionController.text.trim(),
        'type': _selectedType,
        // TODO: Add sellerId (from current user) and timestamp here
      };

      // Show a temporary success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Property Submitted: ${_titleController.text.trim()}'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back after successful submission
      Navigator.of(context).pop();
    }
  }

  // Dispose controllers to prevent memory leaks
  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                decoration: const InputDecoration(
                  labelText: 'Listing Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title for your listing';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- 2. Property Type Dropdown ---
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Property Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
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
                validator: (value) {
                  if (value == null) {
                    return 'Please select a property type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- 3. Address ---
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Full Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the property address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- 4. Price (Simplified) ---
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration( // Removed suffixText
                  labelText: 'Price', // Simplified label
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monetization_on),
                  hintText: 'e.g., 5000',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  // Validation remains the same (ensures it's a positive integer)
                  if (int.tryParse(value) == null || int.parse(value)! <= 0) {
                    return 'Price must be a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- 5. Description ---
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // --- Submit Button ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitProperty,
                  icon: const Icon(Icons.cloud_upload, size: 24),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Submit Listing', style: TextStyle(fontSize: 18)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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