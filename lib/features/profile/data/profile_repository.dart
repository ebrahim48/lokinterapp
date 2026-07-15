import 'package:get/get.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../reviews/data/review_model.dart';

// Rating + verification summary from /rates/getUserInfo.
class RatingSummary {
  final double averageStars;
  final int totalRates;
  final bool identityVerified;
  final bool phoneVerified;
  final int completedDeals;

  const RatingSummary({
    this.averageStars = 0,
    this.totalRates = 0,
    this.identityVerified = false,
    this.phoneVerified = false,
    this.completedDeals = 0,
  });

  // verification flags live under data.user; post counts under data.posts
  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    final user = Map<String, dynamic>.from(json['user'] ?? {});
    return RatingSummary(
      averageStars: ((json['averageStars'] ?? 0) as num).toDouble(),
      totalRates: json['totalRates'] ?? 0,
      identityVerified: user['documentVerified'] ?? json['identityVerified'] ?? false,
      phoneVerified: user['phoneVerified'] ?? json['phoneVerified'] ?? false,
      completedDeals: json['completedDeals'] ?? 0,
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

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    String? country,
  }) async {
    unwrapData(await _api.post('/auth/updateProfile', data: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      if (country != null && country.isNotEmpty) 'country': country,
    }));
  }

  Future<List<Review>> myReviews() async {
    final res = await _api.get('/rates/getUserRates', queryParameters: {'limit': 100});
    return Paged.fromJson(unwrapData(res), Review.fromJson).list;
  }
}
