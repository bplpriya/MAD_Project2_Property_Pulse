import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import '../models/property_model.dart';
import 'tour_scheduling_screen.dart'; 

class PropertyDetailsScreen extends StatefulWidget {
  final PropertyModel property;

  const PropertyDetailsScreen({
    super.key,
    required this.property,
  });

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  final _firestore = FirebaseFirestore.instance;
  // Get the current user ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid; 
  
  bool _isWishlisted = false;
  String _sellerName = 'Loading seller info...';
  
  // Flagging State Variables
  bool _isFlaggedByCurrentUser = false; 
  int _currentFlagCount = 0; 
  static const int _FLAG_THRESHOLD = 5; // Reduced for easier testing
  bool _isFlagging = false;

  @override
  void initState() {
    super.initState();
    // Only proceed if user is logged in
    if (_userId != null) {
      _checkWishlistStatus();
      _checkFlagStatus(); 
    }
    _fetchSellerInfo(); // Fetch seller info regardless of current user's login status
  }
  
  // --- Data Fetching Methods ---

  // 1. Fetch Seller Name (FIXED: ensures 'name' is retrieved)
  Future<void> _fetchSellerInfo() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.property.sellerId).get();
      final data = doc.data();
      if (mounted) {
        setState(() {
          // Attempt to retrieve the 'name' field from the user document
          _sellerName = data?['name'] ?? 'Unknown Seller';
        });
      }
    } catch (e) {
      print('Error fetching seller info: $e');
      if (mounted) {
        setState(() {
          _sellerName = 'Error loading name';
        });
      }
    }
  }

  // 2. Check Property Flag Status
  Future<void> _checkFlagStatus() async {
    if (_userId == null) return;

    try {
      final propertyDoc = _firestore.collection('listings').doc(widget.property.id);
      
      // Listen to the total flag count on the property document
      propertyDoc.snapshots().listen((snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            _currentFlagCount = snapshot.data()?['flagCount'] ?? 0;
          });
        }
      });
      
      // Check if the current user has already flagged this property
      final userFlagDoc = await propertyDoc.collection('flags').doc(_userId!).get();
      
      if (mounted) {
        setState(() {
          _isFlaggedByCurrentUser = userFlagDoc.exists;
        });
      }

    } catch (e) {
      print('Error checking flag status: $e');
    }
  }

  // 3. Check Wishlist Status
  Future<void> _checkWishlistStatus() async {
    if (_userId == null) return;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('wishlist')
          .doc(widget.property.id)
          .get();
      if (mounted) {
        setState(() {
          _isWishlisted = doc.exists;
        });
      }
    } catch (e) {
      print('Error checking wishlist status: $e');
    }
  }

  // --- Action Methods ---

  // 1. Toggle Wishlist Status
  Future<void> _toggleWishlist() async {
    if (_userId == null) {
       _showSnackbar('Please log in to manage your wishlist.', Colors.orange);
       return;
    }
    
    final wishlistRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('wishlist')
        .doc(widget.property.id);

    try {
      if (_isWishlisted) {
        // Remove from wishlist
        await wishlistRef.delete();
        _showSnackbar('Removed from Wishlist', Colors.red);
      } else {
        // Add to wishlist (only store the ID)
        await wishlistRef.set({}); // Set an empty document to indicate presence
        _showSnackbar('Added to Wishlist!', Colors.green);
      }
      if (mounted) {
        setState(() {
          _isWishlisted = !_isWishlisted;
        });
      }
    } catch (e) {
      _showSnackbar('Failed to update wishlist.', Colors.red);
      print('Error toggling wishlist: $e');
    }
  }
  
  // 2. Toggle Flagging Status (Handles both flagging and unflagging)
  Future<void> _toggleFlagProperty() async {
    if (_userId == null) {
      _showSnackbar('Please log in to flag a property.', Colors.orange);
      return;
    }
    if (_isFlagging) return;

    setState(() { _isFlagging = true; });

    final propertyRef = _firestore.collection('listings').doc(widget.property.id);
    final flagRef = propertyRef.collection('flags').doc(_userId!);
    
    try {
      if (_isFlaggedByCurrentUser) {
        // UNFLAG LOGIC
        await _firestore.runTransaction((transaction) async {
          transaction.delete(flagRef);
          transaction.update(propertyRef, {'flagCount': FieldValue.increment(-1)});
        });
        _showSnackbar('Property unflagged.', Colors.green);
      } else {
        // FLAG LOGIC
        await _firestore.runTransaction((transaction) async {
          // Set the flag document to track who flagged it
          transaction.set(flagRef, {'timestamp': FieldValue.serverTimestamp()});
          // Increment the overall flag count on the main property document
          transaction.update(propertyRef, {'flagCount': FieldValue.increment(1)});
        });
        _showSnackbar('Property flagged for review.', Colors.red);
      }
      
      // Update state after successful transaction
      if (mounted) {
        setState(() {
          _isFlaggedByCurrentUser = !_isFlaggedByCurrentUser;
          // The listener in _checkFlagStatus will update _currentFlagCount automatically
        });
      }
      
    } catch (e) {
      _showSnackbar('Failed to update flag status.', Colors.red);
      print('Error toggling flag status: $e');
    } finally {
      if (mounted) {
        setState(() { _isFlagging = false; });
      }
    }
  }

  // --- Utility ---
  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- UI Building Blocks ---

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagStatus() {
    final bool isHighlyFlagged = _currentFlagCount >= _FLAG_THRESHOLD;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isHighlyFlagged ? Icons.warning : Icons.flag, 
                  color: isHighlyFlagged ? Colors.red.shade700 : Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isHighlyFlagged ? 'High Flag Count!' : 'Flag Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isHighlyFlagged ? Colors.red.shade700 : Colors.black87,
                  ),
                ),
              ],
            ),
            
            Text(
              'Count: $_currentFlagCount',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isHighlyFlagged ? Colors.red.shade700 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _userId != null ? _toggleFlagProperty : () => _showSnackbar('Please log in to flag.', Colors.orange),
            // Icons.flag_outlined is the replacement for Icons.flag_off
            icon: Icon(_isFlaggedByCurrentUser ? Icons.flag_outlined : Icons.flag),
            label: Text(
              _isFlagging 
                ? 'Updating...' 
                : (_isFlaggedByCurrentUser ? 'Unflag Property' : 'Flag Property for Review')
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFlaggedByCurrentUser ? Colors.orange.shade200 : Colors.red.shade100,
              foregroundColor: _isFlaggedByCurrentUser ? Colors.orange.shade900 : Colors.red.shade900,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        if (isHighlyFlagged)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'This property has been flagged $_currentFlagCount times. Listings with $_FLAG_THRESHOLD or more flags are automatically under review.',
              style: TextStyle(color: Colors.red.shade700, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }


  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Determine if the URL is valid/present for safe usage
    // We check for null first, then for emptiness.
    final hasImageUrl = widget.property.imageUrl != null && widget.property.imageUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.property.title),
        actions: [
          // Wishlist Toggle Button
          IconButton(
            icon: Icon(
              _isWishlisted ? Icons.favorite : Icons.favorite_border,
              color: _isWishlisted ? Colors.red : Colors.grey.shade700,
            ),
            onPressed: _toggleWishlist,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Property Image (FIXED: Uses null-aware operator for NetworkImage) ---
            Hero(
              tag: 'property-image-${widget.property.id}',
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: hasImageUrl 
                    ? DecorationImage(
                      // FIX: The `!` null-aware operator is used here because we confirm
                      // it's not null and not empty in the `hasImageUrl` check.
                      image: NetworkImage(widget.property.imageUrl!),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        // Placeholder if image loading fails
                        print('Image load error: $exception');
                      },
                    )
                    : null, // No DecorationImage if URL is empty or null
                  color: Colors.grey.shade200,
                ),
                // Display a placeholder icon if URL is empty or null
                child: !hasImageUrl 
                  ? const Center(child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey))
                  : null,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Price & Type ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${widget.property.price}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: theme.primaryColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.property.type,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  // --- Seller Info ---
                  _buildDetailRow(
                    Icons.person_pin_circle, 
                    'Listed By', 
                    '$_sellerName (ID: ${widget.property.sellerId.substring(0, 4)}...)',
                  ),
                  
                  // --- Location & Date ---
                  _buildDetailRow(Icons.location_on, 'Address', widget.property.address),
                  _buildDetailRow(
                    Icons.date_range, 
                    'Date Listed', 
                    widget.property.timestamp.toDate().toString().split(' ')[0],
                  ),
                  const Divider(height: 30),

                  // --- Description ---
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.property.description,
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black54),
                  ),
                  const Divider(height: 30),
                  
                  // --- Flagging/Review Section ---
                  _buildFlagStatus(),
                  const Divider(height: 30),
                  
                ],
              ),
            ),
          ],
        ),
      ),
      // --- Bottom Action Bar (Schedule Tour) ---
      bottomNavigationBar: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // --- NAVIGATION LOGIC (FIXED: Added sellerId) ---
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TourSchedulingScreen(
                              propertyId: widget.property.id,
                              propertyTitle: widget.property.title,
                              // MANDATORY FIX: Pass the sellerId
                              sellerId: widget.property.sellerId, 
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.calendar_month, size: 24),
                      label: const Text('Schedule Virtual Tour', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}