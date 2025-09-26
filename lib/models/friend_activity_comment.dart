import 'package:cloud_firestore/cloud_firestore.dart';

class FriendActivityComment {
  final String id;
  final String userId;
  final String userName;
  final String userUsername;
  final String? profilePhotoUrl;
  final String comment;
  final DateTime createdAt;

  FriendActivityComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userUsername,
    this.profilePhotoUrl,
    required this.comment,
    required this.createdAt,
  });

  factory FriendActivityComment.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'] as Timestamp?;

    return FriendActivityComment(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userUsername: data['userUsername'] as String? ?? '',
      profilePhotoUrl: data['profilePhotoUrl'] as String?,
      comment: data['comment'] as String? ?? '',
      createdAt: timestamp != null ? timestamp.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userUsername': userUsername,
      'profilePhotoUrl': profilePhotoUrl,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
