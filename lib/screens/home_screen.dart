import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/friend_activity.dart';
import '../services/firestore_service.dart';
import '../widgets/friend_activity_card.dart';
import '../widgets/activity_comments_sheet.dart';
import '../widgets/wish_native_ad_card.dart';
import 'add_wish_screen.dart';
import 'edit_wish_screen.dart';
import 'profile_screen.dart';
import 'friends_screen.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';
import 'package:wishlink/l10n/app_localizations.dart';

// (Removed unused left-to-right slide route)

// Custom page route for bottom-to-top slide animation (for add wish)
PageRouteBuilder<bool> _createBottomToTopSlideRoute(Widget page) {
  return PageRouteBuilder<bool>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);

      return SlideTransition(position: offsetAnimation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _nativeAdEvery = 2;
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedIndex = 0;
  bool _hasFriendRequests = false;
  int _unreadNotificationsCount = 0;
  late final PageController _pageController;
  Future<List<FriendActivity>>? _activitiesFuture;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _activitiesFuture = _firestoreService.getAllActivities();
    _loadData();
  }

  int _bottomIndexToPageIndex(int bottomIndex) {
    // Maps BottomNavigationBar indices (0,1,2,3,4) to PageView indices (0,1,2,3)
    // Excludes index 2 (Add Wish) from paging
    return bottomIndex <= 1 ? bottomIndex : bottomIndex - 1;
  }

  int _pageIndexToBottomIndex(int pageIndex) {
    // Maps PageView indices (0,1,2,3) back to BottomNavigationBar indices (0,1,3,4)
    return pageIndex <= 1 ? pageIndex : pageIndex + 1;
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final requests = await _firestoreService.getFriendRequests();
    final unreadCount = await _getUnreadNotificationsCount();
    if (mounted) {
      setState(() {
        _hasFriendRequests = requests['incoming']?.isNotEmpty ?? false;
        _unreadNotificationsCount = unreadCount;
      });
    }
  }

  Future<void> _refreshActivities() async {
    final future = _firestoreService.getAllActivities();
    if (!mounted) {
      _activitiesFuture = future;
      await future;
      return;
    }
    setState(() {
      _activitiesFuture = future;
    });
    await future;
  }

  void _handleLogoTap() {
    const targetBottomIndex = 0;
    final targetPage = _bottomIndexToPageIndex(targetBottomIndex);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedIndex = targetBottomIndex;
    });
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<int> _getUnreadNotificationsCount() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return 0;

      // Get all notifications (friend requests + wish activities)
      final requests = await _firestoreService.getFriendRequests();
      final incomingRequests = requests['incoming'] ?? [];

      final recentActivities = await FirebaseFirestore.instance
          .collection('friend_activities')
          .where('activityType', isEqualTo: 'added')
          .orderBy('activityTime', descending: true)
          .limit(50)
          .get();

      // Get read notifications
      final readNotificationsSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(currentUserId)
          .collection('items')
          .where('isRead', isEqualTo: true)
          .get();
      final readNotificationIds = readNotificationsSnapshot.docs
          .map((doc) => doc.id)
          .toSet();

      // Count unread friend requests
      int unreadCount = 0;
      for (final request in incomingRequests) {
        if (!readNotificationIds.contains(request.id)) {
          unreadCount++;
        }
      }

      // Count unread wish notifications (only for friends after friendship start)
      final friendships = await _firestoreService.getAcceptedFriendships();
      final friendIds = friendships
          .map((friendship) => friendship.friendId)
          .where((id) => id.isNotEmpty)
          .toSet();
      final friendshipStartTimes = _buildFriendshipStartTimes(friendships);

      for (final activity in recentActivities.docs) {
        final activityData = activity.data() as Map<String, dynamic>;
        final activityUserId = activityData['userId'] as String;

        if (!friendIds.contains(activityUserId) ||
            activityUserId == currentUserId ||
            readNotificationIds.contains(activity.id)) {
          continue;
        }

        final activityTimestamp = _extractActivityTimestamp(activityData);
        final friendSince = friendshipStartTimes[activityUserId];
        if (friendSince != null &&
            activityTimestamp.compareTo(friendSince) < 0) {
          continue;
        }

        unreadCount++;
      }

      return unreadCount;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _markAllNotificationsAsRead() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Get all unread notifications
      final requests = await _firestoreService.getFriendRequests();
      final incomingRequests = requests['incoming'] ?? [];

      final recentActivities = await FirebaseFirestore.instance
          .collection('friend_activities')
          .where('activityType', isEqualTo: 'added')
          .orderBy('activityTime', descending: true)
          .limit(50)
          .get();

      final readNotificationsSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(currentUserId)
          .collection('items')
          .where('isRead', isEqualTo: true)
          .get();
      final readNotificationIds = readNotificationsSnapshot.docs
          .map((doc) => doc.id)
          .toSet();

      // Mark friend requests as read
      for (final request in incomingRequests) {
        if (!readNotificationIds.contains(request.id)) {
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(currentUserId)
              .collection('items')
              .doc(request.id)
              .set({'isRead': true, 'timestamp': FieldValue.serverTimestamp()});
        }
      }

      // Mark wish notifications as read (only for friends after friendship start)
      final friendships = await _firestoreService.getAcceptedFriendships();
      final friendIds = friendships
          .map((friendship) => friendship.friendId)
          .where((id) => id.isNotEmpty)
          .toSet();
      final friendshipStartTimes = _buildFriendshipStartTimes(friendships);

      for (final activity in recentActivities.docs) {
        final activityData = activity.data() as Map<String, dynamic>;
        final activityUserId = activityData['userId'] as String;

        if (!friendIds.contains(activityUserId) ||
            activityUserId == currentUserId ||
            readNotificationIds.contains(activity.id)) {
          continue;
        }

        final activityTimestamp = _extractActivityTimestamp(activityData);
        final friendSince = friendshipStartTimes[activityUserId];
        if (friendSince != null &&
            activityTimestamp.compareTo(friendSince) < 0) {
          continue;
        }

        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(currentUserId)
            .collection('items')
            .doc(activity.id)
            .set({'isRead': true, 'timestamp': FieldValue.serverTimestamp()});
      }

      // Update local state
      setState(() {
        _unreadNotificationsCount = 0;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Map<String, Timestamp?> _buildFriendshipStartTimes(
    List<FriendshipRecord> friendships,
  ) {
    final map = <String, Timestamp?>{};
    for (final friendship in friendships) {
      final friendId = friendship.friendId;
      if (friendId.isEmpty) continue;

      final existing = map[friendId];
      final candidate = friendship.createdAt;

      if (existing == null) {
        map[friendId] = candidate;
        continue;
      }

      if (candidate != null &&
          existing != null &&
          candidate.compareTo(existing) < 0) {
        map[friendId] = candidate;
      }
    }
    return map;
  }

  Timestamp _extractActivityTimestamp(Map<String, dynamic> activityData) {
    try {
      if (activityData['activityTime'] is Timestamp) {
        return activityData['activityTime'] as Timestamp;
      }
      if (activityData['timestamp'] is Timestamp) {
        return activityData['timestamp'] as Timestamp;
      }
      if (activityData['createdAt'] is Timestamp) {
        return activityData['createdAt'] as Timestamp;
      }
    } catch (_) {
      // Ignore malformed data and fall back to now
    }
    return Timestamp.now();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      extendBody: true,
      backgroundColor:
          Theme.of(context).appBarTheme.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleLogoTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                _resolveAppBarAsset(
                  context,
                ), // Logo yolunu kendi dosyan�za g�re g�ncelleyin
                height: 70,
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_none),
              if (_unreadNotificationsCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotificationsCount > 9
                          ? '9+'
                          : _unreadNotificationsCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () async {
            // PageView içinde Notifications sekmesine geç; state güncellemeleri onPageChanged'de yapılır
            final targetPage = _bottomIndexToPageIndex(3);
            _pageController.animateToPage(
              targetPage,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        ),
        actions: [
          Container(
            width: 72,
            padding: const EdgeInsets.only(right: 16.0),
            alignment: Alignment.centerRight,
            child: _selectedIndex == 4
                ? IconButton(
                    icon: const Icon(Icons.settings),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 22,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                    tooltip: l10n.t('settings.title'),
                  )
                : GestureDetector(
                    onTap: () {
                      final targetBottomIndex = 4;
                      final targetPage = _bottomIndexToPageIndex(
                        targetBottomIndex,
                      );
                      _pageController.animateToPage(
                        targetPage,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: FutureBuilder<DocumentSnapshot?>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          final userData =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          final profilePhotoUrl =
                              userData?['profilePhotoUrl'] ?? '';

                          if (profilePhotoUrl.isNotEmpty) {
                            return CircleAvatar(
                              backgroundImage: NetworkImage(profilePhotoUrl),
                              radius: 20,
                            );
                          }
                        }

                        return CircleAvatar(
                          backgroundColor: Colors.lightGreen[200],
                          child: Text(
                            l10n.t('home.meBadge'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (pageIndex) {
          _dismissKeyboard();
          final newBottomIndex = _pageIndexToBottomIndex(pageIndex);
          if (newBottomIndex == 3) {
            // Fire-and-forget to avoid race with subsequent page changes
            _markAllNotificationsAsRead();
          }
          if (mounted) {
            setState(() {
              _selectedIndex = newBottomIndex;
              if (newBottomIndex == 3) {
                _unreadNotificationsCount = 0;
              }
            });
          }
        },
        children: [
          // Home
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await _loadData();
                      await _refreshActivities();
                    },
                    child: FutureBuilder<List<FriendActivity>>(
                      future: _activitiesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting ||
                            snapshot.connectionState ==
                                ConnectionState.none) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.t(
                                    'home.activitiesError',
                                    params: {'error': '${snapshot.error}'},
                                  ),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        final activities = snapshot.data ?? [];

                        if (activities.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  l10n.t('home.noActivities'),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  l10n.t('home.connectPrompt'),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        final totalItems =
                            _calculateFeedLength(activities.length);
                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 160),
                          itemCount: totalItems,
                          itemBuilder: (context, index) {
                            if (_isAdPosition(index)) {
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 16.0),
                                child: WishNativeAdCard(),
                              );
                            }

                            final activityIndex =
                                _activityIndexForListIndex(index);
                            final activity = activities[activityIndex];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: FriendActivityCard(
                                activity: activity,
                                onLike: () {},
                                onComment: () =>
                                    _showCommentsBottomSheet(activity),
                                onShare: () {
                                  _shareActivity(activity);
                                },
                                onBuyNow: () {
                                  _buyNow(activity);
                                },
                                onEdit: () => _openEditWish(activity),
                                onDelete: () => _deleteWish(activity),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Friends
          const FriendsScreen(initialTabIndex: 0),
          // Notifications
          const NotificationScreen(),
          // Profile
          const ProfileScreen(),
        ],
      ),

      bottomNavigationBar: Builder(
        builder: (context) {
          const double navBarHeight = 75;
          const double stackExtraSpace = 10;
          const double addButtonSize = 60;
          final double bottomInset = MediaQuery.paddingOf(context).bottom;
          final double stackHeight =
              navBarHeight + stackExtraSpace + bottomInset;
          final double containerHeight = navBarHeight + bottomInset;
          final double addButtonBottomOffset =
              (navBarHeight / 2) - (addButtonSize / 2);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: stackHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: containerHeight,
                      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1F1F1F)
                            : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(navBarHeight / 2),
                          topRight: Radius.circular(navBarHeight / 2),
                          bottomLeft: Radius.zero,
                          bottomRight: Radius.zero,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.35
                                  : 0.15,
                            ),
                            blurRadius: 35,
                            offset: const Offset(0, 22),
                          ),
                          BoxShadow(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0x66FFFFFF),
                            blurRadius: 6,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildBottomNavItem(
                            icon: Icons.home_rounded,
                            index: 0,
                          ),
                          const SizedBox(width: 8),
                          _buildBottomNavItem(
                            icon: Icons.group_outlined,
                            index: 1,
                            showBadge: _hasFriendRequests,
                          ),
                          const Spacer(),
                          SizedBox(width: addButtonSize - 4),
                          const Spacer(),
                          _buildBottomNavItem(
                            icon: Icons.notifications_none_rounded,
                            index: 3,
                            showBadge: _unreadNotificationsCount > 0,
                          ),
                          const SizedBox(width: 8),
                          _buildBottomNavItem(
                            icon: Icons.person_outline_rounded,
                            index: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: bottomInset + addButtonBottomOffset,
                    child: GestureDetector(
                      onTap: () {
                        _openAddWish();
                      },
                      child: Container(
                        width: addButtonSize,
                        height: addButtonSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFDD27B), Color(0xFFF6A441)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          boxShadow:
                              Theme.of(context).brightness == Brightness.dark
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x66F6A441),
                                    blurRadius: 30,
                                    offset: Offset(0, 18),
                                  ),
                                ],
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleBottomNavTap(int index) {
    _dismissKeyboard();
    if (index == 2) {
      _openAddWish();
      return;
    }

    final targetPage = _bottomIndexToPageIndex(index);
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _openAddWish() async {
    final result = await Navigator.push<bool>(
          context,
          _createBottomToTopSlideRoute(const AddWishScreen()),
        ) ??
        false;
    if (result) {
      await _refreshActivities();
    }
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required int index,
    bool showBadge = false,
  }) {
    final theme = Theme.of(context);
    final bool isSelected = _selectedIndex == index;
    final Color activeColor = theme.brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1F1F1F);
    final Color inactiveColor = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.grey[500]!;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _handleBottomNavTap(index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(
                      alpha:
                          theme.brightness == Brightness.dark ? 0.18 : 0.1,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              icon,
              size: 26,
              color: isSelected ? activeColor : inactiveColor,
            ),
          ),
          if (showBadge)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _resolveAppBarAsset(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/AppBarDark.png'
        : 'assets/images/AppBar.png';
  }

  Future<int> _showCommentsBottomSheet(FriendActivity activity) async {
    final addedCounter = ValueNotifier<int>(0);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          ActivityCommentsSheet(activity: activity, addedCounter: addedCounter),
    );

    final added = addedCounter.value;
    addedCounter.dispose();
    return added;
  }

  Future<void> _openEditWish(FriendActivity activity) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditWishScreen(wish: activity.wishItem),
      ),
    );

    if (result == true) {
      await _refreshActivities();
    }
  }

  Future<void> _deleteWish(FriendActivity activity) async {
    final l10n = context.l10n;
    final wishLabel = activity.wishItem.name.isNotEmpty
        ? activity.wishItem.name
        : l10n.t('wishDetail.title');

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('wishDetail.deleteConfirmTitle')),
        content: Text(
          l10n.t(
            'wishDetail.deleteConfirmMessage',
            params: {'wish': wishLabel},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('common.delete')),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _firestoreService.deleteWish(activity.wishItem.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('wishDetail.deleteSuccess'))),
      );
      await _refreshActivities();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = l10n.t(
        'wishDetail.deleteFailed',
        params: {'error': error.toString()},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _shareActivity(FriendActivity activity) {
    final l10n = context.l10n;
    final wishName = activity.wishItem.name.trim().isNotEmpty
        ? activity.wishItem.name.trim()
        : l10n.t('wishDetail.title');
    final ownerLabel = _activityOwnerLabel(activity, l10n);

    final sections = <String>[
      l10n.t(
        'share.friendMessage',
        params: {'user': ownerLabel, 'wish': wishName},
      ),
    ];

    final description = activity.wishItem.description.trim();
    if (description.isNotEmpty) {
      sections.add(
        l10n.t(
          'share.descriptionLine',
          params: {'description': description},
        ),
      );
    }

    final productUrl = activity.wishItem.productUrl.trim();
    if (productUrl.isNotEmpty) {
      sections.add(
        l10n.t(
          'share.productLine',
          params: {'url': productUrl},
        ),
      );
    }

    SharePlus.instance.share(
      ShareParams(
        text: sections.join('\n\n'),
        subject: l10n.t(
          'share.friendSubject',
          params: {'user': ownerLabel, 'wish': wishName},
        ),
      ),
    );
  }

  String _activityOwnerLabel(
    FriendActivity activity,
    AppLocalizations l10n,
  ) {
    final displayName = activity.userName.trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final username = activity.userUsername.trim();
    if (username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }
    return l10n.t('share.someone');
  }

  bool _isAdPosition(int index) {
    if (_nativeAdEvery <= 0) {
      return false;
    }
    final blockSize = _nativeAdEvery + 1;
    return (index + 1) % blockSize == 0;
  }

  int _calculateFeedLength(int activitiesCount) {
    if (_nativeAdEvery <= 0 || activitiesCount <= 0) {
      return activitiesCount;
    }
    final adCount = activitiesCount ~/ _nativeAdEvery;
    return activitiesCount + adCount;
  }

  int _activityIndexForListIndex(int listIndex) {
    if (_nativeAdEvery <= 0) {
      return listIndex;
    }
    final blockSize = _nativeAdEvery + 1;
    final adsBefore = (listIndex + 1) ~/ blockSize;
    return listIndex - adsBefore;
  }

  void _buyNow(FriendActivity activity) {
    final l10n = context.l10n;
    if (activity.wishItem.productUrl.isNotEmpty) {
      _launchUrl(activity.wishItem.productUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t(
              'home.linkMissing',
              params: {'wish': activity.wishItem.name},
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.t('common.linkOpenFailed'))),
          );
        }
      }
    }
  }
}
