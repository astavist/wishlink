import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_activity.dart';
import '../services/firestore_service.dart';
import '../widgets/friend_activity_card.dart';
import 'add_wish_screen.dart';
import 'profile_screen.dart';
import 'friends_screen.dart';
import 'notification_screen.dart';

// Custom page route for left-to-right slide animation (for notifications)
PageRouteBuilder<dynamic> _createLeftToRightSlideRoute(Widget page) {
  return PageRouteBuilder<dynamic>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(-1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);

      return SlideTransition(position: offsetAnimation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

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

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final friends = await _firestoreService.getFriends();
      final friendIds = friends.map((f) => f['friendId'] as String).toSet();

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
      final friends = await _firestoreService.getFriends();
      final friendIds = friends.map((f) => f['friendId'] as String).toSet();

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
              'assets/images/TextLogoBlackPNG.png', // Logo yolunu kendi dosyanıza göre güncelleyin
              height: 70,
            ),
          ],
        ),
        centerTitle: true,
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
            // Tüm bildirimleri okundu olarak işaretle
            await _markAllNotificationsAsRead();
            // NotificationScreen'e yönlendir
            if (mounted) {
              Navigator.push(
                context,
                _createLeftToRightSlideRoute(const NotificationScreen()),
              ).then((_) {
                // Notification screen'den dönüldüğünde veriyi yenile
                _loadData();
              });
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex =
                      4; // Profile tab index (0: Home, 1: Friends, 2: Add Wish, 3: Notifications, 4: Profile)
                });
              },
              child: CircleAvatar(
                backgroundColor: Colors.lightGreen[200],
                child: const Text(
                  'ME',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Home Tab
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
                          return ListView(
                            children: [
                              SizedBox(
                                height: 300,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                ),
                              ),
                            ],
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
                                onLike: () {
                                  // Like functionality
                                },
                                onComment: () {
                                  // Comment functionality
                                  _showCommentDialog(activity);
                                },
                                onShare: () {
                                  // Share functionality
                                  _shareActivity(activity);
                                },
                                onBuyNow: () {
                                  // Buy now functionality
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
          // Friends Tab
          const FriendsScreen(initialTabIndex: 0),
          // Add Wish Tab (placeholder - will navigate to AddWishScreen)
          const Center(child: Text('Add Wish')),
          // Notifications Tab
          const NotificationScreen(),
          // Profile Tab
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
          } else if (index == 3) {
            // Notifications tab - mark all as read and navigate
            await _markAllNotificationsAsRead();
            setState(() {
              _selectedIndex = index;
            });
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
      ),
    );
  }

  void _showCommentDialog(FriendActivity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${activity.userName}\'ın gönderisi'),
        content: const Text('Yorum özelliği yakında gelecek!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${activity.wishItem.name} satın alma sayfasına yönlendiriliyor...',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    // Burada ürünün satın alma sayfasına yönlendirme yapılabilir
    // if (activity.wishItem.productUrl.isNotEmpty) {
    //   launch(activity.wishItem.productUrl);
    // }
  }
}
