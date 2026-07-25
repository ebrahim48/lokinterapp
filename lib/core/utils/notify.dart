import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import '../exceptions/app_exceptions.dart';
import '../theme/app_palette.dart';

// Top-anchored toasts on the root navigator's overlay. That overlay outlives
// route swaps like login's Get.offAll, so — unlike GetX's route-context
// snackbar — it never throws "No Overlay found" and drops the message. A plain
// SnackBar can't sit at the top, hence the custom overlay entry.

DateTime? _lastAt;
VoidCallback? _dismissCurrent;

// One result per user action: the API interceptor reports the backend message
// centrally and a screen may also catch the same call — keep the first, skip a
// near-instant duplicate.
bool _allow() {
  final now = DateTime.now();
  if (_lastAt != null && now.difference(_lastAt!) < const Duration(milliseconds: 1200)) {
    return false;
  }
  _lastAt = now;
  return true;
}

void _show(String text, Color color) {
  final overlay = Get.key.currentState?.overlay;
  if (overlay == null) return;
  _dismissCurrent?.call(); // clear anything still on screen

  var removed = false;
  late final OverlayEntry entry;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
    if (_dismissCurrent == remove) _dismissCurrent = null;
  }

  entry = OverlayEntry(builder: (_) => _TopToast(text: text, color: color, onDone: remove));
  _dismissCurrent = remove;
  overlay.insert(entry);
}

void _snack(String message, Color color) {
  final text = message.trim();
  if (text.isEmpty || !_allow()) return;
  // fired mid-build? defer to the end of the frame to avoid a build-phase insert
  if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    SchedulerBinding.instance.addPostFrameCallback((_) => _show(text, color));
  } else {
    _show(text, color);
  }
}

void toast(String message) => _snack(message, AppPalette.navy);

void toastSuccess(String message) => _snack(message, AppPalette.confirmGreen);

void toastError(Object e) {
  final msg = e is AppException
      ? e.message
      : e is String
          ? e
          : 'Something went wrong';
  _snack(msg, AppPalette.primary);
}

class _TopToast extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onDone;
  const _TopToast({required this.text, required this.color, required this.onDone});

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast> with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _ac.forward();
    _timer = Timer(const Duration(seconds: 3), _close);
  }

  Future<void> _close() async {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    if (mounted) await _ac.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(anim),
        child: FadeTransition(
          opacity: anim,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _close,
                  child: Container(
                    key: const Key('app_toast'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      widget.text,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
