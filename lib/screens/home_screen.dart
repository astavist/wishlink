import 'package:flutter/material.dart';
import '../models/friend_activity.dart';
import '../services/firestore_service.dart';
import '../widgets/friend_activity_card.dart';
import 'add_wish_screen.dart';
import 'profile_screen.dart';
import 'friends_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedIndex = 0;
  bool _hasFriendRequests = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final requests = await _firestoreService.getFriendRequests();
    if (mounted) {
      setState(() {
        _hasFriendRequests = requests['incoming']?.isNotEmpty ?? false;
      });
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
          icon: const Icon(Icons.notifications_none),
          onPressed: () {
            // Bildirimler butonuna basıldığında yapılacak işlem
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
          const FriendsScreen(),
          // Add Wish Tab (placeholder - will navigate to AddWishScreen)
          const Center(child: Text('Add Wish')),
          // Notifications Tab (placeholder)
          const Center(child: Text('Notifications - Coming Soon')),
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 2) {
            // Add Wish button - navigate to AddWishScreen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddWishScreen()),
            );
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
