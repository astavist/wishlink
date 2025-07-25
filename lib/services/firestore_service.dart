import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_activity.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Arkadaş etkinliklerini getir
  Stream<List<FriendActivity>> getFriendActivities() {
    return _firestore
        .collection('friend_activities')
        .orderBy('activityTime', descending: true)
        .limit(20) // Son 20 etkinliği getir
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FriendActivity.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  // Belirli bir kullanıcının etkinliklerini getir
  Stream<List<FriendActivity>> getUserActivities(String userId) {
    return _firestore
        .collection('friend_activities')
        .where('userId', isEqualTo: userId)
        .orderBy('activityTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FriendActivity.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  // Yeni arkadaş etkinliği ekle
  Future<void> addFriendActivity(FriendActivity activity) async {
    await _firestore
        .collection('friend_activities')
        .add(activity.toFirestore());
  }

  // Etkinliği beğen
  Future<void> likeActivity(String activityId) async {
    await _firestore
        .collection('friend_activities')
        .doc(activityId)
        .update({
      'likesCount': FieldValue.increment(1),
    });
  }

  // Etkinlik beğenisini geri al
  Future<void> unlikeActivity(String activityId) async {
    await _firestore
        .collection('friend_activities')
        .doc(activityId)
        .update({
      'likesCount': FieldValue.increment(-1),
    });
  }

  // Etkinlik yorum sayısını güncelle
  Future<void> updateCommentCount(String activityId, int increment) async {
    await _firestore
        .collection('friend_activities')
        .doc(activityId)
        .update({
      'commentsCount': FieldValue.increment(increment),
    });
  }
} 