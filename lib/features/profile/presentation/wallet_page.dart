import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_palette.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  static const _tx = [
    ('Delivery payout — LK-2025', '+ USD 18.00', true),
    ('Delivery payout — LK-2038', '+ TND 20.000', true),
    ('Service fee — LK-2041', '- TND 3.000', false),
    ('Withdrawal to bank', '- USD 40.00', false),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet & payouts')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              gradient: const LinearGradient(
                colors: [AppPalette.primary, Color(0xFF8E3F3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available earnings',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.sp)),
                SizedBox(height: 6.h),
                Text('USD 85.00',
                    style: TextStyle(color: Colors.white, fontSize: 30.sp, fontWeight: FontWeight.w800)),
                SizedBox(height: 16.h),
                _miniBtn(context, Icons.arrow_outward, 'Withdraw to bank'),
              ],
            ),
          ),
          SizedBox(height: 22.h),
          _payoutAccount(context),
          SizedBox(height: 22.h),
          Text('Recent activity',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
          SizedBox(height: 8.h),
          for (final t in _tx) _txRow(context, t.$1, t.$2, t.$3),
        ],
      ),
    );
  }

  Widget _miniBtn(BuildContext context, IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16.sp),
          SizedBox(width: 6.w),
          Text(label, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _payoutAccount(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_outlined, color: cs.onSurfaceVariant, size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payout account',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurface)),
                SizedBox(height: 2.h),
                Text('Bank •••• 4821',
                    style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('Manage')),
        ],
      ),
    );
  }

  Widget _txRow(BuildContext context, String label, String amount, bool credit) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18.r,
            backgroundColor: (credit ? AppPalette.verified : cs.onSurfaceVariant).withValues(alpha: 0.12),
            child: Icon(
              credit ? Icons.south_west : Icons.north_east,
              size: 16.sp,
              color: credit ? AppPalette.verified : cs.onSurfaceVariant,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.sp, color: cs.onSurface)),
          ),
          Text(amount,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: credit ? AppPalette.verified : cs.onSurface,
              )),
        ],
      ),
    );
  }
}
