import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

// ElevatedButton wired to a busy flag — disables itself and shows a spinner.
class LokBusyButton extends StatelessWidget {
  final RxBool busy;
  final String label;
  final Future<void> Function() onPressed;

  const LokBusyButton({
    super.key,
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ElevatedButton(
        onPressed: busy.value ? null : () => onPressed(),
        child: busy.value
            ? SizedBox(
                width: 20.r,
                height: 20.r,
                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}
