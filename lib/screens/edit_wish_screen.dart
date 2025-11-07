import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wishlink/l10n/app_localizations.dart';

import '../models/wish_item.dart';
import '../models/wish_list.dart';
import '../services/firestore_service.dart';
import '../services/product_link_service.dart';
import '../services/storage_service.dart';

class EditWishScreen extends StatefulWidget {
  final WishItem wish;

  const EditWishScreen({super.key, required this.wish});

  @override
  State<EditWishScreen> createState() => _EditWishScreenState();
}

class _EditWishScreenState extends State<EditWishScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productUrlController = TextEditingController();
  final _priceController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();
  final ProductLinkService _productLinkService = ProductLinkService();
  Timer? _productUrlDebounce;

  bool _isInitializing = true;
  bool _isSaving = false;
  bool _isFetchingMetadata = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageMimeType;
  String? _selectedImageName;
  String? _overrideImageUrl;
  String? _selectedListId;
  static const List<String> _defaultCurrencyOptions = [
    'TRY',
    'USD',
    'EUR',
    'GBP',
  ];
  List<String> _availableCurrencies = List<String>.from(
    _defaultCurrencyOptions,
  );
  String _selectedCurrency = 'TRY';
  List<WishList> _lists = [];
  String? _autoMetadataErrorMessage;
  Uint8List? _autoFetchedImageBytes;
  String? _autoFetchedImageContentType;
  String? _autoFetchedProductUrl;
  String? _autoFetchedSourceImageUrl;
  double? _autoFetchedPrice;
  String? _autoFetchedCurrency;
  int _urlRequestId = 0;
  bool _priceManuallyEdited = false;
  bool _currencyManuallySelected = false;

  @override
  void initState() {
    super.initState();
    _productUrlController.addListener(_onProductUrlChanged);
    _initialLoad();
  }

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

  Future<void> _initialLoad() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.t('editWish.sessionMissing'))),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final wishDoc = await FirebaseFirestore.instance
          .collection('wishes')
          .doc(widget.wish.id)
          .get();

      final wishData = wishDoc.data();
      final listIdFromDoc = wishData?['listId'] as String?;
      final imageUrlFromDoc =
          (wishData?['imageUrl'] as String?) ?? widget.wish.imageUrl;

      _nameController.text = widget.wish.name;
      _descriptionController.text = widget.wish.description;
      _productUrlController.text = widget.wish.productUrl;
      _priceController.text = widget.wish.price > 0
          ? widget.wish.price.toStringAsFixed(2)
          : '';
      _selectedListId = widget.wish.listId ?? listIdFromDoc;
      _overrideImageUrl = imageUrlFromDoc;

      final lists = await _firestoreService.getUserWishLists(user.uid);

      if (!mounted) {
        return;
      }

      final initialCurrency = widget.wish.currency.toUpperCase();

      setState(() {
        _lists = lists;
        _selectedCurrency = initialCurrency;
        if (!_availableCurrencies.contains(initialCurrency)) {
          _availableCurrencies = [
            initialCurrency,
            ..._availableCurrencies.where(
              (currency) => currency != initialCurrency,
            ),
          ];
        }
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t('editWish.loadFailed', params: {'error': '$error'}),
          ),
        ),
      );
    }
  }

  void _onProductUrlChanged() {
    if (_isInitializing) {
      return;
    }

    final rawUrl = _productUrlController.text.trim();
    _productUrlDebounce?.cancel();

    if (rawUrl.isEmpty) {
      if (_autoFetchedImageBytes != null ||
          _autoMetadataErrorMessage != null ||
          _isFetchingMetadata ||
          _autoFetchedPrice != null ||
          _autoFetchedCurrency != null) {
        setState(() {
          _autoFetchedImageBytes = null;
          _autoFetchedImageContentType = null;
          _autoFetchedProductUrl = null;
          _autoFetchedSourceImageUrl = null;
          _autoFetchedPrice = null;
          _autoFetchedCurrency = null;
          _autoMetadataErrorMessage = null;
          _isFetchingMetadata = false;
        });
      }
      return;
    }

    _productUrlDebounce = Timer(const Duration(milliseconds: 800), () {
      _priceManuallyEdited = false;
      _currencyManuallySelected = false;
      _fetchMetadataForProductUrl(rawUrl);
    });
  }

  Future<void> _fetchMetadataForProductUrl(String url) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      return;
    }

    if (!_productLinkService.supportsUrl(trimmedUrl)) {
      setState(() {
        _autoMetadataErrorMessage = context.l10n.t(
          'editWish.invalidProductLink',
        );
        _autoFetchedImageBytes = null;
        _autoFetchedImageContentType = null;
        _autoFetchedProductUrl = null;
        _autoFetchedSourceImageUrl = null;
        _autoFetchedPrice = null;
        _autoFetchedCurrency = null;
      });
      return;
    }

    final currentRequestId = ++_urlRequestId;

    setState(() {
      _isFetchingMetadata = true;
      _autoMetadataErrorMessage = null;
      _autoFetchedProductUrl = trimmedUrl;
    });

    try {
      final result = await _productLinkService.fetchMetadata(trimmedUrl);
      if (!mounted || currentRequestId != _urlRequestId) {
        return;
      }

      if (result == null) {
        setState(() {
          _autoMetadataErrorMessage = context.l10n.t(
            'editWish.autoProductUnavailable',
          );
          _autoFetchedImageBytes = null;
          _autoFetchedImageContentType = null;
          _autoFetchedSourceImageUrl = null;
          _autoFetchedPrice = null;
          _autoFetchedCurrency = null;
        });
        return;
      }

      final imageResult = result.image;
      final fetchedPrice = result.price;
      final fetchedCurrency = result.currency?.toUpperCase();

      setState(() {
        if (imageResult != null) {
          _autoFetchedImageBytes = imageResult.imageBytes;
          _autoFetchedImageContentType = imageResult.contentType;
          _autoFetchedSourceImageUrl = imageResult.imageUrl;
          _autoMetadataErrorMessage = null;
        } else if (_selectedImageBytes == null) {
          _autoFetchedImageBytes = null;
          _autoFetchedImageContentType = null;
          _autoFetchedSourceImageUrl = null;
          _autoMetadataErrorMessage = context.l10n.t(
            'editWish.autoImageMissing',
          );
        }

        _autoFetchedPrice = fetchedPrice;

        if (fetchedCurrency != null) {
          _autoFetchedCurrency = fetchedCurrency;
          if (!_availableCurrencies.contains(fetchedCurrency)) {
            _availableCurrencies = [
              fetchedCurrency,
              ..._availableCurrencies.where(
                (currency) => currency != fetchedCurrency,
              ),
            ];
          }
          if (!_currencyManuallySelected) {
            _selectedCurrency = fetchedCurrency;
          }
        } else {
          _autoFetchedCurrency = null;
        }

        if (fetchedPrice == null && !_priceManuallyEdited) {
          _autoMetadataErrorMessage ??= context.l10n.t(
            'editWish.autoPriceMissing',
          );
        }
      });

      if (fetchedPrice != null && !_priceManuallyEdited) {
        _priceController.text = fetchedPrice.toStringAsFixed(2);
      }
    } catch (_) {
      if (!mounted || currentRequestId != _urlRequestId) {
        return;
      }
      setState(() {
        _autoMetadataErrorMessage = context.l10n.t('editWish.autoFetchFailed');
        _autoFetchedImageBytes = null;
        _autoFetchedImageContentType = null;
        _autoFetchedSourceImageUrl = null;
        _autoFetchedPrice = null;
        _autoFetchedCurrency = null;
      });
    } finally {
      if (mounted && currentRequestId == _urlRequestId) {
        setState(() {
          _isFetchingMetadata = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
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
        _selectedImageBytes = bytes;
        _selectedImageMimeType =
            picked.mimeType ??
            _guessContentTypeFromExtension(_extensionOf(picked.name));
        _selectedImageName = picked.name;
        _overrideImageUrl = null;
        _autoFetchedImageBytes = null;
        _autoFetchedImageContentType = null;
        _autoFetchedProductUrl = null;
        _autoFetchedSourceImageUrl = null;
        _autoMetadataErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t(
              'editWish.photoPickFailed',
              params: {'error': '$error'},
            ),
          ),
        ),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageMimeType = null;
      _selectedImageName = null;
      _autoFetchedImageBytes = null;
      _autoFetchedImageContentType = null;
      _autoFetchedProductUrl = null;
      _autoFetchedSourceImageUrl = null;
      _overrideImageUrl = '';
    });
  }

  String? _guessContentTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
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

  String _extensionOf(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return 'jpg';
    }
    return fileName.substring(dotIndex + 1);
  }

  Future<String?> _uploadSelectedImage(String userId) async {
    final bytes = _selectedImageBytes;
    if (bytes == null) {
      return null;
    }

    final mimeType =
        _selectedImageMimeType ??
        _guessContentTypeFromExtension(_extensionOf(_selectedImageName ?? ''));
    final extension = _extensionOf(_selectedImageName ?? 'wish.jpg');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'wish_images/$userId/edit-$timestamp.$extension';

    return _storageService.uploadBytes(
      path: storagePath,
      bytes: bytes,
      contentType: mimeType ?? 'image/jpeg',
    );
  }

  Future<String?> _uploadAutoFetchedImage(String userId) async {
    final bytes = _autoFetchedImageBytes;
    if (bytes == null) {
      return _autoFetchedSourceImageUrl;
    }

    final extension =
        _guessExtensionFromContentType(_autoFetchedImageContentType) ?? 'jpg';
    final contentType =
        _autoFetchedImageContentType ??
        _guessContentTypeFromExtension(extension);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'wish_images/$userId/auto-$timestamp.$extension';

    final uploadedUrl = await _storageService.uploadBytes(
      path: storagePath,
      bytes: bytes,
      contentType: contentType ?? 'image/jpeg',
    );

    setState(() {
      _autoFetchedImageBytes = null;
      _autoFetchedImageContentType = null;
      _autoFetchedSourceImageUrl = uploadedUrl;
    });

    return uploadedUrl;
  }

  Future<String?> _prepareImageForUpdate({
    required String userId,
    required String productUrl,
  }) async {
    if (_selectedImageBytes != null) {
      return _uploadSelectedImage(userId);
    }

    if (_autoFetchedImageBytes != null &&
        _autoFetchedProductUrl == productUrl) {
      return _uploadAutoFetchedImage(userId);
    }

    if (_autoFetchedSourceImageUrl != null &&
        _autoFetchedProductUrl == productUrl) {
      return _autoFetchedSourceImageUrl;
    }

    return _overrideImageUrl;
  }

  Future<void> _saveWish() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('editWish.sessionMissing'))),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final productUrl = _productUrlController.text.trim();
      final imageUrlForUpdate = await _prepareImageForUpdate(
        userId: user.uid,
        productUrl: productUrl,
      );
      final priceText = _priceController.text.trim().replaceAll(',', '.');
      final parsedPrice = double.tryParse(priceText) ?? 0;

      await _firestoreService.updateWish(
        wishId: widget.wish.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        productUrl: productUrl,
        price: parsedPrice,
        currency: _selectedCurrency.toUpperCase(),
        imageUrl: imageUrlForUpdate,
        listId: _selectedListId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wish güncellendi')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t(
              'editWish.updateFailed',
              params: {'error': '$error'},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _createNewListFlow() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
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

    if (result == null || result.isEmpty) {
      return;
    }

    try {
      final newList = await _firestoreService.createWishList(name: result);
      if (!mounted) {
        return;
      }
      setState(() {
        _lists.insert(0, newList);
        _selectedListId = newList.id;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Liste oluşturulamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final imageBytes = _selectedImageBytes;
    final autoImageBytes = _autoFetchedImageBytes;
    final imageUrl = _overrideImageUrl ?? widget.wish.imageUrl;
    final selectedListId = _selectedListId;
    final dropdownItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('Liste yok')),
      ..._lists.map(
        (list) =>
            DropdownMenuItem<String?>(value: list.id, child: Text(list.name)),
      ),
      const DropdownMenuItem<String?>(
        value: '__create__',
        child: Text('+ Yeni liste oluştur'),
      ),
    ];

    final hasExistingList =
        selectedListId != null &&
        _lists.any((list) => list.id == selectedListId);
    if (selectedListId != null &&
        selectedListId.isNotEmpty &&
        !hasExistingList) {
      dropdownItems.insert(
        1,
        DropdownMenuItem<String?>(
          value: selectedListId,
          child: const Text('Önceki liste (silinmiş)'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wish Düzenle'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String?>(
                  value: selectedListId,
                  decoration: const InputDecoration(
                    labelText: 'Liste Seç',
                    border: OutlineInputBorder(),
                  ),
                  items: dropdownItems,
                  onChanged: _isSaving
                      ? null
                      : (value) {
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
                    labelText: 'Wish Adı *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen wish adını girin';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _productUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Ürün URL *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen URL girin';
                    }
                    final uri = Uri.tryParse(value.trim());
                    if (uri == null || !uri.hasAbsolutePath) {
                      return 'Geçerli bir URL girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (_isFetchingMetadata)
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
                          'Ürün bilgileri getiriliyor...',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                if (_isFetchingMetadata) const SizedBox(height: 12),
                if (_autoMetadataErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Text(
                      _autoMetadataErrorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Fiyat *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (value) {
                          if (!_priceManuallyEdited) {
                            setState(() {
                              _priceManuallyEdited = true;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Lütfen fiyat girin';
                          }
                          final normalized = value.trim().replaceAll(',', '.');
                          final parsed = double.tryParse(normalized);
                          if (parsed == null || parsed <= 0) {
                            return 'Please enter a valid price greater than 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<String>(
                        value: _availableCurrencies.contains(_selectedCurrency)
                            ? _selectedCurrency
                            : (_availableCurrencies.isNotEmpty
                                  ? _availableCurrencies.first
                                  : _selectedCurrency),
                        decoration: const InputDecoration(
                          labelText: 'Para Birimi',
                          border: OutlineInputBorder(),
                        ),
                        items: _availableCurrencies
                            .map(
                              (currency) => DropdownMenuItem<String>(
                                value: currency,
                                child: Text(currency),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedCurrency = value;
                                  _currencyManuallySelected = true;
                                });
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Builder(
                    builder: (context) {
                      if (imageBytes != null) {
                        return Image.memory(imageBytes, fit: BoxFit.cover);
                      }
                      if (autoImageBytes != null) {
                        return Image.memory(autoImageBytes, fit: BoxFit.cover);
                      }
                      if (imageUrl.isNotEmpty) {
                        return Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildImagePlaceholder(),
                        );
                      }
                      return _buildImagePlaceholder();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _pickImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Fotoğraf seç'),
                      ),
                    ),
                    if ((imageBytes != null) ||
                        autoImageBytes != null ||
                        imageUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _removeImage,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Fotoğrafı kaldır'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveWish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEFB652),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kaydet', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.image, size: 48, color: Colors.grey),
    );
  }
}
