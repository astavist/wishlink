import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wish_item.dart';
import '../models/wish_list.dart';
import '../utils/currency_utils.dart';
import '../models/user_private_note.dart';
import '../services/firestore_service.dart';
import '../widgets/report_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'wish_detail_screen.dart';
import 'wish_list_detail_screen.dart';
import 'all_wishes_screen.dart';
import 'package:intl/intl.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? userName;
  final String? userEmail;
  final String? userUsername;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.userName,
    this.userEmail,
    this.userUsername,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({required this.formatDate, this.note});

  final UserPrivateNote? note;
  final String Function(DateTime) formatDate;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _controller;
  late DateTime? _selectedDate;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note?.text ?? '');
    _selectedDate = widget.note?.noteDate;
    _canSubmit = _controller.text.trim().isNotEmpty;
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final canSubmit = _controller.text.trim().isNotEmpty;
    if (canSubmit != _canSubmit) {
      setState(() {
        _canSubmit = canSubmit;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 50),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.note == null
            ? context.l10n.t('profile.noteAddTitle')
            : context.l10n.t('profile.noteEditTitle'),
      ),
      content: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: context.l10n.t('profile.noteLabel'),
                  alignLabelWithHint: true,
                ),
                autofocus: true,
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _selectedDate != null
                            ? widget.formatDate(_selectedDate!)
                            : context.l10n.t('profile.pickDateOptional'),
                      ),
                    ),
                  ),
                  if (_selectedDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _clearDate,
                      icon: const Icon(Icons.close),
                      tooltip: context.l10n.t('profile.clearDate'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _canSubmit
              ? () => Navigator.of(context).pop(<String, dynamic>{
                  'text': _controller.text.trim(),
                  'date': _selectedDate,
                })
              : null,
          child: Text(
            widget.note == null
                ? context.l10n.t('common.add')
                : context.l10n.t('common.save'),
          ),
        ),
      ],
    );
  }
}

enum _ProfileAction { reportUser, blockUser, unblockUser }

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _username = '';
  String _profilePhotoUrl = '';
  DateTime? _birthday;
  String _birthdayDisplayPreference = 'dayMonthYear';
  List<WishItem> _userWishes = [];
  List<WishList> _wishLists = [];
  List<UserPrivateNote> _privateNotes = [];
  bool _isFriend = false;
  bool _friendRequestPending = false;
  bool _isSendingFriendRequest = false;
  bool _hasBlockedUser = false;
  bool _isHandlingBlockAction = false;
  bool _isBlockedByTarget = false;

  bool get _isViewingOwnProfile => _auth.currentUser?.uid == widget.userId;

  DateTime? _parseBirthday(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return DateTime(date.year, date.month, date.day);
    }
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    if (value is String && value.isNotEmpty) {
      try {
        final parsed = DateTime.parse(value);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {
        return null;
      }
    }
    if (value is Map) {
      final year = value['year'];
      final month = value['month'];
      final day = value['day'];
      if (year is int && month is int && day is int) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  String _formatBirthday(DateTime date, AppLocalizations l10n) {
    final localeName = l10n.locale.toLanguageTag();
    if (_birthdayDisplayPreference == 'dayMonth') {
      final monthName = DateFormat.MMMM(localeName).format(date);
      return '${date.day} $monthName';
    }
    return DateFormat('dd/MM/yyyy', localeName).format(date);
  }

  String _profileInitials() {
    final first = _firstName.trim();
    final last = _lastName.trim();
    final buffer = StringBuffer();
    if (first.isNotEmpty) {
      buffer.write(first.characters.first);
    }
    if (last.isNotEmpty) {
      buffer.write(last.characters.first);
    }
    if (buffer.isEmpty && _username.trim().isNotEmpty) {
      buffer.write(_username.trim().characters.first);
    }
    if (buffer.isEmpty && _email.trim().isNotEmpty) {
      buffer.write(_email.trim().characters.first);
    }
    return buffer.isNotEmpty ? buffer.toString().toUpperCase() : 'WL';
  }

  String _resolveDisplayName(AppLocalizations l10n) {
    final resolvedName = [
      _firstName.trim(),
      _lastName.trim(),
    ].where((value) => value.isNotEmpty).join(' ').trim();

    if (resolvedName.isNotEmpty) {
      return resolvedName;
    }

    return widget.userName ?? l10n.t('profile.defaultUserName');
  }

  String _formatNoteDate(DateTime date, AppLocalizations l10n) {
    final localeName = l10n.locale.toLanguageTag();
    return DateFormat('dd.MM.yyyy', localeName).format(date);
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      await _checkBlockStates();
      final blockRestriction = _hasBlockedUser || _isBlockedByTarget;
      if (!blockRestriction) {
        await _checkFriendshipStatus();
        if (!_isViewingOwnProfile && !_isFriend) {
          await _checkFriendRequestStatus();
        } else if (mounted) {
          setState(() {
            _friendRequestPending = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _isFriend = false;
          _friendRequestPending = false;
        });
      }

      // Load user profile data
      final userData = await _firestore
          .collection('users')
          .doc(widget.userId)
          .get();
      if (userData.exists) {
        final data = userData.data();
        if (!mounted) {
          return;
        }
        setState(() {
          _firstName = data?['firstName'] ?? '';
          _lastName = data?['lastName'] ?? '';
          _email = data?['email'] ?? '';
          _username =
              (data?['username'] as String?)?.trim() ??
              widget.userUsername ??
              '';
          _profilePhotoUrl = data?['profilePhotoUrl'] ?? '';
          _birthday = _parseBirthday(data?['birthday']);
          final displayPreference =
              (data?['birthdayDisplay'] as String?) ?? 'dayMonthYear';
          if (displayPreference == 'dayMonth' ||
              displayPreference == 'dayMonthYear') {
            _birthdayDisplayPreference = displayPreference;
          } else {
            _birthdayDisplayPreference = 'dayMonthYear';
          }
        });
      }

      if (_isBlockedByTarget && !_isViewingOwnProfile) {
        if (!mounted) {
          return;
        }
        setState(() {
          _userWishes = [];
          _wishLists = [];
          _privateNotes = [];
          _isLoading = false;
        });
        return;
      }

      // Load user's wishes from friend_activities
      await _loadUserWishes(widget.userId);
      await _loadUserWishLists(widget.userId);

      if (_isViewingOwnProfile) {
        if (mounted) {
          setState(() {
            _privateNotes = [];
          });
        }
      } else {
        await _loadPrivateNotes();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('profile.errorLoadingUser'))),
        );
      }
    }
  }

  Future<void> _checkFriendshipStatus() async {
    try {
      final isFriend = await _firestoreService.isFriendWith(widget.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _isFriend = isFriend;
        if (isFriend) {
          _friendRequestPending = false;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFriend = false;
      });
    }
  }

  Future<void> _checkBlockStates() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _hasBlockedUser = false;
          _isBlockedByTarget = false;
        });
        return;
      }

      final results = await Future.wait([
        _firestoreService.hasBlockedUser(widget.userId),
        _firestoreService.isBlockedByUser(widget.userId),
      ]);

      if (!mounted) {
        return;
      }
      final viewerBlockedTarget = results[0];
      final blockedByTarget = results[1];
      setState(() {
        _hasBlockedUser = viewerBlockedTarget;
        _isBlockedByTarget = blockedByTarget;
        if (viewerBlockedTarget || blockedByTarget) {
          _isFriend = false;
          _friendRequestPending = false;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasBlockedUser = false;
        _isBlockedByTarget = false;
      });
    }
  }

  Future<void> _checkFriendRequestStatus() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return;
      }
      final outgoingRequest = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: currentUser.uid)
          .where('friendId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'pending')
          .where('type', isEqualTo: 'request')
          .limit(1)
          .get();
      if (!mounted) {
        return;
      }
      setState(() {
        _friendRequestPending = outgoingRequest.docs.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _friendRequestPending = false;
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_isSendingFriendRequest || _isViewingOwnProfile) {
      return;
    }
    setState(() {
      _isSendingFriendRequest = true;
    });
    try {
      await _firestoreService.sendFriendRequest(widget.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _friendRequestPending = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('friends.snackbarRequestSent'))),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.t('friends.snackbarRequestFailed')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingFriendRequest = false;
        });
      }
    }
  }

  Future<void> _handleReportUser() async {
    final l10n = context.l10n;
    final displayName = _resolveDisplayName(l10n);
    final result = await showReportDialog(
      context: context,
      title: l10n.t('report.userTitle', params: {'name': displayName}),
      description: l10n.t('report.userDescription'),
    );
    if (result == null) {
      return;
    }
    try {
      await _firestoreService.submitReport(
        targetId: widget.userId,
        targetType: 'user',
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

  Future<void> _handleBlockUser() async {
    if (_isHandlingBlockAction) {
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
      _isHandlingBlockAction = true;
    });
    try {
      await _firestoreService.blockUser(widget.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasBlockedUser = true;
        _isFriend = false;
        _friendRequestPending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('block.successMessage'))),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('block.failureMessage'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHandlingBlockAction = false;
        });
      }
    }
  }

  Future<void> _handleUnblockUser() async {
    if (_isHandlingBlockAction) {
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
      _isHandlingBlockAction = true;
    });
    try {
      await _firestoreService.unblockUser(widget.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasBlockedUser = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('block.unblockedMessage'))),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('block.unblockFailureMessage'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHandlingBlockAction = false;
        });
      }
    }
  }

  Future<void> _loadUserWishes(String userId) async {
    try {
      final wishesSnapshot = await _firestore
          .collection('friend_activities')
          .where('userId', isEqualTo: userId)
          .where('activityType', isEqualTo: 'added')
          .orderBy('activityTime', descending: true)
          .limit(20)
          .get();

      final wishes = wishesSnapshot.docs.map((doc) {
        final data = doc.data();
        final wishData = data['wishItem'] as Map<String, dynamic>;
        final wishId =
            (data['wishItemId'] as String?) ?? wishData['id'] ?? doc.id;
        return WishItem.fromMap(wishData, wishId);
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _userWishes = wishes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('profile.errorLoadingWishes'))),
        );
      }
    }
  }

  Future<void> _loadUserWishLists(String userId) async {
    try {
      final lists = await _firestoreService.getUserWishLists(userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _wishLists = lists;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('profile.errorLoadingLists'))),
        );
      }
    }
  }

  Future<void> _loadPrivateNotes() async {
    try {
      final notes = await _firestoreService.getPrivateNotesForUser(
        widget.userId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _privateNotes = notes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('profile.errorLoadingNotes'))),
        );
      }
    }
  }

  Future<void> _handleAddOrEditNote({UserPrivateNote? note}) async {
    final result = await _showNoteEditorDialog(note: note);
    if (result == null) {
      return;
    }

    final text = (result['text'] as String).trim();
    final DateTime? noteDate = result['date'] as DateTime?;

    if (text.isEmpty) {
      return;
    }

    try {
      if (note == null) {
        await _firestoreService.addPrivateNote(
          targetUserId: widget.userId,
          text: text,
          noteDate: noteDate,
        );
      } else {
        await _firestoreService.updatePrivateNote(
          noteId: note.id,
          text: text,
          noteDate: noteDate,
        );
      }

      await _loadPrivateNotes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              note == null
                  ? context.l10n.t('profile.noteSaved')
                  : context.l10n.t('profile.noteUpdated'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('profile.noteSaveFailed'))),
        );
      }
    }
  }

  Future<void> _handleDeleteNote(UserPrivateNote note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.t('profile.noteDeleteTitle')),
        content: Text(context.l10n.t('profile.noteDeleteMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.t('common.delete')),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await _firestoreService.deletePrivateNote(note.id);
      await _loadPrivateNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('profile.noteDeleted'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('profile.noteDeleteFailed'))),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showNoteEditorDialog({UserPrivateNote? note}) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return _NoteEditorDialog(
          note: note,
          formatDate: (date) => _formatNoteDate(date, context.l10n),
        );
      },
    );
  }

  Widget _buildPrivateNotesSection(ThemeData theme, AppLocalizations l10n) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.t('profile.myNotes'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _handleAddOrEditNote,
                tooltip: l10n.t('profile.addNoteTooltip'),
                icon: const Icon(Icons.note_add_outlined),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(32, 32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_privateNotes.isEmpty)
            _buildEmptyNotesState(theme, l10n)
          else
            ..._privateNotes.map((note) => _buildNoteTile(note, theme, l10n)),
        ],
      ),
    );
  }

  Widget _buildEmptyNotesState(ThemeData theme, AppLocalizations l10n) {
    final backgroundColor = theme.brightness == Brightness.dark
        ? Colors.white.withAlpha(13)
        : const Color(0xFFF7F7F7);
    final textColor = theme.brightness == Brightness.dark
        ? Colors.white70
        : Colors.grey[600];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('profile.noNotes'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('profile.notesDescription'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _handleAddOrEditNote,
            icon: const Icon(Icons.add),
            label: Text(l10n.t('profile.addNoteButton')),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTile(
    UserPrivateNote note,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final tileColor = theme.brightness == Brightness.dark
        ? const Color(0xFF262626)
        : Colors.white;
    final borderColor = theme.brightness == Brightness.dark
        ? Colors.white.withAlpha(13)
        : Colors.black.withAlpha(13);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: theme.brightness == Brightness.dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        title: Text(
          note.text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: (note.noteDate != null || note.updatedAt != null)
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.noteDate != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.event,
                            size: 16,
                            color: Color(0xFFEFB652),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatNoteDate(note.noteDate!, l10n),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (note.updatedAt != null)
                      Text(
                        l10n.t(
                          'profile.noteUpdatedAt',
                          params: {
                            'date': _formatNoteDate(note.updatedAt!, l10n),
                          },
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              )
            : null,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _handleAddOrEditNote(note: note);
            } else if (value == 'delete') {
              _handleDeleteNote(note);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'edit',
              child: Text(l10n.t('profile.noteEdit')),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Text(l10n.t('profile.noteDelete')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishesSection(
    ThemeData theme,
    AppLocalizations l10n,
    String wishesTitle,
    String emptyStateName,
  ) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wishesTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          if (_userWishes.isEmpty)
            _buildEmptyWishState(theme, l10n, emptyStateName)
          else
            ..._userWishes.map(
              (wish) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildWishCard(wish, theme, l10n),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWishListsSection(
    ThemeData theme,
    AppLocalizations l10n,
    String allWishesTitle,
  ) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('profile.wishLists'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 12.0;
              final tileWidth = (constraints.maxWidth - spacing) / 2;
              final tiles = <Widget>[
                _buildAllWishesTile(tileWidth, l10n, allWishesTitle),
                ..._wishLists.map(
                  (list) => _buildWishListTile(tileWidth, list),
                ),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: tiles,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAllWishesTile(
    double tileWidth,
    AppLocalizations l10n,
    String appBarTitle,
  ) {
    return SizedBox(
      width: tileWidth,
      child: AspectRatio(
        aspectRatio: 1,
        child: _ListTileCard(
          title: l10n.t('profile.allWishes'),
          imageUrl: _userWishes.isNotEmpty ? _userWishes.first.imageUrl : '',
          leadingIcon: Icons.grid_view,
          onTap: () {
            Navigator.of(
              context,
            ).push(
              createRightToLeftSlideRoute(
                AllWishesScreen(
                  userId: widget.userId,
                  title: appBarTitle,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWishListTile(double tileWidth, WishList list) {
    return SizedBox(
      width: tileWidth,
      child: AspectRatio(
        aspectRatio: 1,
        child: _ListTileCard(
          title: list.name,
          imageUrl: list.coverImageUrl,
          onTap: () {
            Navigator.of(context).push(
              createRightToLeftSlideRoute(WishListDetailScreen(wishList: list)),
            );
          },
        ),
      ),
    );
  }

  Widget? _buildFriendStatusWidget(ThemeData theme, AppLocalizations l10n) {
    if (_isViewingOwnProfile) {
      return null;
    }
    if (_isBlockedByTarget) {
        return _buildStatusPill(
          backgroundColor: theme.colorScheme.errorContainer.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.4 : 0.9,
          ),
        icon: Icons.block,
        iconColor: theme.colorScheme.error,
        label: l10n.t('block.statusBlockedByUser'),
        textStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (_hasBlockedUser) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusPill(
            backgroundColor: theme.colorScheme.errorContainer.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.35 : 0.25,
            ),
            icon: Icons.block,
            iconColor: theme.colorScheme.error,
            label: l10n.t('block.statusBlocked'),
            textStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _isHandlingBlockAction ? null : _handleUnblockUser,
            child: Text(l10n.t('block.actionUnblock')),
          ),
        ],
      );
    }
    if (_isFriend) {
      return _buildStatusPill(
        backgroundColor: const Color(0xFFE6F4EA),
        icon: Icons.check_circle,
        iconColor: Colors.green,
        label: l10n.t('friends.statusFriends'),
        textStyle: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.green[700],
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (_friendRequestPending) {
      return _buildStatusPill(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        icon: Icons.hourglass_top,
        iconColor: theme.colorScheme.primary,
        label: l10n.t('friends.statusRequestSent'),
        textStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSendingFriendRequest ? null : _sendFriendRequest,
        icon: const Icon(Icons.person_add_alt),
        label: Text(l10n.t('friends.buttonSendRequest')),
      ),
    );
  }

  Widget _buildProfileActionsMenu(AppLocalizations l10n) {
    final blockAction =
        _hasBlockedUser ? _ProfileAction.unblockUser : _ProfileAction.blockUser;
    final blockLabel = _hasBlockedUser
        ? l10n.t('block.menuUnblockUser')
        : l10n.t('block.menuBlockUser');

    return PopupMenuButton<_ProfileAction>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert),
      onSelected: (action) async {
        switch (action) {
          case _ProfileAction.reportUser:
            await _handleReportUser();
            break;
          case _ProfileAction.blockUser:
            await _handleBlockUser();
            break;
          case _ProfileAction.unblockUser:
            await _handleUnblockUser();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ProfileAction.reportUser,
          child: Text(l10n.t('report.menuReportUser')),
        ),
        PopupMenuItem(
          value: blockAction,
          enabled: !_isHandlingBlockAction,
          child: Text(blockLabel),
        ),
      ],
    );
  }

  Widget _buildBlockedProfileNotice(
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(20)
              : Colors.black.withAlpha(12),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 30,
                  offset: const Offset(0, 20),
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            l10n.t('block.statusBlockedByUser'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('block.blockedProfileMessage'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required Color backgroundColor,
    required IconData icon,
    required Color iconColor,
    required String label,
    TextStyle? textStyle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishCard(WishItem wish, ThemeData theme, AppLocalizations l10n) {
    final tileColor = theme.brightness == Brightness.dark
        ? const Color(0xFF262626)
        : Colors.white;
    final borderColor = theme.brightness == Brightness.dark
        ? Colors.white.withAlpha(13)
        : Colors.black.withAlpha(13);

    return Container(
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: theme.brightness == Brightness.dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            onTap: () {
              Navigator.of(
                context,
              ).push(createRightToLeftSlideRoute(WishDetailScreen(wish: wish)));
            },
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: wish.imageUrl.isNotEmpty
                  ? Image.network(
                      wish.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildWishPlaceholder(),
                    )
                  : _buildWishPlaceholder(),
            ),
            title: Text(
              wish.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wish.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      wish.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (wish.price > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1A2ECC71),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          currencySymbol(wish.currency),
                          style: const TextStyle(
                            color: Color(0xFF2ECC71),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatAmount(wish.price),
                        style: const TextStyle(
                          color: Color(0xFF2ECC71),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (wish.productUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () => _launchUrl(wish.productUrl),
                icon: const Icon(Icons.link),
                label: Text(l10n.t('common.viewProduct')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWishPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget _buildEmptyWishState(
    ThemeData theme,
    AppLocalizations l10n,
    String emptyStateName,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.favorite_border,
            size: 36,
            color: isDark ? Colors.white70 : Colors.grey[500],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('profile.noWishesTitle'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.t(
              'profile.noWishesSubtitle',
              params: {'name': emptyStateName},
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshPage() async {
    await _loadUserData();
  }

  Future<void> _launchUrl(String url) async {
    if (url.isNotEmpty) {
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final handle =
        (_username.isNotEmpty ? _username : (widget.userUsername ?? '')).trim();
    final resolvedName = [
      _firstName.trim(),
      _lastName.trim(),
    ].where((value) => value.isNotEmpty).join(' ').trim();
    final fallbackName = resolvedName.isNotEmpty
        ? resolvedName
        : (widget.userName ?? l10n.t('profile.defaultUserName'));
    final handleLabel = handle.isNotEmpty ? '@$handle' : '';
    final profileTitle = handleLabel.isNotEmpty ? handleLabel : fallbackName;
    final emptyStateName = handleLabel.isNotEmpty
        ? handleLabel
        : l10n.t('profile.userUnknown');
    final wishesTitle = l10n.t(
      'profile.wishesTitle',
      params: {'handle': emptyStateName},
    );
    final headerSubtitleLines = <String>[
      if (handleLabel.isNotEmpty) handleLabel,
      if (_email.isNotEmpty) _email,
    ];
    final backgroundColor =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final headerRow = Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            profileTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!_isViewingOwnProfile) ...[
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: _buildProfileActionsMenu(l10n),
          ),
        ],
      ],
    );

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isBlockedByTarget && !_isViewingOwnProfile) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                headerRow,
                const SizedBox(height: 32),
                _buildBlockedProfileNotice(l10n, theme),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshPage,
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.surface.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.9 : 1,
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                headerRow,
                const SizedBox(height: 16),
                _ProfileHeaderCard(
                  title: fallbackName,
                  subtitleLines: headerSubtitleLines,
                  birthdayText: _birthday != null
                      ? _formatBirthday(_birthday!, l10n)
                      : null,
                  imageUrl: _profilePhotoUrl,
                  isUploading: false,
                  onAvatarTap: null,
                  wishCount: _userWishes.length,
                  listCount: 0,
                  wishLabel: l10n.t('profile.myWishes'),
                  listLabel: l10n.t('profile.wishLists'),
                  statusWidget: _buildFriendStatusWidget(theme, l10n),
                  initials: _profileInitials(),
                ),
                const SizedBox(height: 24),
                if (!_isViewingOwnProfile) ...[
                  _buildPrivateNotesSection(theme, l10n),
                  const SizedBox(height: 24),
                ],
                _buildWishListsSection(theme, l10n, wishesTitle),
                const SizedBox(height: 24),
                _buildWishesSection(theme, l10n, wishesTitle, emptyStateName),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(13)
              : Colors.black.withAlpha(10),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 32,
                  offset: const Offset(0, 22),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final String title;
  final List<String>? subtitleLines;
  final String? birthdayText;
  final String imageUrl;
  final bool isUploading;
  final VoidCallback? onAvatarTap;
  final int wishCount;
  final int listCount;
  final String wishLabel;
  final String listLabel;
  final Widget? statusWidget;
  final String initials;

  const _ProfileHeaderCard({
    required this.title,
    this.subtitleLines,
    this.birthdayText,
    required this.imageUrl,
    required this.isUploading,
    this.onAvatarTap,
    required this.wishCount,
    required this.listCount,
    required this.wishLabel,
    required this.listLabel,
    this.statusWidget,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentColor = theme.colorScheme.onSurface;
    final captionColor = theme.colorScheme.onSurfaceVariant;
    final effectiveLines =
        subtitleLines
            ?.map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF6A441), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: imageUrl.isNotEmpty
                    ? Colors.white.withAlpha(77)
                    : theme.colorScheme.primary.withValues(
                        alpha:
                            theme.brightness == Brightness.dark ? 0.35 : 0.12,
                      ),
                backgroundImage: imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
                child: imageUrl.isEmpty
                    ? Text(
                        initials,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : theme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(115),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              if (onAvatarTap != null)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onAvatarTap,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Color(0xFFF6A441),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: contentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (effectiveLines.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...effectiveLines.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == effectiveLines.length - 1 ? 0 : 4,
                ),
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: captionColor,
                  ),
                ),
              ),
            ),
          ],
          if (statusWidget != null) ...[
            const SizedBox(height: 12),
            statusWidget!,
          ],
          if (birthdayText != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cake_outlined, size: 18, color: captionColor),
                const SizedBox(width: 8),
                Text(
                  birthdayText!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: captionColor,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatChip(label: listLabel, value: listCount.toString()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(label: wishLabel, value: wishCount.toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.onSurface.withAlpha(80)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListTileCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;
  final IconData? leadingIcon;

  const _ListTileCard({
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.grey[300]),
              )
            else
              Container(color: Colors.grey[200]),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black54],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  if (leadingIcon != null) ...[
                    Icon(leadingIcon, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      title,
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
          ],
        ),
      ),
    );
  }
}
