import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wish_item.dart';
import 'login_screen.dart';
import 'package:url_launcher/url_launcher.dart';

// Custom page route for right-to-left slide animation
PageRouteBuilder<dynamic> _createSlideRoute(Widget page) {
  return PageRouteBuilder<dynamic>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);

      return SlideTransition(position: offsetAnimation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _firstName = '';
  String _lastName = '';
  String _email = '';
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
          });
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
                    const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50),
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
                          final shouldDelete = await _showDeleteWishDialog(
                            wish,
                          );
                          if (shouldDelete) {
                            await _deleteWish(wish);
                          }
                          return shouldDelete;
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          color: Colors.red,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete, color: Colors.white, size: 30),
                              SizedBox(height: 4),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                  const SizedBox(height: 4),
                                ],
                                if (wish.productUrl.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _launchUrl(wish.productUrl),
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
                                  ),
                                ],
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  // TODO: Implement edit wish functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Edit Wish - Coming Soon'),
                                    ),
                                  );
                                } else if (value == 'delete') {
                                  _showDeleteWishDialog(wish);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
