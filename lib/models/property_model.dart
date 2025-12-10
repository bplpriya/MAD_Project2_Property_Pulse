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

  // Moderation fields
  final bool? isRemoved;
  final int? flagCount;

  // NEW: Transaction/Sale fields
  final bool? isSold;
  final String? soldToId;
  final Timestamp? saleTimestamp;

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
    // Moderation fields
    this.isRemoved,
    this.flagCount,
    // NEW: Transaction/Sale fields
    this.isSold,
    this.soldToId,
    this.saleTimestamp,
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

      // Moderation fields (using default values for safety)
      isRemoved: data['isRemoved'] as bool? ?? false,
      flagCount: data['flagCount'] as int? ?? 0,

      // NEW: Transaction/Sale fields
      isSold: data['isSold'] as bool? ?? false,
      soldToId: data['soldToId'] as String?,
      saleTimestamp: data['saleTimestamp'] as Timestamp?,
    );
  }
}