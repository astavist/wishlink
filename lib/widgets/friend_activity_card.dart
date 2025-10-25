import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_activity.dart';
import '../services/firestore_service.dart';
import '../screens/user_profile_screen.dart';
import '../screens/wish_detail_screen.dart';
import '../utils/currency_utils.dart';
import 'wishlink_card.dart';

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
    final theme = Theme.of(context);
    final displayName = widget.activity.userName.isNotEmpty
        ? widget.activity.userName
        : 'Unknown User';
    final handle = widget.activity.userUsername;

    return WishLinkCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.14,
                      ),
                      radius: 24,
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'U',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (handle.isNotEmpty)
                            _InfoPill(
                              label: '@$handle',
                              background: theme.colorScheme.primary.withOpacity(
                                0.14,
                              ),
                              foreground: theme.colorScheme.primary,
                            ),
                          _InfoPill(
                            label: widget.activity.timeAgo,
                            background: theme.colorScheme.surface.withOpacity(
                              0.6,
                            ),
                            foreground:
                                theme.textTheme.bodySmall?.color ??
                                theme.colorScheme.onSurface,
                          ),
                        ],
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
              child: AspectRatio(
                aspectRatio: 16 / 10,
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
                            color: theme.colorScheme.primary.withOpacity(0.06),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: theme.colorScheme.primary.withOpacity(0.4),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: double.infinity,
                        height: 200,
                        color: theme.colorScheme.primary.withOpacity(0.06),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: theme.colorScheme.primary.withOpacity(0.4),
                        ),
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
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.activity.wishItem.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 16),

                // Fiyat
                if (widget.activity.wishItem.price > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        formatPrice(
                          widget.activity.wishItem.price,
                          widget.activity.wishItem.currency,
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
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
              icon: const Icon(Icons.card_giftcard_outlined),
              label: const Text('Hediyeyi satın al'),
            ),
          ),
          const SizedBox(height: 16),

          // Etkileşim butonları
          Row(
            children: [
              Expanded(
                child: _ActionPillButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  label: _likesCount > 0 ? _likesCount.toString() : 'Beğen',
                  isActive: _isLiked,
                  onTap: (!_isOwnActivity && !_isProcessingLike)
                      ? _handleLike
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionPillButton(
                  icon: Icons.chat_bubble_outline,
                  label: _commentsCount > 0
                      ? _commentsCount.toString()
                      : 'Yorum',
                  onTap: !_isOwnActivity ? _handleCommentPressed : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionPillButton(
                  icon: Icons.share_outlined,
                  label: 'Paylaş',
                  onTap: widget.onShare,
                ),
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
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: widget.activity.activityDescription!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.08),
          width: 1.1,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final activeColor = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(enabled ? 0.85 : 0.35);
    final backgroundColor = isActive
        ? theme.colorScheme.primary.withOpacity(0.16)
        : theme.colorScheme.surface.withOpacity(enabled ? 0.7 : 0.45);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: activeColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: activeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
