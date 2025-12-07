// lib/screens/property_listings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart'; 
import 'add_property_screen.dart';
import 'filter_search_screen.dart'; 
import 'property_details_screen.dart'; 
import '../models/property_model.dart'; 
import 'wishlist_screen.dart'; // <--- WISHlist IMPORT ADDED

class PropertyListingsScreen extends StatefulWidget {
  const PropertyListingsScreen({super.key});

  @override
  State<PropertyListingsScreen> createState() => _PropertyListingsScreenState();
}

class _PropertyListingsScreenState extends State<PropertyListingsScreen> {
  
  final _firestore = FirebaseFirestore.instance;

  // --- FILTER STATE ---
  String _selectedType = 'All';
  int _minPrice = 0;
  int _maxPrice = 9999999; 
  // --------------------

  void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // Receives filters from FilterSearchScreen
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

  // --- Dynamic Firestore Query ---
  Stream<QuerySnapshot> _getPropertyStream() {
    Query query = _firestore.collection('listings');

    // 1. Filter by Property Type
    if (_selectedType != 'All') {
      query = query.where('type', isEqualTo: _selectedType);
    }
    
    // 2. Filter by Minimum Price
    if (_minPrice > 0) {
      query = query.where('price', isGreaterThanOrEqualTo: _minPrice);
    }

    // 3. Filter by Maximum Price 
    if (_maxPrice < 9999999) {
      query = query.where('price', isLessThanOrEqualTo: _maxPrice);
    }

    // 4. Order by Timestamp (Requires Firestore Index)
    query = query.orderBy('timestamp', descending: true);
    
    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Pulse'),
        actions: [
          // 1. Wishlist Button (ADDED HERE)
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'My Wishlist',
            onPressed: () => _navigateToScreen(
              context, 
              const WishlistScreen(), 
            ),
          ),
          
          // 2. Filter/Search Button
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Listings',
            onPressed: _navigateToFilterScreen,
          ),
          
          // 3. Add Property Button
          IconButton(
            icon: const Icon(Icons.add_home_work),
            tooltip: 'Add New Property',
            onPressed: () => _navigateToScreen(
              context, 
              const AddPropertyScreen(), 
            ),
          ),
          
          // 4. Profile Button
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

          if (propertyDocs.isEmpty) {
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
                    // Show Reset button if filters are active
                    if (_selectedType != 'All' || _minPrice > 0 || _maxPrice < 9999999)
                      TextButton(
                        onPressed: () => _applyFilters('All', 0, 9999999),
                        child: const Text('Reset Filters'),
                      )
                  ],
                ),
              ),
            );
          }

          // --- Data Display State ---
          return ListView.builder(
            itemCount: propertyDocs.length,
            itemBuilder: (context, index) {
              
              // Retrieve property data safely using the model
              final property = PropertyModel.fromDocument(propertyDocs[index]); 
              
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
                  
                  // --- Navigation to Details Screen ---
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