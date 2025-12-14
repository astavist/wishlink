import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wishlink/l10n/app_localizations.dart';

import '../models/friend_activity.dart';
import '../models/friend_activity_comment.dart';
import '../models/wish_item.dart';
import '../services/firestore_service.dart';
import '../utils/currency_utils.dart';
import '../widgets/report_dialog.dart';
import '../widgets/wishlink_card.dart';
import 'edit_wish_screen.dart';
import 'user_profile_screen.dart';

enum _WishOwnerAction { edit, delete }
enum _WishViewerAction { report, block, unblock }

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
  bool _isSendingComment = false;
  bool _hasLoadedActivity = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  String _ownerAvatarUrl = '';
  bool _hasBlockedOwner = false;
  bool _isBlockedByOwner = false;
  bool _isHandlingOwnerBlock = false;
  String? _ownerUserId;
  late WishItem _wish;
  final TextEditingController _commentController = TextEditingController();
  final GlobalKey _commentsSectionKey = GlobalKey();

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

          final previousOwnerId = _ownerUserId;
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
              _ownerUserId = null;
              _hasBlockedOwner = false;
              return;
            }

            _wish = activity.wishItem;
            _ownerUserId = activity.userId;
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
          if (latestActivity != null &&
              latestActivity.userId.isNotEmpty &&
              latestActivity.userId != previousOwnerId) {
            _refreshOwnerBlockState(latestActivity.userId);
          }
        });
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    _commentController.dispose();
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

  void _openOwnerProfile() {
    final ownerId = _ownerUserId;
    final activity = _activity;
    if (ownerId == null || ownerId.isEmpty || activity == null) {
      return;
    }
    Navigator.of(context).push(
      createRightToLeftSlideRoute(
        UserProfileScreen(
          userId: ownerId,
          userName: activity.userName.isNotEmpty ? activity.userName : null,
          userUsername:
              activity.userUsername.isNotEmpty ? activity.userUsername : null,
        ),
      ),
    );
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

  Future<void> _handleReportWish() async {
    final l10n = context.l10n;
    final result = await showReportDialog(
      context: context,
      title: l10n.t('report.wishTitle'),
      description: l10n.t('report.wishDescription'),
    );
    if (result == null) {
      return;
    }
    try {
      await _firestoreService.submitReport(
        targetId: _wish.id,
        targetType: 'wish',
        reason: result.reason,
        description: result.description,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('report.successMessage'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('report.failureMessage'))),
        );
      }
    }
  }

  Future<void> _handleBlockOwner() async {
    if (_isHandlingOwnerBlock) {
      return;
    }
    final ownerId = _ownerUserId;
    if (ownerId == null || ownerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('wishDetail.ownerMissing'))),
        );
      }
      return;
    }
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('block.confirmTitle')),
        content: Text(l10n.t('block.confirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('block.menuBlockUser')),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    setState(() {
      _isHandlingOwnerBlock = true;
    });
    try {
      await _firestoreService.blockUser(ownerId);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasBlockedOwner = true;
        _isBlockedByOwner = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('block.successMessage'))),
      );
      await _refreshOwnerBlockState(ownerId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('block.failureMessage'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHandlingOwnerBlock = false;
        });
      }
    }
  }

  Future<void> _handleUnblockOwner() async {
    if (_isHandlingOwnerBlock) {
      return;
    }
    final ownerId = _ownerUserId;
    if (ownerId == null || ownerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('wishDetail.ownerMissing'))),
        );
      }
      return;
    }
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('block.unblockConfirmTitle')),
        content: Text(l10n.t('block.unblockConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('block.actionUnblock')),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    setState(() {
      _isHandlingOwnerBlock = true;
    });
    try {
      await _firestoreService.unblockUser(ownerId);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasBlockedOwner = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('block.unblockedMessage'))),
      );
      await _refreshOwnerBlockState(ownerId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('block.unblockFailureMessage'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHandlingOwnerBlock = false;
        });
      }
    }
  }

  Future<void> _handleLike() async {
    final activity = _activity;
    if (activity == null || _isOwnActivity || _isProcessingLike) {
      return;
    }
    if (_hasBlockedOwner || _isBlockedByOwner) {
      final blockMessage = _hasBlockedOwner
          ? context.l10n.t('block.infoBanner')
          : context.l10n.t('block.blockedByOwnerBanner');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(blockMessage)),
        );
      }
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

  void _scrollToComments() {
    if (_isOwnActivity) {
      return;
    }
    final contextRef = _commentsSectionKey.currentContext;
    if (contextRef != null) {
      Scrollable.ensureVisible(
        contextRef,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitComment() async {
    final activity = _activity;
    final text = _commentController.text.trim();

    if (activity == null ||
        text.isEmpty ||
        _isOwnActivity ||
        _isSendingComment) {
      return;
    }
    if (_hasBlockedOwner || _isBlockedByOwner) {
      final blockMessage = _hasBlockedOwner
          ? context.l10n.t('block.infoBanner')
          : context.l10n.t('block.blockedByOwnerBanner');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(blockMessage)),
        );
      }
      return;
    }

    setState(() {
      _isSendingComment = true;
    });

    try {
      await _firestoreService.addCommentToActivity(activity.id, text);
      if (mounted) {
        setState(() {
          _commentsCount += 1;
        });
        _commentController.clear();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('comments.addFailed'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
        });
      }
    }
  }

  void _shareWish() {
    final l10n = context.l10n;
    final wishName = _resolveWishName(l10n);
    final isFriendWish = _activity != null && !_isOwnActivity;
    final friendLabel =
        isFriendWish && _activity != null ? _ownerLabel(_activity!, l10n) : null;

    final sections = <String>[
      isFriendWish
          ? l10n.t(
              'share.friendMessage',
              params: {'user': friendLabel!, 'wish': wishName},
            )
          : l10n.t('share.defaultMessage', params: {'wish': wishName}),
    ];

    final description = _wish.description.trim();
    if (description.isNotEmpty) {
      sections.add(
        l10n.t(
          'share.descriptionLine',
          params: {'description': description},
        ),
      );
    }

    final productUrl = _wish.productUrl.trim();
    if (productUrl.isNotEmpty) {
      sections.add(
        l10n.t(
          'share.productLine',
          params: {'url': productUrl},
        ),
      );
    }

    final subjectKey =
        isFriendWish ? 'share.friendSubject' : 'share.wishSubject';
    final subjectParams = isFriendWish
        ? {'user': friendLabel!, 'wish': wishName}
        : {'wish': wishName};

    SharePlus.instance.share(
      ShareParams(
        text: sections.join('\n\n'),
        subject: l10n.t(subjectKey, params: subjectParams),
      ),
    );
  }

  Future<void> _refreshOwnerBlockState(String ownerId) async {
    try {
      final results = await Future.wait([
        _firestoreService.hasBlockedUser(ownerId),
        _firestoreService.isBlockedByUser(ownerId),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasBlockedOwner = results[0];
        _isBlockedByOwner = results[1];
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasBlockedOwner = false;
        _isBlockedByOwner = false;
      });
    }
  }

  String _resolveWishName(AppLocalizations l10n) {
    final activityWishName = _activity?.wishItem.name ?? '';
    final baseName = activityWishName.trim().isNotEmpty
        ? activityWishName.trim()
        : _wish.name.trim();
    return baseName.isNotEmpty ? baseName : l10n.t('wishDetail.title');
  }

  String _ownerLabel(FriendActivity activity, AppLocalizations l10n) {
    final displayName = activity.userName.trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final username = activity.userUsername.trim();
    if (username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }
    return l10n.t('share.someone');
  }

  Widget _buildHeroImage(BuildContext context, WishItem wish) {
    final theme = Theme.of(context);
    const borderRadius = BorderRadius.all(Radius.circular(18));
    final hasProductLink = wish.productUrl.trim().isNotEmpty;

    Widget hero;

    if (wish.imageUrl.isEmpty) {
      hero = Container(
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
    } else {
      hero = ClipRRect(
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

    if (!hasProductLink) {
      return hero;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => _launchUrl(wish.productUrl),
        child: hero,
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
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.t('wishDetail.ownerLoading'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
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
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.t('wishDetail.ownerMissing'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
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
    final handleLabel =
        handle.startsWith('@') ? handle.substring(1) : handle;
    final header = _isOwnActivity
        ? l10n.t('wishDetail.ownWish')
        : l10n.t('wishDetail.ownerWish', params: {'owner': displayName});
    final addedLabel = l10n.t(
      'wishDetail.addedLabel',
      params: {'time': l10n.relativeTime(activity.activityTime)},
    );
    final initials = displayName.isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';
    final canOpenProfile = _ownerUserId?.isNotEmpty == true;

    Widget avatar = CircleAvatar(
      radius: 28,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      child: hasAvatar
          ? null
          : Text(
              initials,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

    if (canOpenProfile) {
      avatar = GestureDetector(
        onTap: _openOwnerProfile,
        child: avatar,
      );
    }

    Widget ownerDetails = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (handle.isNotEmpty)
              _DetailInfoPill(
                label: handleLabel,
                icon: Icons.alternate_email,
                background: theme.colorScheme.surface.withValues(alpha: 0.65),
                foreground: theme.colorScheme.primary,
                borderColor: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            _DetailInfoPill(
              label: addedLabel,
              icon: Icons.history,
              background: theme.colorScheme.surface.withValues(alpha: 0.65),
              foreground: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ],
        ),
      ],
    );

    if (canOpenProfile) {
      ownerDetails = GestureDetector(
        onTap: _openOwnerProfile,
        behavior: HitTestBehavior.translucent,
        child: ownerDetails,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        avatar,
        const SizedBox(width: 16),
        Expanded(
          child: ownerDetails,
        ),
      ],
    );
  }

  Widget _buildBlockedInfoBanner(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final background = theme.colorScheme.errorContainer.withValues(alpha: 
      theme.brightness == Brightness.dark ? 0.32 : 0.85,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.block,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.t('block.infoBanner'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishInfoCard(BuildContext context, WishItem wish) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final createdLabel =
        '${wish.createdAt.day}.${wish.createdAt.month}.${wish.createdAt.year}';

    final priceLabel = wish.price > 0
        ? '${currencySymbol(wish.currency)} ${formatAmount(wish.price)}'
        : '';

    final pillWidgets = <Widget>[
      if (priceLabel.isNotEmpty)
        _DetailInfoPill(
          label: l10n.t(
            'wishDetail.priceLabel',
            params: {'amount': priceLabel},
          ),
          icon: Icons.sell_outlined,
          background: theme.colorScheme.primary.withValues(alpha: 0.15),
          foreground: theme.colorScheme.primary,
          borderColor: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      _DetailInfoPill(
        label: l10n.t(
          'wishDetail.createdLabel',
          params: {'date': createdLabel},
        ),
        icon: Icons.event_outlined,
        background: theme.colorScheme.surface.withValues(alpha: 0.65),
        foreground: theme.colorScheme.onSurface.withValues(alpha: 0.85),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          wish.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        if (wish.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            wish.description,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: pillWidgets),
        if (wish.productUrl.isNotEmpty) ...[
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _launchUrl(wish.productUrl),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.t('wishDetail.viewProduct')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBlockedWishView(AppLocalizations l10n, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 
                theme.brightness == Brightness.dark ? 0.3 : 0.15,
              ),
            ),
            boxShadow: theme.brightness == Brightness.dark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 32,
                      offset: const Offset(0, 22),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 52, color: theme.colorScheme.error),
              const SizedBox(height: 18),
              Text(
                l10n.t('block.statusBlockedByUser'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.t('block.blockedWishMessage'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
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
    final interactionsBlocked = _hasBlockedOwner || _isBlockedByOwner;
    final likeEnabled =
        _activity != null &&
        !_isOwnActivity &&
        !_isProcessingLike &&
        !interactionsBlocked;
    final commentEnabled =
        _activity != null && !_isOwnActivity && !interactionsBlocked;

    return Row(
      children: [
        Expanded(
          child: _EngagementPillButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            count: _likesCount,
            isActive: _isLiked,
            onTap: likeEnabled ? _handleLike : null,
            tooltip: likeLabel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _EngagementPillButton(
            icon: Icons.chat_bubble_outline,
            count: _commentsCount,
            onTap: commentEnabled ? _scrollToComments : null,
            tooltip: l10n.t('wishDetail.comments'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _EngagementPillButton(
            icon: Icons.share_outlined,
            onTap: _shareWish,
            tooltip: l10n.t('wishDetail.share'),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsSection(BuildContext context) {
    final activity = _activity;
    if (_isOwnActivity || activity == null) {
      return const SizedBox.shrink();
    }
    if (_hasBlockedOwner || _isBlockedByOwner) {
      final message = _hasBlockedOwner
          ? context.l10n.t('block.infoBanner')
          : context.l10n.t('block.blockedWishMessage');
      return Padding(
        key: _commentsSectionKey,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
        ),
      );
    }

    final l10n = context.l10n;
    final stream = _firestoreService.streamActivityComments(activity.id);

    return Column(
      key: _commentsSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('comments.title'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<FriendActivityComment>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.t('comments.unableToLoad'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              );
            }

            final comments = snapshot.data ?? <FriendActivityComment>[];

            if (comments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.t('comments.empty'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final comment = comments[index];
                final relativeTime = l10n.relativeTime(comment.createdAt);
                return _CommentTile(
                  comment: comment,
                  relativeTime: relativeTime,
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        _buildCommentInput(context),
      ],
    );
  }

  Widget _buildCommentInput(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              enabled: !_isSendingComment,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitComment(),
              decoration: InputDecoration(
                hintText: l10n.t('comments.hint'),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_isSendingComment)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              onPressed: _submitComment,
              icon: const Icon(Icons.send_rounded),
              color: theme.colorScheme.primary,
              tooltip: l10n.t('wishDetail.comments'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wish = _wish;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final body = _isBlockedByOwner && !_isOwnActivity
        ? _buildBlockedWishView(l10n, theme)
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: WishLinkCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOwnerSection(context),
                  if (_hasBlockedOwner) ...[
                    const SizedBox(height: 16),
                    _buildBlockedInfoBanner(context),
                  ],
                  const SizedBox(height: 20),
                  _buildHeroImage(context, wish),
                  const SizedBox(height: 20),
                  _buildWishInfoCard(context, wish),
                  const SizedBox(height: 24),
                  _buildEngagementSection(context),
                  if (!_isOwnActivity) ...[
                    const SizedBox(height: 28),
                    _buildCommentsSection(context),
                  ],
                ],
              ),
            ),
          );

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
            )
          else
            PopupMenuButton<_WishViewerAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.t('wishDetail.menuTooltip'),
              onSelected: (action) async {
                switch (action) {
                  case _WishViewerAction.report:
                    await _handleReportWish();
                    break;
                  case _WishViewerAction.block:
                    await _handleBlockOwner();
                    break;
                  case _WishViewerAction.unblock:
                    await _handleUnblockOwner();
                    break;
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<_WishViewerAction>>[
                  PopupMenuItem(
                    value: _WishViewerAction.report,
                    child: Text(l10n.t('report.menuReportWish')),
                  ),
                ];
                final ownerId = _ownerUserId;
                if (ownerId != null && ownerId.isNotEmpty) {
                  final blockAction = _hasBlockedOwner
                      ? _WishViewerAction.unblock
                      : _WishViewerAction.block;
                  final blockLabel = _hasBlockedOwner
                      ? l10n.t('block.menuUnblockUser')
                      : l10n.t('block.menuBlockUser');
                  items.add(
                    PopupMenuItem(
                      value: blockAction,
                      enabled: !_isHandlingOwnerBlock,
                      child: Text(blockLabel),
                    ),
                  );
                }
                return items;
              },
            ),
        ],
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: body,
    );
  }
}

class _EngagementPillButton extends StatelessWidget {
  const _EngagementPillButton({
    required this.icon,
    this.onTap,
    this.isActive = false,
    this.count,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;
  final int? count;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final activeColor = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: enabled ? 0.85 : 0.35);
    final backgroundColor = isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.16)
        : theme.colorScheme.surface.withValues(alpha: enabled ? 0.7 : 0.45);

    Widget button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(icon, size: 20, color: activeColor),
            if ((count ?? 0) > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: activeColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return SizedBox(
      width: double.infinity,
      child: Material(color: Colors.transparent, child: button),
    );
  }
}

class _DetailInfoPill extends StatelessWidget {
  const _DetailInfoPill({
    required this.label,
    this.icon,
    this.background,
    this.foreground,
    this.borderColor,
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor = background ?? theme.colorScheme.surface.withValues(alpha: 0.8);
    final textColor =
        foreground ??
        theme.textTheme.bodySmall?.color ??
        theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? theme.colorScheme.primary.withValues(alpha: 0.08),
          width: 1.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.relativeTime});

  final FriendActivityComment comment;
  final String relativeTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final displayName = comment.userName.isNotEmpty
        ? comment.userName
        : l10n.t('wishDetail.unknownUser');
    final handle = comment.userUsername;
    final avatarUrl = comment.profilePhotoUrl?.trim() ?? '';
    final hasAvatar = avatarUrl.isNotEmpty;
    final initials = displayName.isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'U';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
          child: hasAvatar
              ? null
              : Text(
                  initials,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      relativeTime,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                if (handle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '@$handle',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(comment.comment, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ],
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
