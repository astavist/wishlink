import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/storage_service.dart';

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

  bool _isLoading = true;
  bool _isSaving = false;
  bool _removePhoto = false;
  String? _profilePhotoUrl;
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String _currentUsername = '';

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
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
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
                textInputAction: TextInputAction.done,
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
            ],
          ),
        ),
      ),
    );
  }
}
