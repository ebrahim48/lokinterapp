import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pickup = blue, drop-off = red — same as Google Maps' own from/to pins.
const pickupDotColor = Color(0xFF1A73E8);
const dropoffDotColor = Color(0xFFEA4335);

/// "49 Bir Uttam AK Khandakar Rd, Dhaka 1212, Bangladesh, …" → the first two
/// parts, so a map label stays one short line.
String shortPlace(String? label) {
  final parts = (label ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && e != '-')
      .toList();
  if (parts.isEmpty) return '';
  final s = parts.take(2).join(', ');
  return s.length > 34 ? '${s.substring(0, 33)}…' : s;
}

/// A map pin drawn as a coloured dot with a white label bubble above it
/// ("From: Dhanmondi, Bangladesh") — so both points are named on the map at
/// once, which a normal info window (one at a time) can't do. The dot's
/// centre sits exactly on the coordinate.
class PlaceLabelMarker {
  static final _cache = <String, BitmapDescriptor>{};

  static Future<BitmapDescriptor> build(
    String text,
    Color dot,
    double dpr,
  ) async {
    final key = '$text|${dot.toARGB32()}|$dpr';
    final hit = _cache[key];
    if (hit != null) return hit;
    final desc = BitmapDescriptor.bytes(
      await paint(text, dot, dpr),
      imagePixelRatio: dpr,
    );
    _cache[key] = desc;
    return desc;
  }

  /// The PNG behind [build].
  static Future<Uint8List> paint(String text, Color dot, double dpr) async {
    final s = dpr;
    const fontSize = 12.0,
        padX = 8.0,
        padY = 5.0,
        gap = 4.0,
        dotR = 7.0,
        ring = 2.5;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize * s,
          color: const Color(0xFF202124),
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 220 * s);

    final bubbleW = tp.width + padX * 2 * s;
    final bubbleH = tp.height + padY * 2 * s;
    final shadow = 3 * s;
    final w = bubbleW + shadow * 2;
    final dotTotal = (dotR + ring) * 2 * s;
    final h = bubbleH + gap * s + dotTotal + shadow;

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(shadow, shadow / 2, bubbleW, bubbleH),
      Radius.circular(4 * s),
    );
    c.drawRRect(
      bubble.shift(Offset(0, s)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * s),
    );
    c.drawRRect(bubble, Paint()..color = Colors.white);
    tp.paint(c, Offset(shadow + padX * s, shadow / 2 + padY * s));

    final center = Offset(w / 2, h - dotTotal / 2);
    c.drawCircle(center, (dotR + ring) * s, Paint()..color = Colors.white);
    c.drawCircle(center, dotR * s, Paint()..color = dot);

    final img = await rec.endRecording().toImage(w.ceil(), h.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  /// Anchor that puts the dot's centre on the coordinate.
  static Offset anchorFor(String text, double dpr) {
    // mirrors build(): dot radius + ring = 9.5 logical px from the bottom
    // over the image height, measured the same way
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 220);
    final h = tp.height + 10 + 4 + 19 + 3;
    return Offset(0.5, 1 - 9.5 / h);
  }
}

/// A Google Maps directions endpoint: the place's address when there is one,
/// so Maps shows its real name — the coordinates only as a fallback.
String directionsPoint(LatLng pos, String? label) {
  final l = label?.trim() ?? '';
  return l.isNotEmpty && l != '-' ? l : '${pos.latitude},${pos.longitude}';
}

/// The Google Maps directions URL from [from] to [to] — Google's own road
/// route, not one the app draws or guesses.
Uri directionsUri(
  LatLng from,
  LatLng to, {
  String? fromLabel,
  String? toLabel,
}) => Uri.https('www.google.com', '/maps/dir/', {
  'api': '1',
  'origin': directionsPoint(from, fromLabel),
  'destination': directionsPoint(to, toLabel),
  'travelmode': 'driving',
});

/// Opens Google Maps with directions from [from] to [to], named by their
/// addresses when known.
Future<void> openDirections(
  LatLng from,
  LatLng to, {
  String? fromLabel,
  String? toLabel,
}) => launchUrl(
  directionsUri(from, to, fromLabel: fromLabel, toLabel: toLabel),
  mode: LaunchMode.externalApplication,
);

/// Small, non-scrolling map of a deal's pickup and drop-off with "From" /
/// "To" labels, framed to show both. Tapping it opens the road route in
/// Google Maps.
class PlacesMap extends StatefulWidget {
  final LatLng? pickup;
  final String? pickupLabel;
  final LatLng? dropoff;
  final String? dropoffLabel;
  final double? height;

  /// Whether "Tracking Now" (and tapping the map) opens the route. Off, the
  /// button shows greyed out and does nothing.
  final bool routeEnabled;

  const PlacesMap({
    super.key,
    this.pickup,
    this.pickupLabel,
    this.dropoff,
    this.dropoffLabel,
    this.height,
    this.routeEnabled = true,
  });

  @override
  State<PlacesMap> createState() => _PlacesMapState();
}

class _PlacesMapState extends State<PlacesMap> {
  GoogleMapController? _map;
  Set<Marker> _markers = {};

  String get _fromText =>
      'map_from'.trParams({'place': shortPlace(widget.pickupLabel)});
  String get _toText =>
      'map_to'.trParams({'place': shortPlace(widget.dropoffLabel)});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildMarkers();
  }

  @override
  void didUpdateWidget(PlacesMap old) {
    super.didUpdateWidget(old);
    if (old.pickup != widget.pickup || old.dropoff != widget.dropoff) {
      _buildMarkers();
      _fit();
    }
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _buildMarkers() async {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final next = <Marker>{};
    if (widget.pickup != null) {
      next.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickup!,
          icon: await PlaceLabelMarker.build(_fromText, pickupDotColor, dpr),
          anchor: PlaceLabelMarker.anchorFor(_fromText, dpr),
          zIndexInt: 1,
        ),
      );
    }
    if (widget.dropoff != null) {
      next.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: widget.dropoff!,
          icon: await PlaceLabelMarker.build(_toText, dropoffDotColor, dpr),
          anchor: PlaceLabelMarker.anchorFor(_toText, dpr),
          zIndexInt: 2,
        ),
      );
    }
    if (mounted) setState(() => _markers = next);
  }

  void _fit() {
    final m = _map;
    if (m == null) return;
    final pts = [widget.pickup, widget.dropoff].whereType<LatLng>().toList();
    if (pts.isEmpty) return;
    if (pts.length == 1 || pts[0] == pts[1]) {
      m.moveCamera(CameraUpdate.newLatLngZoom(pts.first, 14));
      return;
    }
    final a = pts[0], b = pts[1];
    m.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            a.latitude < b.latitude ? a.latitude : b.latitude,
            a.longitude < b.longitude ? a.longitude : b.longitude,
          ),
          northeast: LatLng(
            a.latitude > b.latitude ? a.latitude : b.latitude,
            a.longitude > b.longitude ? a.longitude : b.longitude,
          ),
        ),
        // room for the label bubbles above each dot
        56,
      ),
    );
  }

  void _open() {
    if (!widget.routeEnabled) return;
    final a = widget.pickup, b = widget.dropoff;
    if (a != null && b != null) {
      openDirections(
        a,
        b,
        fromLabel: widget.pickupLabel,
        toLabel: widget.dropoffLabel,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.pickup ?? widget.dropoff;
    if (start == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: SizedBox(
        height: widget.height ?? 190.h,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: start, zoom: 12),
              markers: _markers,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              onTap: (_) => _open(),
              onMapCreated: (c) {
                _map = c;
                // the map needs a frame of size before bounds can be fitted
                Future.delayed(const Duration(milliseconds: 300), _fit);
              },
            ),
            if (widget.pickup != null && widget.dropoff != null)
              Positioned(
                right: 8.w,
                bottom: 8.h,
                child: Opacity(
                  opacity: widget.routeEnabled ? 1 : 0.5,
                  child: Material(
                    color: cs.surface,
                    elevation: widget.routeEnabled ? 2 : 0,
                    borderRadius: BorderRadius.circular(20.r),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20.r),
                      onTap: widget.routeEnabled ? _open : null,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions,
                              size: 16.sp,
                              color: widget.routeEnabled
                                  ? pickupDotColor
                                  : cs.onSurfaceVariant,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'view_route'.tr,
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
