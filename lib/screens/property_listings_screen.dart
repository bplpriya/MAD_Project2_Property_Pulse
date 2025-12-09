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
// NEW: Import the Notifications Screen
import 'notifications_screen.dart'; 

class PropertyListingsScreen extends StatefulWidget {
  const PropertyListingsScreen({super.key});

  @override
  State<PropertyListingsScreen> createState() => _PropertyListingsScreenState();
}

class _PropertyListingsScreenState extends State<PropertyListingsScreen> {
  
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance; // For accessing the current user ID
  String? _userId;

  String _selectedType = 'All';
  int _minPrice = 0;
  int _maxPrice = 999999999; 
  
  double? _userLat;
  double? _userLng;
  double _radiusKm = 5.0; 

  // State for unread notifications count
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
    _determinePosition();
    if (_userId != null) {
      _listenForUnreadNotifications();
    }
  }

  // NEW: Real-time listener for unread notifications
  void _listenForUnreadNotifications() {
    if (_userId == null) return;
    
    _firestore
      .collection('users')
      .doc(_userId)
      .collection('notifications')
      .where('isRead', isEqualTo: false) // Only count unread
      .snapshots()
      .listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadNotificationCount = snapshot.docs.length;
          });
        }
      }, onError: (error) {
        print("Error listening to notifications: $error");
      });
  }

  void _navigateToScreen(BuildContext context, Widget screen) {
    // Closes the drawer before navigating
    Navigator.of(context).pop(); 
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }
  
  // Existing method remains...
  Future<void> _determinePosition() async {
    // ... (omitted for brevity, assume this is the same as before)
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return; 
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return;
    } 

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      if(mounted) {
        setState(() {
          _userLat = position.latitude;
          _userLng = position.longitude;
        });
      }
    } catch (e) {
      print("Could not get user location: $e");
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Distance in km
  }

  void _applyFilters(String type, int minPrice, int maxPrice, double? lat, double? lng, double radiusKm) {
    setState(() {
      _selectedType = type;
      _minPrice = minPrice;
      _maxPrice = maxPrice;
      _userLat = lat;
      _userLng = lng;
      _radiusKm = radiusKm;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSeller = _auth.currentUser != null && _auth.currentUser!.email == 'seller@example.com'; // Simple mock role check

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Listings'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // NEW: Notification Icon
          if (_userId != null)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                    );
                  },
                ),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          
          IconButton(
            icon: const Icon(Icons.compare),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PropertyComparisonScreen()),
              );
            },
          ),
          
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => FilterSearchScreen(
                    onApplyFilters: _applyFilters,
                    initialType: _selectedType,
                    initialMinPrice: _minPrice,
                    initialMaxPrice: _maxPrice,
                    initialLat: _userLat,
                    initialLng: _userLng,
                    initialRadiusKm: _radiusKm,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_auth.currentUser?.email ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: const Text('View Profile'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _auth.currentUser?.email?.substring(0, 1).toUpperCase() ?? 'G',
                  style: TextStyle(fontSize: 40.0, color: theme.primaryColor),
                ),
              ),
              onDetailsPressed: () {
                _navigateToScreen(context, const ProfileScreen());
              },
              decoration: BoxDecoration(
                color: theme.primaryColor,
              ),
            ),
            
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Listings'),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer
              },
            ),
            
            if (isSeller)
              ListTile(
                leading: const Icon(Icons.add_home),
                title: const Text('Add New Property'),
                onTap: () => _navigateToScreen(context, const AddPropertyScreen()),
              ),
              
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Wishlist'),
              onTap: () => _navigateToScreen(context, const WishlistScreen()),
            ),
            
            ListTile(
              leading: const Icon(Icons.compare_arrows),
              title: const Text('Property Comparison'),
              onTap: () => _navigateToScreen(context, const PropertyComparisonScreen()),
            ),
            
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () => _navigateToScreen(context, const ProfileScreen()),
            ),
            
            // NEW: Notifications Drawer Item (already covered by AppBar icon but good for completeness)
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              trailing: _unreadNotificationCount > 0 
                  ? Chip(
                      label: Text(_unreadNotificationCount.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.red,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    )
                  : null,
              onTap: () => _navigateToScreen(context, const NotificationsScreen()),
            ),

            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await _auth.signOut();
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('listings')
            .where('type', isEqualTo: _selectedType == 'All' ? null : _selectedType)
            .where('price', isGreaterThanOrEqualTo: _minPrice)
            .where('price', isLessThanOrEqualTo: _maxPrice)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter documents based on geographical proximity if location data is available
          final allProperties = snapshot.data!.docs.map(PropertyModel.fromDocument).toList();
          List<PropertyModel> filteredProperties = allProperties;

          if (_userLat != null && _userLng != null) {
            filteredProperties = allProperties.where((property) {
              if (property.latitude != null && property.longitude != null) {
                final distance = _calculateDistance(_userLat!, _userLng!, property.latitude!, property.longitude!);
                return distance <= _radiusKm;
              }
              return true; // Include if location is missing
            }).toList();
          }

          if (filteredProperties.isEmpty) {
            return const Center(
              child: Text(
                'No properties found matching your criteria.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 80),
            itemCount: filteredProperties.length,
            itemBuilder: (context, index) {
              final property = filteredProperties[index];
              
              String distanceText = '';
              if (_userLat != null && _userLng != null && property.latitude != null && property.longitude != null) {
                final distance = _calculateDistance(_userLat!, _userLng!, property.latitude!, property.longitude!);
                distanceText = ' • ${distance.toStringAsFixed(1)} km away';
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => PropertyDetailsScreen(property: property),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Property Image
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(15), 
                          topRight: Radius.circular(15)
                        ),
                        child: Image.network(
                          property.imageUrl ?? 'https://placehold.co/600x400/AAAAAA/FFFFFF?text=No+Image',
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 50)),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              color: Colors.grey.shade200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Property Details
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Price
                            Text(
                              '\$${property.price}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: theme.primaryColor,
                              ),
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