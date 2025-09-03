import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/wish_item.dart';
import 'wish_detail_screen.dart';
import '../services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

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

  void _openWishDetail(WishItem wish) {
    Navigator.push(
      context,
      createRightToLeftSlideRoute(WishDetailScreen(wish: wish)),
    );
  }

  Future<String?> _showSwipeActionDialog(WishItem wish) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Action'),
          content: Text('What would you like to do with "${wish.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('edit'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('delete'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
          ],
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

              // My Wishes Section
              const Text(
                'My Wishes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        'Add your first wish to get started!',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...(_userWishes
                    .map(
                      (wish) => Dismissible(
                        key: Key(wish.id),
                        direction: DismissDirection
                            .endToStart, // Only allow left swipe
                        confirmDismiss: (direction) async {
                          final action = await _showSwipeActionDialog(wish);
                          if (action == 'delete') {
                            await _deleteWish(wish);
                            return true;
                          } else if (action == 'edit') {
                            _openWishDetail(wish);
                            return false; // Don't dismiss, just show edit dialog
                          }
                          return false; // Don't dismiss if no action selected
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          color: Colors.orange,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.swipe_left,
                                color: Colors.white,
                                size: 30,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Swipe for options',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _openWishDetail(wish),
                          borderRadius: BorderRadius.circular(12),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: wish.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        wish.imageUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
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
                                          '${wish.price.toStringAsFixed(2)}',
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
                                      onPressed: () =>
                                          _launchUrl(wish.productUrl),
                                      icon: const Icon(Icons.link, size: 16),
                                      label: const Text('View Product'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFEFB652,
                                        ),
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
                        ),
                      ),
                    )
                    .toList()),

              // Dynamic spacing based on whether there are wishes
              SizedBox(height: _userWishes.isEmpty ? 16 : 32),

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

  Future<bool> _showDeleteWishDialog(WishItem wish) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wish'),
        content: Text('Are you sure you want to delete "${wish.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteWish(WishItem wish) async {
    try {
      // Find and delete the friend activity that contains this wish
      final activitySnapshot = await _firestore
          .collection('friend_activities')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('activityType', isEqualTo: 'added')
          .get();

      for (var doc in activitySnapshot.docs) {
        final data = doc.data();
        final wishData = data['wishItem'] as Map<String, dynamic>;
        if (wishData['id'] == wish.id || wishData['name'] == wish.name) {
          await doc.reference.delete();
          break;
        }
      }

      await _loadUserWishes(_auth.currentUser!.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wish deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error deleting wish')));
      }
    }
  }
}
