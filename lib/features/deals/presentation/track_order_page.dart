import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/socket_service.dart';
import '../data/deal_model.dart';
import '../data/tracking_models.dart';
import '../data/tracking_repository.dart';

/// Track My Order (REQ §6.2 · GUIDE Screen 6): pickup, drop-off and the
/// transporter's current or last-known position on a map, for the sender,
/// the transporter and admins, while a local deal is ONGOING.
///
/// Live moves arrive over the `private-deal.{id}` socket; a slow refresh
/// covers a dropped socket. The pill and the "last ping" time come from the
/// fix's own timestamp, so a silent transporter turns DELAYED, then
/// UNAVAILABLE, instead of looking live. No route line or ETA is drawn —
/// there is no routing data behind one, and the spec forbids inventing it.
class TrackOrderPage extends StatefulWidget {
  final Deal deal;
  const TrackOrderPage({super.key, required this.deal});

  static Future<void> open(Deal deal) => Get.to(() => TrackOrderPage(deal: deal)) ?? Future.value();

  @override
  State<TrackOrderPage> createState() => _TrackOrderPageState();
}

class _TrackOrderPageState extends State<TrackOrderPage> {
  static const _refresh = Duration(seconds: 45);
  static const _tick = Duration(seconds: 15);

  final _repo = TrackingRepository();
  GoogleMapController? _map;
  TrackingSnapshot? _snap;
  TrackPoint? _last;
  bool _loading = true;
  String? _error;
  bool _ended = false;
  bool _fitted = false;
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _refreshTimer;
  Timer? _tickTimer;

  Deal get deal => widget.deal;

  LatLng? get _pickup {
    final p = _snap?.pickup;
    if (p != null) return LatLng(p.lat, p.lng);
    final e = deal.extras;
    return e.hasPickupPin ? LatLng(e.pickupLat!, e.pickupLng!) : null;
  }

  LatLng? get _dropoff {
    final p = _snap?.dropoff;
    if (p != null) return LatLng(p.lat, p.lng);
    final e = deal.extras;
    return e.hasDropoffPin ? LatLng(e.dropoffLat!, e.dropoffLng!) : null;
  }

  LatLng? get _transporter => _last == null ? null : LatLng(_last!.latitude, _last!.longitude);

  TrackingLink get _link => TrackingLinkX.fromAge(_last?.recordedAt);

  @override
  void initState() {
    super.initState();
    _load();
    if (Get.isRegistered<SocketService>()) {
      final socket = Get.find<SocketService>();
      socket.subscribeDeal(deal.id);
      _sub = socket.locationUpdates.listen(_onLive);
    }
    _refreshTimer = Timer.periodic(_refresh, (_) => _load(quiet: true));
    // re-evaluates LIVE → DELAYED → UNAVAILABLE as the last fix ages
    _tickTimer = Timer.periodic(_tick, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _refreshTimer?.cancel();
    _tickTimer?.cancel();
    if (Get.isRegistered<SocketService>()) Get.find<SocketService>().leaveDeal(deal.id);
    _map?.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final snap = await _repo.snapshot(deal.id);
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _ended = snap.ended;
        // never step back to an older fix than one the socket already gave
        if (snap.last != null &&
            (_last == null || !snap.last!.recordedAt.isBefore(_last!.recordedAt))) {
          _last = snap.last;
        }
        if (_ended) _last = null; // REQ §6.1: no position once the deal is over
        _loading = false;
        _error = null;
      });
      if (_ended) {
        _refreshTimer?.cancel();
        _sub?.cancel();
      }
      _fitOnce();
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // 403 = not a party to this deal any more; keep what we had otherwise
        if (!quiet || _snap == null) _error = e.message;
      });
    }
  }

  void _onLive(Map<String, dynamic> data) {
    final id = data['dealId'];
    if (id != null && '$id' != '${deal.id}') return;
    if (_ended) return;
    final p = TrackPoint.tryParse(data);
    if (p == null || !mounted) return;
    if (_last != null && p.recordedAt.isBefore(_last!.recordedAt)) return;
    setState(() => _last = p);
  }

  void _fitOnce() {
    if (_fitted || _map == null) return;
    final pts = [_pickup, _dropoff, _transporter].whereType<LatLng>().toList();
    if (pts.isEmpty) return;
    _fitted = true;
    if (pts.length == 1) {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 14));
      return;
    }
    double minLat = pts.first.latitude, maxLat = minLat;
    double minLng = pts.first.longitude, maxLng = minLng;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _map!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      60,
    ));
  }

  void _focus(LatLng? target) {
    if (target == null) {
      Get.snackbar('', 'location_not_available_yet'.tr,
          snackPosition: SnackPosition.BOTTOM, titleText: const SizedBox.shrink());
      return;
    }
    _map?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
  }

  Set<Marker> get _markers => {
        if (_pickup != null)
          Marker(
            markerId: const MarkerId('pickup'),
            position: _pickup!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
                title: 'pickup_location'.tr,
                snippet: _snap?.pickup?.label ?? deal.extras.pickupLocation),
          ),
        if (_dropoff != null)
          Marker(
            markerId: const MarkerId('dropoff'),
            position: _dropoff!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
                title: 'dropoff_location'.tr,
                snippet: _snap?.dropoff?.label ?? deal.extras.dropoffLocation),
          ),
        if (_transporter != null && !_ended)
          Marker(
            markerId: const MarkerId('transporter'),
            position: _transporter!,
            rotation: _last?.heading ?? 0,
            flat: _last?.heading != null,
            anchor: const Offset(0.5, 0.5),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: 'transporter'.tr),
            zIndexInt: 2,
          ),
      };

  Set<Circle> get _accuracy => {
        if (_transporter != null && !_ended && (_last?.accuracy ?? 0) > 0)
          Circle(
            circleId: const CircleId('accuracy'),
            center: _transporter!,
            radius: _last!.accuracy!,
            fillColor: const Color(0x2216A34A),
            strokeColor: const Color(0x6616A34A),
            strokeWidth: 1,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final start = _pickup ?? _dropoff ?? const LatLng(36.8065, 10.1815);
    return Scaffold(
      appBar: AppBar(title: Text('track_my_order'.tr)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: start, zoom: 12),
            markers: _markers,
            circles: _accuracy,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) {
              _map = c;
              _fitOnce();
            },
          ),
          Positioned(top: 12.h, left: 12.w, right: 12.w, child: _statusBar(cs)),
          if (!_ended)
            Positioned(
              right: 12.w,
              bottom: 24.h,
              child: Column(
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'focus_transporter',
                    onPressed: () => _focus(_transporter),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text('focus_transporter'.tr),
                  ),
                  SizedBox(height: 10.h),
                  FloatingActionButton.extended(
                    heroTag: 'focus_destination',
                    onPressed: () => _focus(_dropoff),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text('focus_destination'.tr),
                  ),
                ],
              ),
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _statusBar(ColorScheme cs) {
    Widget card(Widget child) => Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(14.r),
          color: cs.surface,
          child: Padding(padding: EdgeInsets.all(12.w), child: child),
        );

    if (_ended) {
      return card(Row(
        children: [
          Icon(Icons.check_circle_outline, color: const Color(0xFF16A34A), size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text('delivery_completed_tracking_ended'.tr,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
          ),
        ],
      ));
    }
    if (_error != null && _snap == null) {
      return card(Row(
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(child: Text(_error!, style: TextStyle(fontSize: 12.5.sp))),
          TextButton(onPressed: _load, child: Text('retry'.tr)),
        ],
      ));
    }

    final link = _link;
    final at = _last?.recordedAt;
    return card(Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: link.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8.r,
                height: 8.r,
                decoration: BoxDecoration(color: link.color, shape: BoxShape.circle),
              ),
              SizedBox(width: 6.w),
              Text(link.label,
                  style: TextStyle(
                      color: link.color, fontSize: 11.5.sp, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            at == null
                ? 'waiting_for_first_gps_ping'.tr
                : 'last_gps_ping'.trParams({'time': _time(at)}),
            style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    ));
  }

  // "10:35 AM" today, "Nov 9, 10:35 AM" otherwise
  String _time(DateTime t) {
    final l = MaterialLocalizations.of(context);
    final hm = l.formatTimeOfDay(TimeOfDay.fromDateTime(t));
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) return hm;
    return '${l.formatShortMonthDay(t)}, $hm';
  }
}
