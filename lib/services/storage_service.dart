import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Profil fotoğrafı yükleme
  Future<String> uploadProfilePhoto({
    required String userId,
    required File file,
  }) async {
    try {
      final fileName = 'profile_photos/$userId.jpg';
      final ref = _storage.ref().child(fileName);

      // Profil fotoğrafı için optimize edilmiş metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000', // 1 yıl cache
      );

      final uploadTask = await ref.putFile(file, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Profil fotoğrafı yüklenirken hata: $e');
    }
  }

  // Profil fotoğrafı yükleme (Web için byte array)
  Future<String> uploadProfilePhotoBytes({
    required String userId,
    required Uint8List bytes,
  }) async {
    try {
      final fileName = 'profile_photos/$userId.jpg';
      final ref = _storage.ref().child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      );

      final uploadTask = await ref.putData(bytes, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Profil fotoğrafı yüklenirken hata: $e');
    }
  }

  // Profil fotoğrafı silme
  Future<void> deleteProfilePhoto(String userId) async {
    try {
      final fileName = 'profile_photos/$userId.jpg';
      final ref = _storage.ref().child(fileName);
      await ref.delete();
    } catch (e) {
      throw Exception('Profil fotoğrafı silinirken hata: $e');
    }
  }

  // Liste kapak fotoğrafı yükleme (byte dizisi)
  Future<String> uploadWishListCoverBytes({
    required String userId,
    required Uint8List bytes,
    String? contentType,
  }) async {
    try {
      final extension = _extensionFromContentType(contentType);
      final fileName =
          'wish_list_covers/$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
      final ref = _storage.ref().child(fileName);
      final metadata = SettableMetadata(
        contentType: contentType ?? 'image/jpeg',
        cacheControl: 'public, max-age=15552000',
      );
      final uploadTask = await ref.putData(bytes, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Liste kapak fotoğrafı yüklenirken hata: $e');
    }
  }

  // Profil fotoğrafı URL'ini alma
  Future<String?> getProfilePhotoUrl(String userId) async {
    try {
      final fileName = 'profile_photos/$userId.jpg';
      final ref = _storage.ref().child(fileName);
      return await ref.getDownloadURL();
    } catch (e) {
      // Fotoğraf bulunamadıysa null döndür
      return null;
    }
  }

  // Genel dosya yükleme
  Future<String> uploadFile({
    required String path,
    required File file,
    String? contentType,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = contentType != null
          ? SettableMetadata(contentType: contentType)
          : null;

      final uploadTask = await ref.putFile(file, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Dosya yüklenirken hata: $e');
    }
  }

  // Byte array yükleme (Web için)
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    String? contentType,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = contentType != null
          ? SettableMetadata(contentType: contentType)
          : null;

      final uploadTask = await ref.putData(bytes, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Dosya yüklenirken hata: $e');
    }
  }

  // Dosya silme
  Future<void> deleteFile(String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e) {
      throw Exception('Dosya silinirken hata: $e');
    }
  }

  String _extensionFromContentType(String? contentType) {
    switch (contentType?.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      default:
        return 'jpg';
    }
  }
}

