import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_palette.dart';
import '../utils/notify.dart';

/// A point on the map plus the address shown for it. Pickup and drop-off
/// travel to the API as `{x}Location`, `{x}Lat`, `{x}Lng` (REQ §4).
class PickedPlace {
  final String label;
  final double lat;
  final double lng;

  const PickedPlace({required this.label, required this.lat, required this.lng});

  LatLng get latLng => LatLng(lat, lng);

  /// Coordinates as text — the label when an address has no name.
  String get coordsLabel => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

/// A stored address, minus the `-` placeholder the API is sent for a blank one.
String realAddress(String? raw) {
  final t = (raw ?? '').trim();
  return t == '-' ? '' : t;
}

/// The pin a post already stored, or null when it has no exact coordinates —
/// an address alone is never turned into a guessed point.
PickedPlace? placeFrom(String? address, double? lat, double? lng) {
  if (lat == null || lng == null) return null;
  final place = PickedPlace(label: realAddress(address), lat: lat, lng: lng);
  return place.label.isEmpty
      ? PickedPlace(label: place.coordsLabel, lat: lat, lng: lng)
      : place;
}

/// Full-screen pin picker: the pin stays in the middle of the map and the
/// user moves the map under it, searches an address, or jumps to their own
/// position. The address under the pin is looked up when the map settles.
///
/// Uses the device geocoder (the `geocoding` package), so it needs no extra
/// Google Places billing and still returns exact coordinates.
class LocationPickerPage extends StatefulWidget {
  final String title;
  final PickedPlace? initial;

  const LocationPickerPage({super.key, required this.title, this.initial});

  static Future<PickedPlace?> open({required String title, PickedPlace? initial}) async =>
      await Get.to<PickedPlace>(() => LocationPickerPage(title: title, initial: initial));

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  // Tunis — where most local deals start when we know nothing better
  static const _fallback = LatLng(36.8065, 10.1815);

  GoogleMapController? _map;
  final _geocoder = Geocoding();
  late LatLng _center = widget.initial?.latLng ?? _fallback;
  String _label = '';
  /// The exact point [_label] was looked up for. Confirm returns this point,
  /// so the saved address and the saved coordinates always describe the same
  /// place (a Dhaka address can never be saved with the Tunis start point).
  LatLng? _labelAt;
  /// The user searched or dragged: a late "find me" must not pull the pin away.
  bool _userMoved = false;
  bool _resolving = false;
  final _search = TextEditingController();
  int _lookupSeq = 0;

  @override
  void initState() {
    super.initState();
    _label = widget.initial?.label ?? '';
    if (widget.initial != null) _labelAt = widget.initial!.latLng;
    if (widget.initial == null) _goToMe(silent: true);
  }

  @override
  void dispose() {
    _search.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress() async {
    final seq = ++_lookupSeq;
    final at = _center;
    setState(() => _resolving = true);
    try {
      final marks = await _geocoder.placemarkFromCoordinates(at.latitude, at.longitude);
      if (seq != _lookupSeq || !mounted) return;
      setState(() {
        _label = marks.isEmpty ? _coordsOf(at) : _format(marks.first, at);
        _labelAt = at;
      });
    } catch (_) {
      // no geocoder / offline: the coordinates are still exact
      if (seq == _lookupSeq && mounted) {
        setState(() {
          _label = _coordsOf(at);
          _labelAt = at;
        });
      }
    } finally {
      if (seq == _lookupSeq && mounted) setState(() => _resolving = false);
    }
  }

  String get _coordsLabel => _coordsOf(_center);

  static String _coordsOf(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

  String _format(Placemark p, LatLng at) {
    final parts = <String>[
      if ((p.street ?? '').isNotEmpty) p.street!,
      if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
      if ((p.locality ?? '').isNotEmpty) p.locality!,
      if ((p.administrativeArea ?? '').isNotEmpty && p.administrativeArea != p.locality)
        p.administrativeArea!,
    ];
    return parts.isEmpty ? _coordsOf(at) : parts.toSet().join(', ');
  }

  Future<void> _searchAddress() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    try {
      final hits = await _geocoder.locationFromAddress(q);
      if (hits.isEmpty) {
        toast('no_place_found'.tr);
        return;
      }
      _userMoved = true;
      _moveTo(LatLng(hits.first.latitude, hits.first.longitude), zoom: 16);
    } catch (_) {
      toast('no_place_found'.tr);
    }
  }

  Future<void> _goToMe({bool silent = false}) async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!silent) toast('location_permission_needed_to_find_you'.tr);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));
      // the silent start-up lookup lost the race to a search or a drag
      if (silent && _userMoved) return;
      if (!silent) _userMoved = true;
      _moveTo(LatLng(pos.latitude, pos.longitude), zoom: 16);
    } catch (_) {
      if (!silent) toast('could_not_get_your_location'.tr);
    }
  }

  void _moveTo(LatLng to, {double? zoom}) {
    _center = to;
    _map?.animateCamera(
      zoom == null ? CameraUpdate.newLatLng(to) : CameraUpdate.newLatLngZoom(to, zoom),
    );
    _resolveAddress();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 14),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (c) {
              _map = c;
              if (_label.isEmpty) _resolveAddress();
            },
            onCameraMoveStarted: () => _labelAt = null,
            onCameraMove: (pos) => _center = pos.target,
            onCameraIdle: _resolveAddress,
          ),
          // the pin's tip sits on the map centre
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40.r),
                child: Icon(Icons.location_on, size: 44.r, color: AppPalette.primary),
              ),
            ),
          ),
          Positioned(
            top: 12.h,
            left: 12.w,
            right: 12.w,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(14.r),
              color: cs.surface,
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchAddress(),
                decoration: InputDecoration(
                  hintText: 'search_an_address'.tr,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _searchAddress,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12.w,
            bottom: 150.h,
            child: FloatingActionButton.small(
              heroTag: 'picker_me',
              onPressed: _goToMe,
              tooltip: 'use_my_location'.tr,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                margin: EdgeInsets.all(12.w),
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 18.sp, color: cs.onSurfaceVariant),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _resolving && _label.isEmpty ? '…' : _label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.sp, color: cs.onSurface),
                          ),
                        ),
                        if (_resolving)
                          SizedBox(
                            width: 14.r,
                            height: 14.r,
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    ElevatedButton(
                      // enabled only once the address under the pin is known
                      // for the pin's current spot
                      onPressed: (_resolving || _labelAt == null)
                          ? null
                          : () => Get.back(
                                result: PickedPlace(
                                  label: _label.isEmpty ? _coordsOf(_labelAt!) : _label,
                                  lat: _labelAt!.latitude,
                                  lng: _labelAt!.longitude,
                                ),
                              ),
                      child: Text('confirm_this_location'.tr),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Form row that opens [LocationPickerPage] — styled like the other Lok fields.
class LokLocationField extends StatelessWidget {
  final String label;
  final String hint;
  final bool required;
  final PickedPlace? value;
  final ValueChanged<PickedPlace> onChanged;
  /// Address shown while [value] is null — an older post saved as text with
  /// no pin. Tapping still opens the map so it can be pinned exactly.
  final String? fallbackLabel;

  const LokLocationField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.fallbackLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fallback = (fallbackLabel ?? '').trim();
    final shown = value?.label ?? (fallback.isEmpty ? null : fallback);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (required)
                const TextSpan(text: ' *', style: TextStyle(color: AppPalette.primary)),
            ],
          ),
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        SizedBox(height: 6.h),
        InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () async {
            final picked = await LocationPickerPage.open(title: label, initial: value);
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.pin_drop_outlined, size: 18.sp, color: cs.onSurfaceVariant),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    shown ?? hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: shown == null ? cs.onSurfaceVariant : cs.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.map_outlined, size: 18.sp, color: AppPalette.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
