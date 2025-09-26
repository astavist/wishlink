import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wish_item.dart';
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

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _username = '';
  String _profilePhotoUrl = '';
  List<WishItem> _userWishes = [];

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
        setState(() {
          _firstName = userData.data()?['firstName'] ?? '';
          _lastName = userData.data()?['lastName'] ?? '';
          _email = userData.data()?['email'] ?? '';
          _username =
              (userData.data()?['username'] as String?)?.trim() ??
              widget.userUsername ??
              '';
          _profilePhotoUrl = userData.data()?['profilePhotoUrl'] ?? '';
        });
      }

      // Load user's wishes from friend_activities
      await _loadUserWishes(widget.userId);

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
                  ],
                ),
              ),
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
