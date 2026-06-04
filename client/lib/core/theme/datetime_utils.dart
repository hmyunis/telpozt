import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class DateTimeUtils {
  DateTimeUtils._();

  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;
    tz.initializeTimeZones();
    _isInitialized = true;
  }

  static String formatUtcToLocal(String utcIso, String ianaTimezone) {
    initialize();
    try {
      final utcDateTime = DateTime.parse(utcIso).toUtc();
      final location = tz.getLocation(ianaTimezone);
      final localDateTime = tz.TZDateTime.from(utcDateTime, location);
      return DateFormat('MMM d, yyyy · h:mm a').format(localDateTime);
    } catch (_) {
      return utcIso;
    }
  }

  static String formatRelativeTime(String? utcIso) {
    if (utcIso == null) return 'Never';
    try {
      final utcDateTime = DateTime.parse(utcIso).toUtc();
      final difference = DateTime.now().toUtc().difference(utcDateTime);
      if (difference.inDays > 0) return '${difference.inDays}d ago';
      if (difference.inHours > 0) return '${difference.inHours}h ago';
      if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return 'Never';
    }
  }
}
