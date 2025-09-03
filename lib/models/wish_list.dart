import 'package:cloud_firestore/cloud_firestore.dart';

class WishList {
  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;
  final String coverImageUrl;

  WishList({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    this.coverImageUrl = '',
  });

  factory WishList.fromMap(Map<String, dynamic> data, String id) {
    return WishList(
      id: id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      coverImageUrl: data['coverImageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'createdAt': createdAt,
      'coverImageUrl': coverImageUrl,
    };
  }
}
