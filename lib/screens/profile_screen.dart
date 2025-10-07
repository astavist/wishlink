import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/wish_item.dart';
import 'wish_detail_screen.dart';
import 'edit_wish_screen.dart';
import '../services/storage_service.dart';
import '../models/wish_list.dart';
import '../services/firestore_service.dart';
import 'all_wishes_screen.dart';
import 'wish_list_detail_screen.dart';

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

  String _formatBirthday(DateTime date) {
    if (_birthdayDisplayPreference == 'dayMonth') {
      final monthName = _turkishMonths[date.month - 1];
      return '${date.day} $monthName';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error loading wishes')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Listeler yüklenemedi')));
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

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditWishScreen(wish: wish),
      ),
    );

    if (updated == true) {
      await _loadUserWishes(user.uid);
    }
  }

  // Profil fotoğrafı seçme ve yükleme
  Future<void> _pickAndUploadProfilePhoto() async {
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
              const SnackBar(
                content: Text('Profil fotoğrafı başarıyla güncellendi!'),
              ),
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
          SnackBar(content: Text('Profil fotoğrafı yüklenirken hata: $e')),
        );
      }
    }
  }

  // Profil fotoğrafı silme
  Future<void> _deleteProfilePhoto() async {
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
            const SnackBar(content: Text('Profil fotoğrafı silindi')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil fotoğrafı silinirken hata: $e')),
        );
      }
    }
  }

  // Profil fotoğrafı seçenekleri dialog'u
  void _showProfilePhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeriden Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadProfilePhoto();
                },
              ),
              if (_profilePhotoUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Fotoğrafı Sil',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteProfilePhoto();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('İptal'),
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

    final displayName = '$_firstName $_lastName'.trim();
    final headerTitle = displayName.isNotEmpty
        ? displayName
        : _username.isNotEmpty
            ? '@$_username'
            : 'Profile';
    final secondaryText = _username.isNotEmpty ? '@$_username' : _email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
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
                    Stack(
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
                        if (_isUploadingPhoto)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: GestureDetector(
                              onTap: _isUploadingPhoto
                                  ? null
                                  : _showProfilePhotoOptions,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      headerTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (secondaryText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        secondaryText,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
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

              // Wish Lists header with Create List button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Wish Lists',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateListDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create List'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFB652),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: (_wishLists.length + 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // All Wishes tile
                    return _ListTileCard(
                      title: 'All Wishes',
                      imageUrl: _userWishes.isNotEmpty
                          ? _userWishes.first.imageUrl
                          : '',
                      onTap: () {
                        Navigator.push(
                          context,
                          createRightToLeftSlideRoute(const AllWishesScreen()),
                        );
                      },
                      leadingIcon: Icons.grid_view,
                    );
                  }

                  final list = _wishLists[index - 1];
                  return _ListTileCard(
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
                  );
                },
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 24),
              const Text(
                'My Wishes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_userWishes.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'You have not added any wishes yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _userWishes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final wish = _userWishes[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            createRightToLeftSlideRoute(
                              WishDetailScreen(wish: wish),
                            ),
                          );
                        },
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
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
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
                            if (wish.price > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.attach_money,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  Text(
                                    wish.price.toStringAsFixed(2),
                                    style: const TextStyle(
                                      color: Colors.green,
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
                          tooltip: 'Wish\'i düzenle',
                          onPressed: () => _openEditWish(wish),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateListDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Liste Oluştur'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Liste adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final newList = await _firestoreService.createWishList(name: result);
        setState(() {
          _wishLists.insert(0, newList);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Liste oluşturulamadı')));
        }
      }
    }
  }

  PopupMenuButton _buildListMenu(WishList list) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'delete') {
          await _firestoreService.deleteWishList(list.id);
          setState(() {
            _wishLists.removeWhere((l) => l.id == list.id);
          });
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
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
        borderRadius: BorderRadius.circular(12),
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
