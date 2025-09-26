import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_service.dart';
import '../screens/user_profile_screen.dart';

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

class FriendsScreen extends StatefulWidget {
  final int initialTabIndex;

  const FriendsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  int _incomingRequestCount = 0;
  Set<String> _friendIds = <String>{};
  Set<String> _incomingRequestIds = <String>{};
  Set<String> _outgoingRequestIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    final requests = await _firestoreService.getFriendRequests();
    final friendIds = await _firestoreService.getFriendIds();

    final incomingDocs = requests['incoming'] ?? <DocumentSnapshot>[];
    final outgoingDocs = requests['outgoing'] ?? <DocumentSnapshot>[];

    final incomingIds = incomingDocs
        .map(
          (doc) =>
              ((doc.data() as Map<String, dynamic>?)?['userId'] as String?) ??
              '',
        )
        .where((id) => id.isNotEmpty)
        .toSet();
    final outgoingIds = outgoingDocs
        .map(
          (doc) =>
              ((doc.data() as Map<String, dynamic>?)?['friendId'] as String?) ??
              '',
        )
        .where((id) => id.isNotEmpty)
        .toSet();

    if (mounted) {
      setState(() {
        _incomingRequestCount = incomingDocs.length;
        _friendIds = friendIds.toSet();
        _incomingRequestIds = incomingIds;
        _outgoingRequestIds = outgoingIds;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _firestoreService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error searching users')));
      }
    }
  }

  String _formatDisplayName(Map<String, dynamic> data) {
    final firstName = (data['firstName'] as String? ?? '').trim();
    final lastName = (data['lastName'] as String? ?? '').trim();
    final username = (data['username'] as String?)?.trim() ?? '';
    final displayName = [
      firstName,
      lastName,
    ].where((value) => value.isNotEmpty).join(' ').trim();

    if (username.isNotEmpty) {
      if (displayName.isNotEmpty) {
        return '$displayName (@$username)';
      }
      return '@$username';
    }

    return displayName.isNotEmpty ? displayName : 'User';
  }

  String _buildInitials(Map<String, dynamic> data) {
    final firstName = (data['firstName'] as String? ?? '').trim();
    final lastName = (data['lastName'] as String? ?? '').trim();
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    }
    final username = (data['username'] as String?)?.trim() ?? '';
    if (username.isNotEmpty) {
      return username[0].toUpperCase();
    }
    return '?';
  }

  Widget _buildStatusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'My Friends'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Incoming'),
                  if (_incomingRequestCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '($_incomingRequestCount)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Tab(text: 'Outgoing'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _isSearching = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),

          // Search Results or TabBarView
          if (_searchController.text.isNotEmpty)
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _buildSearchResults(),
            )
          else
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFriendsList(),
                  _buildIncomingRequests(),
                  _buildOutgoingRequests(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    final currentUserId = _auth.currentUser?.uid;

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final userData = user.data() as Map<String, dynamic>;

        final avatarUrl =
            (userData['profilePhotoUrl'] as String?)?.trim() ?? '';
        final displayName = _formatDisplayName(userData);
        final initials = _buildInitials(userData);
        final email = (userData['email'] as String? ?? '').trim();

        final isSelf = user.id == currentUserId;
        final isFriend = _friendIds.contains(user.id);
        final hasOutgoing = _outgoingRequestIds.contains(user.id);
        final hasIncoming = _incomingRequestIds.contains(user.id);

        Widget? trailing;
        if (isSelf) {
          trailing = null;
        } else if (isFriend) {
          trailing = _buildStatusChip('Friends');
        } else if (hasOutgoing) {
          trailing = _buildStatusChip('Request sent');
        } else if (hasIncoming) {
          trailing = TextButton(
            onPressed: () {
              _tabController.animateTo(1);
            },
            child: const Text('Respond'),
          );
        } else {
          trailing = TextButton(
            onPressed: () async {
              try {
                await _firestoreService.sendFriendRequest(user.id);
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Friend request sent successfully'),
                  ),
                );
                await _loadData();
                setState(() {
                  _outgoingRequestIds.add(user.id);
                });
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error sending friend request'),
                    ),
                  );
                }
              }
            },
            child: const Text('Add Friend'),
          );
        }

        return ListTile(
          leading: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                _createSlideRoute(
                  UserProfileScreen(
                    userId: user.id,
                    userName:
                        '${userData['firstName']} ${userData['lastName']}',
                    userUsername: (userData['username'] as String?)?.trim(),
                  ),
                ),
              );
            },
            child: CircleAvatar(
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isNotEmpty ? null : Text(initials),
            ),
          ),
          title: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                _createSlideRoute(
                  UserProfileScreen(
                    userId: user.id,
                    userName:
                        '${userData['firstName']} ${userData['lastName']}',
                    userUsername: (userData['username'] as String?)?.trim(),
                  ),
                ),
              );
            },
            child: Text(displayName),
          ),
          subtitle: email.isNotEmpty ? Text(email) : null,
          trailing: trailing,
        );
      },
    );
  }

  Widget _buildFriendsList() {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: _firestoreService.getFriends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              await _loadData();
              setState(() {});
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No friends yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Connect with friends to see their wishes',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _loadData();
            setState(() {});
          },
          child: ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friendship = friends[index];
              final friendId = friendship['friendId'] as String;

              return FutureBuilder<DocumentSnapshot?>(
                future: _firestoreService.getUserProfile(friendId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;

                  final displayName = _formatDisplayName(userData);
                  final avatarUrl =
                      (userData['profilePhotoUrl'] as String?)?.trim() ?? '';
                  final email = (userData['email'] as String? ?? '').trim();

                  return ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          _createSlideRoute(
                            UserProfileScreen(
                              userId: friendId,
                              userName:
                                  '${userData['firstName']} ${userData['lastName']}',
                              userUsername:
                                  (userData['username'] as String?)?.trim(),
                            ),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        backgroundImage:
                            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isNotEmpty
                            ? null
                            : Text(_buildInitials(userData)),
                      ),
                    ),
                    title: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          _createSlideRoute(
                            UserProfileScreen(
                              userId: friendId,
                              userName:
                                  '${userData['firstName']} ${userData['lastName']}',
                              userUsername:
                                  (userData['username'] as String?)?.trim(),
                            ),
                          ),
                        );
                      },
                      child: Text(displayName),
                    ),
                    subtitle: email.isNotEmpty ? Text(email) : null,
                    trailing: TextButton(
                      onPressed: () async {
                        try {
                          await _firestoreService.removeFriend(friendId);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Friend removed successfully'),
                              ),
                            );
                            // UI'ı güncelle
                            await _loadData();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error removing friend'),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Remove'),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildIncomingRequests() {
    return FutureBuilder<Map<String, List<DocumentSnapshot>>>(
      future: _firestoreService.getFriendRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data?['incoming'] ?? [];

        if (requests.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              await _loadData();
              setState(() {});
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No incoming friend requests',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'When someone sends you a request, it will appear here',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _loadData();
            setState(() {});
          },
          child: ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final requesterId = request['userId'] as String;

              return FutureBuilder<DocumentSnapshot?>(
                future: _firestoreService.getUserProfile(requesterId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;

                  final displayName = _formatDisplayName(userData);
                  final avatarUrl =
                      (userData['profilePhotoUrl'] as String?)?.trim() ?? '';
                  final email = (userData['email'] as String? ?? '').trim();

                  return ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          _createSlideRoute(
                            UserProfileScreen(
                              userId: requesterId,
                              userName:
                                  '${userData['firstName']} ${userData['lastName']}',
                              userUsername:
                                  (userData['username'] as String?)?.trim(),
                            ),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        backgroundImage:
                            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isNotEmpty
                            ? null
                            : Text(_buildInitials(userData)),
                      ),
                    ),
                    title: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          _createSlideRoute(
                            UserProfileScreen(
                              userId: requesterId,
                              userName:
                                  '${userData['firstName']} ${userData['lastName']}',
                              userUsername:
                                  (userData['username'] as String?)?.trim(),
                            ),
                          ),
                        );
                      },
                      child: Text(displayName),
                    ),
                    subtitle: email.isNotEmpty ? Text(email) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            try {
                              await _firestoreService.acceptFriendRequest(
                                requesterId,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Friend request accepted'),
                                  ),
                                );
                                // UI'ı güncelle
                                await _loadData();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Error accepting friend request',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Accept'),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await _firestoreService.removeFriend(requesterId);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Friend request rejected'),
                                  ),
                                );
                                // UI'ı güncelle
                                await _loadData();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Error rejecting friend request',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOutgoingRequests() {
    return FutureBuilder<Map<String, List<DocumentSnapshot>>>(
      future: _firestoreService.getFriendRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data?['outgoing'] ?? [];

        if (requests.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              await _loadData();
              setState(() {});
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.send_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No outgoing friend requests',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Search for users and send friend requests to connect',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _loadData();
            setState(() {});
          },
          child: ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final friendId = request['friendId'] as String;

              return FutureBuilder<DocumentSnapshot?>(
                future: _firestoreService.getUserProfile(friendId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;

                  final displayName = _formatDisplayName(userData);
                  final avatarUrl =
                      (userData['profilePhotoUrl'] as String?)?.trim() ?? '';
                  final email = (userData['email'] as String? ?? '').trim();

                  return ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          _createSlideRoute(
                            UserProfileScreen(
                              userId: friendId,
                              userName:
                                  '${userData['firstName']} ${userData['lastName']}',
                              userUsername:
                                  (userData['username'] as String?)?.trim(),
                            ),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        backgroundImage:
                            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isNotEmpty
                            ? null
                            : Text(_buildInitials(userData)),
                      ),
                    ),
                    title: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          _createSlideRoute(
                            UserProfileScreen(
                              userId: friendId,
                              userName:
                                  '${userData['firstName']} ${userData['lastName']}',
                              userUsername:
                                  (userData['username'] as String?)?.trim(),
                            ),
                          ),
                        );
                      },
                      child: Text(displayName),
                    ),
                    subtitle: email.isNotEmpty ? Text(email) : null,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
