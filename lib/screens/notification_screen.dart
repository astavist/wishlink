import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import 'package:wishlink/theme/app_theme.dart';

import '../models/wish_item.dart';
import '../screens/friends_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/wish_detail_screen.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../widgets/wishlink_card.dart';

const LinearGradient _lightNotificationsBackground = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFDFDFD), Color(0xFFF2F8FF)],
);

const LinearGradient _darkNotificationsBackground = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF1F1F1F), Color(0xFF101216)],
);

const LinearGradient _unreadCardFallbackGradientLight = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFF4DC), Color(0xFFFDE9C9)],
);

const LinearGradient _readCardFallbackGradientLight = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFF8F1), Color(0xFFF8FDF9)],
);

const LinearGradient _unreadCardFallbackGradientDark = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF2F251C), Color(0xFF1F1812)],
);

const LinearGradient _readCardFallbackGradientDark = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF292019), Color(0xFF1A150F)],
);

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
  final ScrollController _scrollController = ScrollController();

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleLogoTap() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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

      final userProfileCache = await _firestoreService.getUserProfilesByIds(
        profileIds,
      );
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
        final friendshipCutoff = DateTime.now().subtract(
          const Duration(days: 30),
        );

        for (final friendship in friendships) {
          final acceptedAt = friendship.createdAt;
          if (acceptedAt == null) continue;
          if (acceptedAt.toDate().isBefore(friendshipCutoff)) continue;

          final userData = await loadUserProfile(friendship.friendId);
          if (userData == null) continue;

          final displayName = _buildDisplayName(userData: userData, l10n: l10n);
          final avatarUrl = _extractAvatarUrl(userData);
          final usernameValue = _extractUsername(userData);
          final friendshipNotificationId =
              'friendship_${friendship.documentId}';
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
          final fallbackUsername = (activityData['userUsername'] as String?)
              ?.trim();
          final fallbackAvatar = (activityData['userAvatarUrl'] as String?)
              ?.trim();

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

          final candidateWishIdSources = [
            activityData['wishItemId'] as String?,
            wishData['wishItemId'] as String?,
            wishData['id'] as String?,
            wishData['wishId'] as String?,
          ];
          final normalizedWishId = candidateWishIdSources
                  .firstWhere(
                    (value) => (value?.trim().isNotEmpty ?? false),
                    orElse: () => null,
                  )
                  ?.trim() ??
              '';

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
              wishId: normalizedWishId.isNotEmpty ? normalizedWishId : null,
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
      batch.set(itemsCollection.doc(notificationId), {
        'isRead': true,
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
      await _clearBadgeIfNoUnread();
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
      _openFriendsScreen();
      return;
    }

    if (notification.type == NotificationType.friendshipAccepted) {
      _openUserProfile(notification);
      return;
    }

    if (notification.type == NotificationType.newWish) {
      final wishId = notification.wishId;
      if (wishId != null && wishId.isNotEmpty) {
        await _openWishDetail(wishId);
        return;
      }
      _openUserProfile(notification);
    }
  }

  void _openFriendsScreen() {
    if (!mounted) {
      return;
    }
    Navigator.push(
      context,
      _createSlideRoute(const FriendsScreen(initialTabIndex: 1)),
    );
  }

  void _openUserProfile(NotificationItem notification) {
    if (!mounted) {
      return;
    }
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

  Future<void> _openWishDetail(String wishId) async {
    if (wishId.isEmpty) {
      return;
    }

    final l10n = context.l10n;

    try {
      final activity = await _firestoreService.fetchActivityForWish(wishId);
      if (activity != null) {
        if (!mounted) {
          return;
        }

        Navigator.push(
          context,
          _createSlideRoute(WishDetailScreen(wish: activity.wishItem)),
        );
        return;
      }
    } catch (_) {
      // ignore, fallback to direct wish document
    }

    try {
      final snapshot = await _firestore.collection('wishes').doc(wishId).get();
      final data = snapshot.data();
      if (data == null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('common.tryAgain')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final wish = WishItem.fromMap(data, snapshot.id);
      if (!mounted) {
        return;
      }
      Navigator.push(
        context,
        _createSlideRoute(WishDetailScreen(wish: wish)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('common.tryAgain')),
          backgroundColor: Colors.red,
        ),
      );
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
    await _clearBadgeIfNoUnread();
  }
  }

  void _updateNotificationReadState(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    final alreadyLocallyRead = _locallyReadNotificationIds.contains(
      notificationId,
    );
    final alreadyRead = index != -1 ? _notifications[index].isRead : false;

    if (alreadyLocallyRead && alreadyRead) {
      return;
    }

    setState(() {
      _locallyReadNotificationIds.add(notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      }
    });
  }

  bool _hasUnreadNotifications() {
    return _notifications.any(
      (notification) =>
          !(notification.isRead ||
              _locallyReadNotificationIds.contains(notification.id)),
    );
  }

  Future<void> _clearBadgeIfNoUnread() async {
    if (_hasUnreadNotifications()) {
      return;
    }
    await NotificationService.instance.clearBadge();
  }

  String _buildDisplayName({
    Map<String, dynamic>? userData,
    String? fallbackName,
    String? fallbackUsername,
    required AppLocalizations l10n,
  }) {
    final namePart =
        _composeFullName(userData, fallbackName: fallbackName) ?? '';
    final username =
        _extractUsername(userData, fallback: fallbackUsername) ?? '';

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

  String? _extractUsername(Map<String, dynamic>? userData, {String? fallback}) {
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

  String _buildNormalizedSuffix(NotificationItem notification) {
    final rawBody = notification.messageSuffix.isNotEmpty
        ? notification.messageSuffix
        : _removeUserNameFromMessage(
            notification.message,
            notification.userName,
          );
    final normalized = _normalizeInline(
      rawBody.isNotEmpty ? rawBody : notification.message,
    );
    return normalized;
  }

  String _removeUserNameFromMessage(String message, String userName) {
    final candidate = _normalizeInline(userName);
    if (candidate.isEmpty) {
      return message;
    }
    final normalizedMessage = _normalizeInline(message);
    final index = normalizedMessage.indexOf(candidate);
    if (index == -1) {
      return message;
    }
    return normalizedMessage.substring(index + candidate.length);
  }

  String _normalizeInline(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _extractNameOnly(String displayName) {
    final normalizedDisplayName = _normalizeInline(displayName);
    if (normalizedDisplayName.isEmpty) {
      return '';
    }

    final parenIndex = normalizedDisplayName.indexOf('(@');
    if (parenIndex != -1) {
      return normalizedDisplayName.substring(0, parenIndex).trim();
    }

    if (normalizedDisplayName.startsWith('@')) {
      return '';
    }

    return normalizedDisplayName;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final gradients = theme.extension<WishLinkGradients>();
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    final hasUnreadNotifications = _notifications.any(
      (notification) =>
          !(notification.isRead ||
              _locallyReadNotificationIds.contains(notification.id)),
    );

    return Scaffold(
      extendBody: true,
      backgroundColor:
          theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      appBar: AppBar(
        titleSpacing: Navigator.canPop(context) ? 0 : 16,
        title: GestureDetector(
          onTap: _handleLogoTap,
          behavior: HitTestBehavior.opaque,
          child: Text(l10n.t('notifications.title'), style: titleStyle),
        ),
        centerTitle: false,
        leadingWidth: Navigator.canPop(context) ? 56 : 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: hasUnreadNotifications
                    ? theme.colorScheme.primary.withOpacity(0.18)
                    : theme.colorScheme.surface.withOpacity(
                        theme.brightness == Brightness.dark ? 0.25 : 0.7,
                      ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(
                    hasUnreadNotifications ? 0.5 : 0.25,
                  ),
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.done_all_rounded),
                tooltip: l10n.t('notifications.markAllAsRead'),
                onPressed: hasUnreadNotifications
                    ? _markAllNotificationsAsRead
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: gradients?.primary ?? _backgroundGradient(theme),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: _buildBodyContent(context),
        ),
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          child: _buildErrorStateCard(context),
        ),
      );
    }

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      displacement: 32,
      onRefresh: _refreshNotifications,
      child: _buildScrollableContent(context),
    );
  }

  Widget _buildScrollableContent(BuildContext context) {
    final bottomPadding =
        MediaQuery.paddingOf(context).bottom + 140; // room for bottom nav

    if (_notifications.isEmpty) {
      return ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(20, 32, 20, bottomPadding),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [_buildEmptyStateCard(context)],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _buildNotificationCard(context, _notifications[index]),
    );
  }

  Widget _buildEmptyStateCard(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final subtitleColor = theme.colorScheme.onSurface.withOpacity(
      theme.brightness == Brightness.dark ? 0.7 : 0.6,
    );

    return WishLinkCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('notifications.emptyTitle'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('notifications.emptySubtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(color: subtitleColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorStateCard(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final captionColor = theme.colorScheme.onSurface.withOpacity(
      theme.brightness == Brightness.dark ? 0.7 : 0.6,
    );

    return WishLinkCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('notifications.errorLoading'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(color: captionColor),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshNotifications,
            child: Text(l10n.t('notifications.retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationItem notification,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isRead =
        notification.isRead ||
        _locallyReadNotificationIds.contains(notification.id);
    final timestampColor = theme.colorScheme.onSurface.withOpacity(
      theme.brightness == Brightness.dark ? 0.65 : 0.55,
    );
    final userDisplay = _extractNameOnly(notification.userName);
    final normalizedUsername = _normalizeInline(notification.userUsername ?? '');
    final usernameDisplay =
        normalizedUsername.isNotEmpty ? '@$normalizedUsername' : '';
    final messageContent = _buildNormalizedSuffix(notification);

    return WishLinkCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      gradient: _resolveCardGradient(theme, isRead),
      onTap: () => _onNotificationTap(notification),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _buildNotificationAvatar(notification),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (userDisplay.isNotEmpty) ...[
                      Text(
                        userDisplay,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (usernameDisplay.isNotEmpty) ...[
                      Text(
                        usernameDisplay,
                        style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: 13,
                        ) ??
                            TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                            ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    _NotificationTitlePill(
                      title: notification.title,
                      theme: theme,
                      textTheme: textTheme,
                    ),
                    if (messageContent.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        messageContent,
                        style: textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ) ??
                            TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _getTimeAgo(notification.timestamp),
                    style:
                        textTheme.labelSmall?.copyWith(
                          color: timestampColor,
                          fontWeight: FontWeight.w600,
                        ) ??
                        TextStyle(fontSize: 12, color: timestampColor),
                  ),
                  const SizedBox(height: 10),
                  if (!isRead)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Gradient _resolveCardGradient(ThemeData theme, bool isRead) {
    final gradients = theme.extension<WishLinkGradients>();
    if (gradients != null) {
      return isRead ? gradients.secondary : gradients.primary;
    }
    final bool isDarkMode = theme.brightness == Brightness.dark;
    if (isDarkMode) {
      return isRead
          ? _readCardFallbackGradientDark
          : _unreadCardFallbackGradientDark;
    }
    return isRead
        ? _readCardFallbackGradientLight
        : _unreadCardFallbackGradientLight;
  }

  Gradient _backgroundGradient(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? _darkNotificationsBackground
        : _lightNotificationsBackground;
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

class _NotificationTitlePill extends StatelessWidget {
  const _NotificationTitlePill({
    required this.title,
    required this.theme,
    required this.textTheme,
  });

  final String title;
  final ThemeData theme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background = isDark
        ? theme.colorScheme.surface.withOpacity(0.35)
        : theme.colorScheme.primary.withOpacity(0.12);
    final Color borderColor = theme.colorScheme.primary.withOpacity(
      isDark ? 0.35 : 0.45,
    );
    final Color textColor = isDark
        ? theme.colorScheme.onSurface
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
