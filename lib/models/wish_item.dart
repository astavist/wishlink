import 'package:cloud_firestore/cloud_firestore.dart';

class WishItem {
  final String id;
  final String name;
  final String description;
  final String productUrl;
  final String imageUrl;
  final DateTime createdAt;

  WishItem({
    required this.id,
    required this.name,
    required this.description,
    required this.productUrl,
    required this.imageUrl,
    required this.createdAt,
  });

  factory WishItem.fromMap(Map<String, dynamic> data, String id) {
    return WishItem(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      productUrl: data['productUrl'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'productUrl': productUrl,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
    };
  }
}
