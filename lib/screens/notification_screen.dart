import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wishlink/l10n/app_localizations.dart';

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
  final Set<String> _locallyReadNotificationIds = <String>{};
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    final l10n = context.l10n;
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.t('notifications.userNotAuthenticated');
        });
        return;
      }

      // Batch operations to reduce Firestore calls
      final batchResults = await Future.wait([
        _firestoreService.getFriendRequests(),
        _firestoreService.getAcceptedFriendships(),
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
      final friendships = batchResults[1] as List<FriendshipRecord>;
      final readNotificationsSnapshot = batchResults[2] as QuerySnapshot;
      final recentActivities = batchResults[3] as QuerySnapshot;

      final incomingRequests = requests['incoming'] ?? [];
      final readNotificationIds = readNotificationsSnapshot.docs
          .map((doc) => doc.id)
          .toSet();

      final friendIds = friendships
          .map((friendship) => friendship.friendId)
          .where((id) => id.isNotEmpty)
          .toSet();

      final friendshipStartTimes = <String, Timestamp?>{};
      for (final friendship in friendships) {
        final friendId = friendship.friendId;
        final currentTimestamp = friendshipStartTimes[friendId];
        final candidate = friendship.createdAt;

        if (currentTimestamp == null) {
          friendshipStartTimes[friendId] = candidate;
          continue;
        }

        if (candidate != null &&
            currentTimestamp != null &&
            candidate.compareTo(currentTimestamp) < 0) {
          friendshipStartTimes[friendId] = candidate;
        }
      }

      final profileIds = <String>{};
      for (final request in incomingRequests) {
        final requesterId = request['userId'] as String? ?? '';
        if (requesterId.isNotEmpty) {
          profileIds.add(requesterId);
        }
      }
      for (final friendship in friendships) {
        if (friendship.friendId.isNotEmpty) {
          profileIds.add(friendship.friendId);
        }
      }
      for (final activity in recentActivities.docs) {
        final activityData = activity.data() as Map<String, dynamic>;
        final activityUserId = activityData['userId'] as String? ?? '';
        if (activityUserId.isNotEmpty) {
          profileIds.add(activityUserId);
        }
      }

      final userProfileCache =
          await _firestoreService.getUserProfilesByIds(profileIds);
      final missingProfiles = <String>{};

      Future<Map<String, dynamic>?> loadUserProfile(String userId) async {
        if (userId.isEmpty) return null;

        final cached = userProfileCache[userId];
        if (cached != null) {
          return cached;
        }
        if (missingProfiles.contains(userId)) {
          return null;
        }

        try {
          final userData = await _firestoreService.getUserProfile(userId);
          final data = userData?.data() as Map<String, dynamic>?;
          if (data != null) {
            userProfileCache[userId] = data;
            return data;
          }
        } catch (_) {
          // Ignore errors per user for robustness
        }

        missingProfiles.add(userId);
        return null;
      }

      final notifications = <NotificationItem>[];

      // Process friend requests
      if (incomingRequests.isNotEmpty) {
        for (final request in incomingRequests) {
          final requesterId = request['userId'] as String;
          final userData = await loadUserProfile(requesterId);

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

            final displayName = _buildDisplayName(
              userData: userData,
              l10n: l10n,
            );
            final avatarUrl = _extractAvatarUrl(userData);
            final usernameValue = _extractUsername(userData);
            final message = l10n.t(
              'notifications.friendRequestMessage',
              params: {'user': displayName},
            );
            final messageSuffix = _buildMessageSuffix(message, displayName);

            notifications.add(
              NotificationItem(
                id: request.id,
                type: NotificationType.friendRequest,
                title: l10n.t('notifications.friendRequestTitle'),
                message: message,
                messageSuffix: messageSuffix,
                userId: requesterId,
                userName: displayName,
                userUsername: usernameValue,
                userAvatarUrl: avatarUrl,
                timestamp: requestTimestamp,
                isRead: readNotificationIds.contains(request.id),
              ),
            );
          }
        }
      }

      // Process newly accepted friendships (recent ones only)
      if (friendships.isNotEmpty) {
        final friendshipCutoff =
            DateTime.now().subtract(const Duration(days: 30));

        for (final friendship in friendships) {
          final acceptedAt = friendship.createdAt;
          if (acceptedAt == null) continue;
          if (acceptedAt.toDate().isBefore(friendshipCutoff)) continue;

          final userData = await loadUserProfile(friendship.friendId);
          if (userData == null) continue;

          final displayName = _buildDisplayName(
            userData: userData,
            l10n: l10n,
          );
          final avatarUrl = _extractAvatarUrl(userData);
          final usernameValue = _extractUsername(userData);
          final friendshipNotificationId = 'friendship_${friendship.documentId}';
          final message = l10n.t(
            'notifications.friendshipAcceptedMessage',
            params: {'user': displayName},
          );
          final messageSuffix = _buildMessageSuffix(message, displayName);

          notifications.add(
            NotificationItem(
              id: friendshipNotificationId,
              type: NotificationType.friendshipAccepted,
              title: l10n.t('notifications.friendshipAcceptedTitle'),
              message: message,
              messageSuffix: messageSuffix,
              userId: friendship.friendId,
              userName: displayName,
              userUsername: usernameValue,
              userAvatarUrl: avatarUrl,
              timestamp: acceptedAt,
              isRead: readNotificationIds.contains(friendshipNotificationId),
            ),
          );
        }
      }

      // Process wish notifications (only for friends)
      if (recentActivities.docs.isNotEmpty && friendIds.isNotEmpty) {
        for (final activity in recentActivities.docs) {
          final activityData = activity.data() as Map<String, dynamic>;
          final activityUserId = activityData['userId'] as String;

          // Only show notifications for friends' activities
          if (!friendIds.contains(activityUserId) ||
              activityUserId == currentUserId) {
            continue;
          }

          // Safely get timestamp from activity document
          Timestamp activityTimestamp;
          try {
            if (activityData.containsKey('activityTime')) {
              activityTimestamp = activityData['activityTime'] as Timestamp;
            } else if (activityData.containsKey('timestamp')) {
              activityTimestamp = activityData['timestamp'] as Timestamp;
            } else if (activityData.containsKey('createdAt')) {
              activityTimestamp = activityData['createdAt'] as Timestamp;
            } else {
              activityTimestamp = Timestamp.now();
            }
          } catch (e) {
            activityTimestamp = Timestamp.now();
          }

          final friendSince = friendshipStartTimes[activityUserId];
          if (friendSince != null &&
              activityTimestamp.compareTo(friendSince) < 0) {
            continue;
          }

          final userData = await loadUserProfile(activityUserId);
          final wishData = activityData['wishItem'] as Map<String, dynamic>?;
          if (wishData == null) continue;

          final fallbackName = (activityData['userName'] as String?)?.trim();
          final fallbackUsername =
              (activityData['userUsername'] as String?)?.trim();
          final fallbackAvatar =
              (activityData['userAvatarUrl'] as String?)?.trim();

          final displayName = _buildDisplayName(
            userData: userData,
            fallbackName: fallbackName,
            fallbackUsername: fallbackUsername,
            l10n: l10n,
          );
          final avatarUrl = _extractAvatarUrl(
            userData,
            fallback: fallbackAvatar,
          );
          final usernameValue = _extractUsername(
            userData,
            fallback: fallbackUsername,
          );
          final rawWishName = (wishData['name'] as String?)?.trim() ?? '';
          final displayWishName = rawWishName.isEmpty
              ? l10n.t('notifications.unknownWishFallback')
              : rawWishName;

          final message = l10n.t(
            'notifications.newWishMessage',
            params: {'user': displayName, 'wish': displayWishName},
          );
          final messageSuffix = _buildMessageSuffix(message, displayName);

          notifications.add(
            NotificationItem(
              id: activity.id,
              type: NotificationType.newWish,
              title: l10n.t('notifications.newWishTitle'),
              message: message,
              messageSuffix: messageSuffix,
              userId: activityUserId,
              userName: displayName,
              userUsername: usernameValue,
              userAvatarUrl: avatarUrl,
              wishId: wishData['id'] as String? ?? '',
              wishName: displayWishName,
              timestamp: activityTimestamp,
              isRead: readNotificationIds.contains(activity.id),
            ),
          );
        }
      }

      // Sort by timestamp (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        final visibleIds = notifications.map((n) => n.id).toSet();
        _locallyReadNotificationIds.removeWhere(
          (id) => !visibleIds.contains(id),
        );
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.t(
          'notifications.errorLoadingWithReason',
          params: {'error': e.toString()},
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.t(
                'notifications.errorLoadingWithReason',
                params: {'error': e.toString()},
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications();
  }

  Future<void> _markAllNotificationsAsRead() async {
    final unreadNotificationIds = _notifications
        .where(
          (notification) =>
              !(notification.isRead ||
                  _locallyReadNotificationIds.contains(notification.id)),
        )
        .map((notification) => notification.id)
        .toList();

    if (unreadNotificationIds.isEmpty) {
      return;
    }

    setState(() {
      _locallyReadNotificationIds.addAll(unreadNotificationIds);
      _notifications = _notifications
          .map((notification) => notification.copyWith(isRead: true))
          .toList();
    });

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return;
    }

    final batch = _firestore.batch();
    final itemsCollection = _firestore
        .collection('notifications')
        .doc(currentUserId)
        .collection('items');

    for (final notificationId in unreadNotificationIds) {
      batch.set(
        itemsCollection.doc(notificationId),
        {'isRead': true},
        SetOptions(merge: true),
      );
    }

    try {
      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('common.tryAgain')),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    } else if (notification.type == NotificationType.friendshipAccepted ||
        notification.type == NotificationType.newWish) {
      // Navigate to user's profile
      if (mounted) {
        Navigator.push(
          context,
          _createSlideRoute(
            UserProfileScreen(
              userId: notification.userId,
              userName: notification.userName,
              userUsername: notification.userUsername,
            ),
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    _updateNotificationReadState(notificationId);
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
          .update({'isRead': true});
    } catch (e) {
      // If notification document doesn't exist, create it
      try {
        final __uid2 = _auth.currentUser?.uid;
        if (__uid2 == null) return;
        await _firestore
            .collection('notifications')
            .doc(__uid2)
            .collection('items')
            .doc(notificationId)
            .set({'isRead': true, 'timestamp': FieldValue.serverTimestamp()});
      } catch (e) {
        // Fallback to local state only
        _updateNotificationReadState(notificationId);
      }
    }
  }

  void _updateNotificationReadState(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    final alreadyLocallyRead =
        _locallyReadNotificationIds.contains(notificationId);
    final alreadyRead =
        index != -1 ? _notifications[index].isRead : false;

    if (alreadyLocallyRead && alreadyRead) {
      return;
    }

    setState(() {
      _locallyReadNotificationIds.add(notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] =
            _notifications[index].copyWith(isRead: true);
      }
    });
  }

  String _buildDisplayName({
    Map<String, dynamic>? userData,
    String? fallbackName,
    String? fallbackUsername,
    required AppLocalizations l10n,
  }) {
    final namePart =
        _composeFullName(userData, fallbackName: fallbackName) ?? '';
    final username = _extractUsername(
          userData,
          fallback: fallbackUsername,
        ) ??
        '';

    if (namePart.isNotEmpty && username.isNotEmpty) {
      return '$namePart(@$username)';
    }
    if (namePart.isNotEmpty) {
      return namePart;
    }
    if (username.isNotEmpty) {
      return '@$username';
    }

    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName.trim();
    }
    return l10n.t('friends.unknownUser');
  }

  String? _composeFullName(
    Map<String, dynamic>? userData, {
    String? fallbackName,
  }) {
    if (userData != null) {
      final firstName = (userData['firstName'] as String? ?? '').trim();
      final lastName = (userData['lastName'] as String? ?? '').trim();
      final combined = '$firstName $lastName'.trim();
      if (combined.isNotEmpty) {
        return combined;
      }

      final displayName = (userData['displayName'] as String? ?? '').trim();
      if (displayName.isNotEmpty) {
        return displayName;
      }
    }

    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName.trim();
    }

    return null;
  }

  String? _extractUsername(
    Map<String, dynamic>? userData, {
    String? fallback,
  }) {
    if (userData != null) {
      final direct = _normalizeUsername(userData['username'] as String?);
      if (direct != null) {
        return direct;
      }

      final legacy = _normalizeUsername(userData['userUsername'] as String?);
      if (legacy != null) {
        return legacy;
      }
    }

    return _normalizeUsername(fallback);
  }

  String? _normalizeUsername(String? username) {
    final trimmed = username?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }

  String? _extractAvatarUrl(
    Map<String, dynamic>? userData, {
    String? fallback,
  }) {
    if (userData != null) {
      final direct = (userData['profilePhotoUrl'] as String? ?? '').trim();
      if (direct.isNotEmpty) {
        return direct;
      }

      final legacy = (userData['photoUrl'] as String? ?? '').trim();
      if (legacy.isNotEmpty) {
        return legacy;
      }
    }

    final fallbackUrl = (fallback ?? '').trim();
    return fallbackUrl.isNotEmpty ? fallbackUrl : null;
  }

  String _buildMessageSuffix(String fullMessage, String displayName) {
    if (fullMessage.isEmpty) {
      return '';
    }

    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      return ' $fullMessage';
    }

    final index = fullMessage.indexOf(normalizedName);
    if (index == -1) {
      return ' $fullMessage';
    }

    return fullMessage.substring(index + normalizedName.length);
  }

  String _getTimeAgo(Timestamp timestamp) {
    return context.l10n.relativeTime(timestamp.toDate());
  }

  Widget _buildNotificationAvatar(NotificationItem notification) {
    final avatarUrl = notification.userAvatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return CircleAvatar(
      backgroundColor: _getAvatarBackgroundColor(notification.type),
      child: _getNotificationIcon(notification.type),
    );
  }

  Color _getAvatarBackgroundColor(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequest:
        return Colors.blue.shade100;
      case NotificationType.friendshipAccepted:
        return Colors.green.shade100;
      case NotificationType.newWish:
        return Colors.red.shade100;
    }
  }

  Icon _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequest:
        return const Icon(Icons.person_add, color: Colors.blue);
      case NotificationType.friendshipAccepted:
        return const Icon(Icons.people_alt, color: Colors.green);
      case NotificationType.newWish:
        return const Icon(Icons.favorite, color: Colors.red);
    }
  }

  List<TextSpan> _buildMessageTextSpans(NotificationItem notification) {
    final spans = <TextSpan>[];
    final userDisplay = notification.userName.trim();
    final hasUser = userDisplay.isNotEmpty;

    if (hasUser) {
      final fullMessage = notification.message;
      final nameIndex = fullMessage.indexOf(userDisplay);
      final prefix =
          nameIndex > 0 ? fullMessage.substring(0, nameIndex) : '';
      final suffix = notification.messageSuffix.isNotEmpty
          ? notification.messageSuffix
          : nameIndex >= 0
              ? fullMessage.substring(nameIndex + userDisplay.length)
              : ' $fullMessage';

      if (prefix.isNotEmpty) {
        spans.add(TextSpan(text: prefix));
      }

      spans.add(
        TextSpan(
          text: userDisplay,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );

      if (suffix.isNotEmpty) {
        spans.add(TextSpan(text: suffix));
      }
    } else {
      spans.add(TextSpan(text: notification.message));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasUnreadNotifications = _notifications.any(
      (notification) =>
          !(notification.isRead ||
              _locallyReadNotificationIds.contains(notification.id)),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('notifications.title')),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: l10n.t('notifications.markAllAsRead'),
            onPressed:
                hasUnreadNotifications ? _markAllNotificationsAsRead : null,
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
                    l10n.t('notifications.errorLoading'),
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
                    child: Text(l10n.t('notifications.retry')),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshNotifications,
              child: _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.t('notifications.emptyTitle'),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.t('notifications.emptySubtitle'),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        final isRead = notification.isRead ||
                            _locallyReadNotificationIds.contains(
                              notification.id,
                            );
                        final theme = Theme.of(context);
                        final textTheme = theme.textTheme;
                        final onSurface = theme.colorScheme.onSurface;
                        final timestampColor =
                            theme.colorScheme.onSurface.withValues(alpha: 0.6);
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: _buildNotificationAvatar(notification),
                            title: Text(
                              notification.title,
                              style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: onSurface,
                                  ) ??
                                  TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: onSurface,
                                  ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: textTheme.bodyMedium?.copyWith(
                                          color: onSurface,
                                          fontSize: 14,
                                        ) ??
                                        TextStyle(
                                          color: onSurface,
                                          fontSize: 14,
                                        ),
                                    children:
                                        _buildMessageTextSpans(notification),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getTimeAgo(notification.timestamp),
                                  style: textTheme.bodySmall?.copyWith(
                                        color: timestampColor,
                                      ) ??
                                      TextStyle(
                                        fontSize: 12,
                                        color: timestampColor,
                                      ),
                                ),
                              ],
                            ),
                            trailing: isRead
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

enum NotificationType { friendRequest, friendshipAccepted, newWish }

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String messageSuffix;
  final String userId;
  final String userName;
  final String? userUsername;
  final String? userAvatarUrl;
  final String? wishId;
  final String? wishName;
  final Timestamp timestamp;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.messageSuffix,
    required this.userId,
    required this.userName,
    this.userUsername,
    this.userAvatarUrl,
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
    String? messageSuffix,
    String? userId,
    String? userName,
    String? userUsername,
    String? userAvatarUrl,
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
      messageSuffix: messageSuffix ?? this.messageSuffix,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userUsername: userUsername ?? this.userUsername,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      wishId: wishId ?? this.wishId,
      wishName: wishName ?? this.wishName,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
