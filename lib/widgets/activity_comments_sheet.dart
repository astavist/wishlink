import 'package:flutter/material.dart';

import '../models/friend_activity.dart';
import '../models/friend_activity_comment.dart';
import '../services/firestore_service.dart';
import 'package:wishlink/l10n/app_localizations.dart';

class ActivityCommentsSheet extends StatefulWidget {
  final FriendActivity activity;
  final ValueNotifier<int> addedCounter;

  const ActivityCommentsSheet({
    super.key,
    required this.activity,
    required this.addedCounter,
  });

  @override
  State<ActivityCommentsSheet> createState() => _ActivityCommentsSheetState();
}

class _ActivityCommentsSheetState extends State<ActivityCommentsSheet> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _firestoreService.addCommentToActivity(widget.activity.id, text);
      widget.addedCounter.value = widget.addedCounter.value + 1;
      _commentController.clear();

      await Future.delayed(const Duration(milliseconds: 120));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('comments.addFailed'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.t('comments.title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<FriendActivityComment>>(
                  stream: _firestoreService.streamActivityComments(
                    widget.activity.id,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(context.l10n.t('comments.unableToLoad')),
                      );
                    }

                    final comments = snapshot.data ?? <FriendActivityComment>[];

                    if (comments.isEmpty) {
                      return Center(
                        child: Text(
                          context.l10n.t('comments.empty'),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: comments.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final hasAvatar =
                            (comment.profilePhotoUrl ?? '').isNotEmpty;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.orange[200],
                                backgroundImage: hasAvatar
                                    ? NetworkImage(comment.profilePhotoUrl!)
                                    : null,
                                child: hasAvatar
                                    ? null
                                    : Text(
                                        comment.userName.isNotEmpty
                                            ? comment.userName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            comment.userName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (comment.userUsername.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8.0,
                                            ),
                                            child: Text(
                                              '@${comment.userUsername}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          context.l10n.relativeTime(
                                            comment.createdAt,
                                          ),
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(comment.comment),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: context.l10n.t('comments.hint'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _submitComment,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
