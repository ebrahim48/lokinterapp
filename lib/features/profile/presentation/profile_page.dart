import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../auth/presentation/welcome_page.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../../reviews/presentation/user_reviews_page.dart';
import '../../static/presentation/contact_us_page.dart';
import '../../static/presentation/terms_page.dart';
import '../data/profile_mock.dart';
import 'basic_info_page.dart';
import 'increase_visibility_page.dart';
import 'subscription_page.dart';
import 'wallet_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    const p = currentProfile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: () => Get.changeThemeMode(
                Get.isDarkMode ? ThemeMode.light : ThemeMode.dark),
            icon: Icon(Get.isDarkMode
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 28.h),
        children: [
          _header(context, p),
          SizedBox(height: 20.h),
          _group(context, [
            _Item(Icons.person_outline, 'Basic info', () => Get.to(() => const BasicInfoPage())),
            _Item(Icons.trending_up, 'Increase Visibility to Senders',
                () => Get.to(() => const IncreaseVisibilityPage())),
            _Item(Icons.workspace_premium_outlined, 'Subscription',
                () => Get.to(() => const SubscriptionPage())),
            _Item(Icons.account_balance_wallet_outlined, 'Wallet & payouts',
                () => Get.to(() => const WalletPage())),
          ]),
          SizedBox(height: 14.h),
          _group(context, [
            _Item(Icons.notifications_none, 'Notifications',
                () => Get.to(() => const NotificationsPage())),
            _Item(Icons.star_outline, 'My reviews',
                () => Get.to(() => const UserReviewsPage())),
            _Item(Icons.mail_outline, 'Contact us', () => Get.to(() => const ContactUsPage())),
            _Item(Icons.description_outlined, 'Terms & conditions',
                () => Get.to(() => const TermsPage())),
          ]),
          SizedBox(height: 14.h),
          _group(context, [
            _Item(Icons.logout, 'Log out', () => Get.offAll(() => const WelcomePage()),
                danger: true),
          ]),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Profile p) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30.r,
                backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
                child: Text(
                  p.name[0],
                  style: TextStyle(
                      color: AppPalette.primary, fontSize: 24.sp, fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                    SizedBox(height: 2.h),
                    Text(p.email,
                        style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14.sp, color: Colors.amber),
                        SizedBox(width: 4.w),
                        Text('${p.rating}  •  ${p.completedDeliveries} deliveries',
                            style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _verifyChip(context, 'ID verified', p.idVerified),
              SizedBox(width: 8.w),
              _verifyChip(context, 'Phone verified', p.phoneVerified),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verifyChip(BuildContext context, String label, bool ok) {
    final color = ok ? AppPalette.verified : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.verified : Icons.error_outline, size: 13.sp, color: color),
          SizedBox(width: 5.w),
          Text(label, style: TextStyle(fontSize: 10.sp, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, List<_Item> items) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56.w, color: cs.outline),
            _tile(context, items[i]),
          ],
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, _Item item) {
    final cs = Theme.of(context).colorScheme;
    final color = item.danger ? AppPalette.primary : cs.onSurface;
    return ListTile(
      onTap: item.onTap,
      leading: Icon(item.icon, color: item.danger ? AppPalette.primary : cs.onSurfaceVariant, size: 22.sp),
      title: Text(item.label, style: TextStyle(fontSize: 14.sp, color: color)),
      trailing: item.danger
          ? null
          : Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20.sp),
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  _Item(this.icon, this.label, this.onTap, {this.danger = false});
}
