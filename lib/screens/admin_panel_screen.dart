import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import 'package:wishlink/screens/admin_report_detail_screen.dart';
import 'package:wishlink/screens/user_profile_screen.dart';
import 'package:wishlink/services/firestore_service.dart';
import 'package:wishlink/utils/admin_report_utils.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

enum _AdminPanelSection { reports, users, banned }

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _userResults = [];
  _AdminPanelSection _currentSection = _AdminPanelSection.reports;
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isUserSearchLoading = false;
  String? _userSearchError;
  String? _banActionUserId;
  String? _processingReportId;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _reportsStream() {
    return FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _bannedUsersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('isBanned', isEqualTo: true)
        .orderBy('bannedAt', descending: true)
        .snapshots();
  }

  void _onSectionChanged(_AdminPanelSection section) {
    if (_currentSection == section) {
      return;
    }
    setState(() {
      _currentSection = section;
    });
    if (_currentSection == _AdminPanelSection.users) {
      _triggerUserSearch(_searchController.text);
    }
  }

  void _onSearchChanged(String value) {
    final normalized = value.trim().toLowerCase();
    setState(() {
      _searchQuery = normalized;
    });

    _searchDebounce?.cancel();
    if (_currentSection == _AdminPanelSection.users) {
      _searchDebounce = Timer(
        const Duration(milliseconds: 350),
        () => _triggerUserSearch(value),
      );
    }
  }

  void _triggerUserSearch(String rawQuery) {
    final normalized = rawQuery.trim().toLowerCase();
    if (normalized.length < 3) {
      setState(() {
        _userResults.clear();
        _isUserSearchLoading = false;
        _userSearchError = null;
      });
      return;
    }

    setState(() {
      _isUserSearchLoading = true;
      _userSearchError = null;
    });

    FirebaseFirestore.instance
        .collection('users')
        .orderBy('username')
        .startAt([normalized])
        .endAt(['$normalized\uf8ff'])
        .limit(50)
        .get()
        .then((snapshot) {
      if (!mounted) {
        return;
      }
      setState(() {
        _userResults
          ..clear()
          ..addAll(snapshot.docs);
        _isUserSearchLoading = false;
      });
    }).catchError((error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _userResults.clear();
        _isUserSearchLoading = false;
        _userSearchError = '$error';
      });
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _userResults.clear();
      _isUserSearchLoading = false;
      _userSearchError = null;
    });
  }

  Future<void> _handleBanAction(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool ban,
  ) async {
    final l10n = context.l10n;
    setState(() {
      _banActionUserId = doc.id;
    });
    try {
      await _firestoreService.setUserBanState(
        targetUserId: doc.id,
        banned: ban,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ban
                ? l10n.t('admin.userBanSuccess')
                : l10n.t('admin.userUnbanSuccess'),
          ),
        ),
      );
      _triggerUserSearch(_searchController.text);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t(
              'admin.userBanFailure',
              params: {'error': '$error'},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _banActionUserId = null;
        });
      }
    }
  }

  Future<void> _handleReportBanAction(
    String? targetUserId,
    bool ban,
    String reportId,
  ) async {
    final l10n = context.l10n;
    final normalized = targetUserId?.trim();
    if (normalized == null || normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('admin.reportNoTargetForBan'))),
      );
      return;
    }
    setState(() {
      _processingReportId = reportId;
    });
    try {
      await _firestoreService.setUserBanState(
        targetUserId: normalized,
        banned: ban,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ban
                ? l10n.t('admin.userBanSuccess')
                : l10n.t('admin.userUnbanSuccess'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t(
              'admin.userBanFailure',
              params: {'error': '$error'},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingReportId = null;
        });
      }
    }
  }

  Future<void> _handleReportDelete(String reportId) async {
    final l10n = context.l10n;
    setState(() {
      _processingReportId = reportId;
    });
    try {
      await FirebaseFirestore.instance.collection('reports').doc(reportId).delete();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('admin.reportDeleteSuccess'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t(
              'admin.reportDeleteFailure',
              params: {'error': '$error'},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingReportId = null;
        });
      }
    }
  }

  Future<void> _openUserProfileDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final firstName = (data['firstName'] as String? ?? '').trim();
    final lastName = (data['lastName'] as String? ?? '').trim();
    final displayName = [firstName, lastName]
        .where((value) => value.isNotEmpty)
        .join(' ')
        .trim();
    final email = (data['email'] as String? ?? '').trim();
    final username = (data['username'] as String? ?? '').trim();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: _UserProfileDialog(
            userId: doc.id,
            userName: displayName.isNotEmpty ? displayName : null,
            userEmail: email.isNotEmpty ? email : null,
            userUsername: username.isNotEmpty ? username : null,
          ),
        );
      },
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterReports(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (_searchQuery.isEmpty) {
      return docs;
    }

    return docs.where((doc) {
      final data = doc.data();
      final reporter =
          (data['reporterUsername'] as String?)?.trim().toLowerCase() ?? '';
      final target =
          (data['targetUsername'] as String?)?.trim().toLowerCase() ?? '';
      return reporter.contains(_searchQuery) || target.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final searchHint = _currentSection == _AdminPanelSection.reports
        ? l10n.t('admin.searchReportsHint')
        : _currentSection == _AdminPanelSection.users
            ? l10n.t('admin.searchUsersHint')
            : l10n.t('admin.searchBannedHint');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('settings.adminPanel')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminSectionToggle(
                  currentSection: _currentSection,
                  onChanged: _onSectionChanged,
                ),
                const SizedBox(height: 12),
                _SearchField(
                  controller: _searchController,
                  hint: searchHint,
                  onChanged: _onSearchChanged,
                  onSubmitted: (value) {
                    if (_currentSection == _AdminPanelSection.users) {
                      _triggerUserSearch(value);
                    }
                  },
                  onClear: _searchController.text.isNotEmpty ? _clearSearch : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _currentSection == _AdminPanelSection.reports
                ? _ReportsList(
                    stream: _reportsStream(),
                    filter: _filterReports,
                    onBanAction: _handleReportBanAction,
                    onDeleteReport: _handleReportDelete,
                    processingReportId: _processingReportId,
                  )
                : _currentSection == _AdminPanelSection.users
                    ? _UsersSearchList(
                        query: _searchQuery,
                        isLoading: _isUserSearchLoading,
                        errorMessage: _userSearchError,
                        results: _userResults,
                        onUserTap: _openUserProfileDialog,
                        onBanAction: _handleBanAction,
                        processingUserId: _banActionUserId,
                      )
                    : _BannedUsersList(
                        stream: _bannedUsersStream(),
                        searchQuery: _searchQuery,
                        onUserTap: _openUserProfileDialog,
                        onBanAction: _handleBanAction,
                        processingUserId: _banActionUserId,
                      ),
          ),
        ],
      ),
    );
  }
}

class _AdminSectionToggle extends StatelessWidget {
  const _AdminSectionToggle({
    required this.currentSection,
    required this.onChanged,
  });

  final _AdminPanelSection currentSection;
  final ValueChanged<_AdminPanelSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sections = const [
      _AdminPanelSection.reports,
      _AdminPanelSection.users,
      _AdminPanelSection.banned,
    ];

    return ToggleButtons(
      isSelected:
          sections.map((section) => currentSection == section).toList(),
      borderRadius: BorderRadius.circular(999),
      onPressed: (index) {
        if (index < sections.length) {
          onChanged(sections[index]);
        }
      },
      fillColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      selectedColor: theme.colorScheme.primary,
      color: theme.textTheme.bodyMedium?.color,
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_outlined, size: 18),
              const SizedBox(width: 8),
              Text(l10n.t('admin.tabReports')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 8),
              Text(l10n.t('admin.tabUsers')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_outlined, size: 18),
              const SizedBox(width: 8),
              Text(l10n.t('admin.tabBanned')),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.35 : 0.9,
    );

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              splashRadius: 18,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportsList extends StatelessWidget {
  const _ReportsList({
    required this.stream,
    required this.filter,
    required this.onBanAction,
    required this.onDeleteReport,
    this.processingReportId,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> Function(
    List<QueryDocumentSnapshot<Map<String, dynamic>>>,
  ) filter;
  final void Function(String? targetUserId, bool ban, String reportId)
      onBanAction;
  final ValueChanged<String> onDeleteReport;
  final String? processingReportId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
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

        final docs = snapshot.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (docs.isEmpty) {
          return _AdminPanelMessage(
            icon: Icons.inbox_outlined,
            message: l10n.t('admin.reportsEmptyTitle'),
            description: l10n.t('admin.reportsEmptySubtitle'),
          );
        }

        final filteredDocs = filter(docs);
        if (filteredDocs.isEmpty) {
          return _AdminPanelMessage(
            icon: Icons.search_off_outlined,
            message: l10n.t('admin.reportsFilteredEmpty'),
            description: l10n.t('admin.searchReportsHint'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: filteredDocs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data();
            final targetId = (data['targetId'] as String?)?.trim() ?? '';
            return _ReportCard(
              documentId: doc.id,
              data: data,
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
              onDelete: () => onDeleteReport(doc.id),
              onBanTarget: targetId.isNotEmpty
                  ? () => onBanAction(targetId, true, doc.id)
                  : null,
              onUnbanTarget: targetId.isNotEmpty
                  ? () => onBanAction(targetId, false, doc.id)
                  : null,
              isProcessing: processingReportId == doc.id,
            );
          },
        );
      },
    );
  }
}

class _BannedUsersList extends StatelessWidget {
  const _BannedUsersList({
    required this.stream,
    required this.searchQuery,
    required this.onUserTap,
    required this.onBanAction,
    this.processingUserId,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String searchQuery;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onUserTap;
  final void Function(
    QueryDocumentSnapshot<Map<String, dynamic>>,
    bool ban,
  ) onBanAction;
  final String? processingUserId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
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

        final docs = snapshot.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (docs.isEmpty) {
          return _AdminPanelMessage(
            icon: Icons.block_outlined,
            message: l10n.t('admin.bannedEmptyTitle'),
            description: l10n.t('admin.bannedEmptySubtitle'),
          );
        }

        final filteredDocs = _applyFilter(docs);
        if (filteredDocs.isEmpty) {
          return _AdminPanelMessage(
            icon: Icons.search_off_outlined,
            message: l10n.t('admin.bannedFilteredEmpty'),
            description: l10n.t('admin.searchBannedHint'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: filteredDocs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            return _UserResultCard(
              userDoc: doc,
              onTap: () => onUserTap(doc),
              onBanAction: (shouldBan) => onBanAction(doc, shouldBan),
              isProcessing: processingUserId == doc.id,
            );
          },
        );
      },
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return docs;
    }

    return docs.where((doc) {
      final data = doc.data();
      final username =
          (data['username'] as String?)?.trim().toLowerCase() ?? '';
      final firstName =
          (data['firstName'] as String?)?.trim().toLowerCase() ?? '';
      final lastName =
          (data['lastName'] as String?)?.trim().toLowerCase() ?? '';
      final fullName = '$firstName $lastName'.trim();
      return username.contains(query) || fullName.contains(query);
    }).toList();
  }
}

class _UsersSearchList extends StatelessWidget {
  const _UsersSearchList({
    required this.query,
    required this.isLoading,
    required this.errorMessage,
    required this.results,
    required this.onUserTap,
    required this.onBanAction,
    this.processingUserId,
  });

  final String query;
  final bool isLoading;
  final String? errorMessage;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> results;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onUserTap;
  final void Function(
    QueryDocumentSnapshot<Map<String, dynamic>>,
    bool ban,
  ) onBanAction;
  final String? processingUserId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (query.length < 3) {
      return _AdminPanelMessage(
        icon: Icons.person_search_rounded,
        message: l10n.t('admin.searchUsersHint'),
        description: l10n.t('admin.usersSearchStart'),
      );
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return _AdminPanelMessage(
        icon: Icons.error_outline,
        message: l10n.t('common.error'),
        description: l10n.t('admin.usersSearchError'),
      );
    }

    if (results.isEmpty) {
      return _AdminPanelMessage(
        icon: Icons.search_off_outlined,
        message: l10n.t('admin.usersNoResults'),
        description: l10n.t('admin.searchUsersHint'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = results[index];
        return _UserResultCard(
          userDoc: doc,
          onTap: () => onUserTap(doc),
          isProcessing: processingUserId == doc.id,
          onBanAction: (shouldBan) => onBanAction(doc, shouldBan),
        );
      },
    );
  }
}

enum _ReportMenuAction { delete, ban, unban }

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.documentId,
    required this.data,
    this.onTap,
    this.onDelete,
    this.onBanTarget,
    this.onUnbanTarget,
    this.isProcessing = false,
  });

  final String documentId;
  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onBanTarget;
  final VoidCallback? onUnbanTarget;
  final bool isProcessing;

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

    final hasMenu =
        onDelete != null || onBanTarget != null || onUnbanTarget != null;

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
                              '$reportedRelative  $formattedDate',
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
                  if (hasMenu)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: isProcessing
                          ? SizedBox(
                              height: 28,
                              width: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary,
                                ),
                              ),
                            )
                          : PopupMenuButton<_ReportMenuAction>(
                              icon: const Icon(Icons.more_vert_rounded),
                              tooltip: l10n.t('admin.reportActionsTooltip'),
                              onSelected: (action) {
                                switch (action) {
                                  case _ReportMenuAction.delete:
                                    onDelete?.call();
                                    break;
                                  case _ReportMenuAction.ban:
                                    onBanTarget?.call();
                                    break;
                                  case _ReportMenuAction.unban:
                                    onUnbanTarget?.call();
                                    break;
                                }
                              },
                              itemBuilder: (context) {
                                final items =
                                    <PopupMenuEntry<_ReportMenuAction>>[];
                                if (onBanTarget != null) {
                                  items.add(
                                    PopupMenuItem(
                                      value: _ReportMenuAction.ban,
                                      child: Text(l10n.t('admin.userBanOption')),
                                    ),
                                  );
                                }
                                if (onUnbanTarget != null) {
                                  items.add(
                                    PopupMenuItem(
                                      value: _ReportMenuAction.unban,
                                      child:
                                          Text(l10n.t('admin.userUnbanOption')),
                                    ),
                                  );
                                }
                                if (onDelete != null) {
                                  items.add(
                                    PopupMenuItem(
                                      value: _ReportMenuAction.delete,
                                      child: Text(l10n.t('admin.reportDeleteOption')),
                                    ),
                                  );
                                }
                                return items;
                              },
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
                value: typeLabel != null ? '$target  $typeLabel' : target,
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

enum _UserMenuAction { ban, unban }

class _UserResultCard extends StatelessWidget {
  const _UserResultCard({
    required this.userDoc,
    this.onTap,
    this.onBanAction,
    this.isProcessing = false,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> userDoc;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onBanAction;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final data = userDoc.data();
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final firstName = (data['firstName'] as String? ?? '').trim();
    final lastName = (data['lastName'] as String? ?? '').trim();
    final displayName = [firstName, lastName]
        .where((value) => value.isNotEmpty)
        .join(' ')
        .trim();
    final username = (data['username'] as String? ?? '').trim();
    final email = (data['email'] as String? ?? '').trim();
    final isBanned = (data['isBanned'] as bool?) ?? false;
    final handle = username.isNotEmpty ? '@$username' : null;
    final fallback = displayName.isNotEmpty
        ? displayName
        : handle ?? l10n.t('admin.unknownValue');

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
                          fallback,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (displayName.isNotEmpty && handle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            handle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                        if (isBanned) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l10n.t('admin.preview.userStatusBanned'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onBanAction != null)
                    isProcessing
                        ? Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: SizedBox(
                              height: 28,
                              width: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          )
                        : PopupMenuButton<_UserMenuAction>(
                            onSelected: (action) {
                              switch (action) {
                                case _UserMenuAction.ban:
                                  onBanAction?.call(true);
                                  break;
                                case _UserMenuAction.unban:
                                  onBanAction?.call(false);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: _UserMenuAction.ban,
                                child: Text(l10n.t('admin.userBanOption')),
                              ),
                              PopupMenuItem(
                                value: _UserMenuAction.unban,
                                child: Text(l10n.t('admin.userUnbanOption')),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert_rounded),
                            tooltip: l10n.t('admin.userActionsTooltip'),
                          ),
                ],
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.t('common.emailLabel'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(email, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.t('admin.userIdLabel'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                userDoc.id,
                style: theme.textTheme.bodyMedium?.copyWith(
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

class _UserProfileDialog extends StatelessWidget {
  const _UserProfileDialog({
    required this.userId,
    this.userName,
    this.userEmail,
    this.userUsername,
  });

  final String userId;
  final String? userName;
  final String? userEmail;
  final String? userUsername;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double width =
        size.width >= 720 ? 640 : math.max(size.width - 32, 320);
    final double height = size.height * 0.9;
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: UserProfileScreen(
              userId: userId,
              userName: userName,
              userEmail: userEmail,
              userUsername: userUsername,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black.withValues(alpha: 0.2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: context.l10n.t('common.cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
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
