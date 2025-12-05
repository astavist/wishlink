import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'firestore_service.dart';

class AccountDeletionException implements Exception {
  final String code;
  final String? message;

  const AccountDeletionException(this.code, {this.message});

  @override
  String toString() => message ?? code;
}

class AccountDeletionService {
  AccountDeletionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirestoreService? firestoreService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _firestoreService = firestoreService ?? FirestoreService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirestoreService _firestoreService;

  static const String _requiresRecentLoginCode = 'requires-recent-login';

  Future<void> deleteCurrentUserAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountDeletionException('not-authenticated');
    }
    final userId = user.uid;

    await _deleteFirestoreData(userId);
    await _deleteStorageData(userId);

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == _requiresRecentLoginCode) {
        throw const AccountDeletionException(_requiresRecentLoginCode);
      }
      throw AccountDeletionException(e.code, message: e.message);
    }

    await _auth.signOut();
  }

  Future<void> _deleteFirestoreData(String userId) async {
    await _deleteNotifications(userId);
    await _deleteCollection(
      _firestore
          .collection('user_private_notes')
          .where('ownerId', isEqualTo: userId),
    );
    await _deleteFriendships(userId);
    await _deleteFriendActivitiesOwnedBy(userId);
    await _deleteUserComments(userId);
    await _deleteWishes(userId);
    await _deleteCollection(
      _firestore.collection('wish_lists').where('userId', isEqualTo: userId),
    );

    final userDoc = _firestore.collection('users').doc(userId);
    final snapshot = await userDoc.get();
    if (snapshot.exists) {
      await userDoc.delete();
    }
  }

  Future<void> _deleteNotifications(String userId) async {
    final docRef = _firestore.collection('notifications').doc(userId);
    await _deleteCollection(docRef.collection('items'));
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      await docRef.delete();
    }
  }

  Future<void> _deleteFriendships(String userId) async {
    await _deleteCollection(
      _firestore.collection('friendships').where('userId', isEqualTo: userId),
    );
    await _deleteCollection(
      _firestore.collection('friendships').where('friendId', isEqualTo: userId),
    );
  }

  Future<void> _deleteFriendActivitiesOwnedBy(String userId) async {
    const batchSize = 25;
    while (true) {
      final snapshot = await _firestore
          .collection('friend_activities')
          .where('userId', isEqualTo: userId)
          .limit(batchSize)
          .get();
      if (snapshot.docs.isEmpty) {
        break;
      }
      for (final doc in snapshot.docs) {
        await _deleteCollection(doc.reference.collection('comments'));
        await doc.reference.delete();
      }
      if (snapshot.docs.length < batchSize) {
        break;
      }
    }
  }

  Future<void> _deleteUserComments(String userId) async {
    const batchSize = 200;
    while (true) {
      final snapshot = await _firestore
          .collectionGroup('comments')
          .where('userId', isEqualTo: userId)
          .limit(batchSize)
          .get();
      if (snapshot.docs.isEmpty) {
        break;
      }
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < batchSize) {
        break;
      }
    }
  }

  Future<void> _deleteWishes(String userId) async {
    final wishIds = <String>{};
    final ownedSnapshot = await _firestore
        .collection('wishes')
        .where('ownerId', isEqualTo: userId)
        .get();
    for (final doc in ownedSnapshot.docs) {
      wishIds.add(doc.id);
    }
    final legacySnapshot = await _firestore
        .collection('wishes')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in legacySnapshot.docs) {
      wishIds.add(doc.id);
    }

    for (final wishId in wishIds) {
      try {
        await _firestoreService.deleteWish(wishId);
      } catch (_) {
        await _firestore
            .collection('wishes')
            .doc(wishId)
            .delete()
            .catchError((_) => null);
      }
    }
  }

  Future<void> _deleteCollection(Query query) async {
    const batchSize = 200;
    Query snapshotQuery = query.limit(batchSize);
    while (true) {
      final snapshot = await snapshotQuery.get();
      if (snapshot.docs.isEmpty) {
        break;
      }
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < batchSize) {
        break;
      }
    }
  }

  Future<void> _deleteStorageData(String userId) async {
    await _deleteStorageObject('profile_photos/$userId.jpg');
    await _deleteStorageFolder('wish_images/$userId');
    await _deleteStorageFolder('wish_list_covers/$userId');
  }

  Future<void> _deleteStorageObject(String path) async {
    try {
      await _storage.ref().child(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  Future<void> _deleteStorageFolder(String prefix) async {
    try {
      final ref = _storage.ref().child(prefix);
      final listResult = await ref.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
      for (final dir in listResult.prefixes) {
        await _deleteStorageFolder(dir.fullPath);
      }
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }
}
