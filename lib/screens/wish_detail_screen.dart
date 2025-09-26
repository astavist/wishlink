import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/friend_activity.dart';
import '../models/wish_item.dart';
import '../services/firestore_service.dart';
import '../widgets/activity_comments_sheet.dart';

class WishDetailScreen extends StatefulWidget {
  final WishItem wish;

  const WishDetailScreen({super.key, required this.wish});

  @override
  State<WishDetailScreen> createState() => _WishDetailScreenState();
}

class _WishDetailScreenState extends State<WishDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<FriendActivity?>? _activitySubscription;
  FriendActivity? _activity;
  bool _isLiked = false;
  bool _isOwnActivity = false;
  bool _isProcessingLike = false;
  bool _hasLoadedActivity = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  String _ownerAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _subscribeToActivity();
  }

  @override
  void didUpdateWidget(covariant WishDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wish.id != widget.wish.id) {
      _activitySubscription?.cancel();
      _activity = null;
      _isLiked = false;
      _isOwnActivity = false;
      _likesCount = 0;
      _commentsCount = 0;
      _hasLoadedActivity = false;
      _subscribeToActivity();
    }
  }

  void _subscribeToActivity() {
    _activitySubscription = _firestoreService
        .streamActivityForWish(widget.wish.id)
        .listen((activity) {
          if (!mounted) {
            return;
          }

          setState(() {
            _hasLoadedActivity = true;
            _activity = activity;
            final currentUserId = _auth.currentUser?.uid;

            if (activity == null) {
              _isOwnActivity = false;
              _isLiked = false;
              _likesCount = 0;
              _commentsCount = 0;
              _ownerAvatarUrl = '';
              return;
            }

            _isOwnActivity =
                currentUserId != null && activity.userId == currentUserId;
            _isLiked =
                currentUserId != null &&
                activity.likedUserIds.contains(currentUserId);
            _likesCount = activity.likesCount;
            _commentsCount = activity.commentsCount;
            final avatar = activity.userAvatarUrl.trim();
            _ownerAvatarUrl = avatar.isNotEmpty ? avatar : '';
          });

          final latestActivity = activity;
          if (latestActivity != null &&
              latestActivity.userAvatarUrl.trim().isEmpty) {
            _fetchOwnerAvatar(latestActivity.userId);
          }
        });
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) {
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  Future<void> _fetchOwnerAvatar(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final photoUrl =
          (snapshot.data()?['profilePhotoUrl'] as String?)?.trim() ?? '';
      if (photoUrl.isNotEmpty && mounted) {
        setState(() {
          _ownerAvatarUrl = photoUrl;
        });
      }
    } catch (_) {
      // Ignore load errors; we'll keep the placeholder avatar.
    }
  }

  Future<void> _handleLike() async {
    final activity = _activity;
    if (activity == null || _isOwnActivity || _isProcessingLike) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to like wishes.')),
        );
      }
      return;
    }

    setState(() {
      _isProcessingLike = true;
    });

    try {
      if (_isLiked) {
        await _firestoreService.unlikeActivity(
          activityId: activity.id,
          userId: user.uid,
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
          activityId: activity.id,
          userId: user.uid,
        );
        if (mounted) {
          setState(() {
            _isLiked = true;
            _likesCount += 1;
          });
        }
      }
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

  Future<void> _openComments() async {
    final activity = _activity;
    if (activity == null || _isOwnActivity) {
      return;
    }

    final addedCounter = ValueNotifier<int>(0);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          ActivityCommentsSheet(activity: activity, addedCounter: addedCounter),
    );

    final added = addedCounter.value;
    addedCounter.dispose();

    if (added > 0 && mounted) {
      setState(() {
        _commentsCount += added;
      });
    }
  }

  Widget _buildHeroImage(BuildContext context, WishItem wish) {
    final theme = Theme.of(context);
    const borderRadius = BorderRadius.all(Radius.circular(18));

    if (wish.imageUrl.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.15),
              theme.colorScheme.primary.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(
          Icons.card_giftcard,
          size: 72,
          color: theme.colorScheme.primary.withValues(alpha: 0.6),
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          wish.imageUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: borderRadius,
              ),
              child: const Icon(Icons.image, size: 64, color: Colors.grey),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOwnerSection(BuildContext context) {
    final theme = Theme.of(context);
    final decoration = BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: theme.colorScheme.shadow.withValues(alpha: 0.06),
          offset: const Offset(0, 8),
          blurRadius: 20,
        ),
      ],
    );

    if (!_hasLoadedActivity) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: Row(
          children: const [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Yükleniyor...',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    final activity = _activity;

    if (activity == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: Row(
          children: const [
            Icon(Icons.person_outline, size: 28, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sahip bilgisi bulunamadı.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    final activityAvatar = activity.userAvatarUrl.trim();
    final avatarUrl = activityAvatar.isNotEmpty
        ? activityAvatar
        : _ownerAvatarUrl;
    final hasAvatar = avatarUrl.isNotEmpty;
    final displayName = activity.userName.isNotEmpty
        ? activity.userName
        : 'Unknown User';
    final handle = activity.userUsername;
    final initials = displayName.isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';

    final baseBodyColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final subtleColor = baseBodyColor.withValues(alpha: 0.6);
    final title = _isOwnActivity
        ? 'Bu dilek sana ait'
        : handle.isNotEmpty
        ? '$displayName (@$handle)'
        : "$displayName's wish";
    final subtitle =
        "Added ${activity.timeAgo == 'Just now' ? 'moments ago' : activity.timeAgo}";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
            child: hasAvatar
                ? null
                : Text(
                    initials,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishInfoCard(BuildContext context, WishItem wish) {
    final theme = Theme.of(context);
    final createdLabel =
        '${wish.createdAt.day}.${wish.createdAt.month}.${wish.createdAt.year}';

    final chips = <Widget>[];
    if (wish.price > 0) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.attach_money, size: 18),
          label: Text('Fiyat ${wish.price.toStringAsFixed(2)}'),
        ),
      );
    }
    chips.add(
      Chip(
        avatar: const Icon(Icons.event_outlined, size: 18),
        label: Text('Oluşturuldu $createdLabel'),
      ),
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wish.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (wish.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(wish.description, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 8, children: chips),
            if (wish.productUrl.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _launchUrl(wish.productUrl),
                  icon: const Icon(Icons.link),
                  label: const Text('Ürünü Gör'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? iconColor,
    int? count,
  }) {
    final theme = Theme.of(context);
    final disabled = onTap == null;
    final baseLabelColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final textColor = disabled
        ? baseLabelColor.withValues(alpha: 0.4)
        : baseLabelColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor ?? textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              if ((count ?? 0) > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngagementSection(BuildContext context) {
    final theme = Theme.of(context);

    if (!_hasLoadedActivity) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_activity == null || _isOwnActivity) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            offset: const Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildEngagementButton(
              context: context,
              icon: _isLiked ? Icons.favorite : Icons.favorite_border,
              iconColor: _isLiked ? Colors.red : null,
              label: _isLiked ? 'Beğenildi' : 'Beğen',
              onTap: _isProcessingLike ? null : _handleLike,
              count: _likesCount,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildEngagementButton(
              context: context,
              icon: Icons.chat_bubble_outline,
              label: 'Yorumlar',
              onTap: _openComments,
              count: _commentsCount,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wish = widget.wish;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wish Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroImage(context, wish),
            const SizedBox(height: 16),
            _buildOwnerSection(context),
            const SizedBox(height: 16),
            _buildWishInfoCard(context, wish),
            _buildEngagementSection(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

PageRouteBuilder<dynamic> createRightToLeftSlideRoute(Widget page) {
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
