import 'dart:math' as math;
import 'dart:ui';

import 'geo.dart';

class TileCoord {
  const TileCoord(this.z, this.x, this.y);

  final int z;
  final int x;
  final int y;

  String get key => '$z/$x/$y';
}

class MapCamera {
  const MapCamera({required this.center, required this.zoom, required this.size});

  final GeoPoint center;
  final double zoom;
  final Size size;

  int get zoomLevel => zoom.round().clamp(2, 18).toInt();

  double get _world => 256 * math.pow(2, zoom).toDouble();

  Offset project(GeoPoint point) {
    final x = (point.lon + 180) / 360 * _world;
    final lat = point.lat.clamp(-85.05112878, 85.05112878) * math.pi / 180;
    final y = (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * _world;
    return Offset(x, y);
  }

  Offset get origin => project(center) - Offset(size.width / 2, size.height / 2);

  Offset pinOffset(GeoPoint point) => project(point) - origin;

  bool contains(GeoPoint point, {double padding = 24}) {
    final offset = pinOffset(point);
    return offset.dx >= padding && offset.dy >= padding && offset.dx <= size.width - padding && offset.dy <= size.height - padding - 24;
  }

  double get tileScale => math.pow(2, zoom - zoomLevel).toDouble();

  GeoPoint shiftBy(Offset pixels) {
    final moved = project(center) + pixels;
    final lon = moved.dx / _world * 360 - 180;
    final mercator = math.pi - 2 * math.pi * moved.dy / _world;
    final sinh = (math.exp(mercator) - math.exp(-mercator)) / 2;
    final lat = math.atan(sinh) * 180 / math.pi;
    return GeoPoint(lat.clamp(-85, 85), lon.clamp(-180, 180));
  }

  List<TileCoord> get tiles {
    final start = origin;
    final end = start + Offset(size.width, size.height);
    final tileSize = 256 * tileScale;
    final x0 = (start.dx / tileSize).floor();
    final y0 = (start.dy / tileSize).floor();
    final x1 = (end.dx / tileSize).floor();
    final y1 = (end.dy / tileSize).floor();
    final limit = 1 << zoomLevel;
    final tiles = <TileCoord>[];
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        if (x < 0 || y < 0 || x >= limit || y >= limit) continue;
        tiles.add(TileCoord(zoomLevel, x, y));
      }
    }
    return tiles;
  }
}

MapCamera chooseCamera(List<GeoPoint> points, Size size, {GeoPoint? focus}) {
  final center = focus ?? _centroid(points);
  final safe = size.width < 32 || size.height < 32 ? const Size(320, 240) : size;
  for (final zoom in [16, 15, 14, 13, 12, 11]) {
    final camera = MapCamera(center: center, zoom: zoom.toDouble(), size: safe);
    if (points.every((point) => camera.contains(point, padding: 52))) return camera;
  }
  return MapCamera(center: center, zoom: 11, size: safe);
}

GeoPoint _centroid(List<GeoPoint> points) {
  if (points.isEmpty) return const GeoPoint(0, 0);
  var lat = 0.0;
  var lon = 0.0;
  for (final point in points) {
    lat += point.lat;
    lon += point.lon;
  }
  return GeoPoint(lat / points.length, lon / points.length);
}
