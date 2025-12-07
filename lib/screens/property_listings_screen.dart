import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; // Needed if filtering by user later, good practice
import 'profile_screen.dart'; 
import 'add_property_screen.dart';

class PropertyListingsScreen extends StatefulWidget {
  const PropertyListingsScreen({super.key});

  @override
  State<PropertyListingsScreen> createState() => _PropertyListingsScreenState();
}

class _PropertyListingsScreenState extends State<PropertyListingsScreen> {
  
  final _firestore = FirebaseFirestore.instance;

  void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Pulse'),
        actions: [
          // Add Property Button
          IconButton(
            icon: const Icon(Icons.add_home_work),
            tooltip: 'Add New Property',
            onPressed: () => _navigateToScreen(
              context, 
              const AddPropertyScreen(), 
            ),
          ),
          
          // Profile Button
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
        // Stream all documents from the 'listings' collection, ordered by timestamp
        stream: _firestore
            .collection('listings')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error State
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final propertyDocs = snapshot.data?.docs ?? [];

          // 3. Empty State
          if (propertyDocs.isEmpty) {
            return const Center(
              child: Text(
                'No properties listed yet. Be the first to add one!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }

          // 4. Data Display State
          return ListView.builder(
            itemCount: propertyDocs.length,
            itemBuilder: (context, index) {
              final property = propertyDocs[index].data() as Map<String, dynamic>;
              
              // Safely extract data
              final title = property['title'] ?? 'N/A';
              final price = property['price']?.toString() ?? 'N/A';
              final address = property['address'] ?? 'N/A';
              final imageUrl = property['imageUrl'] ?? '';
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                elevation: 3,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  
                  // Leading image display (from Cloudinary URL)
                  leading: SizedBox(
                    width: 80,
                    height: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              // Placeholder while loading
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(child: CircularProgressIndicator(strokeWidth: 2));
                              },
                              // Placeholder on error
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
                        'Type: ${property['type'] ?? 'N/A'}',
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
                  
                  // TODO: Implement onTap to navigate to a Property Detail screen
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Viewing details for: $title')),
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