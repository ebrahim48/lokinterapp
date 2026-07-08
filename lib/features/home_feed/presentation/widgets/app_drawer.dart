import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/lokinter_logo.dart';
import '../../../auth/presentation/welcome_page.dart';
import '../../../my_posts/presentation/my_posts_page.dart';
import '../../../notifications/presentation/notifications_page.dart';
import '../../../profile/presentation/increase_visibility_page.dart';
import '../../../static/presentation/contact_us_page.dart';
import '../../../static/presentation/terms_page.dart';

// Quick menu from the home app bar — shortcuts that aren't already the bottom-nav tabs.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Drawer(
      backgroundColor: cs.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 14.h),
              child: const LokinterLogo(fontSize: 22),
            ),
            Divider(color: cs.outline, height: 1),
            _item(context, Icons.dynamic_feed_outlined, 'My requests & trips',
                () => const MyPostsPage()),
            _item(context, Icons.trending_up, 'Increase visibility',
                () => const IncreaseVisibilityPage()),
            _item(context, Icons.notifications_none, 'Notifications',
                () => const NotificationsPage()),
            _item(context, Icons.mail_outline, 'Contact us', () => const ContactUsPage()),
            _item(context, Icons.description_outlined, 'Terms & conditions',
                () => const TermsPage()),
            Divider(color: cs.outline, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppPalette.primary),
              title: Text('Log out',
                  style: TextStyle(fontSize: 14.sp, color: AppPalette.primary)),
              onTap: () {
                Navigator.pop(context);
                Get.offAll(() => const WelcomePage());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, Widget Function() page) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.onSurfaceVariant, size: 22.sp),
      title: Text(label, style: TextStyle(fontSize: 14.sp, color: cs.onSurface)),
      onTap: () {
        Navigator.pop(context);
        Get.to(page);
      },
    );
  }
}
