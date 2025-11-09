import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wish_item.dart';
import '../utils/currency_utils.dart';
import '../models/user_private_note.dart';
import '../services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'wish_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:wishlink/l10n/app_localizations.dart';
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
  List<UserPrivateNote> _privateNotes = [];
  bool _isFriend = false;

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
      await _checkFriendshipStatus();

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

      // Load user's wishes from friend_activities
      await _loadUserWishes(widget.userId);

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

  Widget _buildPrivateNotesSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.t('profile.myNotes'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _handleAddOrEditNote(),
              tooltip: l10n.t('profile.addNoteTooltip'),
              icon: const Icon(Icons.note_add_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_privateNotes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('profile.noNotes'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t('profile.notesDescription'),
                  style: TextStyle(color: Colors.grey[600], height: 1.4),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _handleAddOrEditNote(),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.t('profile.addNoteButton')),
                ),
              ],
            ),
          )
        else
          ..._privateNotes.map(
            (note) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  note.text,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: (note.noteDate != null || note.updatedAt != null)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (note.noteDate != null) ...[
                            const SizedBox(height: 6),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (note.updatedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              l10n.t(
                                'profile.noteUpdatedAt',
                                params: {
                                  'date': _formatNoteDate(
                                    note.updatedAt!,
                                    l10n,
                                  ),
                                },
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      )
                    : null,
                isThreeLine: note.noteDate != null || note.updatedAt != null,
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
            ),
          ),
      ],
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

    final appBar = AppBar(
      title: Text(profileTitle),
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );

    if (_isLoading) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _profilePhotoUrl.isNotEmpty
                          ? NetworkImage(_profilePhotoUrl)
                          : null,
                      child: _profilePhotoUrl.isEmpty
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      fallbackName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_isFriend && !_isViewingOwnProfile) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4EA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.t('friends.statusFriends'),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_email.isNotEmpty)
                      Text(
                        _email,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    if (_birthday != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cake_outlined,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatBirthday(_birthday!, context.l10n),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (!_isViewingOwnProfile) ...[
                _buildPrivateNotesSection(l10n),
                const SizedBox(height: 32),
              ],

              // User's Wishes Section
              Text(
                wishesTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              if (_userWishes.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.t('profile.noWishesTitle'),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.t(
                          'profile.noWishesSubtitle',
                          params: {'name': emptyStateName},
                        ),
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...(_userWishes
                    .map(
                      (wish) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () {
                            Navigator.of(context).push(
                              createRightToLeftSlideRoute(
                                WishDetailScreen(wish: wish),
                              ),
                            );
                          },
                          leading: wish.imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    wish.imageUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(Icons.image),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.image),
                                ),
                          title: Text(
                            wish.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (wish.description.isNotEmpty)
                                Text(
                                  wish.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              if (wish.price > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        currencySymbol(wish.currency),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      formatAmount(wish.price),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: wish.productUrl.isNotEmpty
                              ? ElevatedButton.icon(
                                  onPressed: () => _launchUrl(wish.productUrl),
                                  icon: const Icon(Icons.link, size: 16),
                                  label: Text(l10n.t('common.viewProduct')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEFB652),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 32),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    )
                    .toList()),
            ],
          ),
        ),
      ),
    );
  }
}
