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
  final String _labelKey;
  const ReportReason(this.code, this._labelKey);

  String get label => _labelKey.tr;
}

const reportReasons = [
  ReportReason('FRAUD', 'report_reason_fraud'),
  ReportReason('INAPPROPRIATE_LANGUAGE', 'report_reason_language'),
  ReportReason('UNPROFESSIONAL_BEHAVIOR', 'report_reason_unprofessional'),
  ReportReason('LOST_OR_DAMAGED_ITEMS', 'report_reason_lost_damaged'),
  ReportReason('OTHER', 'report_reason_other'),
];
