import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wish_item.dart';
import '../utils/currency_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class WishCardDialog extends StatefulWidget {
  final WishItem wish;
  final VoidCallback? onWishUpdated;

  const WishCardDialog({super.key, required this.wish, this.onWishUpdated});

  @override
  State<WishCardDialog> createState() => _WishCardDialogState();
}

class _WishCardDialogState extends State<WishCardDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _productUrlController;
  late TextEditingController _imageUrlController;
  late TextEditingController _priceController;
  static const List<String> _defaultCurrencyOptions = ['TRY', 'USD', 'EUR', 'GBP'];
  late List<String> _availableCurrencies;
  late String _selectedCurrency;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.wish.name);
    _descriptionController = TextEditingController(
      text: widget.wish.description,
    );
    _productUrlController = TextEditingController(text: widget.wish.productUrl);
    _imageUrlController = TextEditingController(text: widget.wish.imageUrl);
        final initialPrice =
        widget.wish.price > 0 ? widget.wish.price.toStringAsFixed(2) : '';
    _priceController = TextEditingController(text: initialPrice);
    _selectedCurrency = widget.wish.currency.toUpperCase();
    _availableCurrencies = [
      _selectedCurrency,
      ..._defaultCurrencyOptions.where(
        (currency) => currency != _selectedCurrency,
      ),
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _productUrlController.dispose();
    _imageUrlController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not open link')));
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Update the wish item
      final normalizedPrice =
          _priceController.text.trim().replaceAll(',', '.');
      final parsedPrice = double.tryParse(normalizedPrice) ?? 0.0;
      final updatedWish = WishItem(
        id: widget.wish.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        productUrl: _productUrlController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        price: parsedPrice,
        currency: _selectedCurrency.toUpperCase(),
        createdAt: widget.wish.createdAt,
      );

      // Update in wishes collection
      await FirebaseFirestore.instance
          .collection('wishes')
          .doc(widget.wish.id)
          .update(updatedWish.toMap());

      // Update in friend_activities collection
      final activitySnapshot = await FirebaseFirestore.instance
          .collection('friend_activities')
          .where('userId', isEqualTo: currentUser.uid)
          .where('activityType', isEqualTo: 'added')
          .get();

      for (var doc in activitySnapshot.docs) {
        final data = doc.data();
        final wishData = data['wishItem'] as Map<String, dynamic>;
        if (wishData['id'] == widget.wish.id) {
          await doc.reference.update({'wishItem': updatedWish.toMap()});
          break;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wish updated successfully!')),
        );
        setState(() {
          _isEditing = false;
        });
        widget.onWishUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating wish: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Reset controllers to original values
        _nameController.text = widget.wish.name;
        _descriptionController.text = widget.wish.description;
        _productUrlController.text = widget.wish.productUrl;
        _imageUrlController.text = widget.wish.imageUrl;
        _priceController.text =
            widget.wish.price > 0 ? widget.wish.price.toStringAsFixed(2) : '';
        _selectedCurrency = widget.wish.currency.toUpperCase();
        _availableCurrencies = [
          _selectedCurrency,
          ..._defaultCurrencyOptions.where(
            (currency) => currency != _selectedCurrency,
          ),
        ];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEFB652),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Wish' : 'Wish Details',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleEditMode,
                    icon: Icon(
                      _isEditing ? Icons.close : Icons.edit,
                      color: Colors.white,
                    ),
                    tooltip: _isEditing ? 'Cancel Edit' : 'Edit Wish',
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _isEditing ? _buildEditForm() : _buildWishDetails(),
              ),
            ),

            // Footer
            if (_isEditing)
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _toggleEditMode,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEFB652),
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wish Image
        if (widget.wish.imageUrl.isNotEmpty)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.wish.imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.image,
                      size: 64,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),

        const SizedBox(height: 20),

        // Wish Name
        Text(
          widget.wish.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        // Description
        if (widget.wish.description.isNotEmpty) ...[
          Text(
            'Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.wish.description, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
        ],

        // Price
        if (widget.wish.price > 0) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currencySymbol(widget.wish.currency),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatAmount(widget.wish.price),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Product URL Button
        if (widget.wish.productUrl.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launchUrl(widget.wish.productUrl),
              icon: const Icon(Icons.link),
              label: const Text('View Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEFB652),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Created Date
        Text(
          'Created: ${_formatDate(widget.wish.createdAt)}',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a price';
                    }
                    final normalized = value.trim().replaceAll(',', '.');
                    final price = double.tryParse(normalized);
                    if (price == null || price <= 0) {
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
                    labelText: 'Currency',
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
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedCurrency = value;
                          });
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}








