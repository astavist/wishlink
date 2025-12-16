import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:wishlink/l10n/app_localizations.dart';

String localizedReportReason(String? reason, AppLocalizations l10n) {
  final normalized = reason?.toLowerCase().trim();
  switch (normalized) {
    case 'spam':
      return l10n.t('report.reasonSpam');
    case 'harassment':
      return l10n.t('report.reasonHarassment');
    case 'inappropriate':
      return l10n.t('report.reasonInappropriate');
    case 'misleading':
      return l10n.t('report.reasonMisleading');
    case 'other':
      return l10n.t('report.reasonOther');
    default:
      final fallback = reason?.trim();
      return fallback != null && fallback.isNotEmpty
          ? fallback
          : l10n.t('report.reasonOther');
  }
}

String formatAdminTargetType(String raw, AppLocalizations l10n) {
  final normalized = raw.toLowerCase().trim();
  switch (normalized) {
    case 'user':
      return l10n.t('admin.targetType.user');
    case 'wish':
      return l10n.t('admin.targetType.wish');
    default:
      return l10n.t('admin.unknownValue');
  }
}

DateTime? reportTimestampToDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

String formatAdminExactDate(DateTime dateTime, AppLocalizations l10n) {
  final locale = l10n.locale;
  final buffer = StringBuffer(locale.languageCode);
  if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
    buffer.write('_${locale.countryCode}');
  }
  final formatter = DateFormat.yMMMd(buffer.toString()).add_Hm();
  return formatter.format(dateTime);
}

String mergeNameAndId(String? name, String? id, AppLocalizations l10n) {
  final trimmedName = name?.trim();
  final trimmedId = id?.trim();

  if ((trimmedName == null || trimmedName.isEmpty) &&
      (trimmedId == null || trimmedId.isEmpty)) {
    return l10n.t('admin.unknownValue');
  }

  if (trimmedName != null && trimmedName.isNotEmpty) {
    if (trimmedId != null && trimmedId.isNotEmpty) {
      return '$trimmedName • $trimmedId';
    }
    return trimmedName;
  }

  return trimmedId ?? l10n.t('admin.unknownValue');
}
