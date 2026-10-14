import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Round profile photo, falling back to the name's initial when there is no
/// photo or it fails to load.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;
  final double? fontSize;

  const UserAvatar({
    super.key,
    required this.name,
    this.url,
    required this.radius,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final initial = CircleAvatar(
      radius: radius,
      backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: AppPalette.primary,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      ),
    );
    final img = url;
    if (img == null || img.isEmpty) return initial;
    return CachedNetworkImage(
      imageUrl: img,
      imageBuilder: (_, provider) =>
          CircleAvatar(radius: radius, backgroundImage: provider),
      placeholder: (_, __) => initial,
      errorWidget: (_, __, ___) => initial,
    );
  }
}
