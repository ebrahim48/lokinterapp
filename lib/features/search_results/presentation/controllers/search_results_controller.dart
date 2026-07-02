import 'package:get/get.dart';
import '../../../posts/data/mock_data.dart';
import '../../../posts/data/models/post_model.dart';

class SearchResultsController extends GetxController {
  // 0 = Trips, 1 = Requests
  final tab = 0.obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments is int) tab.value = Get.arguments as int;
  }

  List<Post> get results => tab.value == 0 ? MockData.trips : MockData.requests;
}
