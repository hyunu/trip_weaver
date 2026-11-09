import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'camera.dart';
import 'geo.dart';
import 'osm_tiles.dart';
import 'place_pins.dart';

const routeEstimateNote = '점선은 방문 번호 순 직선입니다. 거리·도보 시간은 그 직선과 시속 4.5km 추정이며 도로 경로가 아닙니다.';

class TripMap extends StatefulWidget {
  const TripMap({super.key, required this.pins, this.focus, this.onPinTap, this.reportCenter});

  final List<MapPin> pins;
  final GeoPoint? focus;
  final ValueChanged<MapPin>? onPinTap;

  /// Called when the user pans/zooms so pick-on-map sheets can read the map center.
  final ValueChanged<GeoPoint>? reportCenter;

  @override
  State<TripMap> createState() => _TripMapState();
}

class _TripMapState extends State<TripMap> {
  OsmStyleSource? _style;
  String _askedKey = '';
  String _fitKey = '';
  GeoPoint? _center;
  double? _zoom;
  double _gestureZoom = 14;
  GeoPoint _gestureCenter = const GeoPoint(0, 0);
  Offset _gestureFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    OsmStyleSource.load().then((style) {
      if (!mounted) return;
      setState(() => _style = style);
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureZoom = _zoom ?? 14;
    _gestureCenter = _center ?? const GeoPoint(0, 0);
    _gestureFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final zoom = (_gestureZoom + math.log(details.scale) / math.ln2).clamp(3.0, 18.0);
    final delta = details.localFocalPoint - _gestureFocal;
    final base = MapCamera(center: _gestureCenter, zoom: _gestureZoom, size: const Size(1, 1));
  final shifted = base.shiftBy(Offset(-delta.dx, -delta.dy));
    setState(() {
      _zoom = zoom;
      _center = shifted;
    });
    widget.reportCenter?.call(shifted);
  }

  void _ensureTiles(MapCamera camera) {
    final style = _style;
    if (style == null || camera.size.width < 32 || camera.size.height < 32) return;
    final key = camera.tiles.map((tile) => tile.key).join(',');
    if (key == _askedKey) return;
    _askedKey = key;
    final missing = camera.tiles.where((tile) => !OsmTileStore.instance.memory.containsKey(tile.key)).toList();
    if (missing.isEmpty) return;
    OsmTileStore.instance.load(missing, style.template).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite || !constraints.maxHeight.isFinite) return const SizedBox.shrink();
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final fitKey = '${widget.focus?.lat},${widget.focus?.lon}|${widget.pins.map((pin) => pin.id).join(',')}';
        if (_center == null || _fitKey != fitKey) {
          final fitted = chooseCamera(widget.pins.map((pin) => pin.point).toList(), size, focus: widget.focus);
          _fitKey = fitKey;
          _center = fitted.center;
          _zoom = fitted.zoom;
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.reportCenter?.call(_center!));
        }
        final camera = MapCamera(center: _center!, zoom: _zoom!, size: size);
        _ensureTiles(camera);
        final priority = [...widget.pins]..sort((a, b) => _rank(b).compareTo(_rank(a)));
        final anchors = [for (final pin in priority) camera.pinOffset(pin.point)];
        final spots = _spread(anchors);
        final spotFor = {for (var index = 0; index < priority.length; index++) priority[index].id: spots[index]};
        final paintOrder = [...widget.pins]..sort((a, b) => _rank(a).compareTo(_rank(b)));
        final route = orderedVisitPins(widget.pins);
        final routeOffsets = [for (final pin in route) spotFor[pin.id]!];
        final estimate = routeEstimateLabel(visitRouteMeters(widget.pins), route.length);
        return Semantics(
          container: true,
          label: mapSemanticLabel(widget.pins, estimate),
          child: GestureDetector(
            key: const Key('trip-map'),
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: ClipRect(
              // Pin spacing is laid out for fixed-size labels; each pin still
              // carries its full name in semantics at any text scale.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _TilePainter(camera: camera, images: OsmTileStore.instance.memory), size: size),
                    CustomPaint(painter: _RoutePainter(routeOffsets), size: size),
                    for (final pin in paintOrder) _pin(pin, spotFor[pin.id]!, size),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: const Color(0xF2FFFFFF), borderRadius: BorderRadius.circular(6)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(estimate, key: const Key('route-estimate'), style: AppType.footnote, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _rank(MapPin pin) {
    if (pin.emphasized) return 2;
    if (pin.past) return 0;
    return 1;
  }

  List<Offset> _spread(List<Offset> anchors) {
    const minDx = 108.0;
    const minDy = 58.0;
    final placed = <Offset>[];
    for (final anchor in anchors) {
      var spot = anchor;
      var found = false;
      for (var ring = 0; ring < 8 && !found; ring++) {
        final tries = ring == 0 ? 1 : 8;
        for (var step = 0; step < tries; step++) {
          final angle = ring == 0 ? 0.0 : (step / tries) * math.pi * 2;
          final distance = ring * 46.0;
          final candidate = anchor + Offset(math.cos(angle) * distance, math.sin(angle) * distance * 0.65);
          final clash = placed.any((other) => (other.dx - candidate.dx).abs() < minDx && (other.dy - candidate.dy).abs() < minDy);
          if (!clash) {
            spot = candidate;
            found = true;
            break;
          }
        }
      }
      placed.add(spot);
    }
    return placed;
  }

  /// Pins whose circle sits outside the frame are clipped to a sliver, so
  /// screen readers skip them as sighted users do.
  Widget _pinSemantics({required bool visible, required bool button, required String label, required VoidCallback? onTap, required Widget child}) {
    if (!visible) return ExcludeSemantics(child: child);
    return Semantics(button: button, label: label, excludeSemantics: true, onTap: onTap, child: child);
  }

  Widget _pin(MapPin pin, Offset offset, Size size) {
    const diameter = 28.0;
    const labelWidth = 104.0;
    final onTap = widget.onPinTap == null ? null : () => widget.onPinTap!(pin);
    return Positioned(
      left: offset.dx - labelWidth / 2,
      top: offset.dy - diameter / 2,
      child: _pinSemantics(
        visible: (Offset.zero & size).contains(offset),
        button: onTap != null,
        label: mapPinSemanticLabel(pin),
        onTap: onTap,
        child: GestureDetector(
          key: Key('map-pin-${pin.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: labelWidth, minHeight: 48),
            child: Opacity(
              opacity: pin.past ? 0.45 : 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: diameter,
                    height: diameter,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pin.nearby ? Colors.white : (pin.emphasized ? AppColors.ink : AppColors.accent),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: pin.emphasized ? 3 : 2),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))],
                    ),
                    child: Text(
                      pin.order?.toString() ?? '',
                      style: AppType.footnoteStrong.copyWith(color: pin.nearby ? AppColors.ink : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 2),
                  DecoratedBox(
                    decoration: BoxDecoration(color: const Color(0xF2FFFFFF), borderRadius: BorderRadius.circular(4)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      child: SizedBox(
                        width: 96,
                        child: Text(pin.label, textAlign: TextAlign.center, style: AppType.footnoteStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String mapSemanticLabel(List<MapPin> pins, String estimate) {
  if (pins.isEmpty) return '지도, 표시할 장소 없음';
  final visits = orderedVisitPins(pins).length;
  return visits == 0 ? '지도, 장소 ${pins.length}곳' : '지도, 방문 $visits곳. $estimate';
}

String mapPinSemanticLabel(MapPin pin) {
  final parts = <String>[
    if (pin.order != null) '${pin.order}번 방문',
    pin.label,
    if (pin.emphasized) pin.order != null ? '다음 목적지' : '선택됨',
    if (pin.nearby) '주변 장소',
    if (pin.past) '지난 방문',
  ];
  return parts.join(', ');
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var index = 1; index < points.length; index++) {
      _dash(canvas, points[index - 1], points[index], paint);
    }
  }

  void _dash(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final length = delta.distance;
    if (length == 0) return;
    final direction = delta / length;
    const dash = 8.0;
    const gap = 6.0;
    var drawn = 0.0;
    while (drawn < length) {
      final stop = math.min(drawn + dash, length);
      canvas.drawLine(start + direction * drawn, start + direction * stop, paint);
      drawn = stop + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => oldDelegate.points != points;
}

class _TilePainter extends CustomPainter {
  _TilePainter({required this.camera, required this.images});

  final MapCamera camera;
  final Map<String, ui.Image> images;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE7EEF2));
    final origin = camera.origin;
    final tileSize = 256 * camera.tileScale;
    for (final tile in camera.tiles) {
      final image = images[tile.key];
      final dest = Rect.fromLTWH(tile.x * tileSize - origin.dx, tile.y * tileSize - origin.dy, tileSize, tileSize);
      if (image == null) continue;
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), dest, Paint());
    }
  }

  @override
  bool shouldRepaint(covariant _TilePainter oldDelegate) => true;
}
