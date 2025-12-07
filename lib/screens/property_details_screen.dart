// lib/screens/property_details_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for Firestore access
import 'package:firebase_auth/firebase_auth.dart'; // Added for user ID
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

  @override
  void initState() {
    super.initState();
    _checkWishlistStatus();
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
      // Remove from wishlist
      await docRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.property.title} removed from wishlist.')),
      );
    } else {
      // Add to wishlist (store the property ID)
      await docRef.set({
        'addedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.property.title} added to wishlist!')),
      );
    }

    _checkWishlistStatus(); // Refresh the icon state
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.property.title),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(
              _isWishlisted ? Icons.favorite : Icons.favorite_border,
              color: _isWishlisted ? Colors.red : Colors.black,
            ),
            onPressed: _toggleWishlist,
          ),
        ],
      ),
      extendBodyBehindAppBar: true, 
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. Property Image (Header) ---
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
                  // --- 2. Price and Title ---
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

                  // --- 3. Location and Type ---
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
                  
                  // --- 4. Description ---
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
                  
                  // --- 5. Seller/Contact Info ---
                  Text(
                    'Contact Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: const Text('Seller ID: (Name Loading...)'),
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
                  
                  // --- Action Button (Buy/Message) ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Initiating purchase for ${widget.property.title}')),
                        );
                      },
                      icon: const Icon(Icons.attach_money),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text('Buy for \$${widget.property.price}', style: const TextStyle(fontSize: 18)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}