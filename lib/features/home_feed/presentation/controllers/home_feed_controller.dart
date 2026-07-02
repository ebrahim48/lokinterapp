import 'package:get/get.dart';
import '../../../posts/data/mock_data.dart';
import '../../../posts/data/models/post_model.dart';

class HomeFeedController extends GetxController {
  List<Post> get recommended => MockData.recommendedTravelers;

  // newest posts, requests and trips mixed
  List<Post> get feed => [...MockData.requests, ...MockData.trips];
}
