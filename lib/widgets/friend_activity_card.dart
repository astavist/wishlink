import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_activity.dart';
import '../services/firestore_service.dart';
import '../screens/user_profile_screen.dart';
import '../screens/wish_detail_screen.dart';
import '../utils/currency_utils.dart';

// Custom page route for right-to-left slide animation (for user profiles)
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

class FriendActivityCard extends StatefulWidget {
  final FriendActivity activity;
  final VoidCallback? onLike;
  final Future<int> Function()? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onBuyNow;
  final VoidCallback? onEdit;

  const FriendActivityCard({
    super.key,
    required this.activity,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onBuyNow,
    this.onEdit,
  });

  @override
  State<FriendActivityCard> createState() => _FriendActivityCardState();
}

class _FriendActivityCardState extends State<FriendActivityCard> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLiked = false;
  bool _isProcessingLike = false;
  bool _isOwnActivity = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _syncStateFromWidget();
  }

  @override
  void didUpdateWidget(covariant FriendActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncStateFromWidget();
  }

  void _syncStateFromWidget() {
    _currentUserId = _auth.currentUser?.uid;
    _likesCount = widget.activity.likesCount;
    _commentsCount = widget.activity.commentsCount;

    final currentUserId = _currentUserId;
    _isOwnActivity =
        currentUserId != null && widget.activity.userId == currentUserId;
    _isLiked =
        currentUserId != null &&
        widget.activity.likedUserIds.contains(currentUserId);
  }

  Future<void> _handleLike() async {
    final userId = _currentUserId ?? _auth.currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to like wishes.')),
        );
      }
      return;
    }

    if (_isOwnActivity || _isProcessingLike) {
      return;
    }

    setState(() {
      _isProcessingLike = true;
    });

    try {
      if (_isLiked) {
        await _firestoreService.unlikeActivity(
          activityId: widget.activity.id,
          userId: userId,
        );
        if (mounted) {
          setState(() {
            _isLiked = false;
            if (_likesCount > 0) {
              _likesCount -= 1;
            }
          });
        }
      } else {
        await _firestoreService.likeActivity(
          activityId: widget.activity.id,
          userId: userId,
        );
        if (mounted) {
          setState(() {
            _isLiked = true;
            _likesCount += 1;
          });
        }
      }

      widget.onLike?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like. Try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingLike = false;
        });
      }
    }
  }

  Future<void> _handleCommentPressed() async {
    if (_isOwnActivity || widget.onComment == null) {
      return;
    }

    final addedCount = await widget.onComment!.call();
    if (!mounted) {
      return;
    }

    if (addedCount > 0) {
      setState(() {
        _commentsCount += addedCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.activity.userName.isNotEmpty
        ? widget.activity.userName
        : 'Unknown User';
    final handle = widget.activity.userUsername;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kullanıcı bilgisi ve zaman
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      _createSlideRoute(
                        UserProfileScreen(
                          userId: widget.activity.userId,
                          userName: widget.activity.userName,
                          userUsername: handle.isNotEmpty ? handle : null,
                        ),
                      ),
                    );
                  },
                  child: FutureBuilder<DocumentSnapshot?>(
                    future: _firestoreService.getUserProfile(
                      widget.activity.userId,
                    ),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.hasData && userSnapshot.data != null) {
                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>?;
                        final profilePhotoUrl =
                            userData?['profilePhotoUrl'] ?? '';

                        if (profilePhotoUrl.isNotEmpty) {
                          return CircleAvatar(
                            backgroundImage: NetworkImage(profilePhotoUrl),
                            radius: 20,
                          );
                        }
                      }

                      // Fallback to default avatar
                      return CircleAvatar(
                        backgroundColor: Colors.lightGreen[200],
                        radius: 20,
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        _createSlideRoute(
                          UserProfileScreen(
                            userId: widget.activity.userId,
                            userName: widget.activity.userName,
                            userUsername: handle.isNotEmpty ? handle : null,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (handle.isNotEmpty)
                          Text(
                            '@$handle',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        Text(
                          widget.activity.timeAgo,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isOwnActivity && widget.onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit wish',
                    onPressed: widget.onEdit,
                  ),
            ],
          ),
            const SizedBox(height: 16),

            // Ürün görseli
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    createRightToLeftSlideRoute(
                      WishDetailScreen(wish: widget.activity.wishItem),
                    ),
                  );
                },
                child: widget.activity.wishItem.imageUrl.isNotEmpty
                    ? Image.network(
                        widget.activity.wishItem.imageUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Ürün bilgileri (tıklanabilir)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  createRightToLeftSlideRoute(
                    WishDetailScreen(wish: widget.activity.wishItem),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.activity.wishItem.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.activity.wishItem.description,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Fiyat
                  if (widget.activity.wishItem.price > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              currencySymbol(
                                widget.activity.wishItem.currency,
                              ),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatAmount(widget.activity.wishItem.price),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Satın Al butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onBuyNow,
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Buy Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 211, 79, 11),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Etkileşim butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : null,
                      ),
                      onPressed: (!_isOwnActivity && !_isProcessingLike)
                          ? _handleLike
                          : null,
                    ),
                    if (!_isOwnActivity && _likesCount > 0)
                      Text(
                        _likesCount.toString(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: !_isOwnActivity ? _handleCommentPressed : null,
                    ),
                    if (!_isOwnActivity && _commentsCount > 0)
                      Text(
                        _commentsCount.toString(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: widget.onShare,
                ),
              ],
            ),

            // Etkinlik açıklaması
            if (widget.activity.activityDescription != null)
              Column(
                children: [
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: handle.isNotEmpty
                                ? '$displayName (@$handle) '
                                : '$displayName ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          TextSpan(
                            text: widget.activity.activityDescription!,
                            style: const TextStyle(color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}




