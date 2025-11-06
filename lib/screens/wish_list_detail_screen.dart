import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/wish_item.dart';
import '../models/wish_list.dart';
import 'wish_detail_screen.dart';

class WishListDetailScreen extends StatelessWidget {
  final WishList wishList;

  const WishListDetailScreen({super.key, required this.wishList});

  Future<List<WishItem>> _loadWishes() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    // Align with rules: restrict by ownerId
    final snapshot = await FirebaseFirestore.instance
        .collection('wishes')
        .where('ownerId', isEqualTo: uid)
        .where('listId', isEqualTo: wishList.id)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => WishItem.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(wishList.name),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<List<WishItem>>(
        future: _loadWishes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final wishes = snapshot.data ?? [];
          if (wishes.isEmpty) {
            return Center(
              child: Text(
                'No wishes in this list',
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
