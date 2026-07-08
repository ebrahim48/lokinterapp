import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../chat/presentation/chat_inbox_page.dart';
import '../../deals/presentation/deals_page.dart';
import '../../home_feed/presentation/home_feed_page.dart';
import '../../post_request/presentation/post_request_page.dart';
import '../../post_trip/presentation/post_trip_page.dart';
import '../../profile/presentation/profile_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [
    HomeFeedPage(),
    DealsPage(),
    ChatInboxPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppPalette.primary,
        elevation: 2,
        shape: const CircleBorder(),
        onPressed: () => _openPostSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomAppBar(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 64.h,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _tab(0, Icons.home_outlined, Icons.home, 'Home'),
            _tab(1, Icons.handshake_outlined, Icons.handshake, 'Deals'),
            SizedBox(width: 56.w), // notch gap for the FAB
            _tab(2, Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
            _tab(3, Icons.person_outline, Icons.person, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _tab(int index, IconData icon, IconData activeIcon, String label) {
    final cs = Theme.of(context).colorScheme;
    final active = _index == index;
    final color = active ? AppPalette.primary : cs.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 22.sp),
            SizedBox(height: 2.h),
            Text(label, style: TextStyle(fontSize: 10.sp, color: color)),
          ],
        ),
      ),
    );
  }

  void _openPostSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            ListTile(
              leading: const Icon(Icons.flight_takeoff, color: AppPalette.intlAccent),
              title: const Text('Post a Trip'),
              onTap: () {
                Get.back();
                Get.to(() => const PostTripPage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: AppPalette.primary),
              title: const Text('Post a delivery request'),
              onTap: () {
                Get.back();
                Get.to(() => const PostRequestPage());
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}
