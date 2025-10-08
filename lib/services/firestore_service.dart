import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_activity.dart';
import '../models/friend_activity_comment.dart';
import '../models/wish_list.dart';
import '../models/user_private_note.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's friends
  Future<List<String>> getFriendIds() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    // Get all friendships where current user is either userId or friendId
    final snapshot = await _firestore
        .collection('friendships')
        .where('status', isEqualTo: 'accepted')
        .where('type', isEqualTo: 'friendship')
        .get();

    // Filter to get only mutual friendships and extract friend IDs
    final friendIds = <String>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String;
      final friendId = data['friendId'] as String;

      // Current user must be one of the parties
      if (userId == currentUser.uid || friendId == currentUser.uid) {
        // Add the other user's ID
        if (userId == currentUser.uid) {
          friendIds.add(friendId);
        } else {
          friendIds.add(userId);
        }
      }
    }

    return friendIds.toList();
  }

  // Get friend activities only from friends
  Future<List<FriendActivity>> getFriendActivities() async {
    final friendIds = await getFriendIds();
    if (friendIds.isEmpty) return <FriendActivity>[];

    final snapshot = await _firestore
        .collection('friend_activities')
        .where('userId', whereIn: friendIds)
        .orderBy('activityTime', descending: true)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => FriendActivity.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Get all activities including user's own activities
  Future<List<FriendActivity>> getAllActivities() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final friendIds = await getFriendIds();
    final allUserIds = [currentUser.uid, ...friendIds];

    if (allUserIds.isEmpty) return <FriendActivity>[];

    final snapshot = await _firestore
        .collection('friend_activities')
        .where('userId', whereIn: allUserIds)
        .orderBy('activityTime', descending: true)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => FriendActivity.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Send friend request
  Future<void> sendFriendRequest(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Check if friendship already exists
    final existingRequests = await Future.wait([
      _firestore
          .collection('friendships')
          .where('userId', isEqualTo: currentUser.uid)
          .where('friendId', isEqualTo: targetUserId)
          .get(),
      _firestore
          .collection('friendships')
          .where('userId', isEqualTo: targetUserId)
          .where('friendId', isEqualTo: currentUser.uid)
          .get(),
    ]);

    if (existingRequests.any((snapshot) => snapshot.docs.isNotEmpty)) {
      throw Exception('Friend request already exists');
    }

    // Create friendship request (only one document)
    await _firestore.collection('friendships').add({
      'userId': currentUser.uid,
      'friendId': targetUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'request', // İsteği kimin gönderdiğini belirtmek için
    });
  }

  // Accept friend request
  Future<void> acceptFriendRequest(String requesterId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Get the friend request document
    final requestSnapshot = await _firestore
        .collection('friendships')
        .where('userId', isEqualTo: requesterId)
        .where('friendId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .where('type', isEqualTo: 'request')
        .get();

    if (requestSnapshot.docs.isEmpty) {
      throw Exception('Friend request not found');
    }

    // Create a batch
    final batch = _firestore.batch();

    // Delete the request document (no longer needed)
    batch.delete(requestSnapshot.docs.first.reference);

    // Create friendship documents for both users
    batch.set(_firestore.collection('friendships').doc(), {
      'userId': currentUser.uid,
      'friendId': requesterId,
      'status': 'accepted',
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'friendship',
    });

    // Create friendship document for the requester as well
    batch.set(_firestore.collection('friendships').doc(), {
      'userId': requesterId,
      'friendId': currentUser.uid,
      'status': 'accepted',
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'friendship',
    });

    await batch.commit();
  }

  // Reject or remove friend
  Future<void> removeFriend(String friendId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Get all related documents (requests and friendships)
    final documents = await Future.wait([
      _firestore
          .collection('friendships')
          .where('userId', isEqualTo: currentUser.uid)
          .where('friendId', isEqualTo: friendId)
          .get(),
      _firestore
          .collection('friendships')
          .where('userId', isEqualTo: friendId)
          .where('friendId', isEqualTo: currentUser.uid)
          .get(),
    ]);

    // Delete all related documents
    final batch = _firestore.batch();
    for (var snapshot in documents) {
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
  }

  // Get friend requests (both incoming and outgoing)
  Future<Map<String, List<DocumentSnapshot>>> getFriendRequests() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return {'incoming': [], 'outgoing': []};
    }

    // Get incoming requests
    final incomingSnapshot = await _firestore
        .collection('friendships')
        .where('friendId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .where('type', isEqualTo: 'request')
        .get();

    // Get outgoing requests
    final outgoingSnapshot = await _firestore
        .collection('friendships')
        .where('userId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .where('type', isEqualTo: 'request')
        .get();

    return {
      'incoming': incomingSnapshot.docs,
      'outgoing': outgoingSnapshot.docs,
    };
  }

  // Get user's friends (returns documents for backward compatibility)
  Future<List<DocumentSnapshot>> getFriends() async {
    final friendIds = await getFriendIds();
    if (friendIds.isEmpty) return [];

    // Get the actual friendship documents
    final friendDocs = <DocumentSnapshot>[];
    for (final friendId in friendIds) {
      final friendDoc = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('friendId', isEqualTo: friendId)
          .where('status', isEqualTo: 'accepted')
          .where('type', isEqualTo: 'friendship')
          .get();

      if (friendDoc.docs.isNotEmpty) {
        friendDocs.add(friendDoc.docs.first);
      }
    }

    return friendDocs;
  }

  // Search users by first name and username (prefix search, minimum 3 chars)
  Future<List<DocumentSnapshot>> searchUsers(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 3) return [];

    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final firstNameFuture = _firestore
        .collection('users')
        .where('firstName', isGreaterThanOrEqualTo: trimmedQuery)
        .where('firstName', isLessThan: '$trimmedQuery\uf8ff')
        .limit(10)
        .get();

    final usernameFuture = _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: trimmedQuery)
        .where('username', isLessThan: '$trimmedQuery\uf8ff')
        .limit(10)
        .get();

    final snapshots = await Future.wait([firstNameFuture, usernameFuture]);

    final uniqueResults = <String, DocumentSnapshot>{};

    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        if (doc.id == currentUser.uid) continue;
        uniqueResults.putIfAbsent(doc.id, () => doc);
      }
    }

    return uniqueResults.values.take(10).toList();
  }

  // Get user profile
  Future<DocumentSnapshot?> getUserProfile(String userId) async {
    return await _firestore.collection('users').doc(userId).get();
  }

  // Add friend activity
  Future<void> addFriendActivity(FriendActivity activity) async {
    await _firestore.collection('friend_activities').add(activity.toMap());
  }

  Stream<FriendActivity?> streamActivityForWish(String wishId) {
    return _firestore
        .collection('friend_activities')
        .where('wishItemId', isEqualTo: wishId)
        .where('activityType', isEqualTo: 'added')
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          final doc = snapshot.docs.first;
          return FriendActivity.fromMap(doc.data(), doc.id);
        });
  }

  Future<FriendActivity?> fetchActivityForWish(String wishId) async {
    final snapshot = await _firestore
        .collection('friend_activities')
        .where('wishItemId', isEqualTo: wishId)
        .where('activityType', isEqualTo: 'added')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    return FriendActivity.fromMap(doc.data(), doc.id);
  }

  // Like activity
  Future<void> likeActivity({
    required String activityId,
    required String userId,
  }) async {
    final docRef = _firestore.collection('friend_activities').doc(activityId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data();
      final likedUsers = List<String>.from(
        (data?['likedUserIds'] as List<dynamic>?) ?? const [],
      );

      if (likedUsers.contains(userId)) {
        return;
      }

      transaction.update(docRef, {
        'likedUserIds': FieldValue.arrayUnion([userId]),
        'likesCount': FieldValue.increment(1),
      });
    });
  }

  // Unlike activity
  Future<void> unlikeActivity({
    required String activityId,
    required String userId,
  }) async {
    final docRef = _firestore.collection('friend_activities').doc(activityId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data();
      final likedUsers = List<String>.from(
        (data?['likedUserIds'] as List<dynamic>?) ?? const [],
      );

      if (!likedUsers.contains(userId)) {
        return;
      }

      transaction.update(docRef, {
        'likedUserIds': FieldValue.arrayRemove([userId]),
        'likesCount': FieldValue.increment(-1),
      });
    });
  }

  // Update comment count
  Future<void> updateCommentCount(String activityId, int increment) async {
    await _firestore.collection('friend_activities').doc(activityId).update({
      'commentsCount': FieldValue.increment(increment),
    });
  }

  Stream<List<FriendActivityComment>> streamActivityComments(
    String activityId,
  ) {
    return _firestore
        .collection('friend_activities')
        .doc(activityId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(FriendActivityComment.fromDocument).toList(),
        );
  }

  Future<void> addCommentToActivity(
    String activityId,
    String commentText,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Not authenticated');
    }

    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final firstName = (userData['firstName'] as String?)?.trim() ?? '';
    final lastName = (userData['lastName'] as String?)?.trim() ?? '';
    final combinedName = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ').trim();
    final displayName = combinedName.isNotEmpty
        ? combinedName
        : (userData['username'] as String?)?.trim() ??
              currentUser.displayName ??
              currentUser.email ??
              'Anonymous';

    final username =
        (userData['username'] as String?)?.trim().toLowerCase() ?? '';
    final profilePhotoUrl = userData['profilePhotoUrl'] as String?;

    final commentData = {
      'userId': currentUser.uid,
      'userName': displayName,
      'userUsername': username,
      'profilePhotoUrl': profilePhotoUrl,
      'comment': commentText.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    final commentsRef = _firestore
        .collection('friend_activities')
        .doc(activityId)
        .collection('comments');

    await commentsRef.add(commentData);
    await updateCommentCount(activityId, 1);
  }

  // Dispose method to clean up resources
  void dispose() {
    // No longer needed since we're using Future instead of Stream
  }

  // ===================== Wish Lists =====================
  Future<WishList> createWishList({
    required String name,
    String coverImageUrl = '',
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Not authenticated');
    }

    final docRef = await _firestore.collection('wish_lists').add({
      'userId': currentUser.uid,
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'coverImageUrl': coverImageUrl,
    });

    final created = await docRef.get();
    return WishList.fromMap(created.data() as Map<String, dynamic>, created.id);
  }

  Future<List<WishList>> getUserWishLists(String userId) async {
    final snapshot = await _firestore
        .collection('wish_lists')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => WishList.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> deleteWishList(String listId) async {
    await _firestore.collection('wish_lists').doc(listId).delete();
  }

  // Assign wish to list by writing `listId` to wish document
  Future<void> assignWishToList({
    required String wishId,
    required String listId,
  }) async {
    await _firestore.collection('wishes').doc(wishId).update({
      'listId': listId,
    });
  }

  Future<void> updateWish({
    required String wishId,
    required String name,
    required String description,
    required String productUrl,
    required double price,
    required String currency,
    String? imageUrl,
    String? listId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Not authenticated');
    }

    final wishRef = _firestore.collection('wishes').doc(wishId);
    final wishSnapshot = await wishRef.get();

    if (!wishSnapshot.exists) {
      throw Exception('Wish not found');
    }

    final wishData =
        Map<String, dynamic>.from(wishSnapshot.data() as Map<String, dynamic>);
    final updatePayload = <String, dynamic>{
      'name': name,
      'description': description,
      'productUrl': productUrl,
      'price': price,
      'currency': currency.toUpperCase(),
    };

    if (imageUrl != null) {
      updatePayload['imageUrl'] = imageUrl;
    }
    if (listId != null) {
      updatePayload['listId'] = listId;
    } else {
      updatePayload['listId'] = FieldValue.delete();
    }

    await wishRef.update(updatePayload);

    final activitySnapshot = await _firestore
        .collection('friend_activities')
        .where('wishItemId', isEqualTo: wishId)
        .where('activityType', isEqualTo: 'added')
        .limit(1)
        .get();

    if (activitySnapshot.docs.isEmpty) {
      return;
    }

    final activityDoc = activitySnapshot.docs.first;
    final activityData = Map<String, dynamic>.from(activityDoc.data());
    final existingWishItem =
        Map<String, dynamic>.from(activityData['wishItem'] ?? {});
    final createdAt = existingWishItem['createdAt'] ??
        wishData['createdAt'] ??
        Timestamp.fromDate(DateTime.now());

    final updatedWishItem = <String, dynamic>{
      'id': wishId,
      'name': name,
      'description': description,
      'productUrl': productUrl,
      'imageUrl': imageUrl ?? (existingWishItem['imageUrl'] ?? ''),
      'price': price,
      'currency': currency.toUpperCase(),
      'createdAt': createdAt,
      if (listId != null) 'listId': listId,
    };

    await activityDoc.reference.update({
      'wishItem': updatedWishItem,
      'wishItemId': wishId,
    });
  }

  Future<List<DocumentSnapshot>> getWishesByList(String listId) async {
    final snapshot = await _firestore
        .collection('wishes')
        .where('listId', isEqualTo: listId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs;
  }

  Future<List<UserPrivateNote>> getPrivateNotesForUser(
    String targetUserId,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return <UserPrivateNote>[];
    }

    final snapshot = await _firestore
        .collection('user_private_notes')
        .where('ownerId', isEqualTo: currentUser.uid)
        .where('targetUserId', isEqualTo: targetUserId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              UserPrivateNote.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  Future<UserPrivateNote> addPrivateNote({
    required String targetUserId,
    required String text,
    DateTime? noteDate,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Not authenticated');
    }

    final payload = <String, dynamic>{
      'ownerId': currentUser.uid,
      'targetUserId': targetUserId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (noteDate != null) {
      payload['noteDate'] = Timestamp.fromDate(noteDate);
    }

    final docRef = await _firestore.collection('user_private_notes').add(payload);
    final snapshot = await docRef.get();

    return UserPrivateNote.fromMap(
      snapshot.data() as Map<String, dynamic>,
      snapshot.id,
    );
  }

  Future<void> updatePrivateNote({
    required String noteId,
    required String text,
    DateTime? noteDate,
  }) async {
    final updatePayload = <String, dynamic>{
      'text': text,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (noteDate != null) {
      updatePayload['noteDate'] = Timestamp.fromDate(noteDate);
    } else {
      updatePayload['noteDate'] = FieldValue.delete();
    }

    await _firestore
        .collection('user_private_notes')
        .doc(noteId)
        .update(updatePayload);
  }

  Future<void> deletePrivateNote(String noteId) async {
    await _firestore.collection('user_private_notes').doc(noteId).delete();
  }
}
