import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wish_item.dart';
import '../models/user_private_note.dart';
import '../services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'wish_detail_screen.dart';

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
  const _NoteEditorDialog({
    required this.formatDate,
    this.note,
  });

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
      title: Text(widget.note == null ? 'Not Ekle' : 'Notu Düzenle'),
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
                decoration: const InputDecoration(
                  labelText: 'Not',
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
                            : 'Tarih seç (opsiyonel)',
                      ),
                    ),
                  ),
                  if (_selectedDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _clearDate,
                      icon: const Icon(Icons.close),
                      tooltip: 'Tarihi temizle',
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
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _canSubmit
              ? () => Navigator.of(context).pop(
                    <String, dynamic>{
                      'text': _controller.text.trim(),
                      'date': _selectedDate,
                    },
                  )
              : null,
          child: Text(widget.note == null ? 'Ekle' : 'Kaydet'),
        ),
      ],
    );
  }
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _username = '';
  String _profilePhotoUrl = '';
  DateTime? _birthday;
  String _birthdayDisplayPreference = 'dayMonthYear';
  static const List<String> _turkishMonths = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  List<WishItem> _userWishes = [];
  List<UserPrivateNote> _privateNotes = [];

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

  String _formatBirthday(DateTime date) {
    if (_birthdayDisplayPreference == 'dayMonth') {
      final monthName = _turkishMonths[date.month - 1];
      return '${date.day} $monthName';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatNoteDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
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

      await _loadPrivateNotes();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading user data')),
        );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error loading wishes')));
      }
    }
  }

  Future<void> _loadPrivateNotes() async {
    try {
      final notes =
          await _firestoreService.getPrivateNotesForUser(widget.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _privateNotes = notes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(content: Text('Notlar yüklenirken bir hata oluştu')),
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
            content: Text(note == null
                ? 'Not kaydedildi'
                : 'Not güncellendi'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not kaydedilemedi')),
        );
      }
    }
  }

  Future<void> _handleDeleteNote(UserPrivateNote note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notu Sil'),
        content: const Text(
          'Bu notu silmek istediğinden emin misin? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
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
          const SnackBar(content: Text('Not silindi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not silinemedi')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showNoteEditorDialog({
    UserPrivateNote? note,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return _NoteEditorDialog(
          note: note,
          formatDate: _formatNoteDate,
        );
      },
    );
  }

  Widget _buildPrivateNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Kişisel Notlarım',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _handleAddOrEditNote(),
              tooltip: 'Not ekle',
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
                  'Henüz not eklemedin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu kullanıcı hakkında sadece senin görebileceğin hatırlatıcılar oluşturabilirsin.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _handleAddOrEditNote(),
                  icon: const Icon(Icons.add),
                  label: const Text('Not ekle'),
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
                                  _formatNoteDate(note.noteDate!),
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
                              'Son güncelleme: ${_formatNoteDate(note.updatedAt!)}',
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
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Düzenle'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Sil'),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not open link')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final handle =
        (_username.isNotEmpty ? _username : (widget.userUsername ?? '')).trim();
    final resolvedName = [
      _firstName.trim(),
      _lastName.trim(),
    ].where((value) => value.isNotEmpty).join(' ').trim();
    final fallbackName = resolvedName.isNotEmpty
        ? resolvedName
        : (widget.userName ?? 'User');
    final profileTitle = handle.isNotEmpty ? '@$handle' : fallbackName;
    final wishesTitle = handle.isNotEmpty
        ? '@$handle\'s Wishes'
        : "$fallbackName's Wishes";
    final emptyStateName = handle.isNotEmpty
        ? '@$handle'
        : (fallbackName.isNotEmpty ? fallbackName : 'This user');

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
                            _formatBirthday(_birthday!),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildPrivateNotesSection(),
              const SizedBox(height: 32),

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
                        'No wishes yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$emptyStateName hasn\'t added any wishes yet',
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
                                    const Icon(
                                      Icons.attach_money,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      wish.price.toStringAsFixed(2),
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
                                  label: const Text('View Product'),
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
