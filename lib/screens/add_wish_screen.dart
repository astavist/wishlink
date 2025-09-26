import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wish_item.dart';
import '../models/friend_activity.dart';
import '../services/firestore_service.dart';
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
  final _imageUrlController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isLoading = false;
  String? _selectedListId;
  List<WishList> _lists = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _productUrlController.dispose();
    _imageUrlController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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

      final wishItem = WishItem(
        id: '', // Will be set by Firestore
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        productUrl: _productUrlController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0.0,
        createdAt: DateTime.now(),
      );

      // Add wish to wishes collection
      final wishDocRef = await FirebaseFirestore.instance
          .collection('wishes')
          .add({
            ...wishItem.toMap(),
            if (_selectedListId != null) 'listId': _selectedListId,
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
          child: const Icon(Icons.keyboard_hide),
          tooltip: 'Close Keyboard',
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: GestureDetector(
        onTap: _closeKeyboard,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                      child: Text('➕ Create new list'),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
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
                      : const Text('Add Wish', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
