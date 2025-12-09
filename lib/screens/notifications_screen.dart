import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/property_model.dart';
import 'property_details_screen.dart'; 

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // Simplified: We'll stream the latest listings and treat them as "notifications"
  // In a real app, you would stream a 'notifications' collection in the user's profile.
  Stream<QuerySnapshot> _getRecentListingsStream() {
    return FirebaseFirestore.instance
        .collection('listings')
        // Order by timestamp to show the newest at the top
        .orderBy('timestamp', descending: true)
        // Limit to, say, the last 20 listings
        .limit(20) 
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("New Listing Alerts"),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getRecentListingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading notifications: ${snapshot.error}'));
          }

          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No new listings found in your feed.'));
          }

          final recentListings = snapshot.data!.docs
              .map((doc) => PropertyModel.fromDocument(doc))
              .toList();

          return ListView.builder(
            itemCount: recentListings.length,
            itemBuilder: (context, index) {
              final property = recentListings[index];
              // Determine if the listing is very recent (e.g., within the last 24 hours)
              final isNew = property.timestamp.toDate().isAfter(
                DateTime.now().subtract(const Duration(hours: 24))
              );
              
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.lightGreen,
                    child: Icon(Icons.home_work_outlined, color: Colors.white),
                  ),
                  title: Text(
                    property.title,
                    style: TextStyle(
                      fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                      color: isNew ? theme.primaryColor : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    '${property.address} - \$${property.price}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isNew
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('New!', style: TextStyle(color: Colors.white, fontSize: 12)),
                        )
                      : null,
                  onTap: () {
                    // Navigate to the property details screen when tapped
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