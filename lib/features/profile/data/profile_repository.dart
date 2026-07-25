import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/data_bus.dart';
import '../../reviews/data/review_model.dart';

// Rating + verification summary from /rates/getUserInfo. The website's
// public profile also breaks the average down by role and shows post
// counts, so we carry those too.
class RatingSummary {
  final double averageStars;
  final double averageStarsAsTraveler;
  final double averageStarsAsSender;
  final int totalRates;
  final bool identityVerified;
  final bool phoneVerified;
  final bool emailVerified;
  final int completedDeals;
  final int totalTrips;
  final int totalRequests;
  final int totalDelivers;
  final String userName;
  final String? avatarUrl;

  const RatingSummary({
    this.averageStars = 0,
    this.averageStarsAsTraveler = 0,
    this.averageStarsAsSender = 0,
    this.totalRates = 0,
    this.identityVerified = false,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.completedDeals = 0,
    this.totalTrips = 0,
    this.totalRequests = 0,
    this.totalDelivers = 0,
    this.userName = '',
    this.avatarUrl,
  });

  // verification flags live under data.user; the activity counts under
  // data.posts (NOT at the top level, where they'd always read 0)
  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    final user = Map<String, dynamic>.from(json['user'] ?? {});
    final posts = Map<String, dynamic>.from(json['posts'] ?? {});
    double numOf(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    int intOf(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    final url = (user['avatarUrl'] ?? user['imageUrl'] ?? user['avatar']?['url'])?.toString();
    return RatingSummary(
      averageStars: numOf(json['averageStars']),
      averageStarsAsTraveler: numOf(json['averageStarsAsTraveler']),
      averageStarsAsSender: numOf(json['averageStarsAsSender']),
      totalRates: intOf(json['totalRates']),
      identityVerified: user['documentVerified'] ?? json['identityVerified'] ?? false,
      phoneVerified: user['phoneVerified'] ?? json['phoneVerified'] ?? false,
      emailVerified: user['emailVerified'] ?? false,
      completedDeals: intOf(json['completedDeals']),
      totalTrips: intOf(posts['totalTrips'] ?? json['totalTrips']),
      totalRequests: intOf(posts['totalRequests'] ?? json['totalRequests']),
      totalDelivers: intOf(posts['totalDelivers'] ?? json['totalDelivers']),
      userName: (user['name'] ??
              [user['firstName'] ?? '', user['lastName'] ?? '']
                  .where((s) => '$s'.isNotEmpty)
                  .join(' '))
          .toString()
          .trim(),
      avatarUrl: (url == null || url.isEmpty) ? null : url,
    );
  }
}

class ProfileRepository {
  final _api = Get.find<ApiService>();

  // omit userId for the logged-in user
  Future<RatingSummary> userInfo([int? userId]) async {
    final res = await _api.get('/rates/getUserInfo${userId != null ? '/$userId' : ''}');
    return RatingSummary.fromJson(Map<String, dynamic>.from(unwrapData(res)));
  }

  /// [avatarPath] uploads a new profile photo (multipart, same field name
  /// the website's basic-info form sends: `image`).
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    String? country,
    String? avatarPath,
  }) async {
    final fields = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      if (country != null && country.isNotEmpty) 'country': country,
    };
    if (avatarPath != null) {
      final form = FormData.fromMap({
        ...fields,
        'image': await MultipartFile.fromFile(avatarPath,
            filename: avatarPath.split('/').last),
      });
      unwrapData(await _api.post('/auth/updateProfile', data: form));
    DataBus.changed(DataTopic.profile);
      return;
    }
    unwrapData(await _api.post('/auth/updateProfile', data: fields));
    DataBus.changed(DataTopic.profile);
  }

  /// Pass [userId] to read another user's reviews (public profile);
  /// omit for the logged-in user.
  Future<List<Review>> reviews([int? userId]) async {
    final res = await _api.get(
        '/rates/getUserRates${userId != null ? '/$userId' : ''}',
        queryParameters: {'limit': 100});
    return Paged.fromJson(unwrapData(res), Review.fromJson).list;
  }

  Future<List<Review>> myReviews() => reviews();

  // ---- WhatsApp phone verification (website: basic-info modal) ----

  Future<void> sendPhoneOtp(String phoneNumber, String countryCode) async {
    unwrapData(await _api.post('/auth/sendPhoneOtp', data: {
      'phoneNumber': phoneNumber,
      'countryCode': countryCode,
    }));
  }

  Future<void> verifyPhoneOtp(
      String otp, String phoneNumber, String countryCode) async {
    unwrapData(await _api.post('/auth/verifyPhoneOtp', data: {
      'otp': otp,
      'phoneNumber': phoneNumber,
      'countryCode': countryCode,
    }));
  }
}
