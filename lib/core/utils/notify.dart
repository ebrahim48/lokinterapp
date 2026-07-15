import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../exceptions/app_exceptions.dart';
import '../theme/app_palette.dart';

void toast(String message) {
  // snackbars can land mid-route-transition when there's no overlay yet;
  // losing the toast beats crashing
  try {
    Get.snackbar(
      'Lokinter', message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppPalette.navy,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  } catch (_) {}
}

void toastError(Object e) {
  final msg = e is AppException ? e.message : 'Something went wrong';
  try {
    Get.snackbar(
      'Oops', msg,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppPalette.primary,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  } catch (_) {}
}
