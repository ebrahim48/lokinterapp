import 'package:get/get.dart';
import '../data/deal_model.dart';
import '../data/mock_deals.dart';

class DealsController extends GetxController {
  final filter = Rxn<DealStatus>(); // null = all

  List<Deal> get deals => filter.value == null
      ? mockDeals
      : mockDeals.where((d) => d.status == filter.value).toList();
}
