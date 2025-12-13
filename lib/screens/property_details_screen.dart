// lib/screens/property_details_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import '../models/property_model.dart';
import 'tour_scheduling_screen.dart'; 
import 'rating_review_screen.dart'; 

class PropertyDetailsScreen extends StatefulWidget {
  final PropertyModel property;

  const PropertyDetailsScreen({super.key, required this.property});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  final _firestore = FirebaseFirestore.instance;
  String? get _userId => FirebaseAuth.instance.currentUser?.uid; 
  
  bool _isWishlisted = false;
  bool _isLiked = false; 
  String _sellerName = 'Loading...';
  bool _isSold = false; 
  int _currentFlagCount = 0;
  bool _isFlaggedByCurrentUser = false;

  @override
  void initState() {
    super.initState();
    _isSold = widget.property.isSold ?? false; 
    _loadData();
  }

  void _loadData() {
    if (_userId != null) {
      _checkWishlistStatus();
      _checkLikeStatus();
      _checkFlagStatus();
    }
    _fetchSellerInfo();
  }

  // --- DATA FETCHING ---
  Future<void> _fetchSellerInfo() async {
    final doc = await _firestore.collection('users').doc(widget.property.sellerId).get();
    if (mounted) setState(() => _sellerName = doc.data()?['name'] ?? 'Unknown Seller');
  }

  Future<void> _checkWishlistStatus() async {
    final doc = await _firestore.collection('users').doc(_userId).collection('wishlist').doc(widget.property.id).get();
    if (mounted) setState(() => _isWishlisted = doc.exists);
  }

  Future<void> _checkLikeStatus() async {
    final doc = await _firestore.collection('listings').doc(widget.property.id).collection('likes').doc(_userId).get();
    if (mounted) setState(() => _isLiked = doc.exists);
  }

  Future<void> _checkFlagStatus() async {
    _firestore.collection('listings').doc(widget.property.id).snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() => _currentFlagCount = snap.data()?['flagCount'] ?? 0);
      }
    });
    final userFlag = await _firestore.collection('listings').doc(widget.property.id).collection('flags').doc(_userId).get();
    if (mounted) setState(() => _isFlaggedByCurrentUser = userFlag.exists);
  }

  // --- ACTIONS ---
  Future<void> _handleLikeAction() async {
    if (_userId == null) return;
    final likeRef = _firestore.collection('listings').doc(widget.property.id).collection('likes').doc(_userId);
    
    if (_isLiked) {
      await likeRef.delete();
    } else {
      await likeRef.set({'timestamp': FieldValue.serverTimestamp()});
    }
    setState(() => _isLiked = !_isLiked);
  }

  Future<void> _toggleWishlist() async {
    if (_userId == null) return;
    final ref = _firestore.collection('users').doc(_userId).collection('wishlist').doc(widget.property.id);
    _isWishlisted ? await ref.delete() : await ref.set({'addedAt': Timestamp.now()});
    setState(() => _isWishlisted = !_isWishlisted);
  }

  Future<void> _markPropertyAsSold() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Sale"),
        content: const Text("Mark this property as SOLD? This action is permanent."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Confirm")),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('listings').doc(widget.property.id).update({'isSold': true});
      setState(() => _isSold = true);
    }
  }

  Future<void> _toggleFlagProperty() async {
    if (_userId == null) return;
    final propertyRef = _firestore.collection('listings').doc(widget.property.id);
    final flagRef = propertyRef.collection('flags').doc(_userId!);

    if (_isFlaggedByCurrentUser) {
      await flagRef.delete();
      await propertyRef.update({'flagCount': FieldValue.increment(-1)});
    } else {
      await flagRef.set({'timestamp': FieldValue.serverTimestamp()});
      await propertyRef.update({'flagCount': FieldValue.increment(1)});
    }
    setState(() => _isFlaggedByCurrentUser = !_isFlaggedByCurrentUser);
  }

  // --- UI BUILDING BLOCKS ---
  Widget _buildReviewList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('listings').doc(widget.property.id).collection('reviews').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const Text("No reviews yet.");
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: snap.data!.docs.map((doc) => ListTile(
            title: Text("${doc['rating']} ⭐"),
            subtitle: Text(doc['review'] ?? ""),
          )).toList(),
        );
      },
    );
  }

  Widget _buildFlagStatus() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Flag Count: $_currentFlagCount", 
            style: TextStyle(color: _currentFlagCount >= 5 ? Colors.red : Colors.black, fontWeight: FontWeight.bold)),
          TextButton.icon(
            onPressed: _toggleFlagProperty,
            icon: Icon(_isFlaggedByCurrentUser ? Icons.flag : Icons.flag_outlined),
            label: Text(_isFlaggedByCurrentUser ? "Unflag" : "Flag"),
          )
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    if (_isSold) return const ElevatedButton(onPressed: null, child: Text("PROPERTY SOLD"));
    if (_userId == widget.property.sellerId) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        onPressed: _markPropertyAsSold, 
        child: const Text("Mark as Sold", style: TextStyle(color: Colors.white)),
      );
    }
    return ElevatedButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TourSchedulingScreen(
        propertyId: widget.property.id, 
        propertyTitle: widget.property.title, 
        sellerId: widget.property.sellerId
      ))),
      child: const Text("Schedule Virtual Tour"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Property Details"),
        actions: [
          IconButton(
            icon: Icon(_isLiked ? Icons.thumb_up : Icons.thumb_up_outlined),
            color: _isLiked ? Colors.blue : null,
            onPressed: _handleLikeAction,
          ),
          IconButton(
            icon: Icon(_isWishlisted ? Icons.favorite : Icons.favorite_border),
            color: _isWishlisted ? Colors.red : null,
            onPressed: _toggleWishlist,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\$${widget.property.price}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 10),
            Text(widget.property.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text("Seller"),
              subtitle: Text(_sellerName),
            ),
            
            const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(widget.property.description, style: const TextStyle(fontSize: 16)),
            
            const Divider(height: 30),

            // REVIEWS SECTION
            const Text("User Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _buildReviewList(),
            
            const SizedBox(height: 20),

            // RATE & REVIEW BUTTON (Fixed: Passing propertyId)
            if (_userId != widget.property.sellerId && !_isSold)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.star_rate, color: Colors.amber),
                  label: const Text("Leave a Review"),
                  onPressed: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => RatingReviewScreen(propertyId: widget.property.id))
                  ),
                ),
              ),
            
            const SizedBox(height: 20),
            if (!_isSold) _buildFlagStatus(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildBottomButton(),
        ),
      ),
    );
  }
}