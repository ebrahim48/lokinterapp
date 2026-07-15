import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../data/deal_model.dart';
import '../data/deals_repository.dart';

class DealsController extends GetxController {
  final filter = Rxn<DealStatus>(); // null = all
  final deals = <Deal>[].obs;
  final loading = true.obs;
  final error = RxnString();

  final _repo = DealsRepository();

  @override
  void onInit() {
    super.onInit();
    ever(filter, (_) => load());
    load();
  }

  Future<void> load() async {
    final status = filter.value?.apiValue ?? 'ALL';

    // last full list paints instantly while the filtered fetch runs
    if (status == 'ALL') {
      final cached = _repo.cachedAll();
      if (cached != null) {
        deals.assignAll(cached);
        loading.value = false;
      }
    } else {
      loading.value = true;
    }

    try {
      deals.assignAll(await _repo.list(status));
      error.value = null;
    } on AppException catch (e) {
      if (deals.isEmpty) error.value = e.message;
    } finally {
      loading.value = false;
    }
  }
}
