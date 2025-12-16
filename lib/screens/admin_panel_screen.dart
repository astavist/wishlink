import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import 'package:wishlink/screens/admin_report_detail_screen.dart';
import 'package:wishlink/utils/admin_report_utils.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _reportsStream() {
    return FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('settings.adminPanel')),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _reportsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminPanelMessage(
              icon: Icons.warning_amber_outlined,
              message: l10n.t('common.error'),
              description: l10n.t('common.tryAgain'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs =
              snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          if (docs.isEmpty) {
            return _AdminPanelMessage(
              icon: Icons.inbox_outlined,
              message: l10n.t('admin.reportsEmptyTitle'),
              description: l10n.t('admin.reportsEmptySubtitle'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _ReportCard(
                documentId: doc.id,
                data: doc.data(),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminReportDetailScreen(
                        reportId: doc.id,
                        initialData: doc.data(),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.documentId, required this.data, this.onTap});

  final String documentId;
  final Map<String, dynamic> data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final reason = localizedReportReason(data['reason'] as String?, l10n);
    final status = (data['status'] as String?)?.trim();
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
    final targetType = (data['targetType'] as String?)?.trim();
    final description = (data['description'] as String?)?.trim();
    final createdAt = reportTimestampToDateTime(data['createdAt']);
    final formattedDate = createdAt != null
        ? formatAdminExactDate(createdAt, l10n)
        : null;
    final reportedRelative = createdAt != null
        ? l10n.relativeTime(createdAt)
        : null;

    final typeLabel = targetType != null
        ? formatAdminTargetType(targetType, l10n)
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reason,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (reportedRelative != null && formattedDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${l10n.t('admin.reportedAtLabel')}: '
                              '$reportedRelative • $formattedDate',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (status != null && status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _capitalize(status),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _ReportInfoRow(
                label: l10n.t('admin.reporterLabel'),
                value: reporter,
              ),
              const SizedBox(height: 12),
              _ReportInfoRow(
                label: l10n.t('admin.targetLabel'),
                value: typeLabel != null ? '$target • $typeLabel' : target,
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.t('admin.detailsLabel'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(description, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              _ReportInfoRow(
                label: l10n.t('admin.reportIdLabel'),
                value: documentId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportInfoRow extends StatelessWidget {
  const _ReportInfoRow({required this.label, required this.value});

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

class _AdminPanelMessage extends StatelessWidget {
  const _AdminPanelMessage({
    required this.icon,
    required this.message,
    this.description,
  });

  final IconData icon;
  final String message;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null && description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
