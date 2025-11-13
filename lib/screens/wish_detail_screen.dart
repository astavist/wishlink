import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wishlink/l10n/app_localizations.dart';

import '../models/friend_activity.dart';
import '../models/wish_item.dart';
import '../services/firestore_service.dart';
import '../widgets/activity_comments_sheet.dart';
import 'edit_wish_screen.dart';
import '../utils/currency_utils.dart';

enum _WishOwnerAction { edit, delete }

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
  late WishItem _wish;

  @override
  void initState() {
    super.initState();
    _wish = widget.wish;
    _subscribeToActivity();
  }

  @override
  void didUpdateWidget(covariant WishDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wish.id != widget.wish.id) {
      _wish = widget.wish;
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
        .streamActivityForWish(_wish.id)
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

            _wish = activity.wishItem;
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

  Future<void> _reloadWish() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('wishes')
          .doc(_wish.id)
          .get();
      final data = snapshot.data();
      if (data != null) {
        setState(() {
          _wish = WishItem.fromMap(data, snapshot.id);
        });
      }
    } catch (_) {
      // ignore refresh errors
    }
  }

  Future<void> _openEditWish() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditWishScreen(wish: _wish)),
    );

    if (updated == true) {
      await _reloadWish();
    }
  }

  Future<void> _confirmDeleteWish() async {
    final l10n = context.l10n;
    final wishLabel = _wish.name.isNotEmpty
        ? _wish.name
        : l10n.t('wishDetail.title');

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('wishDetail.deleteConfirmTitle')),
        content: Text(
          l10n.t(
            'wishDetail.deleteConfirmMessage',
            params: {'wish': wishLabel},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('common.delete')),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _firestoreService.deleteWish(_wish.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('wishDetail.deleteSuccess'))),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = l10n.t(
        'wishDetail.deleteFailed',
        params: {'error': error.toString()},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('common.couldNotOpenLink'))),
        );
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
          SnackBar(content: Text(context.l10n.t('common.signInToLike'))),
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
          SnackBar(content: Text(context.l10n.t('common.likeFailed'))),
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
    final l10n = context.l10n;

    if (!_hasLoadedActivity) {
      return Row(
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.t('wishDetail.ownerLoading'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
        ],
      );
    }

    final activity = _activity;

    if (activity == null) {
      return Row(
        children: [
          Icon(
            Icons.person_outline,
            size: 26,
            color: theme.colorScheme.primary.withOpacity(0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.t('wishDetail.ownerMissing'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
          ),
        ],
      );
    }

    final activityAvatar = activity.userAvatarUrl.trim();
    final avatarUrl = activityAvatar.isNotEmpty
        ? activityAvatar
        : _ownerAvatarUrl;
    final hasAvatar = avatarUrl.isNotEmpty;
    final displayName = activity.userName.isNotEmpty
        ? activity.userName
        : l10n.t('wishDetail.unknownUser');
    final handle = activity.userUsername;
    final title = _isOwnActivity
        ? l10n.t('wishDetail.ownWish')
        : handle.isNotEmpty
        ? '$displayName (@$handle)'
        : l10n.t('wishDetail.ownerWish', params: {'owner': displayName});
    final subtitle = l10n.t(
      'wishDetail.addedLabel',
      params: {'time': l10n.relativeTime(activity.activityTime)},
    );
    final initials = displayName.isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
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
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWishInfoCard(BuildContext context, WishItem wish) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final createdLabel =
        '${wish.createdAt.day}.${wish.createdAt.month}.${wish.createdAt.year}';

    Widget? priceChip;
    if (wish.price > 0) {
      priceChip = Chip(
        avatar: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.1),
          child: Text(
            currencySymbol(wish.currency),
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        label: Text(
          '${currencySymbol(wish.currency)} ${formatAmount(wish.price)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final createdChip = Chip(
      avatar: const Icon(Icons.event_outlined, size: 18),
      label: Text(
        l10n.t('wishDetail.createdLabel', params: {'date': createdLabel}),
      ),
    );

    return Column(
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
        if (priceChip != null) ...[priceChip, const SizedBox(height: 12)],
        createdChip,
        if (wish.productUrl.isNotEmpty) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _launchUrl(wish.productUrl),
              icon: const Icon(Icons.link),
              label: Text(l10n.t('wishDetail.viewProduct')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEngagementButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? iconColor,
    int? count,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final effectiveIconColor =
        iconColor ??
        (isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withOpacity(enabled ? 0.85 : 0.35));
    final textColor = isActive
        ? theme.colorScheme.primary
        : theme.textTheme.bodyMedium?.color?.withOpacity(enabled ? 0.9 : 0.4) ??
              theme.colorScheme.onSurface.withOpacity(enabled ? 0.9 : 0.4);
    final borderColor = isActive
        ? theme.colorScheme.primary.withOpacity(0.55)
        : theme.dividerColor;
    final backgroundColor = isActive
        ? theme.colorScheme.primary.withOpacity(0.08)
        : Colors.transparent;

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: borderColor),
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: effectiveIconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if ((count ?? 0) > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.18),
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
    );
  }

  Widget _buildEngagementSection(BuildContext context) {
    final l10n = context.l10n;

    if (!_hasLoadedActivity) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final likeLabel = _isLiked
        ? l10n.t('wishDetail.liked')
        : l10n.t('wishDetail.like');
    final likeEnabled =
        _activity != null && !_isOwnActivity && !_isProcessingLike;
    final commentEnabled = _activity != null && !_isOwnActivity;

    return Row(
      children: [
        Expanded(
          child: _buildEngagementButton(
            context: context,
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: likeLabel,
            onTap: likeEnabled ? _handleLike : null,
            count: _likesCount,
            isActive: _isLiked,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildEngagementButton(
            context: context,
            icon: Icons.chat_bubble_outline,
            label: l10n.t('wishDetail.comments'),
            onTap: commentEnabled ? _openComments : null,
            count: _commentsCount,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wish = _wish;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('wishDetail.title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: l10n.t('wishDetail.backTooltip'),
        ),
        actions: [
          if (_isOwnActivity)
            PopupMenuButton<_WishOwnerAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.t('wishDetail.menuTooltip'),
              onSelected: (action) async {
                switch (action) {
                  case _WishOwnerAction.edit:
                    await _openEditWish();
                    break;
                  case _WishOwnerAction.delete:
                    await _confirmDeleteWish();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _WishOwnerAction.edit,
                  child: Text(l10n.t('common.edit')),
                ),
                PopupMenuItem(
                  value: _WishOwnerAction.delete,
                  child: Text(l10n.t('common.delete')),
                ),
              ],
            ),
        ],
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroImage(context, wish),
              const SizedBox(height: 20),
              _buildOwnerSection(context),
              const SizedBox(height: 20),
              _buildWishInfoCard(context, wish),
              const SizedBox(height: 24),
              _buildEngagementSection(context),
            ],
          ),
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
