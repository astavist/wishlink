import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../screens/user_profile_screen.dart';
import '../screens/friends_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Load friend requests
      final requests = await _firestoreService.getFriendRequests();
      final incomingRequests = requests['incoming'] ?? [];

      // Load read status for notifications
      final readNotificationsSnapshot = await _firestore
          .collection('notifications')
          .where('isRead', isEqualTo: true)
          .get();
      final readNotificationIds = readNotificationsSnapshot.docs
          .map((doc) => doc.id)
          .toSet();

      // Load recent friend activities (wish additions)
      final recentActivities = await _firestore
          .collection('friend_activities')
          .where('activityType', isEqualTo: 'added')
          .orderBy('activityTime', descending: true)
          .limit(50)
          .get();

      final notifications = <NotificationItem>[];

      // Add friend request notifications
      for (final request in incomingRequests) {
        final requesterId = request['userId'] as String;
        final userData = await _firestoreService.getUserProfile(requesterId);

        if (userData != null) {
          final userDataMap = userData.data() as Map<String, dynamic>;
          notifications.add(
            NotificationItem(
              id: request.id,
              type: NotificationType.friendRequest,
              title: 'New Friend Request',
              message:
                  '${userDataMap['firstName']} ${userDataMap['lastName']} sent you a friend request',
              userId: requesterId,
              userName:
                  '${userDataMap['firstName']} ${userDataMap['lastName']}',
              timestamp: request['timestamp'] as Timestamp? ?? Timestamp.now(),
              isRead: readNotificationIds.contains(request.id),
            ),
          );
        }
      }

      // Add wish notifications (only for friends)
      final friends = await _firestoreService.getFriends();
      final friendIds = friends.map((f) => f['friendId'] as String).toSet();

      for (final activity in recentActivities.docs) {
        final activityData = activity.data();
        final activityUserId = activityData['userId'] as String;

        // Only show notifications for friends' activities
        if (friendIds.contains(activityUserId) &&
            activityUserId != currentUserId) {
          final userData = await _firestoreService.getUserProfile(
            activityUserId,
          );

          if (userData != null) {
            final userDataMap = userData.data() as Map<String, dynamic>;
            final wishData = activityData['wishItem'] as Map<String, dynamic>;

            notifications.add(
              NotificationItem(
                id: activity.id,
                type: NotificationType.newWish,
                title: 'New Wish Added',
                message:
                    '${userDataMap['firstName']} ${userDataMap['lastName']} added "${wishData['name']}" to their wishlist',
                userId: activityUserId,
                userName:
                    '${userDataMap['firstName']} ${userDataMap['lastName']}',
                wishId: wishData['id'] as String? ?? '',
                wishName: wishData['name'] as String? ?? '',
                timestamp:
                    activityData['activityTime'] as Timestamp? ??
                    Timestamp.now(),
                isRead: readNotificationIds.contains(activity.id),
              ),
            );
          }
        }
      }

      // Sort by timestamp (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading notifications')),
        );
      }
    }
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications();
  }

  void _onNotificationTap(NotificationItem notification) async {
    // Mark as read
    await _markAsRead(notification.id);

    if (notification.type == NotificationType.friendRequest) {
      // Navigate to Friends screen with incoming requests tab
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FriendsScreen(initialTabIndex: 1),
          ),
        );
      }
    } else if (notification.type == NotificationType.newWish) {
      // Navigate to user's profile
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(
              userId: notification.userId,
              userName: notification.userName,
            ),
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      // Mark as read in Firestore
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });

      // Update local state
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
        }
      });
    } catch (e) {
      // If notification document doesn't exist, create it
      try {
        await _firestore.collection('notifications').doc(notificationId).set({
          'isRead': true,
          'timestamp': FieldValue.serverTimestamp(),
        });

        setState(() {
          final index = _notifications.indexWhere(
            (n) => n.id == notificationId,
          );
          if (index != -1) {
            _notifications[index] = _notifications[index].copyWith(
              isRead: true,
            );
          }
        });
      } catch (e) {
        // Fallback to local state only
        setState(() {
          final index = _notifications.indexWhere(
            (n) => n.id == notificationId,
          );
          if (index != -1) {
            _notifications[index] = _notifications[index].copyWith(
              isRead: true,
            );
          }
        });
      }
    }
  }

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Icon _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequest:
        return const Icon(Icons.person_add, color: Colors.blue);
      case NotificationType.newWish:
        return const Icon(Icons.favorite, color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshNotifications,
              child: _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You\'ll see friend requests and new wishes here',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: _getNotificationIcon(notification.type),
                            ),
                            title: Text(
                              notification.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.message,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getTimeAgo(notification.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            trailing: notification.isRead
                                ? null
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            onTap: () => _onNotificationTap(notification),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

enum NotificationType { friendRequest, newWish }

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String userId;
  final String userName;
  final String? wishId;
  final String? wishName;
  final Timestamp timestamp;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.userId,
    required this.userName,
    this.wishId,
    this.wishName,
    required this.timestamp,
    required this.isRead,
  });

  NotificationItem copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    String? userId,
    String? userName,
    String? wishId,
    String? wishName,
    Timestamp? timestamp,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      wishId: wishId ?? this.wishId,
      wishName: wishName ?? this.wishName,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
