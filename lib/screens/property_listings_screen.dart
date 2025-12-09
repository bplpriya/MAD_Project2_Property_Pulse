// lib/screens/property_listings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; 
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
  int _maxPrice = 999999999; 
  
  double? _userLat;
  double? _userLng;
  double _radiusKm = 5.0; 

  void _navigateToScreen(BuildContext context, Widget screen) {
    // Closes the drawer before navigating
    Navigator.of(context).pop(); 
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // UPDATED CALLBACK SIGNATURE
  void _applyFilters(String type, int minPrice, int maxPrice, double? lat, double? lng, double radiusKm) {
    setState(() {
      _selectedType = type;
      _minPrice = minPrice;
      _maxPrice = maxPrice;
      
      // Update Location State
      _userLat = lat;
      _userLng = lng;
      _radiusKm = radiusKm;
    });
  }

  void _navigateToFilterScreen() {
    // Closes the drawer before navigating
    Navigator.of(context).pop(); 
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FilterSearchScreen(
          onApplyFilters: _applyFilters,
          initialType: _selectedType,
          initialMinPrice: _minPrice,
          initialMaxPrice: _maxPrice,
          
          // Pass current location state to filter screen
          initialLat: _userLat,
          initialLng: _userLng,
          initialRadiusKm: _radiusKm,
        ),
      ),
    );
  }

  // Helper function for client-side filtering by distance
  bool _isWithinRadius(PropertyModel property) {
    if (_userLat == null || _userLng == null) {
      return true; // No location filter is active
    }
    
    // Check if the property has location data
    if (property.latitude == null || property.longitude == null) {
      return false; // Cannot filter properties without location data
    }
    
    // Calculate distance in meters
    final distanceMeters = Geolocator.distanceBetween(
      _userLat!,
      _userLng!,
      property.latitude!,
      property.longitude!,
    );
    
    final distanceKm = distanceMeters / 1000;
    
    // Check if distance is less than or equal to the selected radius
    return distanceKm <= _radiusKm;
  }


  Stream<QuerySnapshot> _getPropertyStream() {
    Query query = _firestore.collection('listings');

    // REMOVED: query = query.where('isRemoved', isEqualTo: false);
    // This filter is now applied on the client side below.

    // Check if a price inequality filter is active
    bool isPriceFilterActive = _minPrice > 0 || _maxPrice < 999999999; 

    // 1. Filter by Price Range (Inequality Filters)
    if (_minPrice > 0) {
      query = query.where('price', isGreaterThanOrEqualTo: _minPrice);
    }

    if (_maxPrice < 999999999) {
      query = query.where('price', isLessThanOrEqualTo: _maxPrice);
    }

    // 2. APPLY ORDERING: Simplified Logic
    if (isPriceFilterActive) {
      query = query.orderBy('price', descending: false); 
    } else {
      query = query.orderBy('timestamp', descending: true);
    }
    
    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Pulse', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0, 
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
      ),
      
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const SizedBox(
                width: double.infinity,
                child: Text(
                  'Navigation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () => _navigateToScreen(context, const ProfileScreen()),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_home_work),
              title: const Text('Add New Property'),
              onTap: () => _navigateToScreen(context, const AddPropertyScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.filter_list),
              title: const Text('Filter Listings'),
              onTap: _navigateToFilterScreen,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.compare_arrows),
              title: const Text('Compare Properties'),
              onTap: () => _navigateToScreen(context, const PropertyComparisonScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('My Wishlist'),
              onTap: () => _navigateToScreen(context, const WishlistScreen()),
            ),
          ],
        ),
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
          
          // Client-Side filtering: Type, Location, AND Moderation status
          List<PropertyModel> filteredProperties = propertyDocs
            .map((doc) => PropertyModel.fromDocument(doc))
            .where((property) {
              // 1. Apply Moderation filter (NEW: Client-side only)
              final isNotRemoved = !(property.isRemoved ?? false); // Assuming isRemoved is false by default
              
              // 2. Apply Type filter
              final typeMatches = (_selectedType == 'All') || (property.type == _selectedType);
              
              // 3. Apply Location filter
              final locationMatches = _isWithinRadius(property);
              
              return isNotRemoved && typeMatches && locationMatches;
            }).toList();
            
          // If a location filter is active, sort by distance
          if (_userLat != null && _userLng != null) {
            filteredProperties.sort((a, b) {
              final distA = Geolocator.distanceBetween(_userLat!, _userLng!, a.latitude ?? 0, a.longitude ?? 0);
              final distB = Geolocator.distanceBetween(_userLat!, _userLng!, b.latitude ?? 0, b.longitude ?? 0);
              return distA.compareTo(distB);
            });
          }


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
                    if (_selectedType != 'All' || _minPrice > 0 || _maxPrice < 999999999 || _userLat != null)
                      TextButton(
                        onPressed: () => _applyFilters('All', 0, 999999999, null, null, 5.0),
                        child: const Text('Reset Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredProperties.length,
            itemBuilder: (context, index) {
              
              final property = filteredProperties[index];
              final price = property.price.toString();
              
              // Helper to display distance if location filter is active
              String distanceText = '';
              if (_userLat != null && property.latitude != null) {
                final distanceMeters = Geolocator.distanceBetween(
                  _userLat!, _userLng!, property.latitude!, property.longitude!
                );
                distanceText = ' · ${(distanceMeters / 1000).toStringAsFixed(1)} km away';
              }
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                elevation: 6, // High elevation for a prominent card
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // Increased rounding
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => PropertyDetailsScreen(property: property)),
                    );
                  },
                  borderRadius: BorderRadius.circular(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Section (Larger and more prominent)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: SizedBox(
                          height: 200,
                          width: double.infinity,
                          child: property.imageUrl != null && property.imageUrl!.isNotEmpty
                              ? Image.network(
                                  property.imageUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)));
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey));
                                  },
                                )
                              : const Center(child: Icon(Icons.house, size: 80, color: Colors.blueGrey)),
                        ),
                      ),
                      
                      // Details Section
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Price
                                Text(
                                  '\$$price',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                // Type Chip
                                Chip(
                                  label: Text(
                                    property.type, 
                                    style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)
                                  ),
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Title
                            Text(
                              property.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black),
                            ),
                            const SizedBox(height: 4),

                            // Address and Distance
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${property.address}$distanceText', 
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}