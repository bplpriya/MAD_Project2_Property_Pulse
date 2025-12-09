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
  static const int MAX_COMPARISON_COUNT = 3;

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
    // This is now redundant but kept as a trigger placeholder
    if (_selectedProperties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one property to compare.')),
      );
    }
  }
  
  void _togglePropertySelection(PropertyModel property, bool isSelected) {
    setState(() {
      if (isSelected) {
        if (_selectedProperties.length < MAX_COMPARISON_COUNT) {
          _selectedProperties.add(property);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum of $MAX_COMPARISON_COUNT properties can be selected for comparison.')),
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
    
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select up to $MAX_COMPARISON_COUNT properties (${_selectedProperties.length}/$MAX_COMPARISON_COUNT):',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 15),
        
        Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45, 
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(), 
            itemCount: _availableProperties.length,
            itemBuilder: (context, index) {
              final property = _availableProperties[index];
              final isSelected = _selectedProperties.contains(property);
              
              return CheckboxListTile(
                title: Text(property.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('\$${property.price} - ${property.address}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600)),
                value: isSelected,
                activeColor: primaryColor,
                onChanged: (bool? value) {
                  if (value != null) {
                    _togglePropertySelection(property, value);
                  }
                },
                enabled: isSelected || _selectedProperties.length < MAX_COMPARISON_COUNT,
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Comparison Table Helper Widgets ---

  // NEW: Dedicated cell builder for images
  Widget _buildImageCell(String? imageUrl, Color color) {
    const double size = 70.0; // Increased size for better visibility
    
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
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                  ),
                )
              : const Icon(Icons.house, size: 40, color: Colors.blueGrey),
        ),
      ),
    );
  }

  Widget _buildComparisonCell(String header, String? value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), // Increased padding
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
              color: color == Colors.white ? Colors.black87 : Colors.black87,
            ),
            maxLines: 4,
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10), // Increased padding
          decoration: BoxDecoration(
            color: color,
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
        ...values.map((value) => _buildComparisonCell('', value, Colors.white)).toList(),
      ],
    );
  }

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
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
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
        title: const Text('Property Comparison', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1.0), child: Container(color: Colors.grey.shade200, height: 1.0)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Selection List ---
            _buildPropertySelectionList(),
            
            const SizedBox(height: 30), // Increased spacing

            // --- Comparison Output Table ---
            if (validProperties.isNotEmpty)
              Text(
                'Comparison Results (${validProperties.length} selected):',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            if (validProperties.isNotEmpty)
              const Divider(thickness: 1.5),
              
            if (validProperties.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    // Header Row (Titles)
                    Row(
                      children: [
                        Container(width: 120, padding: const EdgeInsets.all(12), color: Theme.of(context).colorScheme.primary.withOpacity(0.1), child: const Text('Feature', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87))),
                        // Map over selected properties for the header
                        ...validProperties.map((p) => _buildComparisonCell(
                          '', 
                          p!.title, 
                          Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        )).toList(),
                        // Fill remaining columns with empty placeholders
                        ...List.generate(MAX_COMPARISON_COUNT - validProperties.length, (index) => Container(width: 150, padding: const EdgeInsets.all(12), color: Colors.grey.shade100, child: const Text(''))),
                      ],
                    ),
                    const Divider(height: 0),
                    
                    // Comparison Rows
                    _buildImageRow(validProperties.map((p) => p!.imageUrl).toList(), Colors.white), 
                    _buildPropertyRow('Listing ID', validProperties.map((p) => p!.id).toList(), Colors.grey.shade50), 
                    _buildPropertyRow('Price', validProperties.map((p) => '\$${p!.price}').toList(), Colors.white),
                    _buildPropertyRow('Type', validProperties.map((p) => p!.type).toList(), Colors.grey.shade50),
                    _buildPropertyRow('Address', validProperties.map((p) => p!.address).toList(), Colors.white),
                    _buildPropertyRow('Description', validProperties.map((p) => p!.description).toList(), Colors.grey.shade50),
                    _buildPropertyRow('Seller ID', validProperties.map((p) => p!.sellerId).toList(), Colors.white),
                    _buildPropertyRow('Listing Date', validProperties.map((p) => p!.timestamp.toDate().toString().split(' ')[0]).toList(), Colors.grey.shade50),
                  ],
                ),
              ),

            if (_selectedProperties.isEmpty && !_isLoading && _availableProperties.isNotEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50.0),
                  child: Text('Select properties from the list above to view the comparison table.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}