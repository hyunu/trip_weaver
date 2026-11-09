import 'package:flutter/material.dart';

import '../map/geo.dart';
import '../map/trip_map.dart';
import '../theme/app_theme.dart';
import 'chrome.dart';

/// Map sheet: pan/zoom, then confirm the map center as the coordinate.
class CoordinatePickSheet extends StatefulWidget {
  const CoordinatePickSheet({super.key, required this.title, this.initial});

  final String title;
  final GeoPoint? initial;

  static Future<GeoPoint?> show(BuildContext context, {required String title, GeoPoint? initial}) {
    return showModalBottomSheet<GeoPoint>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CoordinatePickSheet(title: title, initial: initial),
    );
  }

  @override
  State<CoordinatePickSheet> createState() => _CoordinatePickSheetState();
}

class _CoordinatePickSheetState extends State<CoordinatePickSheet> {
  GeoPoint? _center;

  @override
  void initState() {
    super.initState();
    _center = widget.initial ?? const GeoPoint(37.5665, 126.978);
  }

  @override
  Widget build(BuildContext context) {
    final center = _center!;
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xs),
            child: Text(widget.title, style: AppType.headline),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Text(
              '지도를 움직여 십자 위치에 맞춘 뒤 확인하세요.',
              style: AppType.footnote.copyWith(color: AppColors.secondary),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MapFrame(
                  expand: true,
                  child: _CenterTrackingMap(
                    focus: center,
                    onCenterChanged: (point) => setState(() => _center = point),
                  ),
                ),
                const IgnorePointer(
                  child: Center(child: Icon(Icons.add, size: 32, color: AppColors.accent)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('좌표 ${center.lat.toStringAsFixed(4)}, ${center.lon.toStringAsFixed(4)}', style: AppType.footnote),
                const SizedBox(height: AppSpace.sm),
                AppButton(
                  key: const Key('map-pick-confirm'),
                  label: '이 위치로 확인',
                  onPressed: () => Navigator.pop(context, center),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterTrackingMap extends StatefulWidget {
  const _CenterTrackingMap({required this.focus, required this.onCenterChanged});

  final GeoPoint focus;
  final ValueChanged<GeoPoint> onCenterChanged;

  @override
  State<_CenterTrackingMap> createState() => _CenterTrackingMapState();
}

class _CenterTrackingMapState extends State<_CenterTrackingMap> {
  final GlobalKey<_TripMapAccessorState> _mapKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return TripMapAccessor(
      key: _mapKey,
      focus: widget.focus,
      onCenterChanged: widget.onCenterChanged,
    );
  }
}

/// Thin wrapper so [TripMap] center updates are forwarded after gestures.
class TripMapAccessor extends StatefulWidget {
  const TripMapAccessor({super.key, required this.focus, required this.onCenterChanged});

  final GeoPoint focus;
  final ValueChanged<GeoPoint> onCenterChanged;

  @override
  State<TripMapAccessor> createState() => _TripMapAccessorState();
}

class _TripMapAccessorState extends State<TripMapAccessor> {
  GeoPoint? _lastReported;

  void _report(GeoPoint center) {
    if (_lastReported != null &&
        (_lastReported!.lat - center.lat).abs() < 0.00001 &&
        (_lastReported!.lon - center.lon).abs() < 0.00001) {
      return;
    }
    _lastReported = center;
    widget.onCenterChanged(center);
  }

  @override
  Widget build(BuildContext context) {
    return TripMap(
      key: const Key('coordinate-pick-map'),
      pins: const [],
      focus: widget.focus,
      reportCenter: _report,
    );
  }
}
