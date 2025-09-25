import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/friend_activity.dart';
import '../services/firestore_service.dart';
import '../widgets/friend_activity_card.dart';
import '../widgets/activity_comments_sheet.dart';
import 'add_wish_screen.dart';
import 'profile_screen.dart';
import 'friends_screen.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';

// (Removed unused left-to-right slide route)

// Custom page route for bottom-to-top slide animation (for add wish)
PageRouteBuilder<dynamic> _createBottomToTopSlideRoute(Widget page) {
  return PageRouteBuilder<dynamic>(
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
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedIndex = 0;
  bool _hasFriendRequests = false;
  int _unreadNotificationsCount = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _loadData();
    _pageController = PageController(initialPage: 0);
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

      // Count unread wish notifications (only for friends)
      final friendIds = await _firestoreService.getFriendIds();

      for (final activity in recentActivities.docs) {
        final activityData = activity.data();
        final activityUserId = activityData['userId'] as String;

        if (friendIds.contains(activityUserId) &&
            activityUserId != currentUserId &&
            !readNotificationIds.contains(activity.id)) {
          unreadCount++;
        }
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
              .doc(request.id)
              .set({'isRead': true, 'timestamp': FieldValue.serverTimestamp()});
        }
      }

      // Mark wish notifications as read (only for friends)
      final friendIds = await _firestoreService.getFriendIds();

      for (final activity in recentActivities.docs) {
        final activityData = activity.data();
        final activityUserId = activityData['userId'] as String;

        if (friendIds.contains(activityUserId) &&
            activityUserId != currentUserId &&
            !readNotificationIds.contains(activity.id)) {
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(activity.id)
              .set({'isRead': true, 'timestamp': FieldValue.serverTimestamp()});
        }
      }

      // Update local state
      setState(() {
        _unreadNotificationsCount = 0;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/AppBar.png', // Logo yolunu kendi dosyanıza göre güncelleyin
              height: 70,
            ),
          ],
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
                    tooltip: 'Settings',
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
                          child: const Text(
                            'ME',
                            style: TextStyle(
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Friend Activity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: FutureBuilder<List<FriendActivity>>(
                      future: _firestoreService.getAllActivities(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
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
                                  'An error occurred:  ${snapshot.error}',
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
                                  'No activities yet',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Add your first wish or connect with friends',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: activities.length,
                          itemBuilder: (context, index) {
                            final activity = activities[index];

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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.people),
                if (_hasFriendRequests)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEFB652),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 40),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) async {
          if (index == 2) {
            // Add Wish button - navigate to AddWishScreen
            Navigator.push(
              context,
              _createBottomToTopSlideRoute(const AddWishScreen()),
            );
            return;
          }

          final targetPage = _bottomIndexToPageIndex(index);
          _pageController.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
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

  void _shareActivity(FriendActivity activity) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${activity.wishItem.name} paylaşıldı!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _buyNow(FriendActivity activity) {
    if (activity.wishItem.productUrl.isNotEmpty) {
      _launchUrl(activity.wishItem.productUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${activity.wishItem.name} için link bulunamadı'),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Link açılamadı')));
        }
      }
    }
  }
}
