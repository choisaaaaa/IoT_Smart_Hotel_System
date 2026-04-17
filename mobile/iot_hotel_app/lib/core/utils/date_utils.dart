import 'package:intl/intl.dart';

class DateUtils {
  static const Duration _utc8Offset = Duration(hours: 8);

  static DateTime toUtc8(DateTime dt) {
    final utc = dt.isUtc ? dt : dt.toUtc();
    return utc.add(_utc8Offset);
  }

  static String formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('yyyy-MM-dd').format(toUtc8(dt));
  }

  static String formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(toUtc8(dt));
  }

  static String formatDateTimeFull(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('yyyy年MM月dd日 HH:mm').format(toUtc8(dt));
  }

  static String formatDateCN(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('yyyy年MM月dd日').format(toUtc8(dt));
  }

  static String formatShortDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('MM月dd日').format(toUtc8(dt));
  }

  static String formatDotDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('MM.dd').format(toUtc8(dt));
  }

  static String formatDotDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('MM.dd HH:mm').format(toUtc8(dt));
  }

  static String formatSlashDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('MM/dd HH:mm').format(toUtc8(dt));
  }

  static String formatDashDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('MM-dd').format(toUtc8(dt));
  }

  static String formatMonthYear(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('yyyy年MM月').format(toUtc8(dt));
  }

  static String formatDynamic(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    if (value is DateTime) return formatDateTime(value);
    final str = value.toString();
    if (str.isEmpty) return fallback;
    try {
      return formatDateTime(DateTime.parse(str));
    } catch (_) {
      if (str.length >= 16) return str.substring(0, 16);
      if (str.length >= 10) return str.substring(0, 10);
      return str;
    }
  }

  static String formatDateDynamic(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    if (value is DateTime) return formatDate(value);
    final str = value.toString();
    if (str.isEmpty) return fallback;
    try {
      return formatDate(DateTime.parse(str));
    } catch (_) {
      if (str.length >= 10) return str.substring(0, 10);
      return str;
    }
  }
}
