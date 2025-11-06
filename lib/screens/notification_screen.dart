import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../screens/user_profile_screen.dart';
import '../screens/friends_screen.dart';

// Custom page route for right-to-left slide animation
PageRouteBuilder<dynamic> _createSlideRoute(Widget page) {
  return PageRouteBuilder<dynamic>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);

      return SlideTransition(position: offsetAnimation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not authenticated';
        });
        return;
      }

      // Batch operations to reduce Firestore calls
      final batchResults = await Future.wait([
        _firestoreService.getFriendRequests(),
        _firestoreService.getFriendIds(),
        _firestore
            .collection('notifications')
            .doc(currentUserId)
            .collection('items')
            .where('isRead', isEqualTo: true)
            .get(),
        _firestore
            .collection('friend_activities')
            .where('activityType', isEqualTo: 'added')
            .orderBy('activityTime', descending: true)
            .limit(20) // Reduced from 50 to 20
            .get(),
      ], eagerError: true);

      final requests = batchResults[0] as Map<String, List<DocumentSnapshot>>;
      final friendIds = batchResults[1] as List<String>;
      final readNotificationsSnapshot = batchResults[2] as QuerySnapshot;
      final recentActivities = batchResults[3] as QuerySnapshot;

      final incomingRequests = requests['incoming'] ?? [];
      final readNotificationIds = readNotificationsSnapshot.docs
          .map((doc) => doc.id)
          .toSet();

      final notifications = <NotificationItem>[];

      // Process friend requests
      if (incomingRequests.isNotEmpty) {
        final requesterIds = incomingRequests
            .map((doc) => doc['userId'] as String)
            .toSet();

        // Batch fetch user profiles for friend requests
        final userProfiles = <String, Map<String, dynamic>>{};
        for (final requesterId in requesterIds) {
          try {
            final userData = await _firestoreService.getUserProfile(
              requesterId,
            );
            if (userData != null) {
              userProfiles[requesterId] =
                  userData.data() as Map<String, dynamic>;
            }
          } catch (e) {
            // Skip this user if profile fetch fails
            continue;
          }
        }

        for (final request in incomingRequests) {
          final requesterId = request['userId'] as String;
          final userData = userProfiles[requesterId];

          if (userData != null) {
            // Safely get timestamp from request document
            Timestamp requestTimestamp;
            try {
              final requestData = request.data() as Map<String, dynamic>?;
              // Try to get timestamp from different possible fields
              if (requestData != null && requestData.containsKey('timestamp')) {
                requestTimestamp = request['timestamp'] as Timestamp;
              } else if (requestData != null &&
                  requestData.containsKey('createdAt')) {
                requestTimestamp = request['createdAt'] as Timestamp;
              } else {
                // If no timestamp field exists, use current time
                requestTimestamp = Timestamp.now();
              }
            } catch (e) {
              // Fallback to current time if timestamp parsing fails
              requestTimestamp = Timestamp.now();
            }

            notifications.add(
              NotificationItem(
                id: request.id,
                type: NotificationType.friendRequest,
                title: 'New Friend Request',
                message:
                    '${userData['firstName']} ${userData['lastName']} sent you a friend request',
                userId: requesterId,
                userName: '${userData['firstName']} ${userData['lastName']}',
                timestamp: requestTimestamp,
                isRead: readNotificationIds.contains(request.id),
              ),
            );
          }
        }
      }

      // Process wish notifications (only for friends)
      if (recentActivities.docs.isNotEmpty && friendIds.isNotEmpty) {
        final activityUserIds = recentActivities.docs
            .map((doc) => doc['userId'] as String)
            .where((id) => friendIds.contains(id) && id != currentUserId)
            .toSet();

        if (activityUserIds.isNotEmpty) {
          // Batch fetch user profiles for activities
          final activityUserProfiles = <String, Map<String, dynamic>>{};
          for (final userId in activityUserIds) {
            try {
              final userData = await _firestoreService.getUserProfile(userId);
              if (userData != null) {
                activityUserProfiles[userId] =
                    userData.data() as Map<String, dynamic>;
              }
            } catch (e) {
              // Skip this user if profile fetch fails
              continue;
            }
          }

          for (final activity in recentActivities.docs) {
            final activityData = activity.data() as Map<String, dynamic>;
            final activityUserId = activityData['userId'] as String;

            // Only show notifications for friends' activities
            if (friendIds.contains(activityUserId) &&
                activityUserId != currentUserId) {
              final userData = activityUserProfiles[activityUserId];

              if (userData != null) {
                final wishData =
                    activityData['wishItem'] as Map<String, dynamic>?;
                if (wishData != null) {
                  // Safely get timestamp from activity document
                  Timestamp activityTimestamp;
                  try {
                    if (activityData.containsKey('activityTime')) {
                      activityTimestamp =
                          activityData['activityTime'] as Timestamp;
                    } else if (activityData.containsKey('timestamp')) {
                      activityTimestamp =
                          activityData['timestamp'] as Timestamp;
                    } else if (activityData.containsKey('createdAt')) {
                      activityTimestamp =
                          activityData['createdAt'] as Timestamp;
                    } else {
                      // If no timestamp field exists, use current time
                      activityTimestamp = Timestamp.now();
                    }
                  } catch (e) {
                    // Fallback to current time if timestamp parsing fails
                    activityTimestamp = Timestamp.now();
                  }

                  notifications.add(
                    NotificationItem(
                      id: activity.id,
                      type: NotificationType.newWish,
                      title: 'New Wish Added',
                      message:
                          '${userData['firstName']} ${userData['lastName']} added "${wishData['name']}" to their wishlist',
                      userId: activityUserId,
                      userName:
                          '${userData['firstName']} ${userData['lastName']}',
                      wishId: wishData['id'] as String? ?? '',
                      wishName: wishData['name'] as String? ?? '',
                      timestamp: activityTimestamp,
                      isRead: readNotificationIds.contains(activity.id),
                    ),
                  );
                }
              }
            }
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
        _errorMessage = 'Error loading notifications: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading notifications: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
          _createSlideRoute(const FriendsScreen(initialTabIndex: 1)),
        );
      }
    } else if (notification.type == NotificationType.newWish) {
      // Navigate to user's profile
      if (mounted) {
        Navigator.push(
          context,
          _createSlideRoute(
            UserProfileScreen(
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
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final __uid = _auth.currentUser?.uid;
      if (__uid == null) return;

      await _firestore
          .collection('notifications')
          .doc(__uid)
          .collection('items')
          .doc(notificationId)
          .update({
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
        final __uid2 = _auth.currentUser?.uid; if (__uid2 == null) return;
        await _firestore
            .collection('notifications')
            .doc(__uid2)
            .collection('items')
            .doc(notificationId)
            .set({
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
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notifications',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshNotifications,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
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
