import 'package:cloud_firestore/cloud_firestore.dart';

class UserPrivateNote {
  final String id;
  final String ownerId;
  final String targetUserId;
  final String text;
  final DateTime? noteDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserPrivateNote({
    required this.id,
    required this.ownerId,
    required this.targetUserId,
    required this.text,
    this.noteDate,
    this.createdAt,
    this.updatedAt,
  });

  factory UserPrivateNote.fromMap(Map<String, dynamic> data, String id) {
    DateTime? toDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return null;
    }

    return UserPrivateNote(
      id: id,
      ownerId: data['ownerId'] as String? ?? '',
      targetUserId: data['targetUserId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      noteDate: toDate(data['noteDate']),
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'ownerId': ownerId,
      'targetUserId': targetUserId,
      'text': text,
      if (noteDate != null) 'noteDate': Timestamp.fromDate(noteDate!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
