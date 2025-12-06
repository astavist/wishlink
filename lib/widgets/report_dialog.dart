import 'package:flutter/material.dart';
import 'package:wishlink/l10n/app_localizations.dart';

class ReportFormResult {
  final String reason;
  final String? description;

  const ReportFormResult({required this.reason, this.description});
}

class _ReportReasonOption {
  final String value;
  final String labelKey;

  const _ReportReasonOption(this.value, this.labelKey);
}

const List<_ReportReasonOption> _reasonOptions = [
  _ReportReasonOption('spam', 'report.reasonSpam'),
  _ReportReasonOption('harassment', 'report.reasonHarassment'),
  _ReportReasonOption('inappropriate', 'report.reasonInappropriate'),
  _ReportReasonOption('misleading', 'report.reasonMisleading'),
  _ReportReasonOption('other', 'report.reasonOther'),
];

Future<ReportFormResult?> showReportDialog({
  required BuildContext context,
  required String title,
  String? description,
}) {
  return showDialog<ReportFormResult>(
    context: context,
    builder: (dialogContext) => _ReportDialog(
      title: title,
      description: description,
    ),
  );
}

class _ReportDialog extends StatefulWidget {
  final String title;
  final String? description;

  const _ReportDialog({required this.title, this.description});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canSubmit = _selectedReason != null;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.description != null && widget.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            Text(
              l10n.t('report.reasonLabel'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            ..._reasonOptions.map(
              (option) => RadioListTile<String>(
                value: option.value,
                groupValue: _selectedReason,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.t(option.labelKey)),
                onChanged: (value) {
                  setState(() {
                    _selectedReason = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.t('report.noteLabel'),
                hintText: l10n.t('report.noteHint'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.t('common.cancel')),
        ),
        FilledButton(
          onPressed: canSubmit
              ? () {
                  Navigator.of(context).pop(
                    ReportFormResult(
                      reason: _selectedReason!,
                      description: _detailsController.text.trim().isEmpty
                          ? null
                          : _detailsController.text.trim(),
                    ),
                  );
                }
              : null,
          child: Text(l10n.t('report.submitAction')),
        ),
      ],
    );
  }
}
