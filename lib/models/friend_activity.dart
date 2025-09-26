import 'package:cloud_firestore/cloud_firestore.dart';
import 'wish_item.dart';

class FriendActivity {
  final String id;
  final String userId;
  final String userName;
  final String userUsername;
  final String userAvatarUrl;
  final WishItem wishItem;
  final DateTime activityTime;
  final String activityType; // 'added', 'liked', 'shared', etc.
  final String? activityDescription;
  final int likesCount;
  final int commentsCount;
  final List<String> likedUserIds;

  FriendActivity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userUsername,
    required this.userAvatarUrl,
    required this.wishItem,
    required this.activityTime,
    required this.activityType,
    this.activityDescription,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedUserIds = const [],
  });

  factory FriendActivity.fromMap(Map<String, dynamic> data, String id) {
    return FriendActivity(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userUsername: data['userUsername'] ?? '',
      userAvatarUrl: data['userAvatarUrl'] ?? '',
      wishItem: WishItem.fromMap(
        data['wishItem'] ?? {},
        data['wishItemId'] ?? '',
      ),
      activityTime: (data['activityTime'] as Timestamp).toDate(),
      activityType: data['activityType'] ?? 'added',
      activityDescription: data['activityDescription'],
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      likedUserIds: List<String>.from(data['likedUserIds'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userUsername': userUsername,
      'userAvatarUrl': userAvatarUrl,
      'wishItem': wishItem.toMap(),
      'wishItemId': wishItem.id,
      'activityTime': Timestamp.fromDate(activityTime),
      'activityType': activityType,
      'activityDescription': activityDescription,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'likedUserIds': likedUserIds,
    };
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(activityTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
