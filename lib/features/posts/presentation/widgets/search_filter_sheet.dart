import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/widgets/lok_fields.dart';
import '../../../../core/widgets/lok_segmented.dart';
import '../../data/mock_data.dart';

// The "Search for deals" panel from the homepage mockup.
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
  int _mode = 0; // 0 = Local, 1 = International
  String? _localCountry, _fromCity, _toCity, _fromCountry, _toCountry;

  bool get _local => _mode == 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
        child: Column(
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
                options: MockData.countries,
                value: _localCountry,
                onChanged: (v) => setState(() => _localCountry = v),
              ),
              SizedBox(height: 14.h),
              LokDropdownField(
                label: 'From',
                hint: 'from city',
                icon: Icons.directions_car_filled_outlined,
                options: MockData.cities,
                value: _fromCity,
                onChanged: (v) => setState(() => _fromCity = v),
              ),
              SizedBox(height: 14.h),
              LokDropdownField(
                label: 'To',
                hint: 'to city',
                icon: Icons.directions_car_filled_outlined,
                options: MockData.cities,
                value: _toCity,
                onChanged: (v) => setState(() => _toCity = v),
              ),
            ] else ...[
              LokDropdownField(
                label: 'From',
                hint: 'from country',
                icon: Icons.public,
                options: MockData.countries,
                value: _fromCountry,
                onChanged: (v) => setState(() => _fromCountry = v),
              ),
              SizedBox(height: 14.h),
              LokDropdownField(
                label: 'To',
                hint: 'to country',
                icon: Icons.public,
                options: MockData.countries,
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
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
