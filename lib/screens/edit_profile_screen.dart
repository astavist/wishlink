import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wishlink/l10n/app_localizations.dart';

import '../services/storage_service.dart';
import '../models/wish_item.dart';
import 'edit_wish_screen.dart';
import '../utils/currency_utils.dart';

const _lightBackground = Color(0xFFFDF9F4);
const _darkBackground = Color(0xFF0F0F0F);
const _cardLightColor = Colors.white;
const _cardDarkColor = Color(0xFF161616);
const _cardBorderLight = Color(0xFFFFE1C0);
const _cardBorderDark = Color(0x19FFFFFF);
const _heroGradientLightTop = Color(0xFFFFF0DA);
const _heroGradientLightBottom = Color(0xFFF6A441);
const _heroGradientDarkTop = Color(0xFF2A1908);
const _heroGradientDarkBottom = Color(0xFFF2753A);
const _actionOrange = Color(0xFFF2753A);
const _actionOrangeDark = Color(0xFFF6A441);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _removePhoto = false;
  String? _profilePhotoUrl;
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String _currentUsername = '';
  DateTime? _selectedBirthday;
  String _birthdayDisplayPreference = 'dayMonthYear';
  List<WishItem> _userWishes = [];

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  Future<void> _pickBirthday() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final minSelectable = DateTime(now.year - 120, now.month, now.day);
    final fallbackInitial = DateTime(now.year - 18, now.month, now.day);
    final initial = _selectedBirthday ?? fallbackInitial;

    final chosenDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(minSelectable) ? minSelectable : initial,
      firstDate: minSelectable,
      lastDate: now,
    );
    if (chosenDate != null) {
      final normalized = DateTime(
        chosenDate.year,
        chosenDate.month,
        chosenDate.day,
      );
      setState(() {
        _selectedBirthday = normalized;
        _birthdayController.text = _formatDate(normalized);
      });
    }
  }

  void _clearBirthday() {
    setState(() {
      _selectedBirthday = null;
      _birthdayController.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final data = snapshot.data();

      if (data != null) {
        _firstNameController.text =
            (data['firstName'] as String?)?.trim() ?? '';
        _lastNameController.text = (data['lastName'] as String?)?.trim() ?? '';
        _usernameController.text =
            (data['username'] as String?)?.trim().toLowerCase() ?? '';
        _currentUsername = _usernameController.text;
        _profilePhotoUrl = (data['profilePhotoUrl'] as String?)?.trim();

        final birthdayData = data['birthday'];
        DateTime? birthday;
        if (birthdayData is Timestamp) {
          birthday = birthdayData.toDate();
        } else if (birthdayData is String && birthdayData.isNotEmpty) {
          try {
            birthday = DateTime.parse(birthdayData);
          } catch (_) {
            birthday = null;
          }
        } else if (birthdayData is Map) {
          final year = birthdayData['year'];
          final month = birthdayData['month'];
          final day = birthdayData['day'];
          if (year is int && month is int && day is int) {
            birthday = DateTime(year, month, day);
          }
        }
        if (birthday != null) {
          final normalized = DateTime(
            birthday.year,
            birthday.month,
            birthday.day,
          );
          _selectedBirthday = normalized;
          _birthdayController.text = _formatDate(normalized);
        } else {
          _selectedBirthday = null;
          _birthdayController.clear();
        }

        final displayPreference =
            (data['birthdayDisplay'] as String?) ?? 'dayMonthYear';
        if (displayPreference == 'dayMonth' ||
            displayPreference == 'dayMonthYear') {
          _birthdayDisplayPreference = displayPreference;
        } else {
          _birthdayDisplayPreference = 'dayMonthYear';
        }
      }

      await _loadUserWishes(user.uid);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.t('editProfile.loadFailed', params: {'error': '$e'}),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadUserWishes(String userId) async {
    try {
      final wishesSnapshot = await _firestore
          .collection('friend_activities')
          .where('userId', isEqualTo: userId)
          .where('activityType', isEqualTo: 'added')
          .orderBy('activityTime', descending: true)
          .limit(20)
          .get();

      final wishes = wishesSnapshot.docs.map((doc) {
        final data = doc.data();
        final wishData = data['wishItem'] as Map<String, dynamic>;
        final wishId =
            (data['wishItemId'] as String?) ?? wishData['id'] ?? doc.id;
        return WishItem.fromMap(wishData, wishId);
      }).toList();

      if (mounted) {
        setState(() {
          _userWishes = wishes;
        });
      }
    } catch (_) {
      // Ignore wish load errors on profile edit screen
    }
  }

  Future<void> _openEditWish(WishItem wish) async {
    final updated = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => EditWishScreen(wish: wish)));

    final user = _auth.currentUser;
    if (updated == true && user != null) {
      await _loadUserWishes(user.uid);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageFile = null;
            _removePhoto = false;
          });
        } else {
          setState(() {
            _selectedImageFile = File(pickedFile.path);
            _selectedImageBytes = null;
            _removePhoto = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.t(
                'editProfile.photoPickFailed',
                params: {'error': '$e'},
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeImage() async {
    final hadStoredPhoto =
        _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty;
    setState(() {
      _removePhoto = hadStoredPhoto;
      _selectedImageFile = null;
      _selectedImageBytes = null;
      _profilePhotoUrl = null;
    });
  }

  String? _validateUsernameFormat(String? value) {
    final l10n = context.l10n;
    if (value == null || value.trim().isEmpty) {
      return l10n.t('editProfile.usernameRequired');
    }
    final normalized = value.trim().toLowerCase();
    final regex = RegExp(r'^[a-z0-9._-]{3,20}$');
    if (!regex.hasMatch(normalized)) {
      return l10n.t('editProfile.usernameRules');
    }
    return null;
  }

  String _normalizeUsername(String value) => value.trim().toLowerCase();

  Future<bool> _isUsernameAvailable(
    String username, {
    required String userId,
  }) async {
    final normalized = _normalizeUsername(username);
    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return true;
    }

    return query.docs.first.id == userId;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final l10n = context.l10n;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final usernameInput = _usernameController.text.trim();
      final usernameError = _validateUsernameFormat(usernameInput);
      if (usernameError != null) {
        setState(() {
          _isSaving = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(usernameError)));
        }
        return;
      }
      final normalizedUsername = _normalizeUsername(usernameInput);
      final usernameChanged = normalizedUsername != _currentUsername;

      String? photoUrl =
          _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
          ? _profilePhotoUrl
          : null;

      if (_selectedImageFile != null || _selectedImageBytes != null) {
        if (kIsWeb && _selectedImageBytes != null) {
          photoUrl = await _storageService.uploadProfilePhotoBytes(
            userId: user.uid,
            bytes: _selectedImageBytes!,
          );
        } else if (_selectedImageFile != null) {
          photoUrl = await _storageService.uploadProfilePhoto(
            userId: user.uid,
            file: _selectedImageFile!,
          );
        }
      } else if (_removePhoto) {
        try {
          await _storageService.deleteProfilePhoto(user.uid);
        } catch (_) {
          // Ignore storage errors when deleting a missing photo.
        }
        photoUrl = null;
      }

      if (usernameChanged) {
        final available = await _isUsernameAvailable(
          normalizedUsername,
          userId: user.uid,
        );
        if (!available) {
          setState(() {
            _isSaving = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.t('editProfile.usernameTaken'))),
            );
          }
          return;
        }
      }

      final Map<String, dynamic> updates = {
        'firstName': firstName,
        'lastName': lastName,
      };

      if (_selectedImageFile != null ||
          _selectedImageBytes != null ||
          _removePhoto) {
        updates['profilePhotoUrl'] = photoUrl ?? '';
      }

      if (usernameChanged) {
        updates['username'] = normalizedUsername;
      }

      if (_selectedBirthday != null) {
        updates['birthday'] = Timestamp.fromDate(_selectedBirthday!);
      } else {
        updates['birthday'] = FieldValue.delete();
      }
      updates['birthdayDisplay'] = _birthdayDisplayPreference;

      await _firestore.collection('users').doc(user.uid).update(updates);

      final displayName = [
        firstName,
        lastName,
      ].where((value) => value.isNotEmpty).join(' ');

      await user.updateDisplayName(displayName.isNotEmpty ? displayName : null);

      if (_selectedImageFile != null ||
          _selectedImageBytes != null ||
          _removePhoto) {
        await user.updatePhotoURL(photoUrl);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _currentUsername = normalizedUsername;

      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.t('editProfile.saveFailed', params: {'error': '$e'}),
            ),
          ),
        );
      }
    }
  }

  ImageProvider? _buildAvatarImage() {
    if (_selectedImageBytes != null) {
      return MemoryImage(_selectedImageBytes!);
    }

    if (_selectedImageFile != null) {
      return FileImage(_selectedImageFile!);
    }

    if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) {
      return NetworkImage(_profilePhotoUrl!);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? _darkBackground : _lightBackground;

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
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF131313), Color(0xFF1E1E1E)]
                  : const [Color(0xFFFFF5E8), Color(0xFFF7F4EF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHero(context, l10n),
                    const SizedBox(height: 24),
                    _buildSectionCard(
                      context: context,
                      title: l10n.t('editProfile.section.profile'),
                      subtitle: l10n.t('editProfile.section.profileSubtitle'),
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          decoration: _fieldDecoration(
                            context: context,
                            label: l10n.t('editProfile.usernameLabel'),
                            prefixText: '@',
                          ),
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: _validateUsernameFormat,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _firstNameController,
                          decoration: _fieldDecoration(
                            context: context,
                            label: l10n.t('editProfile.firstNameLabel'),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.t('editProfile.firstNameRequired');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: _fieldDecoration(
                            context: context,
                            label: l10n.t('editProfile.lastNameLabel'),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ),
                    _buildSectionCard(
                      context: context,
                      title: l10n.t('editProfile.section.personal'),
                      subtitle: l10n.t('editProfile.section.personalSubtitle'),
                      children: [
                        TextFormField(
                          controller: _birthdayController,
                          readOnly: true,
                          decoration: _fieldDecoration(
                            context: context,
                            label: l10n.t('editProfile.birthDateLabel'),
                            prefixIcon: const Icon(Icons.cake_outlined),
                          ),
                          onTap: _isSaving ? null : _pickBirthday,
                        ),
                        if (_selectedBirthday != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isSaving ? null : _clearBirthday,
                              child: Text(
                                l10n.t('editProfile.removeBirthDate'),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _birthdayDisplayPreference,
                          decoration: _fieldDecoration(
                            context: context,
                            label: l10n.t('editProfile.birthDateDisplayLabel'),
                          ),
                          borderRadius: BorderRadius.circular(20),
                          items: [
                            DropdownMenuItem(
                              value: 'dayMonthYear',
                              child: Text(
                                l10n.t('editProfile.birthDateOptionFull'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'dayMonth',
                              child: Text(
                                l10n.t('editProfile.birthDateOptionPartial'),
                              ),
                            ),
                          ],
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      _birthdayDisplayPreference = value;
                                    });
                                  }
                                },
                        ),
                      ],
                    ),
                    _buildPrimaryButton(context, l10n),
                    const SizedBox(height: 24),
                    _buildWishesSection(context, l10n),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHero(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasPhoto = _hasProfilePhoto;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [_heroGradientDarkTop, _heroGradientDarkBottom]
              : const [_heroGradientLightTop, _heroGradientLightBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : const Color(0x66F6A441),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundImage: _buildAvatarImage(),
                    child: _buildAvatarImage() == null
                        ? const Icon(Icons.person_outline, size: 48)
                        : null,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _isSaving ? null : _pickImage,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.edit,
                            color: isDark ? _actionOrangeDark : _actionOrange,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('editProfile.heroTitle'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.t('editProfile.heroSubtitle'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _isSaving ? null : _removeImage,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              label: Text(
                (_selectedImageFile != null || _selectedImageBytes != null)
                    ? l10n.t('editProfile.removeSelectedPhoto')
                    : l10n.t('editProfile.removeCurrentPhoto'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasProfilePhoto =>
      (_profilePhotoUrl?.isNotEmpty ?? false) ||
      _selectedImageFile != null ||
      _selectedImageBytes != null;

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? _cardDarkColor : _cardLightColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? _cardBorderDark : _cardBorderLight),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0x1AF6A441),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required BuildContext context,
    required String label,
    Widget? prefixIcon,
    String? prefixText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    OutlineInputBorder border(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: color, width: 1),
      );
    }

    final Color baseColor = isDark ? _cardBorderDark : _cardBorderLight;

    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon,
      prefixText: prefixText,
      filled: true,
      fillColor: isDark ? const Color(0xFF1D1D1D) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: border(baseColor),
      enabledBorder: border(baseColor),
      focusedBorder: border(isDark ? _actionOrangeDark : _actionOrange),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? _actionOrangeDark
              : _actionOrange,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(l10n.t('editProfile.saveButton')),
      ),
    );
  }

  Widget _buildWishesSection(BuildContext context, AppLocalizations l10n) {
    if (_userWishes.isEmpty) {
      return _buildSectionCard(
        context: context,
        title: l10n.t('editProfile.wishesTitle'),
        subtitle: l10n.t('editProfile.wishesEmpty'),
        children: [_buildEmptyWishesState(context, l10n)],
      );
    }

    return _buildSectionCard(
      context: context,
      title: l10n.t('editProfile.wishesTitle'),
      children: [
        Column(
          children: [
            for (var i = 0; i < _userWishes.length; i++) ...[
              if (i != 0) const SizedBox(height: 12),
              _buildWishTile(context, _userWishes[i], l10n),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyWishesState(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFFFF1E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 36),
          const SizedBox(height: 12),
          Text(
            l10n.t('editProfile.wishesEmpty'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildWishTile(
    BuildContext context,
    WishItem wish,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? _cardBorderDark : const Color(0xFFFFE1C0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: wish.imageUrl.isNotEmpty
                ? Image.network(
                    wish.imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildWishPlaceholder(),
                  )
                : _buildWishPlaceholder(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wish.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (wish.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    wish.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (wish.price > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          currencySymbol(wish.currency),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatAmount(wish.price),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.t('editProfile.editWishTooltip'),
            onPressed: () => _openEditWish(wish),
          ),
        ],
      ),
    );
  }

  String _resolveAppBarAsset(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/AppBarDark.png'
        : 'assets/images/AppBar.png';
  }

  Widget _buildWishPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.image_outlined, color: Colors.grey),
    );
  }
}
