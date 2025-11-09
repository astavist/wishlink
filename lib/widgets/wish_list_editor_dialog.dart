import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';

class WishListEditorResult {
  final String name;
  final Uint8List? coverImageBytes;
  final String? coverImageContentType;
  final bool removeExistingCover;

  const WishListEditorResult({
    required this.name,
    this.coverImageBytes,
    this.coverImageContentType,
    this.removeExistingCover = false,
  });
}

Future<WishListEditorResult?> showWishListEditorDialog({
  required BuildContext context,
  String? initialName,
  String? existingCoverImageUrl,
  required bool isEditing,
}) async {
  return showDialog<WishListEditorResult>(
    context: context,
    builder: (dialogContext) => _WishListEditorDialog(
      isEditing: isEditing,
      initialName: initialName,
      existingCoverImageUrl: existingCoverImageUrl,
    ),
  );
}

class _WishListEditorDialog extends StatefulWidget {
  final bool isEditing;
  final String? initialName;
  final String? existingCoverImageUrl;

  const _WishListEditorDialog({
    required this.isEditing,
    this.initialName,
    this.existingCoverImageUrl,
  });

  @override
  State<_WishListEditorDialog> createState() => _WishListEditorDialogState();
}

class _WishListEditorDialogState extends State<_WishListEditorDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName ?? '');
  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedBytes;
  String? _selectedContentType;
  bool _removeExistingCover = false;
  String? _errorText;

  bool get _hasExistingCover =>
      (widget.existingCoverImageUrl?.isNotEmpty ?? false) &&
      !_removeExistingCover &&
      _selectedBytes == null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedBytes = bytes;
        _selectedContentType =
            picked.mimeType ?? _contentTypeFromName(picked.name);
        _removeExistingCover = false;
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedBytes = null;
      _selectedContentType = null;
      _removeExistingCover = _hasExistingCover;
    });
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorText = context.l10n.t('profile.listNameRequired');
      });
      return;
    }
    Navigator.of(context).pop(
      WishListEditorResult(
        name: trimmed,
        coverImageBytes: _selectedBytes,
        coverImageContentType: _selectedContentType,
        removeExistingCover: _removeExistingCover && _selectedBytes == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.isEditing
            ? l10n.t('profile.editListTitle')
            : l10n.t('profile.newListTitle'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.t('profile.listNameLabel'),
                hintText: l10n.t('profile.newListHint'),
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('profile.coverPhotoLabel'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: _CoverPreview(
                  bytes: _selectedBytes,
                  existingUrl:
                      _hasExistingCover ? widget.existingCoverImageUrl : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickCover,
                  icon: const Icon(Icons.photo),
                  label: Text(l10n.t('profile.selectCoverPhoto')),
                ),
                if (_selectedBytes != null || _hasExistingCover)
                  TextButton.icon(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.close),
                    label: Text(l10n.t('profile.removeCoverPhoto')),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.t('common.cancel')),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.isEditing ? l10n.t('common.save') : l10n.t('common.create'),
          ),
        ),
      ],
    );
  }
}

class _CoverPreview extends StatelessWidget {
  final Uint8List? bytes;
  final String? existingUrl;

  const _CoverPreview({this.bytes, this.existingUrl});

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return Image.memory(
        bytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    if (existingUrl != null && existingUrl!.isNotEmpty) {
      return Image.network(
        existingUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.photo, color: Colors.grey),
      ),
    );
  }
}

String _contentTypeFromName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}
