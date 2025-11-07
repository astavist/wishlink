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
    if (value == null || value.trim().isEmpty) {
      return 'Please choose a username';
    }
    final normalized = value.trim().toLowerCase();
    final regex = RegExp(r'^[a-z0-9._-]{3,20}$');
    if (!regex.hasMatch(normalized)) {
      return '3-20 characters using letters, numbers, ., _, -';
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
              const SnackBar(content: Text('This username is already taken')),
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _buildAvatarImage(),
                      child: _buildAvatarImage() == null
                          ? const Icon(Icons.person, size: 60)
                          : null,
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _pickImage,
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if ((_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) ||
                  _selectedImageFile != null ||
                  _selectedImageBytes != null)
                TextButton.icon(
                  onPressed: _removeImage,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    (_selectedImageFile != null || _selectedImageBytes != null)
                        ? 'Remove selected photo'
                        : 'Remove current photo',
                  ),
                ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
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
                decoration: const InputDecoration(labelText: 'First name'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last name'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _birthdayController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Birth date',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                onTap: _isSaving ? null : _pickBirthday,
              ),
              if (_selectedBirthday != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSaving ? null : _clearBirthday,
                    child: const Text('Remove birth date'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Birth date display',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _birthdayDisplayPreference,
                    items: const [
                      DropdownMenuItem(
                        value: 'dayMonthYear',
                        child: Text('Show day / month / year (dd.mm.yyyy)'),
                      ),
                      DropdownMenuItem(
                        value: 'dayMonth',
                        child: Text('Show only day / month (dd.mm)'),
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
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'My Wishes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_userWishes.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'You have not added any wishes yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _userWishes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final wish = _userWishes[index];
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          wish.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (wish.description.isNotEmpty)
                              Text(
                                wish.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (wish.price > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      currencySymbol(wish.currency),
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatAmount(wish.price),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: wish.imageUrl.isNotEmpty
                              ? Image.network(
                                  wish.imageUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildWishPlaceholder(),
                                )
                              : _buildWishPlaceholder(),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Wish\'i düzenle',
                          onPressed: () => _openEditWish(wish),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWishPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }
}
