import 'package:cloud_firestore/cloud_firestore.dart';

class WishItem {
  final String id;
  final String name;
  final String description;
  final String productUrl;
  final String imageUrl;
  final double price;
  final String currency;
  final DateTime createdAt;
  final String? listId;

  WishItem({
    required this.id,
    required this.name,
    required this.description,
    required this.productUrl,
    required this.imageUrl,
    required this.price,
    required this.currency,
    required this.createdAt,
    this.listId,
  });

  factory WishItem.fromMap(Map<String, dynamic> data, String id) {
    final createdAtValue = data['createdAt'];
    final createdAt = createdAtValue is Timestamp
        ? createdAtValue.toDate()
        : createdAtValue is DateTime
            ? createdAtValue
            : DateTime.now();

    return WishItem(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      productUrl: data['productUrl'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      currency: (data['currency'] as String?)?.toUpperCase() ?? 'TRY',
      createdAt: createdAt,
      listId: data['listId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'productUrl': productUrl,
      'imageUrl': imageUrl,
      'price': price,
      'currency': currency,
      'createdAt': createdAt,
      if (listId != null) 'listId': listId,
    };
  }
}
