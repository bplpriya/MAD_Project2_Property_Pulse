// lib/screens/property_listings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart'; 
import 'add_property_screen.dart';
import 'filter_search_screen.dart'; 
import 'property_details_screen.dart'; 
import '../models/property_model.dart'; 
import 'wishlist_screen.dart'; 
import 'property_comparison_screen.dart';

class PropertyListingsScreen extends StatefulWidget {
  const PropertyListingsScreen({super.key});

  @override
  State<PropertyListingsScreen> createState() => _PropertyListingsScreenState();
}

class _PropertyListingsScreenState extends State<PropertyListingsScreen> {
  
  final _firestore = FirebaseFirestore.instance;

  String _selectedType = 'All';
  int _minPrice = 0;
  int _maxPrice = 999999999; // UPDATED DEFAULT MAX PRICE

  void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _applyFilters(String type, int minPrice, int maxPrice) {
    setState(() {
      _selectedType = type;
      _minPrice = minPrice;
      _maxPrice = maxPrice;
    });
  }

  void _navigateToFilterScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FilterSearchScreen(
          onApplyFilters: _applyFilters,
          initialType: _selectedType,
          initialMinPrice: _minPrice,
          initialMaxPrice: _maxPrice,
        ),
      ),
    );
  }

  // MODIFIED: Simplified Query for Firestore
  Stream<QuerySnapshot> _getPropertyStream() {
    Query query = _firestore.collection('listings');

    // Check if a price inequality filter is active
    bool isPriceFilterActive = _minPrice > 0 || _maxPrice < 999999999; // UPDATED DEFAULT MAX PRICE

    // We DO NOT filter by Property Type here (Client-side filtering below handles this)
    
    // 1. Filter by Price Range (Inequality Filters)
    if (_minPrice > 0) {
      // Must be the first inequality or orderBy field
      query = query.where('price', isGreaterThanOrEqualTo: _minPrice);
    }

    if (_maxPrice < 999999999) { // UPDATED DEFAULT MAX PRICE
      query = query.where('price', isLessThanOrEqualTo: _maxPrice);
    }

    // 2. APPLY ORDERING: Simplified Logic
    if (isPriceFilterActive) {
      // Must order by price when price inequality filter is present (Firestore rule)
      query = query.orderBy('price', descending: false); 
    } else {
      // If ONLY price filter is not active, we can order by timestamp.
      query = query.orderBy('timestamp', descending: true);
    }
    
    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Pulse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Compare Properties',
            onPressed: () => _navigateToScreen(
              context, 
              const PropertyComparisonScreen(), 
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'My Wishlist',
            onPressed: () => _navigateToScreen(
              context, 
              const WishlistScreen(), 
            ),
          ),
          
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Listings',
            onPressed: _navigateToFilterScreen,
          ),
          
          IconButton(
            icon: const Icon(Icons.add_home_work),
            tooltip: 'Add New Property',
            onPressed: () => _navigateToScreen(
              context, 
              const AddPropertyScreen(), 
            ),
          ),
          
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => _navigateToScreen(
              context, 
              const ProfileScreen(), 
            ),
          ),
        ],
      ),
      
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPropertyStream(),
        
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading listings: ${snapshot.error}'));
          }

          final propertyDocs = snapshot.data?.docs ?? [];
          
          // Client-Side filtering by property type
          List<PropertyModel> filteredProperties = propertyDocs
            .map((doc) => PropertyModel.fromDocument(doc))
            .where((property) {
              // Apply the Type filter ONLY here (client-side)
              if (_selectedType == 'All') {
                return true;
              }
              return property.type == _selectedType;
            }).toList();

          if (filteredProperties.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'No properties match your current filters.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    if (_selectedType != 'All' || _minPrice > 0 || _maxPrice < 999999999) // UPDATED DEFAULT MAX PRICE
                      TextButton(
                        onPressed: () => _applyFilters('All', 0, 999999999), // UPDATED DEFAULT MAX PRICE
                        child: const Text('Reset Filters'),
                      )
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredProperties.length, // Use the new filtered list
            itemBuilder: (context, index) {
              
              final property = filteredProperties[index]; // Use the filtered model
              
              final title = property.title;
              final price = property.price.toString();
              final address = property.address;
              final imageUrl = property.imageUrl ?? '';
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                elevation: 3,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  
                  leading: SizedBox(
                    width: 80,
                    height: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.image_not_supported, color: Colors.grey);
                              },
                            )
                          : const Icon(Icons.house, size: 40, color: Colors.blueGrey),
                    ),
                  ),

                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(address, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        'Type: ${property.type}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$$price',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const Text('Price', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => PropertyDetailsScreen(property: property),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}