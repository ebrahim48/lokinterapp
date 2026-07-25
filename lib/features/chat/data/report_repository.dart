import 'package:get/get.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';

// Reporting the person you're chatting with. The API stores the enum-style
// reason and a free-text comment separately (website payload shape).
class ReportRepository {
  final _api = Get.find<ApiService>();

  Future<void> report(int userId, String reason, {String? comment}) async {
    unwrapData(await _api.post('/reportProfiles/addReport', data: {
      'userId': userId,
      'reason': reason,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    }));
  }
}

// Same reason codes the website's report-profile dialog submits.
class ReportReason {
  final String code;
  final String label;
  const ReportReason(this.code, this.label);
}

const reportReasons = [
  ReportReason('FRAUD', 'Fraud or scam'),
  ReportReason('INAPPROPRIATE_LANGUAGE', 'Inappropriate language'),
  ReportReason('UNPROFESSIONAL_BEHAVIOR', 'Unprofessional behavior'),
  ReportReason('LOST_OR_DAMAGED_ITEMS', 'Lost or damaged items'),
  ReportReason('OTHER', 'Something else'),
];
