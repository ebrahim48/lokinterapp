import '../constants/api_constants.dart';

// The dev backend embeds media links on the dashboard host, where they 404.
// Rewrite them onto the API host until APP_URL is fixed server-side.
String? fixMediaUrl(String? url) {
  if (url == null) return null;
  const wrongHost = 'https://dev-dashboard.lokinter.com/api/v1';
  return url.startsWith(wrongHost)
      ? url.replaceFirst(wrongHost, ApiConstants.baseUrl)
      : url;
}

/// A user's profile photo from any payload shape the API sends: `imageUrl`,
/// `avatarUrl`, `profile_image`, or `avatar` as a string or `{url, isFallback}`.
/// The fallback is an SVG placeholder an image widget can't draw, so it counts
/// as "no photo".
String? avatarUrlFrom(Map json) {
  final a = json['avatar'];
  if (a is Map && a['isFallback'] == true) return null;
  final raw = json['imageUrl'] ??
      json['avatarUrl'] ??
      json['profile_image'] ??
      json['profileImage'] ??
      (a is Map ? a['url'] : a);
  final url = fixMediaUrl(raw?.toString().trim());
  if (url == null || url.isEmpty || !url.startsWith('http')) return null;
  return url.toLowerCase().endsWith('.svg') ? null : url;
}
