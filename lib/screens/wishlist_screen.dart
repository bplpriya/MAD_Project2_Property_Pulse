// lib/screens/wishlist_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/property_model.dart';
import 'property_details_screen.dart'; // For navigating to details

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Wishlist')),
        body: const Center(child: Text('Please log in to view your wishlist.')),
      );
    }

    // Stream the documents from the user's 'wishlist' sub-collection
    // The documents here will just be identifiers (Property IDs)
    return Scaffold(
      appBar: AppBar(title: const Text('My Wishlist')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('wishlist')
            .snapshots(),
        
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading wishlist: ${snapshot.error}'));
          }

          final wishlistDocs = snapshot.data?.docs ?? [];

          if (wishlistDocs.isEmpty) {
            return const Center(
              child: Text(
                'Your wishlist is empty! Start adding properties you love.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Fetch the actual property data based on the stored IDs
          final propertyIds = wishlistDocs.map((doc) => doc.id).toList();

          return FutureBuilder<List<PropertyModel>>(
            future: _fetchPropertiesFromIds(propertyIds),
            builder: (context, propertySnapshot) {
              if (propertySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (propertySnapshot.hasError) {
                return Center(child: Text('Error fetching properties: ${propertySnapshot.error}'));
              }

              final properties = propertySnapshot.data ?? [];

              return ListView.builder(
                itemCount: properties.length,
                itemBuilder: (context, index) {
                  final property = properties[index];
                  
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
                          child: property.imageUrl != null && property.imageUrl!.isNotEmpty
                              ? Image.network(
                                  property.imageUrl!,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.house, size: 40, color: Colors.blueGrey),
                        ),
                      ),
                      
                      title: Text(property.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(property.address, style: const TextStyle(color: Colors.grey)),
                      
                      trailing: Text(
                        '\$${property.price}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).primaryColor,
                        ),
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
          );
        },
      ),
    );
  }
  
  // Helper function to fetch the actual property documents
  Future<List<PropertyModel>> _fetchPropertiesFromIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    // Firestore allows up to 10 'whereIn' conditions per query
    final snapshot = await FirebaseFirestore.instance
        .collection('listings')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
        
    return snapshot.docs.map(PropertyModel.fromDocument).toList();
  }
}