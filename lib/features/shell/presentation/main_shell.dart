import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/kyc_gate.dart';
import '../../chat/presentation/chat_inbox_page.dart';
import '../../deals/presentation/deals_page.dart';
import '../../home_feed/presentation/home_feed_page.dart';
import '../../post_request/presentation/post_request_page.dart';
import '../../post_trip/presentation/post_trip_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../chat/presentation/controllers/chat_inbox_controller.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // bring up the realtime layer once we're inside the app (login/restore)
    if (Get.find<SessionService>().loggedIn) {
      Get.find<SocketService>().connect();
    }
  }

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
        onPressed: () {
          if (!requireLogin()) return;
          _openPostSheet(context);
        },
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
            _tab(0, Icons.home_outlined, Icons.home, 'nav.home'.tr),
            _tab(1, Icons.handshake_outlined, Icons.handshake, 'nav.deals'.tr),
            SizedBox(width: 56.w), // notch gap for the FAB
            _tab(2, Icons.chat_bubble_outline, Icons.chat_bubble, 'nav.chat'.tr,
                badge: true),
            _tab(3, Icons.person_outline, Icons.person, 'nav.profile'.tr),
          ],
        ),
      ),
    );
  }

  Widget _tab(int index, IconData icon, IconData activeIcon, String label,
      {bool badge = false}) {
    final cs = Theme.of(context).colorScheme;
    final active = _index == index;
    final color = active ? AppPalette.primary : cs.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: () {
          // Deals / Chat / Profile are account screens — guests get the login ask
          if (index != 0 && !requireLogin()) return;
          setState(() => _index = index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            badge
                ? Obx(() => _badged(
                      Icon(active ? activeIcon : icon, color: color, size: 22.sp),
                      Get.isRegistered<ChatInboxController>()
                          ? Get.find<ChatInboxController>().unreadTotal
                          : 0,
                    ))
                : Icon(active ? activeIcon : icon, color: color, size: 22.sp),
            SizedBox(height: 2.h),
            Text(label, style: TextStyle(fontSize: 10.sp, color: color)),
          ],
        ),
      ),
    );
  }

  // unread pill over the chat icon, so a new message is visible from any tab
  Widget _badged(Widget child, int count) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6.w,
          top: -4.h,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
            constraints: BoxConstraints(minWidth: 16.w),
            decoration: BoxDecoration(
              color: AppPalette.primary,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
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
              onTap: () async {
                Get.back();
                // website gates posting behind identity verification
                if (await requireIdentityVerified(action: 'post a trip')) {
                  Get.to(() => const PostTripPage());
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: AppPalette.primary),
              title: const Text('Post a delivery request'),
              onTap: () async {
                Get.back();
                if (await requireIdentityVerified(action: 'post a delivery request')) {
                  Get.to(() => const PostRequestPage());
                }
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}
