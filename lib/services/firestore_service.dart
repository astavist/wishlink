import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_activity.dart';
import '../models/wish_list.dart';

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

  // Search users
  Future<List<DocumentSnapshot>> searchUsers(String query) async {
    if (query.length < 3) return [];

    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .where('firstName', isGreaterThanOrEqualTo: query)
        .where('firstName', isLessThan: query + 'z')
        .get();

    return snapshot.docs
        .where((doc) => doc.id != currentUser.uid)
        .take(10)
        .toList();
  }

  // Get user profile
  Future<DocumentSnapshot?> getUserProfile(String userId) async {
    return await _firestore.collection('users').doc(userId).get();
  }

  // Add friend activity
  Future<void> addFriendActivity(FriendActivity activity) async {
    await _firestore.collection('friend_activities').add(activity.toMap());
  }

  // Like activity
  Future<void> likeActivity(String activityId) async {
    await _firestore.collection('friend_activities').doc(activityId).update({
      'likesCount': FieldValue.increment(1),
    });
  }

  // Unlike activity
  Future<void> unlikeActivity(String activityId) async {
    await _firestore.collection('friend_activities').doc(activityId).update({
      'likesCount': FieldValue.increment(-1),
    });
  }

  // Update comment count
  Future<void> updateCommentCount(String activityId, int increment) async {
    await _firestore.collection('friend_activities').doc(activityId).update({
      'commentsCount': FieldValue.increment(increment),
    });
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

  Future<List<DocumentSnapshot>> getWishesByList(String listId) async {
    final snapshot = await _firestore
        .collection('wishes')
        .where('listId', isEqualTo: listId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs;
  }
}
