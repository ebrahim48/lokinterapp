import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/notify.dart';
import '../../../../core/widgets/lok_fields.dart';
import '../../../../core/widgets/lok_segmented.dart';
import '../../../lookups/data/lookup_models.dart';
import '../../../lookups/data/lookups_repository.dart';
import '../search_results_page.dart';

// The website's "Search for deals" hero: a Local/International toggle, from/to
// (countries international, cities local) and weight, with two buttons that
// each pick the search type and jump to the results — Trip or Delivery Request.
class SearchDealsForm extends StatefulWidget {
  const SearchDealsForm({super.key});

  @override
  State<SearchDealsForm> createState() => _SearchDealsFormState();
}

class _SearchDealsFormState extends State<SearchDealsForm> {
  final _lookups = LookupsRepository();
  final _weight = TextEditingController();

  List<Country> _countries = [];
  List<City> _cities = [];

  int _mode = 0; // 0 = Local, 1 = International
  String? _localCountry, _fromCity, _toCity, _fromCountry, _toCountry;

  bool get _local => _mode == 0;
  List<String> get _countryNames => _countries.map((e) => e.name).toList();
  List<String> get _cityNames => _cities.map((e) => e.name).toList();

  String? _iso(String? name) =>
      _countries.firstWhereOrNull((e) => e.name == name)?.iso2;
  int? _cityId(String? name) => _cities.firstWhereOrNull((e) => e.name == name)?.id;

  @override
  void initState() {
    super.initState();
    _lookups.countries().then((list) {
      if (mounted) setState(() => _countries = list);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Future<void> _loadCities(String? countryName) async {
    final iso = _iso(countryName);
    setState(() {
      _cities = [];
      _fromCity = null;
      _toCity = null;
    });
    if (iso == null) return;
    try {
      final list = await _lookups.cities(iso);
      if (mounted) setState(() => _cities = list);
    } catch (_) {}
  }

  // tab 0 = Trip (searchAs TRIP), tab 1 = Delivery Request (searchAs DELIVER)
  void _search(int tab) {
    final w = _weight.text.trim();
    if (w.isNotEmpty && double.tryParse(w) == null) {
      toast('weight_must_be_a_number'.tr);
      return;
    }
    final filters = <String, dynamic>{
      'searchType': _local ? 'LOCAL' : 'INTERNATIONAL',
      'fromCountryId': _iso(_local ? _localCountry : _fromCountry),
      'toCountryId': _local ? null : _iso(_toCountry),
      'fromCityId': _local ? _cityId(_fromCity) : null,
      'toCityId': _local ? _cityId(_toCity) : null,
      'weight': double.tryParse(w),
    }..removeWhere((_, v) => v == null);

    Get.to(() => const SearchResultsPage(),
        arguments: {'tab': tab, 'filters': filters});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('search_for_deals'.tr,
                  style: TextStyle(
                      fontSize: 16.sp, fontWeight: FontWeight.w800, color: cs.onSurface)),
              SizedBox(
                width: 168.w,
                child: LokSegmented(
                  labels: const ['Local', 'International'],
                  selected: _mode,
                  onChanged: (i) => setState(() {
                    _mode = i;
                    _localCountry = _fromCity = _toCity = null;
                    _fromCountry = _toCountry = null;
                    _cities = [];
                  }),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text('find_the_best_delivery_deals_for_your_shipments'.tr,
              style: TextStyle(fontSize: 11.5.sp, color: cs.onSurfaceVariant)),
          SizedBox(height: 16.h),
          if (_local) ...[
            LokDropdownField(
              label: 'local_country'.tr,
              hint: 'local_country_2'.tr,
              icon: Icons.public,
              options: _countryNames,
              value: _localCountry,
              onChanged: (v) {
                setState(() => _localCountry = v);
                _loadCities(v);
              },
            ),
            SizedBox(height: 12.h),
            LokDropdownField(
              label: 'from'.tr,
              hint: 'from_city'.tr,
              icon: Icons.location_city_outlined,
              options: _cityNames,
              value: _fromCity,
              onChanged: (v) => setState(() => _fromCity = v),
            ),
            SizedBox(height: 12.h),
            LokDropdownField(
              label: 'to'.tr,
              hint: 'to_city'.tr,
              icon: Icons.location_city_outlined,
              options: _cityNames,
              value: _toCity,
              onChanged: (v) => setState(() => _toCity = v),
            ),
          ] else ...[
            LokDropdownField(
              label: 'from'.tr,
              hint: 'from_country'.tr,
              icon: Icons.public,
              options: _countryNames,
              value: _fromCountry,
              onChanged: (v) => setState(() => _fromCountry = v),
            ),
            SizedBox(height: 12.h),
            LokDropdownField(
              label: 'to'.tr,
              hint: 'to_country'.tr,
              icon: Icons.public,
              options: _countryNames,
              value: _toCountry,
              onChanged: (v) => setState(() => _toCountry = v),
            ),
          ],
          SizedBox(height: 12.h),
          LokTextField(
            label: 'weight'.tr,
            hint: 'kg_to_deliver'.tr,
            icon: Icons.inventory_2_outlined,
            keyboardType: TextInputType.number,
            controller: _weight,
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _search(0),
              icon: Icon(Icons.map_outlined, size: 16.sp),
              label: Text('search_for_trip'.tr),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, 46.h),
                foregroundColor: AppPalette.navy,
                side: BorderSide(color: cs.outline),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _search(1),
              icon: Icon(Icons.search, size: 16.sp),
              label: Text('search_for_delivery_request'.tr),
              style: ElevatedButton.styleFrom(minimumSize: Size(0, 46.h)),
            ),
          ),
        ],
      ),
    );
  }
}
