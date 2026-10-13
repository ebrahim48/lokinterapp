import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Full-screen, pinch-to-zoom view of a remote image — used for chat attachments
// and item pictures, matching the live site where both are clickable.
class ImageViewerPage extends StatelessWidget {
  final String url;
  final String? title;

  const ImageViewerPage({super.key, required this.url, this.title});

  static void open(BuildContext context, String url, {String? title}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ImageViewerPage(url: url, title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // the app theme's icon/title colours win over foregroundColor and
        // are dark — invisible on black
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: title == null
            ? null
            : Text(title!,
                style: TextStyle(fontSize: 14.sp, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        // double-tap or pinch to zoom; drag to pan once zoomed in
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, __) => Shimmer.fromColors(
              baseColor: const Color(0xFF1C1C1C),
              highlightColor: const Color(0xFF3A3A3A),
              child: Container(
                  width: double.infinity, height: 320.h, color: Colors.white),
            ),
            errorWidget: (_, __, ___) => Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 40.sp,
            ),
          ),
        ),
      ),
    );
  }
}
