import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_service.dart';
import '../widgets/wishlink_card.dart';
import '../widgets/wishlink_section_header.dart';
import '../screens/user_profile_screen.dart';
import 'profile_screen.dart';
import 'package:wishlink/l10n/app_localizations.dart';
import 'package:wishlink/theme/app_theme.dart';

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

const LinearGradient _lightFriendsBackground = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFDFCF7), Color(0xFFF6F0FF)],
);

const LinearGradient _darkFriendsBackground = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF1F1F1F), Color(0xFF0F1116)],
);

Gradient _friendsBackgroundGradient(BuildContext context) {
  final theme = Theme.of(context);
  final gradients = theme.extension<WishLinkGradients>();
  return gradients?.primary ??
      (theme.brightness == Brightness.dark
          ? _darkFriendsBackground
          : _lightFriendsBackground);
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
  final FocusNode _searchFocusNode = FocusNode();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchFocused = false;
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
    _searchFocusNode.addListener(_handleSearchFocusChange);
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
    _searchFocusNode
      ..removeListener(_handleSearchFocusChange)
      ..dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('friends.searchError'))),
        );
      }
    }
  }

  void _handleSearchFocusChange() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isSearchFocused = _searchFocusNode.hasFocus;
    });
  }

  String _formatDisplayName(Map<String, dynamic> data, AppLocalizations l10n) {
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

    return displayName.isNotEmpty ? displayName : l10n.t('friends.unknownUser');
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

  Widget _buildStatusChip(
    String label, {
    Color? background,
    Color? foreground,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final Color resolvedForeground = foreground ?? theme.colorScheme.primary;
    final Color resolvedBackground =
        background ??
        theme.colorScheme.primary.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.25 : 0.12,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: resolvedForeground.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: resolvedForeground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: resolvedForeground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final bool showClear =
        _searchController.text.isNotEmpty || _isSearchFocused;
    final Color iconColor =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
        theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.9 : 0.96,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.35 : 0.08,
              ),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (value) {
                    setState(() {});
                    _searchUsers(value);
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.t('friends.searchHint'),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              if (showClear)
                IconButton(
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  icon: Icon(Icons.close_rounded, color: iconColor),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _searchResults = [];
                      _isSearching = false;
                      _isSearchFocused = false;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(
            alpha: isDark ? 0.45 : 0.95,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            dividerHeight: 0,
            indicator: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.35 : 0.15,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 2),
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withValues(
              alpha: 0.65,
            ),
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            tabs: [
              Tab(text: l10n.t('friends.tabMyFriends')),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.t('friends.tabIncoming')),
                    if (_incomingRequestCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _buildIncomingBadge(),
                      ),
                  ],
                ),
              ),
              Tab(text: l10n.t('friends.tabOutgoing')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingBadge() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _incomingRequestCount > 9 ? '9+' : _incomingRequestCount.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final showLocalAppBar = Navigator.canPop(context);

    final bool isSearchActive =
        _isSearchFocused || _searchController.text.isNotEmpty;

    return Scaffold(
      extendBody: true,
      backgroundColor:
          theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      appBar: showLocalAppBar
          ? AppBar(
              title: Image.asset(_resolveAppBarAsset(context), height: 64),
              centerTitle: true,
              backgroundColor: theme.appBarTheme.backgroundColor,
              foregroundColor: theme.appBarTheme.foregroundColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              leadingWidth: 64,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                    child: FutureBuilder<DocumentSnapshot?>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data?.data() != null) {
                          final userData =
                              snapshot.data!.data() as Map<String, dynamic>;
                          final profilePhotoUrl =
                              (userData['profilePhotoUrl'] as String?)
                                  ?.trim() ??
                              '';
                          if (profilePhotoUrl.isNotEmpty) {
                            return CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(profilePhotoUrl),
                            );
                          }
                        }
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                          child: Text(
                            l10n.t('home.meBadge'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: _friendsBackgroundGradient(context),
        ),
        child: SafeArea(
          top: !showLocalAppBar,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              WishLinkSectionHeader(title: l10n.t('friends.title')),
              _buildSearchField(l10n),
              if (!isSearchActive)
                _buildTabSelector(l10n)
              else
                const SizedBox(height: 12),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.25
                              : 0.08,
                        ),
                        blurRadius: 30,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    child: isSearchActive
                        ? (_isSearching
                              ? const Center(child: CircularProgressIndicator())
                              : _buildSearchResults())
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildFriendsList(),
                              _buildIncomingRequests(),
                              _buildOutgoingRequests(),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom + 120;
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(20, 40, 20, bottomPadding),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [_buildSearchPromptCard(l10n)],
      );
    }

    if (_searchResults.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(20, 40, 20, bottomPadding),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _buildEmptyStateCard(
            icon: Icons.search_off_rounded,
            title: l10n.t('friends.noUsersFound'),
            subtitle: l10n.t('friends.searchHint'),
          ),
        ],
      );
    }

    final currentUserId = _auth.currentUser?.uid;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _searchResults.length,
      separatorBuilder: (_, unusedIndex) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final userData =
            (user.data() ?? <String, dynamic>{}) as Map<String, dynamic>;

        final bool isSelf = user.id == currentUserId;
        final bool isFriend = _friendIds.contains(user.id);
        final bool hasOutgoing = _outgoingRequestIds.contains(user.id);
        final bool hasIncoming = _incomingRequestIds.contains(user.id);

        Widget? trailing;
        if (isSelf) {
          trailing = _buildStatusChip(
            l10n.t('home.meBadge'),
            background: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.6,
            ),
            foreground: theme.colorScheme.onSurfaceVariant,
          );
        } else if (isFriend) {
          trailing = _buildStatusChip(
            l10n.t('friends.statusFriends'),
            icon: Icons.check_rounded,
          );
        } else if (hasOutgoing) {
          trailing = _buildStatusChip(
            l10n.t('friends.statusRequestSent'),
            icon: Icons.hourglass_bottom_rounded,
            background: theme.colorScheme.secondary.withValues(alpha: 0.18),
            foreground: theme.colorScheme.secondary,
          );
        } else if (hasIncoming) {
          trailing = _buildTextActionButton(
            l10n.t('friends.buttonRespond'),
            onPressed: () => _tabController.animateTo(1),
            background: theme.colorScheme.secondary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.25 : 0.15,
            ),
            foreground: theme.colorScheme.secondary,
          );
        } else {
          final messenger = ScaffoldMessenger.of(context);
          final successMessage = l10n.t('friends.snackbarRequestSent');
          final failureMessage = l10n.t('friends.snackbarRequestFailed');
          trailing = _buildTextActionButton(
            l10n.t('friends.buttonAdd'),
            onPressed: () async {
              try {
                await _firestoreService.sendFriendRequest(user.id);
                if (!mounted) {
                  return;
                }
                messenger.showSnackBar(SnackBar(content: Text(successMessage)));
                await _loadData();
                if (!mounted) {
                  return;
                }
                setState(() {
                  _outgoingRequestIds.add(user.id);
                });
              } catch (e) {
                if (!mounted) {
                  return;
                }
                messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
              }
            },
          );
        }

        return _buildPersonCard(
          userData: userData,
          onTap: () => _openProfile(user.id, userData),
          trailing: trailing,
        );
      },
    );
  }

  Widget _buildFriendsList() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom + 140;
    return FutureBuilder<List<DocumentSnapshot>>(
      future: _firestoreService.getFriends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              l10n.t('friends.error', params: {'error': '${snapshot.error}'}),
            ),
          );
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return RefreshIndicator(
            color: theme.colorScheme.primary,
            onRefresh: _refreshData,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 48, 20, bottomPadding),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: [
                _buildEmptyStateCard(
                  icon: Icons.people_outline,
                  title: l10n.t('friends.emptyFriendsTitle'),
                  subtitle: l10n.t('friends.emptyFriendsSubtitle'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: _refreshData,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: friends.length,
            separatorBuilder: (_, unusedIndex) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final friendship = friends[index];
              final friendId = friendship['friendId'] as String;

              return FutureBuilder<DocumentSnapshot?>(
                future: _firestoreService.getUserProfile(friendId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final userData =
                      (userSnapshot.data!.data() ?? <String, dynamic>{})
                          as Map<String, dynamic>;

                  return _buildPersonCard(
                    userData: userData,
                    onTap: () => _openProfile(friendId, userData),
                    trailing: _buildTextActionButton(
                      l10n.t('friends.buttonRemove'),
                      onPressed: () => _removeFriend(friendId, l10n),
                      background: theme.colorScheme.error.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.25
                            : 0.12,
                      ),
                      foreground: theme.colorScheme.error,
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom + 140;
    return FutureBuilder<Map<String, List<DocumentSnapshot>>>(
      future: _firestoreService.getFriendRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              l10n.t('friends.error', params: {'error': '${snapshot.error}'}),
            ),
          );
        }

        final requests = snapshot.data?['incoming'] ?? [];

        if (requests.isEmpty) {
          return RefreshIndicator(
            color: theme.colorScheme.primary,
            onRefresh: _refreshData,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 48, 20, bottomPadding),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: [
                _buildEmptyStateCard(
                  icon: Icons.person_add_outlined,
                  title: l10n.t('friends.emptyIncomingTitle'),
                  subtitle: l10n.t('friends.emptyIncomingSubtitle'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: _refreshData,
          child: ListView.separated(
            itemCount: requests.length,
            padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            separatorBuilder: (_, unusedIndex) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final request = requests[index];
              final requesterId = request['userId'] as String;

              return FutureBuilder<DocumentSnapshot?>(
                future: _firestoreService.getUserProfile(requesterId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final userData =
                      (userSnapshot.data!.data() ?? <String, dynamic>{})
                          as Map<String, dynamic>;

                  return _buildPersonCard(
                    userData: userData,
                    onTap: () => _openProfile(requesterId, userData),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          _buildTextActionButton(
                            l10n.t('friends.buttonAccept'),
                            onPressed: () => _acceptRequest(requesterId, l10n),
                          ),
                          _buildTextActionButton(
                            l10n.t('friends.buttonReject'),
                            onPressed: () => _rejectRequest(requesterId, l10n),
                            background: theme.colorScheme.error.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.25
                                  : 0.12,
                            ),
                            foreground: theme.colorScheme.error,
                          ),
                        ],
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

  Widget _buildOutgoingRequests() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom + 140;
    return FutureBuilder<Map<String, List<DocumentSnapshot>>>(
      future: _firestoreService.getFriendRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              l10n.t('friends.error', params: {'error': '${snapshot.error}'}),
            ),
          );
        }

        final requests = snapshot.data?['outgoing'] ?? [];

        if (requests.isEmpty) {
          return RefreshIndicator(
            color: theme.colorScheme.primary,
            onRefresh: _refreshData,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 48, 20, bottomPadding),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: [
                _buildEmptyStateCard(
                  icon: Icons.send_outlined,
                  title: l10n.t('friends.emptyOutgoingTitle'),
                  subtitle: l10n.t('friends.emptyOutgoingSubtitle'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: _refreshData,
          child: ListView.separated(
            itemCount: requests.length,
            padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            separatorBuilder: (_, unusedIndex) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final request = requests[index];
              final friendId = request['friendId'] as String;

              return FutureBuilder<DocumentSnapshot?>(
                future: _firestoreService.getUserProfile(friendId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final userData =
                      (userSnapshot.data!.data() ?? <String, dynamic>{})
                          as Map<String, dynamic>;

                  return _buildPersonCard(
                    userData: userData,
                    onTap: () => _openProfile(friendId, userData),
                    trailing: _buildStatusChip(
                      l10n.t('friends.statusPending'),
                      icon: Icons.hourglass_empty_rounded,
                      background: theme.colorScheme.surfaceContainerHighest
                          .withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? 0.5
                                : 0.6,
                          ),
                      foreground: theme.colorScheme.onSurfaceVariant,
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

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final subtitleColor = theme.textTheme.bodyMedium?.color?.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.7 : 0.6,
    );

    return WishLinkCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: subtitleColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPromptCard(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return WishLinkCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.manage_search_rounded,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('friends.searchHint'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.t('friends.searchHint'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonCard({
    required Map<String, dynamic> userData,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final displayName = _formatDisplayName(userData, l10n);
    final avatarUrl = (userData['profilePhotoUrl'] as String?)?.trim() ?? '';
    final email = (userData['email'] as String? ?? '').trim();
    final initials = _buildInitials(userData);

    return WishLinkCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTap,
            child: _buildAvatar(avatarUrl: avatarUrl, initials: initials),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (email.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing],
        ],
      ),
    );
  }

  Widget _buildAvatar({required String avatarUrl, required String initials}) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.35 : 0.12,
    );
    final textColor = theme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.primary;

    return CircleAvatar(
      radius: 26,
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      backgroundColor: avatarUrl.isNotEmpty ? null : background,
      child: avatarUrl.isEmpty
          ? Text(
              initials,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            )
          : null,
    );
  }

  Widget _buildTextActionButton(
    String label, {
    required VoidCallback onPressed,
    Color? background,
    Color? foreground,
  }) {
    final theme = Theme.of(context);
    final Color resolvedForeground = foreground ?? theme.colorScheme.primary;
    final Color resolvedBackground =
        background ??
        theme.colorScheme.primary.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.35 : 0.16,
        );

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: resolvedBackground,
        foregroundColor: resolvedForeground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  void _openProfile(String userId, Map<String, dynamic> userData) {
    Navigator.push(
      context,
      _createSlideRoute(
        UserProfileScreen(
          userId: userId,
          userName: '${userData['firstName']} ${userData['lastName']}',
          userUsername: (userData['username'] as String?)?.trim(),
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    await _loadData();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _removeFriend(String friendId, AppLocalizations l10n) async {
    try {
      await _firestoreService.removeFriend(friendId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('friends.snackbarFriendRemoved'))),
      );
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('friends.snackbarFriendRemoveFailed'))),
        );
      }
    }
  }

  Future<void> _acceptRequest(String requesterId, AppLocalizations l10n) async {
    try {
      await _firestoreService.acceptFriendRequest(requesterId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('friends.snackbarAccepted'))),
      );
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('friends.snackbarAcceptFailed'))),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requesterId, AppLocalizations l10n) async {
    try {
      await _firestoreService.removeFriend(requesterId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('friends.snackbarRejected'))),
      );
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('friends.snackbarRejectFailed'))),
        );
      }
    }
  }

  String _resolveAppBarAsset(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/AppBarDark.png'
        : 'assets/images/AppBar.png';
  }
}
