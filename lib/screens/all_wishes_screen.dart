import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/wish_item.dart';
import 'wish_detail_screen.dart';

class AllWishesScreen extends StatelessWidget {
  const AllWishesScreen({super.key});

  Future<List<WishItem>> _loadUserWishes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final wishesSnapshot = await FirebaseFirestore.instance
        .collection('friend_activities')
        .where('userId', isEqualTo: user.uid)
        .where('activityType', isEqualTo: 'added')
        .orderBy('activityTime', descending: true)
        .get();

    return wishesSnapshot.docs.map((doc) {
      final data = doc.data();
      final wishData = data['wishItem'] as Map<String, dynamic>;
      final wishId = (data['wishItemId'] as String?) ?? wishData['id'] ?? doc.id;
      return WishItem.fromMap(wishData, wishId);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Wishes'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<List<WishItem>>(
        future: _loadUserWishes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final wishes = snapshot.data ?? [];
          if (wishes.isEmpty) {
            return Center(
              child: Text(
                'No wishes yet',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: wishes.length,
            itemBuilder: (context, index) {
              final wish = wishes[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    createRightToLeftSlideRoute(WishDetailScreen(wish: wish)),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (wish.imageUrl.isNotEmpty)
                        Image.network(
                          wish.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.grey[300]),
                        )
                      else
                        Container(color: Colors.grey[200]),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black54],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Text(
                          wish.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
