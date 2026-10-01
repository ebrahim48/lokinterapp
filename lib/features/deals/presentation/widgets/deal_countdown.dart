import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// Which deal window is counting down — each has its own wording and tint.
enum DealWindow { payment, arrival, dispute }

/// Live HH:MM:SS countdown to [endsAt], e.g.
/// "Dispute window: 05:42:16 remaining". Ticks every second and calls
/// [onExpired] once when it reaches zero so the screen can reload the deal
/// (the server cron has auto-cancelled / auto-completed / released by then).
class DealCountdown extends StatefulWidget {
  final DateTime endsAt;
  final DealWindow window;
  final VoidCallback? onExpired;
  /// Smaller single-line variant for deal cards.
  final bool compact;

  const DealCountdown({
    super.key,
    required this.endsAt,
    required this.window,
    this.onExpired,
    this.compact = false,
  });

  static String format(Duration d) {
    if (d.isNegative) d = Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  State<DealCountdown> createState() => _DealCountdownState();
}

class _DealCountdownState extends State<DealCountdown> {
  Timer? _timer;
  late Duration _left;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(DealCountdown old) {
    super.didUpdateWidget(old);
    if (old.endsAt != widget.endsAt) {
      _fired = false;
      _tick();
    }
  }

  void _tick() {
    final left = widget.endsAt.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _left = left.isNegative ? Duration.zero : left);
    if (_left == Duration.zero && !_fired) {
      _fired = true;
      widget.onExpired?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  (IconData, Color, String, String?) get _style => switch (widget.window) {
        DealWindow.payment => (
            Icons.timer_outlined,
            const Color(0xFFB45309),
            'payment_window_remaining',
            'payment_window_hint',
          ),
        DealWindow.arrival => (
            Icons.hourglass_bottom,
            const Color(0xFF0369A1),
            'arrival_window_remaining',
            'arrival_window_hint',
          ),
        DealWindow.dispute => (
            Icons.gpp_maybe_outlined,
            const Color(0xFFBE123C),
            'dispute_window_remaining',
            null,
          ),
      };

  @override
  Widget build(BuildContext context) {
    // never a frozen 00:00:00 — gone the moment it runs out, while the
    // reload triggered by onExpired swaps in the new deal state
    if (_left == Duration.zero) return const SizedBox.shrink();
    final (icon, color, key, hintKey) = _style;
    final text = key.trParams({'time': DealCountdown.format(_left)});

    if (widget.compact) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.sp, color: color),
            SizedBox(width: 5.w),
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                if (hintKey != null) ...[
                  SizedBox(height: 4.h),
                  Text(hintKey.tr,
                      style: TextStyle(
                          fontSize: 11.5.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Auto-completed" marker for deals the server closed after the 48h
/// arrival window ran out with no completion and no dispute.
class AutoCompletedChip extends StatelessWidget {
  const AutoCompletedChip({super.key});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF065F46);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_mode, size: 12.sp, color: color),
          SizedBox(width: 4.w),
          Text('auto_completed'.tr,
              style: TextStyle(
                  fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
