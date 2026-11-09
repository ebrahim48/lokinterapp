import 'package:url_launcher/url_launcher.dart';

/// True when a location string is a real place, not the "-" placeholder.
bool hasPlace(String? place) {
  final p = place?.trim() ?? '';
  return p.isNotEmpty && p != '-';
}

/// The Google Maps URL for a pickup / drop-off location, or null when there is
/// nothing to open. The API's own link wins, but for an empty location it
/// still sends a search for "-" — that one is ignored.
String? mapUrl(String? link, String? place) {
  if (link != null) {
    final q = Uri.tryParse(link)?.queryParameters['query']?.trim();
    if (q == null || hasPlace(q)) return link;
  }
  return hasPlace(place)
      ? 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(place!.trim())}'
      : null;
}

/// Opens a pickup / drop-off location in Google Maps.
Future<void> openMapLink(String? link, String? place) async {
  final url = mapUrl(link, place);
  if (url == null) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
