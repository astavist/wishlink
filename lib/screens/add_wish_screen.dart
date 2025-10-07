import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/wish_item.dart';
import '../models/friend_activity.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/product_link_service.dart';
import '../models/wish_list.dart';

class AddWishScreen extends StatefulWidget {
  const AddWishScreen({super.key});

  @override
  State<AddWishScreen> createState() => _AddWishScreenState();
}

class _AddWishScreenState extends State<AddWishScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productUrlController = TextEditingController();
  final _priceController = TextEditingController();
  final _storageService = StorageService();
  final ProductLinkService _productLinkService = ProductLinkService();
  final ImagePicker _imagePicker = ImagePicker();

  Timer? _productUrlDebounce;
  bool _isFetchingImagePreview = false;
  String? _autoImageErrorMessage;
  Uint8List? _autoFetchedImageBytes;
  String? _autoFetchedImageContentType;
  String? _autoFetchedProductUrl;
  String? _autoFetchedSourceImageUrl;
  Uint8List? _selectedLocalImageBytes;
  String? _selectedLocalImageContentType;
  String? _selectedLocalImageName;
  int _urlRequestId = 0;
  bool _isLoading = false;
  String? _selectedListId;
  List<WishList> _lists = [];

  @override
  void dispose() {
    _productUrlDebounce?.cancel();
    _productUrlController.removeListener(_onProductUrlChanged);
    _productLinkService.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _productUrlController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _productUrlController.addListener(_onProductUrlChanged);
    _loadLists();
  }

  Future<void> _loadLists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final service = FirestoreService();
    final lists = await service.getUserWishLists(user.uid);
    if (mounted) {
      setState(() {
        _lists = lists;
      });
    }
  }

  Future<void> _createNewListFlow() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Liste Oluştur'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Liste adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final service = FirestoreService();
      final newList = await service.createWishList(name: name);
      if (mounted) {
        setState(() {
          _lists.insert(0, newList);
          _selectedListId = newList.id;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Liste oluşturulamadı')));
      }
    }
  }

  void _onProductUrlChanged() {
    final rawUrl = _productUrlController.text.trim();
    _productUrlDebounce?.cancel();

    if (rawUrl.isEmpty) {
      if (_autoFetchedImageBytes != null ||
          _autoImageErrorMessage != null ||
          _isFetchingImagePreview ||
          _selectedLocalImageBytes != null) {
        setState(() {
          _autoFetchedImageBytes = null;
          _autoFetchedImageContentType = null;
          _autoFetchedProductUrl = null;
          _autoFetchedSourceImageUrl = null;
          _autoImageErrorMessage = null;
          _isFetchingImagePreview = false;
          _selectedLocalImageBytes = null;
          _selectedLocalImageContentType = null;
          _selectedLocalImageName = null;
        });
      }
      return;
    }

    _productUrlDebounce = Timer(const Duration(milliseconds: 800), () {
      _fetchImageForProductUrl(rawUrl);
    });
  }

  Future<void> _fetchImageForProductUrl(String url) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      return;
    }

    if (!_productLinkService.supportsUrl(trimmedUrl)) {
      setState(() {
        _autoImageErrorMessage =
            'Please enter a valid product link that starts with http or https.';
        _autoFetchedImageBytes = null;
        _autoFetchedImageContentType = null;
        _autoFetchedProductUrl = null;
        _autoFetchedSourceImageUrl = null;
      });
      return;
    }

    if (_autoFetchedProductUrl == trimmedUrl &&
        _autoFetchedImageBytes != null) {
      return;
    }

    final currentRequestId = ++_urlRequestId;

    setState(() {
      _isFetchingImagePreview = true;
      _autoImageErrorMessage = null;
      _autoFetchedProductUrl = trimmedUrl;
    });

    try {
      final result = await _productLinkService.fetchPrimaryImage(trimmedUrl);
      if (!mounted || currentRequestId != _urlRequestId) {
        return;
      }

      if (result == null) {
        setState(() {
          _autoImageErrorMessage =
              'We could not find a product photo for this link. You can select one from your gallery.';
          _autoFetchedImageBytes = null;
          _autoFetchedImageContentType = null;
          _autoFetchedSourceImageUrl = null;
        });
        return;
      }

      setState(() {
        _autoFetchedImageBytes = result.imageBytes;
        _autoFetchedImageContentType = result.contentType;
        _autoFetchedProductUrl = trimmedUrl;
        _autoFetchedSourceImageUrl = result.imageUrl;
        _autoImageErrorMessage = null;
      });
    } catch (_) {
      if (!mounted || currentRequestId != _urlRequestId) {
        return;
      }
      setState(() {
        _autoImageErrorMessage =
            'We could not fetch a product photo for this link right now.';
        _autoFetchedImageBytes = null;
        _autoFetchedImageContentType = null;
        _autoFetchedSourceImageUrl = null;
      });
    } finally {
      if (mounted && currentRequestId == _urlRequestId) {
        setState(() {
          _isFetchingImagePreview = false;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 92,
      );
      if (picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLocalImageBytes = bytes;
        _selectedLocalImageContentType =
            picked.mimeType ??
            _guessContentTypeFromExtension(
              _guessExtensionFromName(picked.name) ?? 'jpg',
            );
        _selectedLocalImageName = picked.name;
        _autoFetchedImageBytes = null;
        _autoFetchedImageContentType = null;
        _autoFetchedProductUrl = null;
        _autoFetchedSourceImageUrl = null;
        _autoImageErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to select photo: $error')));
    }
  }

  void _clearManualImage() {
    if (_selectedLocalImageBytes == null) {
      return;
    }
    setState(() {
      _selectedLocalImageBytes = null;
      _selectedLocalImageContentType = null;
      _selectedLocalImageName = null;
    });
  }

  Widget _buildImagePreview() {
    final manualBytes = _selectedLocalImageBytes;
    final autoBytes = _autoFetchedImageBytes;
    final hasImage = manualBytes != null || autoBytes != null;

    if (!hasImage) {
      return Container(
        height: 200,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade100,
        ),
        child: const Text(
          'No product photo selected yet.',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      );
    }

    final bytes = manualBytes ?? autoBytes!;
    final isManual = manualBytes != null;

    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isManual ? 'Gallery photo' : 'From product link',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          if (isManual)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  tooltip: 'Remove photo',
                  onPressed: _clearManualImage,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<String?> _prepareImageUpload({
    required String userId,
    required String productUrl,
  }) async {
    if (_selectedLocalImageBytes != null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension =
          _guessExtensionFromName(_selectedLocalImageName) ??
          _guessExtensionFromContentType(_selectedLocalImageContentType) ??
          'jpg';
      final contentType =
          _selectedLocalImageContentType ??
          _guessContentTypeFromExtension(extension);
      final storagePath = 'wish_images/$userId/local-$timestamp.$extension';

      final uploadedUrl = await _storageService.uploadBytes(
        path: storagePath,
        bytes: _selectedLocalImageBytes!,
        contentType: contentType,
      );

      setState(() {
        _selectedLocalImageBytes = null;
        _selectedLocalImageContentType = null;
        _selectedLocalImageName = null;
      });

      return uploadedUrl;
    }

    if (_autoFetchedImageBytes != null &&
        _autoFetchedProductUrl == productUrl) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension =
          _guessExtensionFromContentType(_autoFetchedImageContentType) ?? 'jpg';
      final contentType =
          _autoFetchedImageContentType ??
          _guessContentTypeFromExtension(extension);
      final storagePath = 'wish_images/$userId/auto-$timestamp.$extension';

      final uploadedUrl = await _storageService.uploadBytes(
        path: storagePath,
        bytes: _autoFetchedImageBytes!,
        contentType: contentType,
      );

      setState(() {
        _autoFetchedImageBytes = null;
        _autoFetchedImageContentType = null;
        _autoFetchedSourceImageUrl = uploadedUrl;
      });

      return uploadedUrl;
    }

    if (_autoFetchedSourceImageUrl != null &&
        _autoFetchedProductUrl == productUrl) {
      return _autoFetchedSourceImageUrl;
    }

    return null;
  }

  String? _guessExtensionFromName(String? fileName) {
    if (fileName == null) {
      return null;
    }
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return null;
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  String? _guessExtensionFromContentType(String? contentType) {
    if (contentType == null) {
      return null;
    }
    final lower = contentType.toLowerCase();
    if (lower.contains('png')) {
      return 'png';
    }
    if (lower.contains('webp')) {
      return 'webp';
    }
    if (lower.contains('gif')) {
      return 'gif';
    }
    if (lower.contains('svg')) {
      return 'svg';
    }
    if (lower.contains('bmp')) {
      return 'bmp';
    }
    if (lower.contains('heic')) {
      return 'heic';
    }
    if (lower.contains('heif')) {
      return 'heif';
    }
    if (lower.contains('avif')) {
      return 'avif';
    }
    if (lower.contains('jpeg') || lower.contains('jpg')) {
      return 'jpg';
    }
    return null;
  }

  String _guessContentTypeFromExtension(String extension) {
    final lower = extension.toLowerCase();
    switch (lower) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'svg':
        return 'image/svg+xml';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'avif':
        return 'image/avif';
      case 'jfif':
        return 'image/jpeg';
      default:
        return 'image/jpeg';
    }
  }

  void _closeKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _saveWish() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get user profile data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data();
      final userName =
          '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}'
              .trim();
      final userUsername =
          (userData?['username'] as String?)?.trim().toLowerCase() ?? '';
      final userAvatarUrl =
          (userData?['profilePhotoUrl'] as String?)?.trim() ?? '';

      final productUrl = _productUrlController.text.trim();
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

      final preparedImageUrl = await _prepareImageUpload(
        userId: currentUser.uid,
        productUrl: productUrl,
      );

      final imageUrl =
          preparedImageUrl ??
          ((_autoFetchedSourceImageUrl != null &&
                  _autoFetchedProductUrl == productUrl)
              ? _autoFetchedSourceImageUrl!
              : '');

      final wishItem = WishItem(
        id: '', // Will be set by Firestore
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        productUrl: productUrl,
        imageUrl: imageUrl,
        price: price,
        createdAt: DateTime.now(),
        listId: _selectedListId,
      );

      // Add wish to wishes collection
      final wishDocRef = await FirebaseFirestore.instance
          .collection('wishes')
          .add({
            ...wishItem.toMap(),
          });

      // Create friend activity
      final friendActivity = FriendActivity(
        id: '', // Will be set by Firestore
        userId: currentUser.uid,
        userName: userName.isNotEmpty ? userName : 'Unknown User',
        userUsername: userUsername,
        userAvatarUrl: userAvatarUrl,
        wishItem: WishItem(
          id: wishDocRef.id,
          name: wishItem.name,
          description: wishItem.description,
          productUrl: wishItem.productUrl,
          imageUrl: wishItem.imageUrl,
          price: wishItem.price,
          createdAt: wishItem.createdAt,
          listId: wishItem.listId,
        ),
        activityTime: DateTime.now(),
        activityType: 'added',
        activityDescription: 'added a new wish',
      );

      // Add friend activity
      final firestoreService = FirestoreService();
      await firestoreService.addFriendActivity(friendActivity);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wish added successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding wish: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Wish'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: FloatingActionButton(
          onPressed: _closeKeyboard,
          backgroundColor: const Color(0xFFEFB652),
          foregroundColor: Colors.white,
          mini: true,
          tooltip: 'Close Keyboard',
          child: const Icon(Icons.keyboard_hide),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: GestureDetector(
        onTap: _closeKeyboard,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String?>(
                    value: _selectedListId,
                    decoration: const InputDecoration(
                      labelText: 'Assign to List',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No list'),
                      ),
                      ..._lists.map(
                        (l) => DropdownMenuItem<String?>(
                          value: l.id,
                          child: Text(l.name),
                        ),
                      ),
                      const DropdownMenuItem<String?>(
                        value: '__create__',
                        child: Text('? Create new list'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == '__create__') {
                        FocusScope.of(context).unfocus();
                        _createNewListFlow();
                        return;
                      }
                      setState(() {
                        _selectedListId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Wish Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a wish name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _productUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Product URL *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a product URL';
                      }
                      final uri = Uri.tryParse(value.trim());
                      if (uri == null || !uri.hasAbsolutePath) {
                        return 'Please enter a valid URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_isFetchingImagePreview)
                    Row(
                      children: const [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fetching product photo...',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  if (_isFetchingImagePreview) const SizedBox(height: 12),
                  if (_autoImageErrorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: Text(
                        _autoImageErrorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  _buildImagePreview(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Select photo from gallery'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a price';
                      }
                      final price = double.tryParse(value.trim());
                      if (price == null || price <= 0) {
                        return 'Please enter a valid price greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveWish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFB652),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Add Wish',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
