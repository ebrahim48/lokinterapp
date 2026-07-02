import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../posts/presentation/post_details_page.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../../posts/presentation/widgets/search_filter_sheet.dart';
import '../../../core/widgets/lok_segmented.dart';
import 'controllers/search_results_controller.dart';

class SearchResultsPage extends StatelessWidget {
  const SearchResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SearchResultsController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search for deals'),
        actions: [
          IconButton(
            onPressed: () => SearchFilterSheet.show(context),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
            child: Obx(() => LokSegmented(
                  labels: const ['Trips', 'Requests'],
                  selected: c.tab.value,
                  onChanged: (i) => c.tab.value = i,
                )),
          ),
          Expanded(
            child: Obx(
              () => ListView.separated(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                itemCount: c.results.length,
                separatorBuilder: (_, __) => SizedBox(height: 14.h),
                itemBuilder: (_, i) => PostCard(
                  post: c.results[i],
                  onTap: () => Get.to(() => PostDetailsPage(post: c.results[i])),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
