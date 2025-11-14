import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import '../models/wish_item.dart';
import 'wish_detail_screen.dart';
import 'edit_wish_screen.dart';
import '../services/storage_service.dart';
import '../models/wish_list.dart';
import '../services/firestore_service.dart';
import '../utils/currency_utils.dart';
import 'all_wishes_screen.dart';
import 'wish_list_detail_screen.dart';
import '../widgets/wish_list_editor_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _username = '';
  String _profilePhotoUrl = '';
  DateTime? _birthday;
  String _birthdayDisplayPreference = 'dayMonthYear';
  List<WishItem> _userWishes = [];
  List<WishList> _wishLists = [];
  final FirestoreService _firestoreService = FirestoreService();

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Load user profile data
        final userData = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userData.exists) {
          final data = userData.data();
          setState(() {
            _firstName = data?['firstName'] ?? '';
            _lastName = data?['lastName'] ?? '';
            _email = data?['email'] ?? '';
            _username = (data?['username'] as String?)?.trim() ?? '';
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

        // Load profile photo from storage if not in Firestore
        if (_profilePhotoUrl.isEmpty) {
          try {
            final photoUrl = await _storageService.getProfilePhotoUrl(user.uid);
            if (photoUrl != null) {
              setState(() {
                _profilePhotoUrl = photoUrl;
              });
              // Update Firestore with the photo URL
              await _firestore.collection('users').doc(user.uid).update({
                'profilePhotoUrl': photoUrl,
              });
            }
          } catch (e) {
            // Profile photo not found, that's okay
          }
        }

        // Load user's wishes from friend_activities
        await _loadUserWishes(user.uid);
        // Load user's wish lists
        await _loadUserWishLists(user.uid);

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('profile.errorLoadingUser'))),
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
          .get();

      final wishes = wishesSnapshot.docs.map((doc) {
        final data = doc.data();
        final wishData = data['wishItem'] as Map<String, dynamic>;
        final wishId =
            (data['wishItemId'] as String?) ?? wishData['id'] ?? doc.id;
        return WishItem.fromMap(wishData, wishId);
      }).toList();

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

  Future<void> _refreshPage() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _loadUserData();
    }
  }

  Future<void> _openEditWish(WishItem wish) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final updated = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => EditWishScreen(wish: wish)));

    if (updated == true) {
      await _loadUserWishes(user.uid);
    }
  }

  // Profil fotoğrafı seçme ve yükleme
  Future<void> _pickAndUploadProfilePhoto() async {
    final l10n = context.l10n;
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _isUploadingPhoto = true;
        });

        final user = _auth.currentUser;
        if (user != null) {
          final file = File(pickedFile.path);

          // Upload to Firebase Storage
          final photoUrl = await _storageService.uploadProfilePhoto(
            userId: user.uid,
            file: file,
          );

          // Update Firestore
          await _firestore.collection('users').doc(user.uid).update({
            'profilePhotoUrl': photoUrl,
          });

          setState(() {
            _profilePhotoUrl = photoUrl;
            _isUploadingPhoto = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.t('profile.photoUpdateSuccess'))),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isUploadingPhoto = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.t('profile.photoUpdateError', params: {'error': '$e'}),
            ),
          ),
        );
      }
    }
  }

  // Profil fotoğrafı silme
  Future<void> _deleteProfilePhoto() async {
    final l10n = context.l10n;
    try {
      final user = _auth.currentUser;
      if (user != null && _profilePhotoUrl.isNotEmpty) {
        // Delete from Storage
        await _storageService.deleteProfilePhoto(user.uid);

        // Update Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'profilePhotoUrl': '',
        });

        setState(() {
          _profilePhotoUrl = '';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('profile.photoDeleteSuccess'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.t('profile.photoDeleteError', params: {'error': '$e'}),
            ),
          ),
        );
      }
    }
  }

  // Profil fotoğrafı seçenekleri dialog'u
  void _showProfilePhotoOptions() {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(l10n.t('profile.photoPickFromGallery')),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadProfilePhoto();
                },
              ),
              if (_profilePhotoUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    l10n.t('profile.photoRemove'),
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteProfilePhoto();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(l10n.t('common.cancel')),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final displayName = '$_firstName $_lastName'.trim();
    final headerTitle = displayName.isNotEmpty
        ? displayName
        : _username.isNotEmpty
        ? '@$_username'
        : l10n.t('profile.title');
    final secondaryText = _username.isNotEmpty ? '@$_username' : _email;

    return Scaffold(
      backgroundColor:
          theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        color: theme.primaryColor,
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
              _ProfileHeaderCard(
                title: headerTitle,
                subtitle: secondaryText.isNotEmpty ? secondaryText : null,
                birthdayText: _birthday != null
                    ? _formatBirthday(_birthday!, l10n)
                    : null,
                imageUrl: _profilePhotoUrl,
                isUploading: _isUploadingPhoto,
                onAvatarTap: _isUploadingPhoto
                    ? null
                    : _showProfilePhotoOptions,
                wishCount: _userWishes.length,
                listCount: _wishLists.length,
                wishLabel: l10n.t('profile.myWishes'),
                listLabel: l10n.t('profile.wishLists'),
              ),
              const SizedBox(height: 24),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            l10n.t('profile.wishLists'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _showCreateListDialog(),
                          tooltip: l10n.t('profile.createList'),
                          icon: const Icon(Icons.add_circle_outline),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(32, 32),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final spacing = 12.0;
                        final tileWidth = (constraints.maxWidth - spacing) / 2;
                        final tiles = <Widget>[
                          _ListTileCard(
                            title: l10n.t('profile.allWishes'),
                            imageUrl: _userWishes.isNotEmpty
                                ? _userWishes.first.imageUrl
                                : '',
                            onTap: () {
                              Navigator.push(
                                context,
                                createRightToLeftSlideRoute(
                                  const AllWishesScreen(),
                                ),
                              );
                            },
                            leadingIcon: Icons.grid_view,
                          ),
                          ..._wishLists.map(
                            (list) => _ListTileCard(
                              title: list.name,
                              imageUrl: list.coverImageUrl,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  createRightToLeftSlideRoute(
                                    WishListDetailScreen(wishList: list),
                                  ),
                                );
                              },
                              menuBuilder: _buildListMenu(list),
                            ),
                          ),
                        ];

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: tiles
                              .map(
                                (tile) => SizedBox(
                                  width: tileWidth,
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: tile,
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('profile.myWishes'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_userWishes.isEmpty)
                      _buildEmptyWishState(theme, l10n)
                    else
                      Column(
                        children: List.generate(_userWishes.length, (index) {
                          final wish = _userWishes[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _userWishes.length - 1 ? 0 : 12,
                            ),
                            child: _buildWishCard(wish, theme, l10n),
                          );
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateListDialog() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }
    final l10n = context.l10n;
    final result = await showWishListEditorDialog(
      context: context,
      isEditing: false,
    );
    if (result == null) {
      return;
    }

    try {
      var coverUrl = '';
      if (result.coverImageBytes != null) {
        coverUrl = await _storageService.uploadWishListCoverBytes(
          userId: user.uid,
          bytes: result.coverImageBytes!,
          contentType: result.coverImageContentType,
        );
      }
      final newList = await _firestoreService.createWishList(
        name: result.name,
        coverImageUrl: coverUrl,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _wishLists.insert(0, newList);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('profile.listCreateFailed'))),
      );
    }
  }

  Future<void> _showEditListDialog(WishList list) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }
    final l10n = context.l10n;
    final result = await showWishListEditorDialog(
      context: context,
      isEditing: true,
      initialName: list.name,
      existingCoverImageUrl: list.coverImageUrl,
    );
    if (result == null) {
      return;
    }

    try {
      String? coverUrl;
      if (result.coverImageBytes != null) {
        coverUrl = await _storageService.uploadWishListCoverBytes(
          userId: user.uid,
          bytes: result.coverImageBytes!,
          contentType: result.coverImageContentType,
        );
      } else if (result.removeExistingCover) {
        coverUrl = '';
      }

      await _firestoreService.updateWishList(
        listId: list.id,
        name: result.name,
        coverImageUrl: coverUrl,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final index = _wishLists.indexWhere((item) => item.id == list.id);
        if (index != -1) {
          _wishLists[index] = list.copyWith(
            name: result.name,
            coverImageUrl: coverUrl ?? list.coverImageUrl,
          );
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('profile.listUpdateFailed'))),
      );
    }
  }

  PopupMenuButton _buildListMenu(WishList list) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'edit') {
          await _showEditListDialog(list);
          return;
        }
        if (value == 'delete') {
          await _firestoreService.deleteWishList(list.id);
          setState(() {
            _wishLists.removeWhere((l) => l.id == list.id);
          });
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'edit',
          child: Text(l10n.t('common.edit')),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(l10n.t('common.delete')),
        ),
      ],
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () {
          Navigator.push(
            context,
            createRightToLeftSlideRoute(WishDetailScreen(wish: wish)),
          );
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
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.t('profile.editWishTooltip'),
          onPressed: () => _openEditWish(wish),
        ),
      ),
    );
  }

  Widget _buildEmptyWishState(ThemeData theme, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withAlpha(13)
            : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.favorite_border,
            size: 36,
            color: theme.brightness == Brightness.dark
                ? Colors.white70
                : Colors.grey[500],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('profile.emptyWishes'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey[600],
            ),
          ),
        ],
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
  final String? subtitle;
  final String? birthdayText;
  final String imageUrl;
  final bool isUploading;
  final VoidCallback? onAvatarTap;
  final int wishCount;
  final int listCount;
  final String wishLabel;
  final String listLabel;

  const _ProfileHeaderCard({
    required this.title,
    this.subtitle,
    this.birthdayText,
    required this.imageUrl,
    required this.isUploading,
    this.onAvatarTap,
    required this.wishCount,
    required this.listCount,
    required this.wishLabel,
    required this.listLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentColor = theme.colorScheme.onSurface;
    final captionColor = theme.colorScheme.onSurfaceVariant;
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
                backgroundColor: Colors.white.withAlpha(77),
                backgroundImage: imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
                child: imageUrl.isEmpty
                    ? const Icon(Icons.person, size: 48, color: Colors.white)
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
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(color: captionColor),
            ),
          ],
          if (birthdayText != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cake_outlined, color: contentColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  birthdayText!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w500,
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
          const SizedBox(height: 18),
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
  final PopupMenuButton? menuBuilder;

  const _ListTileCard({
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.leadingIcon,
    this.menuBuilder,
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black54],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
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
                  if (menuBuilder != null) menuBuilder!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
