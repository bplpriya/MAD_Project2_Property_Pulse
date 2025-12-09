// lib/screens/property_comparison_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/property_model.dart';

class PropertyComparisonScreen extends StatefulWidget {
  const PropertyComparisonScreen({super.key});

  @override
  State<PropertyComparisonScreen> createState() => _PropertyComparisonScreenState();
}

class _PropertyComparisonScreenState extends State<PropertyComparisonScreen> {
  final _firestore = FirebaseFirestore.instance;
  
  List<PropertyModel> _availableProperties = [];
  List<PropertyModel> _selectedProperties = [];
  bool _isLoading = true; 

  @override
  void initState() {
    super.initState();
    _loadAvailableProperties();
  }
  
  Future<void> _loadAvailableProperties() async {
    try {
      final snapshot = await _firestore.collection('listings').orderBy('timestamp', descending: true).get();
      
      final loadedProperties = snapshot.docs
          .map((doc) => PropertyModel.fromDocument(doc))
          .toList();
          
      if (mounted) {
        setState(() {
          _availableProperties = loadedProperties;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading properties for comparison: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startComparison() {
    if (_selectedProperties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one property to compare.')),
      );
    }
  }
  
  void _togglePropertySelection(PropertyModel property, bool isSelected) {
    setState(() {
      if (isSelected) {
        if (_selectedProperties.length < 3) {
          _selectedProperties.add(property);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum of 3 properties can be selected for comparison.')),
          );
        }
      } else {
        _selectedProperties.removeWhere((p) => p.id == property.id);
      }
    });
  }


  Widget _buildPropertySelectionList() {
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(30.0),
        child: CircularProgressIndicator(),
      ));
    }
    
    if (_availableProperties.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(30.0),
        child: Text('No properties available to compare.'),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select up to 3 properties (${_selectedProperties.length}/3):',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        
        // Constrain the list height to prevent infinite sizing conflict
        Container(
          constraints: BoxConstraints(
            // Set max height to 45% of the screen height
            maxHeight: MediaQuery.of(context).size.height * 0.45, 
          ),
          child: ListView.builder(
            // Use ListView.builder to handle the list efficiently
            shrinkWrap: true,
            // Use clamping physics to handle nested scrolling properly
            physics: const ClampingScrollPhysics(), 
            itemCount: _availableProperties.length,
            itemBuilder: (context, index) {
              final property = _availableProperties[index];
              final isSelected = _selectedProperties.contains(property);
              
              return CheckboxListTile(
                title: Text(property.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('\$${property.price} - ${property.address}', maxLines: 1, overflow: TextOverflow.ellipsis),
                value: isSelected,
                onChanged: (bool? value) {
                  if (value != null) {
                    _togglePropertySelection(property, value);
                  }
                },
                enabled: isSelected || _selectedProperties.length < 3,
              );
            },
          ),
        ),
      ],
    );
  }

  // NEW: Dedicated cell builder for images
  Widget _buildImageCell(String? imageUrl, Color color) {
    const double size = 60.0;
    
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
        color: color,
      ),
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: imageUrl != null && imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                  ),
                )
              : const Icon(Icons.house, size: 30, color: Colors.blueGrey),
        ),
      ),
    );
  }

  Widget _buildComparisonCell(String header, String? value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
        color: color,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header.isNotEmpty)
            Text(
              header,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color == Colors.white ? Colors.black : Colors.black),
            ),
          if (header.isNotEmpty) const SizedBox(height: 4),
          Text(
            value ?? 'N/A',
            style: TextStyle(
              fontSize: 14,
              fontStyle: value == 'N/A' ? FontStyle.italic : FontStyle.normal,
              color: color == Colors.white ? Colors.black : Colors.black,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(String label, List<String?> values, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...values.map((value) => _buildComparisonCell('', value, Colors.white)).toList(),
      ],
    );
  }

  // NEW: Dedicated row builder for images
  Widget _buildImageRow(List<String?> imageUrls, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: const Text(
            'Image',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...imageUrls.map((url) => _buildImageCell(url, Colors.white)).toList(),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    List<PropertyModel?> validProperties = _selectedProperties.where((p) => p != null).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Comparison'),
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Selection List ---
            _buildPropertySelectionList(),
            
            const SizedBox(height: 20),

            // --- Comparison Output Table ---
            if (validProperties.isNotEmpty)
              Text(
                'Comparison Results (${validProperties.length} selected):',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            if (validProperties.isNotEmpty)
              const Divider(),
              
            if (validProperties.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    // Header Row (Titles)
                    Row(
                      children: [
                        Container(width: 120, padding: const EdgeInsets.all(8), color: Colors.grey.shade100, child: const Text('Feature', style: const TextStyle(fontWeight: FontWeight.bold))),
                        // Map over selected properties for the header
                        ...validProperties.map((p) => _buildComparisonCell(
                          '', 
                          p!.title, 
                          Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        )).toList(),
                        // Fill remaining columns with empty placeholders
                        ...List.generate(3 - validProperties.length, (index) => Container(width: 150, padding: const EdgeInsets.all(8), color: Colors.grey.shade100, child: const Text(''))),
                      ],
                    ),
                    const Divider(height: 0),
                    
                    // NEW ROW: Image
                    _buildImageRow(validProperties.map((p) => p!.imageUrl).toList(), Colors.grey.shade50), 

                    // Comparison Rows (rest of the data)
                    _buildPropertyRow('Listing ID', validProperties.map((p) => p!.id).toList(), Colors.white), 
                    _buildPropertyRow('Price', validProperties.map((p) => '\$${p!.price}').toList(), Colors.grey.shade50),
                    _buildPropertyRow('Type', validProperties.map((p) => p!.type).toList(), Colors.white),
                    _buildPropertyRow('Address', validProperties.map((p) => p!.address).toList(), Colors.grey.shade50),
                    _buildPropertyRow('Description', validProperties.map((p) => p!.description).toList(), Colors.white),
                    _buildPropertyRow('Seller ID', validProperties.map((p) => p!.sellerId).toList(), Colors.grey.shade50),
                    _buildPropertyRow('Listing Date', validProperties.map((p) => p!.timestamp.toDate().toString().split(' ')[0]).toList(), Colors.white),
                  ],
                ),
              ),

            if (_selectedProperties.isEmpty && !_isLoading && _availableProperties.isNotEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50.0),
                  child: Text('Select properties from the list above to view the comparison table.'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}