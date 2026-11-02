import 'package:url_launcher/url_launcher.dart';

/// True when a location string is a real place, not the "-" placeholder.
bool hasPlace(String? place) {
  final p = place?.trim() ?? '';
  return p.isNotEmpty && p != '-';
}

/// Opens a pickup / drop-off location in Google Maps. Uses the API's own link
/// when it sent one, otherwise builds the same search link from the text.
Future<void> openMapLink(String? link, String? place) async {
  final url = link ??
      (hasPlace(place)
          ? 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(place!.trim())}'
          : null);
  if (url == null) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
