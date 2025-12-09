// lib/models/property_model.dart (The file you need to update)

import 'package:cloud_firestore/cloud_firestore.dart';

class PropertyModel {
  final String id;
  final String title;
  final int price;
  final String type;
  final String address;
  final String description;
  final String? imageUrl;
  final String sellerId;
  final Timestamp timestamp;
  
  // Location fields
  final double? latitude;
  final double? longitude;

  // NEW: Moderation fields
  final bool? isRemoved;
  final int? flagCount;

  PropertyModel({
    required this.id,
    required this.title,
    required this.price,
    required this.type,
    required this.address,
    required this.description,
    this.imageUrl,
    required this.sellerId,
    required this.timestamp,
    this.latitude, 
    this.longitude,
    // NEW
    this.isRemoved,
    this.flagCount,
  });

  factory PropertyModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Helper function for safe double parsing
    double? parseDouble(dynamic value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return null;
    }

    return PropertyModel(
      id: doc.id,
      title: data['title'] ?? 'N/A',
      price: data['price'] ?? 0,
      type: data['type'] ?? 'N/A',
      address: data['address'] ?? 'N/A',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] as String?,
      sellerId: data['sellerId'] ?? 'N/A',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      
      // Location fields
      latitude: parseDouble(data['latitude']),
      longitude: parseDouble(data['longitude']),

      // NEW: Moderation fields
      isRemoved: data['isRemoved'] as bool? ?? false,
      flagCount: data['flagCount'] as int? ?? 0,
    );
  }
}