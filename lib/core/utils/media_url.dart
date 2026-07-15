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
