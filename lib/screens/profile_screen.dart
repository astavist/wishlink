import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/wish_item.dart';
import 'wish_detail_screen.dart';
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
  String _profilePhotoUrl = '';
  List<WishItem> _userWishes = [];
  List<WishList> _wishLists = [];
  final FirestoreService _firestoreService = FirestoreService();

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
          setState(() {
            _firstName = userData.data()?['firstName'] ?? '';
            _lastName = userData.data()?['lastName'] ?? '';
            _email = userData.data()?['email'] ?? '';
            _profilePhotoUrl = userData.data()?['profilePhotoUrl'] ?? '';
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
        return WishItem.fromMap(wishData, wishData['id'] ?? doc.id);
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

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      // AuthWrapper will automatically navigate to LoginScreen
      // No need to manually navigate as Firebase Auth handles the state
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error signing out')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
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
                      '$_firstName $_lastName',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _email,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    ),
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

              // Account Settings Section
              const Text(
                'Account Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Edit Profile Option
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement edit profile functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit Profile - Coming Soon')),
                  );
                },
              ),

              // Change Password Option
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Change Password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement change password functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Change Password - Coming Soon'),
                    ),
                  );
                },
              ),

              // Notification Settings
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Notification Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement notification settings
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifications - Coming Soon'),
                    ),
                  );
                },
              ),

              const Divider(height: 32),

              // Privacy Settings
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Privacy Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement privacy settings
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Privacy Settings - Coming Soon'),
                    ),
                  );
                },
              ),

              // Help & Support
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('Help & Support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement help & support
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Help & Support - Coming Soon'),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Sign Out'),
                ),
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
