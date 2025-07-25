import 'package:flutter/material.dart';
import '../models/friend_activity.dart';
import '../services/firestore_service.dart';
import '../widgets/friend_activity_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/wishlink_logo.png', // Logo yolunu kendi dosyanıza göre güncelleyin
              height: 30,
            ),
            const SizedBox(width: 8),
            const Text(
              'WishLink',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
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
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Friend Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<FriendActivity>>(
                stream: _firestoreService.getFriendActivities(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
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
                            'Bir hata oluştu: ${snapshot.error}',
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
                    return const Center(
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
                            'Henüz arkadaş etkinliği yok',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Arkadaşlarınız wishlist\'e ürün eklediğinde burada görünecek',
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

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    child: ListView.builder(
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: FriendActivityCard(
                            activity: activity,
                            onLike: () {
                              // Beğeni işlemi
                            },
                            onComment: () {
                              // Yorum işlemi
                              _showCommentDialog(activity);
                            },
                            onShare: () {
                              // Paylaşma işlemi
                              _shareActivity(activity);
                            },
                            onBuyNow: () {
                              // Satın alma işlemi
                              _buyNow(activity);
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
        ],
        currentIndex: 0, // Home seçili
        onTap: (index) {
          // Bottom navigation bar öğelerine tıklandığında yapılacak işlem
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
        content: Text('${activity.wishItem.name} satın alma sayfasına yönlendiriliyor...'),
        duration: const Duration(seconds: 2),
      ),
    );
    // Burada ürünün satın alma sayfasına yönlendirme yapılabilir
    // if (activity.wishItem.productUrl.isNotEmpty) {
    //   launch(activity.wishItem.productUrl);
    // }
  }
}