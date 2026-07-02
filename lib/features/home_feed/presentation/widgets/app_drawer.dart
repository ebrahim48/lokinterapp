import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../auth/presentation/welcome_page.dart';
import '../../../notifications/presentation/notifications_page.dart';
import '../../../profile/presentation/increase_visibility_page.dart';
import '../../../profile/presentation/profile_page.dart';
import '../../../profile/presentation/subscription_page.dart';
import '../../../profile/presentation/wallet_page.dart';
import '../../../static/presentation/contact_us_page.dart';
import '../../../static/presentation/terms_page.dart';

// Side menu opened from the home app bar.
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
              child: Text(
                'LOKINTER',
                style: TextStyle(
                  color: AppPalette.primary,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            Divider(color: cs.outline, height: 1),
            _item(context, Icons.person_outline, 'My profile', () => const ProfilePage()),
            _item(context, Icons.notifications_none, 'Notifications', () => const NotificationsPage()),
            _item(context, Icons.trending_up, 'Increase visibility', () => const IncreaseVisibilityPage()),
            _item(context, Icons.workspace_premium_outlined, 'Subscription', () => const SubscriptionPage()),
            _item(context, Icons.account_balance_wallet_outlined, 'Wallet & payouts', () => const WalletPage()),
            _item(context, Icons.mail_outline, 'Contact us', () => const ContactUsPage()),
            _item(context, Icons.description_outlined, 'Terms & conditions', () => const TermsPage()),
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
        Navigator.pop(context); // close the drawer first
        Get.to(page);
      },
    );
  }
}
