import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import 'package:wishlink/services/firestore_service.dart';
import 'package:wishlink/utils/admin_report_utils.dart';
import 'package:wishlink/utils/currency_utils.dart';

enum _AdminReportAction { ignore, removeTarget, banUser }

class AdminReportDetailScreen extends StatefulWidget {
  const AdminReportDetailScreen({
    super.key,
    required this.reportId,
    this.initialData,
  });

  final String reportId;
  final Map<String, dynamic>? initialData;

  @override
  State<AdminReportDetailScreen> createState() =>
      _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isProcessingAction = false;
  String? _banUserId;

  @override
  void initState() {
    super.initState();
    _scheduleBanCandidateUpdate(_candidateUserFromReport(widget.initialData));
  }

  void _scheduleBanCandidateUpdate(String? userId) {
    final normalized = (userId?.trim().isEmpty ?? true) ? null : userId!.trim();
    if (normalized == _banUserId) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _banUserId = normalized;
      });
    });
  }

  String? _candidateUserFromReport(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    final type = _normalizeTargetType(data['targetType']);
    if (type == 'user') {
      final targetId = (data['targetId'] as String?)?.trim();
      if (targetId != null && targetId.isNotEmpty) {
        return targetId;
      }
    }
    return null;
  }

  String _normalizeTargetType(dynamic value) {
    return (value as String?)?.toLowerCase().trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final reportRef = _firestore.collection('reports').doc(widget.reportId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: reportRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? widget.initialData;
        final isLoading = !snapshot.hasData && data == null;
        if (isLoading) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.t('admin.reportDetailTitle')),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (data == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.t('admin.reportDetailTitle')),
            ),
            body: Center(
              child: Text(
                context.l10n.t('admin.targetPreviewUnavailableTitle'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        _scheduleBanCandidateUpdate(_candidateUserFromReport(data));
        final docRef = snapshot.data?.reference ?? reportRef;
        final actions = _availableActions(data);

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.t('admin.reportDetailTitle')),
            actions: [
              if (actions.isNotEmpty)
                _ReportActionsButton(
                  actions: actions,
                  isProcessing: _isProcessingAction,
                  onSelected: (action) => _handleAction(action, docRef, data),
                ),
            ],
          ),
          body: _buildBody(context, data),
        );
      },
    );
  }

  List<_AdminReportAction> _availableActions(Map<String, dynamic> data) {
    final actions = <_AdminReportAction>[_AdminReportAction.ignore];
    final targetType = _normalizeTargetType(data['targetType']);
    if (targetType == 'wish') {
      actions.add(_AdminReportAction.removeTarget);
    }
    if (_banUserId != null && _banUserId!.isNotEmpty) {
      actions.add(_AdminReportAction.banUser);
    }
    return actions;
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> data) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final reason = localizedReportReason(data['reason'] as String?, l10n);
    final status = (data['status'] as String?)?.trim();
    final createdAt = reportTimestampToDateTime(data['createdAt']);
    final formattedCreated = createdAt != null
        ? formatAdminExactDate(createdAt, l10n)
        : null;
    final relativeCreated = createdAt != null
        ? l10n.relativeTime(createdAt)
        : null;
    final reporter = mergeNameAndId(
      data['reporterUsername'] as String?,
      data['reporterId'] as String?,
      l10n,
    );
    final target = mergeNameAndId(
      data['targetUsername'] as String?,
      data['targetId'] as String?,
      l10n,
    );
    final targetTypeLabel = data['targetType'] is String
        ? formatAdminTargetType(data['targetType'] as String, l10n)
        : l10n.t('admin.unknownValue');
    final description = (data['description'] as String?)?.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (status != null && status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Chip(
                      label: Text(_capitalize(status)),
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.08,
                      ),
                    ),
                  ),
                if (relativeCreated != null && formattedCreated != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${l10n.t('admin.reportedAtLabel')}: '
                      '$relativeCreated • $formattedCreated',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 16),
                _KeyValueBlock(
                  label: l10n.t('admin.reporterLabel'),
                  value: reporter,
                ),
                const SizedBox(height: 12),
                _KeyValueBlock(
                  label: l10n.t('admin.targetLabel'),
                  value: '$target • $targetTypeLabel',
                ),
                const SizedBox(height: 12),
                _KeyValueBlock(
                  label: l10n.t('admin.reportIdLabel'),
                  value: widget.reportId,
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('admin.detailsLabel'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(description),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('admin.targetSectionTitle'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _KeyValueBlock(
                  label: l10n.t('admin.targetLabel'),
                  value: '$target • $targetTypeLabel',
                ),
                const SizedBox(height: 12),
                _KeyValueBlock(
                  label: l10n.t('admin.preview.targetIdLabel'),
                  value: (data['targetId'] as String?) ?? '-',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _TargetPreviewSection(
          reportData: data,
          onOwnerResolved: _scheduleBanCandidateUpdate,
        ),
      ],
    );
  }

  Future<void> _handleAction(
    _AdminReportAction action,
    DocumentReference<Map<String, dynamic>> reportRef,
    Map<String, dynamic> reportData,
  ) async {
    final l10n = context.l10n;
    final confirm = await _confirmAction(action, l10n, reportData);
    if (!confirm) {
      return;
    }

    setState(() {
      _isProcessingAction = true;
    });

    try {
      switch (action) {
        case _AdminReportAction.ignore:
          await _updateReportStatus(reportRef, 'ignored');
          break;
        case _AdminReportAction.removeTarget:
          await _removeTarget(reportData);
          await _updateReportStatus(reportRef, 'removed');
          break;
        case _AdminReportAction.banUser:
          final userId = _banUserId;
          if (userId == null || userId.isEmpty) {
            throw Exception('User unavailable');
          }
          await _firestoreService.setUserBanState(
            targetUserId: userId,
            banned: true,
          );
          await _updateReportStatus(reportRef, 'banned');
          break;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('admin.action.success'))));
    } catch (error) {
      if (mounted) {
        final message = l10n.t(
          'admin.action.failure',
          params: {'error': error.toString()},
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _removeTarget(Map<String, dynamic> data) async {
    final targetType = _normalizeTargetType(data['targetType']);
    if (targetType != 'wish') {
      return;
    }
    final targetId = (data['targetId'] as String?)?.trim();
    if (targetId == null || targetId.isEmpty) {
      throw Exception('Target unavailable');
    }
    await _firestoreService.deleteWish(targetId);
  }

  Future<bool> _confirmAction(
    _AdminReportAction action,
    AppLocalizations l10n,
    Map<String, dynamic> data,
  ) async {
    String message;
    switch (action) {
      case _AdminReportAction.ignore:
        message = l10n.t('admin.action.confirmIgnore');
        break;
      case _AdminReportAction.removeTarget:
        message = l10n.t('admin.action.confirmRemove');
        break;
      case _AdminReportAction.banUser:
        message = l10n.t('admin.action.confirmBanUser');
        break;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_actionLabel(action, l10n)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('admin.action.confirm')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _updateReportStatus(
    DocumentReference<Map<String, dynamic>> ref,
    String status,
  ) async {
    final resolvedBy = FirebaseAuth.instance.currentUser?.uid;
    await ref.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
    });
  }

  String _actionLabel(_AdminReportAction action, AppLocalizations l10n) {
    switch (action) {
      case _AdminReportAction.ignore:
        return l10n.t('admin.action.ignore');
      case _AdminReportAction.removeTarget:
        return l10n.t('admin.action.remove');
      case _AdminReportAction.banUser:
        return l10n.t('admin.action.banUser');
    }
  }
}

class _ReportActionsButton extends StatelessWidget {
  const _ReportActionsButton({
    required this.actions,
    required this.isProcessing,
    required this.onSelected,
  });

  final List<_AdminReportAction> actions;
  final bool isProcessing;
  final ValueChanged<_AdminReportAction> onSelected;

  @override
  Widget build(BuildContext context) {
    if (isProcessing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return PopupMenuButton<_AdminReportAction>(
      onSelected: onSelected,
      itemBuilder: (context) => actions
          .map(
            (action) => PopupMenuItem<_AdminReportAction>(
              value: action,
              child: Text(_actionLabel(action, context.l10n)),
            ),
          )
          .toList(),
      icon: const Icon(Icons.more_vert),
    );
  }

  String _actionLabel(_AdminReportAction action, AppLocalizations l10n) {
    switch (action) {
      case _AdminReportAction.ignore:
        return l10n.t('admin.action.ignore');
      case _AdminReportAction.removeTarget:
        return l10n.t('admin.action.remove');
      case _AdminReportAction.banUser:
        return l10n.t('admin.action.banUser');
    }
  }
}

class _TargetPreviewSection extends StatelessWidget {
  const _TargetPreviewSection({
    required this.reportData,
    required this.onOwnerResolved,
  });

  final Map<String, dynamic> reportData;
  final ValueChanged<String?> onOwnerResolved;

  String _targetType() {
    return (reportData['targetType'] as String?)?.toLowerCase().trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final targetId = (reportData['targetId'] as String?)?.trim() ?? '';
    if (targetId.isEmpty) {
      return _PreviewMessage(
        title: l10n.t('admin.targetPreviewUnavailableTitle'),
        subtitle: l10n.t('admin.targetPreviewUnavailableSubtitle'),
      );
    }

    final type = _targetType();
    if (type == 'wish') {
      return _WishPreviewCard(
        wishId: targetId,
        onOwnerResolved: onOwnerResolved,
      );
    }
    if (type == 'user') {
      return _UserPreviewCard(userId: targetId);
    }
    return _PreviewMessage(
      title: l10n.t('admin.targetPreviewUnknown'),
      subtitle: targetId,
    );
  }
}

class _WishPreviewCard extends StatefulWidget {
  const _WishPreviewCard({required this.wishId, required this.onOwnerResolved});

  final String wishId;
  final ValueChanged<String?> onOwnerResolved;

  @override
  State<_WishPreviewCard> createState() => _WishPreviewCardState();
}

class _WishPreviewCardState extends State<_WishPreviewCard> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _wishFuture;

  @override
  void initState() {
    super.initState();
    _wishFuture = FirebaseFirestore.instance
        .collection('wishes')
        .doc(widget.wishId)
        .get();
  }

  @override
  void didUpdateWidget(covariant _WishPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wishId != widget.wishId) {
      _wishFuture = FirebaseFirestore.instance
          .collection('wishes')
          .doc(widget.wishId)
          .get();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _wishFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            widget.onOwnerResolved('');
            return _PreviewMessage(
              title: l10n.t('admin.targetPreviewUnavailableTitle'),
              subtitle: l10n.t('admin.targetPreviewLoadError'),
            );
          }

          final doc = snapshot.data;
          if (doc == null || !doc.exists) {
            widget.onOwnerResolved('');
            return _PreviewMessage(
              title: l10n.t('admin.targetPreviewUnavailableTitle'),
              subtitle: l10n.t('admin.targetPreviewUnavailableSubtitle'),
            );
          }

          final wishData = doc.data()!;
          final ownerId =
              (wishData['ownerId'] as String?)?.trim() ??
              (wishData['userId'] as String?)?.trim() ??
              '';
          widget.onOwnerResolved(ownerId);

          final imageUrl = (wishData['imageUrl'] as String?)?.trim() ?? '';
          final name = (wishData['name'] as String?)?.trim().isNotEmpty == true
              ? (wishData['name'] as String).trim()
              : l10n.t('admin.preview.wishUnknownName');
          final description =
              (wishData['description'] as String?)?.trim() ?? '';
          final price = (wishData['price'] as num?)?.toDouble() ?? 0;
          final currency = (wishData['currency'] as String?)?.trim() ?? 'TRY';
          final productUrl = (wishData['productUrl'] as String?)?.trim() ?? '';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceVariant,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('admin.targetPreviewWishTitle'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t(
                        'admin.preview.wishPriceLabel',
                        params: {'price': formatPrice(price, currency)},
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.t('admin.preview.wishDescriptionLabel'),
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(description),
                    ],
                    const SizedBox(height: 12),
                    _KeyValueBlock(
                      label: l10n.t('admin.preview.wishOwnerLabel'),
                      value: ownerId.isNotEmpty
                          ? ownerId
                          : l10n.t('admin.unknownValue'),
                    ),
                    if (productUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.t('admin.preview.wishLinkLabel'),
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(productUrl),
                    ],
                    const SizedBox(height: 12),
                    _KeyValueBlock(
                      label: l10n.t('admin.preview.targetIdLabel'),
                      value: widget.wishId,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UserPreviewCard extends StatelessWidget {
  const _UserPreviewCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _PreviewMessage(
              title: l10n.t('admin.targetPreviewUnavailableTitle'),
              subtitle: l10n.t('admin.targetPreviewUnavailableSubtitle'),
            );
          }

          final userData = snapshot.data!.data()!;
          final avatarUrl =
              (userData['profilePhotoUrl'] as String?)?.trim() ?? '';
          final username = (userData['username'] as String?)?.trim();
          final firstName = (userData['firstName'] as String?)?.trim() ?? '';
          final lastName = (userData['lastName'] as String?)?.trim() ?? '';
          final email = (userData['email'] as String?)?.trim();
          final isBanned = userData['isBanned'] == true;

          final fullName = [
            firstName,
            lastName,
          ].where((part) => part.isNotEmpty).join(' ').trim();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('admin.targetPreviewUserTitle'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? Icon(
                              Icons.person_outline,
                              size: 32,
                              color: theme.colorScheme.onSurfaceVariant,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username?.isNotEmpty == true
                                ? '@$username'
                                : l10n.t('admin.unknownValue'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (fullName.isNotEmpty)
                            Text(fullName, style: theme.textTheme.bodyMedium),
                          if (email != null && email.isNotEmpty)
                            Text(
                              email,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _KeyValueBlock(
                  label: l10n.t('admin.preview.userStatusLabel'),
                  value: isBanned
                      ? l10n.t('admin.preview.userStatusBanned')
                      : l10n.t('admin.preview.userStatusActive'),
                ),
                const SizedBox(height: 12),
                _KeyValueBlock(
                  label: l10n.t('admin.preview.targetIdLabel'),
                  value: userId,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyValueBlock extends StatelessWidget {
  const _KeyValueBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  if (value.length == 1) {
    return value.toUpperCase();
  }
  return value[0].toUpperCase() + value.substring(1);
}
