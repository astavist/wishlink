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
import '../widgets/wish_list_editor_dialog.dart';
import 'package:wishlink/l10n/app_localizations.dart';

const _accentColor = Color(0xFFF2753A);
const _darkBorderColor = Color(0xFFFFB691);

class AddWishScreen extends StatefulWidget {
  const AddWishScreen({super.key});

  @override
  State<AddWishScreen> createState() => _AddWishScreenState();
}

class _AddWishScreenState extends State<AddWishScreen> {
  AppLocalizations get l10n => context.l10n;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productUrlController = TextEditingController();
  final _priceController = TextEditingController();
  final TextEditingController _currencyController =
      TextEditingController(text: 'TRY');
  final _storageService = StorageService();
  final ProductLinkService _productLinkService = ProductLinkService();
  final ImagePicker _imagePicker = ImagePicker();

  Timer? _productUrlDebounce;
  bool _isFetchingMetadata = false;
  String? _autoMetadataErrorMessage;
  Uint8List? _autoFetchedImageBytes;
  String? _autoFetchedImageContentType;
  String? _autoFetchedProductUrl;
  String? _autoFetchedSourceImageUrl;
  double? _autoFetchedPrice;
  String? _autoFetchedCurrency;
  Uint8List? _selectedLocalImageBytes;
  String? _selectedLocalImageContentType;
  String? _selectedLocalImageName;
  int _urlRequestId = 0;
  bool _isLoading = false;
  bool _priceManuallyEdited = false;
  bool _currencyManuallySelected = false;
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
    _currencyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _productUrlController.addListener(_onProductUrlChanged);
    _currencyController.text = _selectedCurrency;
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final l10n = context.l10n;
    final result = await showWishListEditorDialog(
      context: context,
      isEditing: false,
    );
    if (result == null) return;

    try {
      var coverUrl = '';
      if (result.coverImageBytes != null) {
        coverUrl = await _storageService.uploadWishListCoverBytes(
          userId: user.uid,
          bytes: result.coverImageBytes!,
          contentType: result.coverImageContentType,
        );
      }
      final service = FirestoreService();
      final newList = await service.createWishList(
        name: result.name,
        coverImageUrl: coverUrl,
      );
      if (mounted) {
        setState(() {
          _lists.insert(0, newList);
          _selectedListId = newList.id;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('addWish.listCreateFailed'))),
        );
      }
    }
  }

  void _onProductUrlChanged() {
    final rawUrl = _productUrlController.text.trim();
    _productUrlDebounce?.cancel();

    if (rawUrl.isEmpty) {
      if (_autoFetchedImageBytes != null ||
          _autoMetadataErrorMessage != null ||
          _isFetchingMetadata ||
          _selectedLocalImageBytes != null ||
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
          _selectedLocalImageBytes = null;
          _selectedLocalImageContentType = null;
          _selectedLocalImageName = null;
          _priceManuallyEdited = false;
          _currencyManuallySelected = false;
          _availableCurrencies = List<String>.from(_defaultCurrencyOptions);
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
        _autoMetadataErrorMessage = l10n.t('addWish.invalidLink');
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
        final shouldClearPrice = !_priceManuallyEdited;
        setState(() {
          _autoMetadataErrorMessage = l10n.t('addWish.metadataUnavailable');
          _autoFetchedImageBytes = null;
          _autoFetchedImageContentType = null;
          _autoFetchedSourceImageUrl = null;
          _autoFetchedPrice = null;
          _autoFetchedCurrency = null;
        });
        if (shouldClearPrice) {
          _priceController.clear();
        }
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
        } else if (_selectedLocalImageBytes == null) {
          _autoFetchedImageBytes = null;
          _autoFetchedImageContentType = null;
          _autoFetchedSourceImageUrl = null;
          _autoMetadataErrorMessage = l10n.t('addWish.noPhotoFromLink');
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
            _applyCurrencySelection(fetchedCurrency);
          }
        } else {
          _autoFetchedCurrency = null;
          if (!_currencyManuallySelected) {
            final fallback = _defaultCurrencyOptions.first;
            _applyCurrencySelection(fallback);
            if (!_availableCurrencies.contains(fallback)) {
              _availableCurrencies = [fallback, ..._availableCurrencies];
            }
          }
        }

        if (fetchedPrice == null && !_priceManuallyEdited) {
          _autoMetadataErrorMessage ??= l10n.t('addWish.noPriceFromLink');
        }
      });

      if (fetchedPrice != null && !_priceManuallyEdited) {
        _priceController.text = fetchedPrice.toStringAsFixed(2);
      } else if (fetchedPrice == null && !_priceManuallyEdited) {
        _priceController.clear();
      }
    } catch (_) {
      if (!mounted || currentRequestId != _urlRequestId) {
        return;
      }
      setState(() {
        _autoMetadataErrorMessage = l10n.t('addWish.metadataFetchFailed');
        _autoFetchedImageBytes = null;
        _autoFetchedImageContentType = null;
        _autoFetchedSourceImageUrl = null;
        _autoFetchedPrice = null;
        _autoFetchedCurrency = null;
      });
      if (!_priceManuallyEdited) {
        _priceController.clear();
      }
    } finally {
      if (mounted && currentRequestId == _urlRequestId) {
        setState(() {
          _isFetchingMetadata = false;
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
        _autoMetadataErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('addWish.photoPickFailed', params: {'error': '$error'}),
          ),
        ),
      );
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
    final l10n = this.l10n;
    final manualBytes = _selectedLocalImageBytes;
    final autoBytes = _autoFetchedImageBytes;
    final hasImage = manualBytes != null || autoBytes != null;

    if (!hasImage) {
      return Container(
        height: 220,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _resolveBorderColor(context),
          ),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : const Color(0xFFFFFBF6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 36,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('addWish.noPhotoSelected'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final bytes = manualBytes ?? autoBytes!;
    final isManual = manualBytes != null;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isManual
                    ? l10n.t('addWish.galleryPhoto')
                    : l10n.t('addWish.linkPhoto'),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          if (isManual)
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  tooltip: l10n.t('addWish.removePhotoTooltip'),
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
      final priceInput = _priceController.text.trim().replaceAll(',', '.');
      final price = double.tryParse(priceInput) ?? 0.0;

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
        currency: _selectedCurrency.toUpperCase(),
        createdAt: DateTime.now(),
        listId: _selectedListId,
      );

      // Add wish to wishes collection
      final wishDocRef = await FirebaseFirestore.instance
          .collection('wishes')
          .add({
            ...wishItem.toMap(),
            // Security rules: ensure wish ownership is enforced
            'ownerId': currentUser.uid,
          });

      // Create friend activity
      final friendActivity = FriendActivity(
        id: '', // Will be set by Firestore
        userId: currentUser.uid,
        userName: userName.isNotEmpty
            ? userName
            : l10n.t('wishDetail.unknownUser'),
        userUsername: userUsername,
        userAvatarUrl: userAvatarUrl,
        wishItem: WishItem(
          id: wishDocRef.id,
          name: wishItem.name,
          description: wishItem.description,
          productUrl: wishItem.productUrl,
          imageUrl: wishItem.imageUrl,
          price: wishItem.price,
          currency: wishItem.currency,
          createdAt: wishItem.createdAt,
          listId: wishItem.listId,
        ),
        activityTime: DateTime.now(),
        activityType: 'added',
        activityDescription: l10n.t('addWish.activityDescription'),
      );

      // Add friend activity
      final firestoreService = FirestoreService();
      await firestoreService.addFriendActivity(friendActivity);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('addWish.success'))));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('addWish.error', params: {'error': '$e'})),
          ),
        );
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
    final l10n = this.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDF9F4);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Image.asset(
          _resolveAppBarAsset(context),
          height: 42,
        ),
        actions: [
          IconButton(
            tooltip: l10n.t('addWish.closeKeyboard'),
            icon: const Icon(Icons.keyboard_hide_outlined),
            onPressed: _closeKeyboard,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onTap: _closeKeyboard,
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFF131313), Color(0xFF1E1E1E)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFFFF5E8), Color(0xFFF7F4EF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                24 + MediaQuery.of(context).padding.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(context, l10n),
                    const SizedBox(height: 24),
                    _buildSectionCard(
                      context: context,
                      children: [
                        _buildSectionTitle(
                          context,
                          l10n.t('addWish.mediaSectionTitle'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _productUrlController,
                          decoration: _wishFieldDecoration(
                            context: context,
                            label: l10n.t('addWish.productUrlLabel'),
                            suffixIcon: _productUrlController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(_productUrlController.clear);
                                    },
                                  ),
                          ),
                          keyboardType: TextInputType.url,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.t('addWish.productUrlRequired');
                            }
                            final uri = Uri.tryParse(value.trim());
                            if (uri == null ||
                                !uri.hasScheme ||
                                !uri.hasAuthority) {
                              return l10n.t('addWish.productUrlInvalid');
                            }
                            return null;
                          },
                        ),
                        _buildMetadataStatus(context),
                        const SizedBox(height: 16),
                        _buildImagePreview(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _isLoading ? null : _pickImageFromGallery,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(
                                  l10n.t('addWish.selectPhotoButton'),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  side: BorderSide(
                                    color: _resolveBorderColor(context),
                                  ),
                                  foregroundColor: _resolveBorderColor(context),
                                ),
                              ),
                            ),
                            if (_selectedLocalImageBytes != null) ...[
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: _clearManualImage,
                                tooltip: l10n.t('addWish.removePhotoTooltip'),
                                icon:
                                    const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    _buildSectionCard(
                      context: context,
                      children: [
                        _buildSectionTitle(
                          context,
                          l10n.t('addWish.pricingSectionTitle'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                decoration: _wishFieldDecoration(
                                  context: context,
                                  label: l10n.t('addWish.priceLabel'),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                                    return l10n.t('addWish.priceRequired');
                                  }
                                  final normalized =
                                      value.trim().replaceAll(',', '.');
                                  final price = double.tryParse(normalized);
                                  if (price == null || price <= 0) {
                                    return l10n.t('addWish.priceInvalid');
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 140,
                              child: DropdownMenu<String>(
                                controller: _currencyController,
                                initialSelection:
                                    _availableCurrencies.contains(
                                  _selectedCurrency,
                                )
                                        ? _selectedCurrency
                                        : (_availableCurrencies.isNotEmpty
                                              ? _availableCurrencies.first
                                              : _selectedCurrency),
                                enabled: !_isLoading,
                                label: Text(
                                  l10n.t('addWish.currencyLabel'),
                                ),
                                inputDecorationTheme:
                                    _dropdownDecorationTheme(context),
                                dropdownMenuEntries: _availableCurrencies
                                    .map(
                                      (currency) => DropdownMenuEntry<String>(
                                        value: currency,
                                        label: currency,
                                      ),
                                    )
                                    .toList(),
                                onSelected: _isLoading
                                    ? null
                                    : (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        setState(() {
                                          _currencyManuallySelected = true;
                                          _applyCurrencySelection(value);
                                        });
                                      },
                              ),
                            ),
                          ],
                        ),
                        if (_autoFetchedPrice != null && !_priceManuallyEdited)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              l10n.t('addWish.priceFetched'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (_autoFetchedCurrency != null &&
                            !_currencyManuallySelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              l10n.t(
                                'addWish.currencyDetected',
                                params: {'currency': _autoFetchedCurrency!},
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    _buildSectionCard(
                      context: context,
                      children: [
                        _buildSectionTitle(
                          context,
                          l10n.t('addWish.listSectionTitle'),
                        ),
                        const SizedBox(height: 12),
                        _buildListSelector(context, l10n),
                      ],
                    ),
                    _buildSectionCard(
                      context: context,
                      children: [
                        _buildSectionTitle(
                          context,
                          l10n.t('addWish.detailsSectionTitle'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: _wishFieldDecoration(
                            context: context,
                            label: l10n.t('addWish.wishNameLabel'),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.t('addWish.wishNameValidation');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: _wishFieldDecoration(
                            context: context,
                            label: l10n.t('addWish.descriptionLabel'),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildPrimaryButton(context, l10n),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveWish,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF2753A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                l10n.t('addWish.submit'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF322E2B), Color(0xFF1C1A18)]
        : const [Color(0xFFFFE4B4), Color(0xFFF6A441)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x33F6A441),
                  blurRadius: 40,
                  offset: Offset(0, 20),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('addWish.title'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.t('addWish.heroSubtitle'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildListSelector(BuildContext context, AppLocalizations l10n) {
    final chips = <Widget>[
      _buildListChip(
        context: context,
        label: l10n.t('addWish.noList'),
        isSelected: _selectedListId == null,
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _selectedListId = null;
          });
        },
      ),
      ..._lists.map(
        (list) => _buildListChip(
          context: context,
          label: list.name,
          isSelected: _selectedListId == list.id,
          onTap: () {
            FocusScope.of(context).unfocus();
            setState(() {
              _selectedListId = list.id;
            });
          },
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final chip in chips)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: chip,
                ),
            ],
          ),
        ),
        if (_lists.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.t('addWish.noListInfo'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.8),
                  ),
            ),
          ),
        TextButton.icon(
          onPressed: () {
            FocusScope.of(context).unfocus();
            _createNewListFlow();
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.t('addWish.createListOption')),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFF2753A),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildListChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color selectedColor = const Color(0xFFF2753A);
    final Color unselectedColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF6F2EA);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : Theme.of(context).textTheme.bodyMedium?.color,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: unselectedColor,
      selectedColor: selectedColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : _resolveBorderColor(context),
        ),
      ),
      pressElevation: 0,
    );
  }

  InputDecoration _wishFieldDecoration({
    required BuildContext context,
    required String label,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    OutlineInputBorder border(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: color, width: 1),
      );
    }

    final Color baseColor = _resolveBorderColor(context);

    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: isDark ? const Color(0xFF1D1D1D) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      border: border(baseColor),
      enabledBorder: border(baseColor),
      focusedBorder: border(_resolveBorderColor(context)),
      suffixIcon: suffixIcon,
    );
  }

  InputDecorationTheme _dropdownDecorationTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    OutlineInputBorder border(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: color, width: 1),
      );
    }

    final Color baseColor = _resolveBorderColor(context);

    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1D1D1D) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      border: border(baseColor),
      enabledBorder: border(baseColor),
      focusedBorder: border(_resolveBorderColor(context)),
      labelStyle: Theme.of(context).textTheme.bodySmall,
    );
  }

  Widget _buildMetadataStatus(BuildContext context) {
    Widget child = const SizedBox.shrink();

    if (_isFetchingMetadata) {
      child = _buildAssistBanner(
        context: context,
        key: const ValueKey('metadataLoading'),
        icon: Icons.sync_rounded,
        color: const Color(0xFFF6A441),
        text: l10n.t('addWish.fetchingMetadata'),
      );
    } else if (_autoMetadataErrorMessage != null) {
      child = _buildAssistBanner(
        context: context,
        key: const ValueKey('metadataError'),
        icon: Icons.info_outline_rounded,
        color: Theme.of(context).colorScheme.error,
        text: _autoMetadataErrorMessage!,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: child,
    );
  }

  Widget _buildAssistBanner({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String text,
    Key? key,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: key,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyCurrencySelection(String currency) {
    _selectedCurrency = currency;
    _currencyController.text = currency;
  }

  Color _resolveBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkBorderColor
        : _accentColor;
  }

  String _resolveAppBarAsset(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/AppBarDark.png'
        : 'assets/images/AppBar.png';
  }
}
