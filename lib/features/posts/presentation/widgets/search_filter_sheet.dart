import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/lok_fields.dart';
import '../../../../core/widgets/lok_segmented.dart';
import '../../../search_results/presentation/controllers/search_results_controller.dart';

// The "Search for deals" panel from the homepage mockup. Reads its country
// and city options from the search controller and applies filters through it.
class SearchFilterSheet extends StatefulWidget {
  const SearchFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (_) => const SearchFilterSheet(),
    );
  }

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  final _c = Get.find<SearchResultsController>();
  final _weight = TextEditingController();

  int _mode = 0; // 0 = Local, 1 = International
  String? _localCountry, _fromCity, _toCity, _fromCountry, _toCountry;

  bool get _local => _mode == 0;

  List<String> get _countryNames => _c.countries.map((e) => e.name).toList();
  List<String> get _cityNames => _c.cities.map((e) => e.name).toList();

  int? _countryId(String? name) =>
      _c.countries.firstWhereOrNull((e) => e.name == name)?.id;
  int? _cityId(String? name) => _c.cities.firstWhereOrNull((e) => e.name == name)?.id;

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  void _apply() {
    _c.applyFilters({
      'postLocation': _local ? 'LOCAL' : 'INTERNATIONAL',
      'fromCountryId': _countryId(_local ? _localCountry : _fromCountry),
      'toCountryId': _local ? null : _countryId(_toCountry),
      'fromCityId': _local ? _cityId(_fromCity) : null,
      'toCityId': _local ? _cityId(_toCity) : null,
      'weight': double.tryParse(_weight.text),
    }..removeWhere((_, v) => v == null));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Search for deals',
                      style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              LokSegmented(
                labels: const ['Local', 'International'],
                selected: _mode,
                onChanged: (i) => setState(() => _mode = i),
              ),
              SizedBox(height: 18.h),
              if (_local) ...[
                LokDropdownField(
                  label: 'Local Country',
                  hint: 'local country',
                  icon: Icons.public,
                  options: _countryNames,
                  value: _localCountry,
                  onChanged: (v) {
                    setState(() {
                      _localCountry = v;
                      _fromCity = null;
                      _toCity = null;
                    });
                    final country = _c.countries.firstWhereOrNull((e) => e.name == v);
                    if (country != null) _c.loadCities(country);
                  },
                ),
                SizedBox(height: 14.h),
                LokDropdownField(
                  label: 'From',
                  hint: 'from city',
                  icon: Icons.directions_car_filled_outlined,
                  options: _cityNames,
                  value: _fromCity,
                  onChanged: (v) => setState(() => _fromCity = v),
                ),
                SizedBox(height: 14.h),
                LokDropdownField(
                  label: 'To',
                  hint: 'to city',
                  icon: Icons.directions_car_filled_outlined,
                  options: _cityNames,
                  value: _toCity,
                  onChanged: (v) => setState(() => _toCity = v),
                ),
              ] else ...[
                LokDropdownField(
                  label: 'From',
                  hint: 'from country',
                  icon: Icons.public,
                  options: _countryNames,
                  value: _fromCountry,
                  onChanged: (v) => setState(() => _fromCountry = v),
                ),
                SizedBox(height: 14.h),
                LokDropdownField(
                  label: 'To',
                  hint: 'to country',
                  icon: Icons.public,
                  options: _countryNames,
                  value: _toCountry,
                  onChanged: (v) => setState(() => _toCountry = v),
                ),
              ],
              SizedBox(height: 14.h),
              LokTextField(
                label: 'Weight',
                hint: 'KG To Deliver',
                icon: Icons.scale_outlined,
                keyboardType: TextInputType.number,
                controller: _weight,
              ),
              SizedBox(height: 20.h),
              ElevatedButton(
                onPressed: _apply,
                child: const Text('Apply Filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
