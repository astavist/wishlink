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
import '../widgets/wish_list_editor_dialog.dart';

const _accentColor = Color(0xFFF2753A);
const _darkBorderColor = Color(0xFFFFB691);

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
  final TextEditingController _currencyController = TextEditingController(
    text: 'TRY',
  );
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();
  final ProductLinkService _productLinkService = ProductLinkService();
  Timer? _productUrlDebounce;

  bool _isInitializing = true;
  AppLocalizations get l10n => context.l10n;
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
    _currencyController.text = _selectedCurrency;
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
    _currencyController.dispose();
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
        _currencyController.text = initialCurrency;
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

  void _closeKeyboard() => FocusScope.of(context).unfocus();

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final l10n = context.l10n;
    final result = await showWishListEditorDialog(
      context: context,
      isEditing: false,
    );
    if (result == null) {
      return;
    }

    try {
      var coverUrl = '';
      if (result.coverImageBytes != null) {
        coverUrl = await _storageService.uploadWishListCoverBytes(
          userId: user.uid,
          bytes: result.coverImageBytes!,
          contentType: result.coverImageContentType,
        );
      }
      final newList = await _firestoreService.createWishList(
        name: result.name,
        coverImageUrl: coverUrl,
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('profile.listCreateFailed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0F0F0F)
        : const Color(0xFFFDF9F4);
    final currencySelection = _availableCurrencies.contains(_selectedCurrency)
        ? _selectedCurrency
        : (_availableCurrencies.isNotEmpty
              ? _availableCurrencies.first
              : _selectedCurrency);

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
        title: Image.asset(_resolveAppBarAsset(context), height: 42),
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
                            label: l10n.t('editWish.urlLabel'),
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
                              return l10n.t('editWish.urlRequired');
                            }
                            final uri = Uri.tryParse(value.trim());
                            if (uri == null ||
                                !uri.hasScheme ||
                                !uri.hasAuthority) {
                              return l10n.t('editWish.urlInvalid');
                            }
                            return null;
                          },
                        ),
                        _buildMetadataStatus(context),
                        const SizedBox(height: 16),
                        _buildImagePreview(context),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSaving ? null : _pickImage,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(l10n.t('editWish.pickPhoto')),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
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
                            if (_selectedImageBytes != null ||
                                _autoFetchedImageBytes != null ||
                                (_overrideImageUrl?.isNotEmpty ?? false) ||
                                widget.wish.imageUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: OutlinedButton.icon(
                                  onPressed: _isSaving ? null : _removeImage,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  label: Text(l10n.t('editWish.removePhoto')),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    side: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                  ),
                                ),
                              ),
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
                                  label: l10n.t('editWish.priceLabel'),
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
                                    return l10n.t('editWish.priceRequired');
                                  }
                                  final normalized = value.trim().replaceAll(
                                    ',',
                                    '.',
                                  );
                                  final price = double.tryParse(normalized);
                                  if (price == null || price <= 0) {
                                    return l10n.t('editWish.priceInvalid');
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
                                initialSelection: currencySelection,
                                enabled: !_isSaving,
                                label: Text(l10n.t('editWish.currencyLabel')),
                                inputDecorationTheme: _dropdownDecorationTheme(
                                  context,
                                ),
                                dropdownMenuEntries: _availableCurrencies
                                    .map(
                                      (currency) => DropdownMenuEntry<String>(
                                        value: currency,
                                        label: currency,
                                      ),
                                    )
                                    .toList(),
                                onSelected: _isSaving
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
                        _buildListSelector(context),
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
                            label: l10n.t('editWish.nameLabel'),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.t('editWish.nameValidation');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: _wishFieldDecoration(
                            context: context,
                            label: l10n.t('editWish.descriptionLabel'),
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

  Widget _buildPrimaryButton(BuildContext context, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveWish,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF2753A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                l10n.t('editWish.save'),
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
              color: Colors.white.withOpacity(isDark ? 0.12 : 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.edit_rounded,
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
                  l10n.t('editWish.title'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.t('addWish.heroSubtitle'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
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

  Widget _buildListSelector(BuildContext context) {
    final l10n = context.l10n;
    final chips = <Widget>[
      _buildListChip(
        context: context,
        label: l10n.t('addWish.noList'),
        isSelected: _selectedListId == null,
        onTap: () {
          _closeKeyboard();
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
            _closeKeyboard();
            setState(() {
              _selectedListId = list.id;
            });
          },
        ),
      ),
    ];
    final previousListId = _selectedListId;
    if (previousListId != null &&
        previousListId.isNotEmpty &&
        !_lists.any((list) => list.id == previousListId)) {
      chips.add(
        _buildListChip(
          context: context,
          label: l10n.t('editWish.previousList'),
          isSelected: true,
          onTap: () {
            _closeKeyboard();
            setState(() {
              _selectedListId = previousListId;
            });
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final chip in chips)
                Padding(padding: const EdgeInsets.only(right: 12), child: chip),
            ],
          ),
        ),
        if (_lists.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.t('editWish.noLists'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.8),
              ),
            ),
          ),
        TextButton.icon(
          onPressed: _isSaving
              ? null
              : () {
                  _closeKeyboard();
                  _createNewListFlow();
                },
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.t('editWish.createNewList')),
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
    final Color unselectedColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF6F2EA);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : Theme.of(context).textTheme.bodyMedium?.color,
      ),
      selectedColor: selectedColor,
      backgroundColor: unselectedColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    final l10n = context.l10n;
    final manualBytes = _selectedImageBytes;
    final autoBytes = _autoFetchedImageBytes;
    final imageUrl = (_overrideImageUrl?.isNotEmpty ?? false)
        ? _overrideImageUrl!
        : widget.wish.imageUrl;
    final hasImage =
        manualBytes != null || autoBytes != null || imageUrl.isNotEmpty;

    if (!hasImage) {
      return Container(
        height: 220,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _resolveBorderColor(context)),
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

    final bytes = manualBytes ?? autoBytes;
    final isManual = manualBytes != null;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    Widget child;
    if (bytes != null) {
      child = Image.memory(bytes, fit: BoxFit.cover);
    } else {
      child = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDarkTheme
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
          ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
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
                color: Colors.black.withOpacity(0.45),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  tooltip: l10n.t('addWish.removePhotoTooltip'),
                  onPressed: _removeImage,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetadataStatus(BuildContext context) {
    final l10n = context.l10n;
    Widget child = const SizedBox.shrink();

    if (_isFetchingMetadata) {
      child = _buildAssistBanner(
        context: context,
        key: const ValueKey('metadataLoading'),
        icon: Icons.sync_rounded,
        color: const Color(0xFFF6A441),
        text: l10n.t('editWish.fetchingProduct'),
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
        color: color.withOpacity(isDark ? 0.22 : 0.15),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: border(baseColor),
      enabledBorder: border(baseColor),
      focusedBorder: border(_resolveBorderColor(context)),
      labelStyle: Theme.of(context).textTheme.bodySmall,
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
