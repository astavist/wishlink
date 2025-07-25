import 'package:flutter/material.dart';
import '../models/friend_activity.dart';
import '../services/firestore_service.dart';

class FriendActivityCard extends StatefulWidget {
  final FriendActivity activity;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onBuyNow;

  const FriendActivityCard({
    super.key,
    required this.activity,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onBuyNow,
  });

  @override
  State<FriendActivityCard> createState() => _FriendActivityCardState();
}

class _FriendActivityCardState extends State<FriendActivityCard> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLiked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.activity.likesCount;
  }

  void _handleLike() async {
    setState(() {
      if (_isLiked) {
        _likesCount--;
        _firestoreService.unlikeActivity(widget.activity.id);
      } else {
        _likesCount++;
        _firestoreService.likeActivity(widget.activity.id);
      }
      _isLiked = !_isLiked;
    });

    if (widget.onLike != null) {
      widget.onLike!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kullanıcı bilgisi ve zaman
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: widget.activity.userAvatarUrl.isNotEmpty
                      ? NetworkImage(widget.activity.userAvatarUrl)
                      : null,
                  backgroundColor: Colors.lightGreen[200],
                  radius: 20,
                  child: widget.activity.userAvatarUrl.isEmpty
                      ? Text(
                          widget.activity.userName.isNotEmpty
                              ? widget.activity.userName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.activity.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    // Daha fazla seçenek menüsü
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ürün görseli
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
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
            const SizedBox(height: 16),

            // Ürün bilgileri
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
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            // Fiyat
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '\$${widget.activity.wishItem.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Satın Al butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onBuyNow,
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Buy Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
                      onPressed: _handleLike,
                    ),
                    if (_likesCount > 0)
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
                      onPressed: widget.onComment,
                    ),
                    if (widget.activity.commentsCount > 0)
                      Text(
                        widget.activity.commentsCount.toString(),
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
                            text: '${widget.activity.userName} ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          TextSpan(
                            text: widget.activity.activityDescription!,
                            style: const TextStyle(
                              color: Colors.black,
                            ),
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