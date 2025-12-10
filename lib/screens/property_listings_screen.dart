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
import 'notifications_screen.dart'; 

class PropertyListingsScreen extends StatefulWidget {
  const PropertyListingsScreen({super.key});

  @override
  State<PropertyListingsScreen> createState() => _PropertyListingsScreenState();
}

class _PropertyListingsScreenState extends State<PropertyListingsScreen> {
  
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance; 
  String? _userId;

  String _selectedType = 'All';
  int _minPrice = 0;
  int _maxPrice = 999999999; 
  
  double? _userLat;
  double? _userLng;
  double _radiusKm = 5.0; 

  int _unreadNotificationCount = 0;
  
  // State for user role fetched from Firestore
  String _userRole = 'Buyer'; 

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
    _determinePosition();
    if (_userId != null) {
      _listenForUnreadNotifications();
      _fetchUserRole(); 
    }
  }

  // Method to fetch user role from Firestore
  Future<void> _fetchUserRole() async {
    if (_userId == null) return;
    try {
      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists && mounted) {
        setState(() {
          // Fetch the role field saved during sign-up
          _userRole = doc.data()?['role'] ?? 'Buyer';
        });
      }
    } catch (e) {
      print('Error fetching user role: $e');
    }
  }

  void _listenForUnreadNotifications() {
    if (_userId == null) return;
    
    _firestore
      .collection('users')
      .doc(_userId)
      .collection('notifications')
      .where('isRead', isEqualTo: false)
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
    Navigator.of(context).pop(); 
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }
  
  // Existing location method remains...
  Future<void> _determinePosition() async {
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
      // Triggering a re-render will cause the StreamBuilder to refresh its query if _selectedType changed.
    });
  }

  void _checkSellerRoleAndNavigate(BuildContext context, bool isSeller) {
    if (isSeller) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const AddPropertyScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in as a seller/agent to add a property.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSeller = _userRole == 'Seller/Agent'; 

    // --- Start Firestore Query Construction ---
    Query listingsQuery = _firestore.collection('listings');
    
    // Step 1: Apply the least restrictive filter (Type) directly to Firestore.
    // If 'All' is selected, don't apply the type filter.
    if (_selectedType != 'All') {
      listingsQuery = listingsQuery.where('type', isEqualTo: _selectedType);
    }
    
    // We cannot add price filters or multiple range/equality filters without an index.
    // The rest of the filtering must be done client-side.
    // --- End Firestore Query Construction ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Listings'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          
          IconButton(
            icon: const Icon(Icons.add_home),
            tooltip: 'Add New Property',
            onPressed: () => _checkSellerRoleAndNavigate(context, isSeller),
          ),

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
      
      floatingActionButton: null, 
      
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_auth.currentUser?.email ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text('Role: $_userRole'), 
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
                Navigator.of(context).pop(); 
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
        // Use the simplified query
        stream: listingsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Fetch all documents matching the primary Firestore filter (Type)
          final allProperties = snapshot.data!.docs.map(PropertyModel.fromDocument).toList();
          List<PropertyModel> filteredProperties = allProperties;

          // --- PERFORM CLIENT-SIDE FILTERING HERE ---

          // 1. Price Filtering (Client-side)
          filteredProperties = filteredProperties.where((property) {
            return property.price >= _minPrice && property.price <= _maxPrice;
          }).toList();

          // 2. Location Filtering (Client-side)
          if (_userLat != null && _userLng != null) {
            filteredProperties = filteredProperties.where((property) {
              if (property.latitude != null && property.longitude != null) {
                final distance = _calculateDistance(_userLat!, _userLng!, property.latitude!, property.longitude!);
                return distance <= _radiusKm;
              }
              return true; 
            }).toList();
          }
          
          // --- END CLIENT-SIDE FILTERING ---

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