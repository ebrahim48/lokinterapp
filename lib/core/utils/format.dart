import 'package:get/get.dart';

// Small formatting helpers so we don't pull in intl just for a few strings.
// Month names and the clock follow the app language (fr: "3 oct. 2026 · 14:05").
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _monthsFr = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

bool get _fr => (Get.locale?.languageCode ?? 'en') == 'fr';

String _month(int m) => (_fr ? _monthsFr : _months)[m - 1];

String shortDate(DateTime d) =>
    _fr ? '${d.day} ${_month(d.month)} ${d.year}' : '${_month(d.month)} ${d.day}, ${d.year}';

String shortDateTime(DateTime d) => '${shortDate(d)} · ${clockTime(d)}';

String dayMonth(DateTime d) => '${d.day} ${_month(d.month)}';

String clockTime(DateTime d) {
  final mm = d.minute.toString().padLeft(2, '0');
  if (_fr) return '${d.hour.toString().padLeft(2, '0')}:$mm';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:$mm ${d.hour < 12 ? 'AM' : 'PM'}';
}

// Parses whatever timestamp shape the API sends into DEVICE-LOCAL time. The
// backend stores UTC, so a naive stamp (no 'Z'/offset) is read as UTC, not as
// local — otherwise chat times drift by the user's timezone. Handles ISO
// (with/without zone) and the "MM/DD/YYYY hh:mm AM/PM" form used elsewhere.
DateTime? parseServerDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  final iso = DateTime.tryParse(s);
  if (iso != null) {
    final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(s);
    // tryParse flags 'Z'/offset stamps as UTC; naive ones as local — force UTC
    return hasZone
        ? iso.toLocal()
        : DateTime.utc(iso.year, iso.month, iso.day, iso.hour, iso.minute, iso.second,
                iso.millisecond)
            .toLocal();
  }

  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})\s*([AaPp][Mm])$')
      .firstMatch(s);
  if (m != null) {
    var h = int.parse(m.group(4)!);
    final pm = m.group(6)!.toUpperCase() == 'PM';
    if (pm && h != 12) h += 12;
    if (!pm && h == 12) h = 0;
    return DateTime.utc(int.parse(m.group(3)!), int.parse(m.group(1)!),
            int.parse(m.group(2)!), h, int.parse(m.group(5)!))
        .toLocal();
  }
  return null;
}

// Chat stamps: time for today, weekday-ish date beyond that. Accepts the
// timestamps the API sends and passes through anything already humanised
// ("2 hours ago").
String chatTime(String raw) {
  if (raw.isEmpty) return '';
  final d = parseServerDate(raw);
  if (d == null) return raw;

  final now = DateTime.now();
  final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
  if (sameDay) return clockTime(d);

  final yesterday = now.subtract(const Duration(days: 1));
  final wasYesterday =
      d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day;
  if (wasYesterday) return 'yesterday_at'.trParams({'time': clockTime(d)});

  return '${dayMonth(d)}, ${clockTime(d)}';
}

String kg(double value) {
  final s = value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  return '$s kg';
}
