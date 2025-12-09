// lib/screens/property_details_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import '../models/property_model.dart';

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
  final _userId = FirebaseAuth.instance.currentUser?.uid;
  bool _isWishlisted = false;
  String _sellerName = 'Loading seller info...';
  bool _isFlaggedByCurrentUser = false; 
  static const int _FLAG_THRESHOLD = 10; 

  @override
  void initState() {
    super.initState();
    _checkWishlistStatus();
    _fetchSellerInfo();
    _checkFlagStatus(); 
  }

  Future<void> _fetchSellerInfo() async {
    try {
      final sellerDoc = await _firestore
          .collection('users')
          .doc(widget.property.sellerId)
          .get();
      
      if (sellerDoc.exists && mounted) {
        setState(() {
          _sellerName = sellerDoc.data()?['name'] ?? 'Seller Not Found';
        });
      } else if (mounted) {
        setState(() {
          _sellerName = 'Seller Not Found';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sellerName = 'Error loading seller';
        });
      }
    }
  }

  Future<void> _checkWishlistStatus() async {
    if (_userId == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('wishlist')
        .doc(widget.property.id);

    final doc = await docRef.get();
    
    if (mounted) {
      setState(() {
        _isWishlisted = doc.exists;
      });
    }
  }
  
  // --- Flagging Logic ---

  Future<void> _checkFlagStatus() async {
    if (_userId == null) return;

    final flagDocRef = _firestore
        .collection('listings')
        .doc(widget.property.id)
        .collection('flags')
        .doc(_userId);

    final doc = await flagDocRef.get();
    
    if (mounted) {
      setState(() {
        _isFlaggedByCurrentUser = doc.exists;
      });
    }
  }
  
  Future<void> _toggleFlagStatus() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to manage flags.')),
      );
      return;
    }

    final propertyId = widget.property.id;
    final flagDocRef = _firestore
        .collection('listings')
        .doc(propertyId)
        .collection('flags')
        .doc(_userId);
        
    final listingDocRef = _firestore.collection('listings').doc(propertyId);

    try {
      if (_isFlaggedByCurrentUser) {
        // --- Unflagging ---
        await flagDocRef.delete();
        await listingDocRef.update({
          'flagCount': FieldValue.increment(-1),
        });

        if (mounted) {
          setState(() {
            _isFlaggedByCurrentUser = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Listing unflagged.')),
          );
        }

      } else {
        // --- Flagging ---
        await flagDocRef.set({
          'userId': _userId,
          'flaggedAt': FieldValue.serverTimestamp(),
        });
        
        // Update flag count and mark for review
        await listingDocRef.update({
          'flagCount': FieldValue.increment(1),
          'isUnderReview': true,
        });

        // Check if the new flag count meets the removal threshold
        final listingSnapshot = await listingDocRef.get();
        final currentFlagCount = listingSnapshot.data()?['flagCount'] ?? 0;

        if (currentFlagCount >= _FLAG_THRESHOLD) {
          await listingDocRef.update({
            'isRemoved': true, // New field to hide the listing globally
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Listing flagged and removed from public view due to multiple reports.')),
          );
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Listing flagged successfully. It is now under review.')),
          );
        }

        if (mounted) {
          setState(() {
            _isFlaggedByCurrentUser = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update flag status: $e')),
        );
      }
    }
  }

  // --- End Flagging Logic ---

  Future<void> _toggleWishlist() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to manage your wishlist.')),
      );
      return;
    }

    final docRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('wishlist')
        .doc(widget.property.id);

    if (_isWishlisted) {
      await docRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.property.title} removed from wishlist.')),
      );
    } else {
      await docRef.set({
        'addedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.property.title} added to wishlist!')),
      );
    }

    _checkWishlistStatus(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.property.title),
        elevation: 4, 
        actions: [
          // REMOVED FLAG BUTTON FROM APPBAR
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            SizedBox(
              height: 300,
              width: double.infinity,
              child: widget.property.imageUrl != null && widget.property.imageUrl!.isNotEmpty
                  ? Image.network(
                      widget.property.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Icon(Icons.broken_image, size: 60, color: Colors.grey));
                      },
                    )
                  : const Center(
                      child: Icon(Icons.house, size: 100, color: Colors.blueGrey),
                    ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.property.title,
                          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '\$${widget.property.price}',
                        style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        widget.property.address,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Chip(
                    label: Text(widget.property.type),
                    backgroundColor: Colors.blue.shade100,
                  ),

                  const SizedBox(height: 25),
                  
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  Text(
                    widget.property.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),

                  const SizedBox(height: 30),
                  
                  // --- 1. Wishlist Button ---
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _toggleWishlist,
                      icon: Icon(
                        _isWishlisted ? Icons.favorite : Icons.favorite_border,
                        color: _isWishlisted ? Colors.red : Theme.of(context).primaryColor,
                      ),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          _isWishlisted ? 'REMOVE FROM WISHLIST' : 'ADD TO WISHLIST',
                          style: TextStyle(
                            fontSize: 16,
                            color: _isWishlisted ? Colors.red : Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: _isWishlisted ? Colors.red : Theme.of(context).primaryColor, 
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10), // Small spacer
                  
                  // --- 2. Flagging Button (New Position) ---
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _toggleFlagStatus,
                      icon: Icon(
                        _isFlaggedByCurrentUser ? Icons.flag : Icons.flag_outlined,
                        color: _isFlaggedByCurrentUser ? Colors.red : Colors.grey.shade600,
                      ),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          _isFlaggedByCurrentUser ? 'UNFLAG LISTING' : 'FLAG LISTING FOR REVIEW',
                          style: TextStyle(
                            fontSize: 16,
                            color: _isFlaggedByCurrentUser ? Colors.red : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: _isFlaggedByCurrentUser ? Colors.red : Colors.grey.shade400, 
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  Text(
                    'Contact Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(_sellerName),
                    subtitle: Text('Listing ID: ${widget.property.id}'),

                    trailing: IconButton(
                      icon: const Icon(Icons.chat),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat feature coming soon!')),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 50),
                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}