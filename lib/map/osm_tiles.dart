import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'camera.dart';
import 'geo.dart';

class OsmStyleSource {
  const OsmStyleSource({required this.template, required this.attribution});

  final String template;
  final String attribution;

  static Future<OsmStyleSource> load() async {
    final raw = jsonDecode(await rootBundle.loadString('assets/map/osm_style.json')) as Map<String, dynamic>;
    final source = (raw['sources'] as Map<String, dynamic>)['osm'] as Map<String, dynamic>;
    final tiles = (source['tiles'] as List<dynamic>).cast<String>();
    return OsmStyleSource(template: tiles.first, attribution: source['attribution'] as String);
  }
}

class _PassthroughOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => super.createHttpClient(context);
}

class OsmTileStore {
  OsmTileStore._();

  static final instance = OsmTileStore._();

  static const userAgent = 'TripWeave/0.1 (https://www.openstreetmap.org/copyright)';

  final Map<String, ui.Image> memory = {};
  final Set<String> failedKeys = {};
  VoidCallback? onFetchFailure;
  Directory? _directory;

  @visibleForTesting
  void resetForTest() {
    memory.clear();
    failedKeys.clear();
    onFetchFailure = null;
  }

  Directory get directory => _directory ??= Directory('${Directory.systemTemp.path}/trip_weave_osm_cache')..createSync(recursive: true);

  Future<void> load(List<TileCoord> tiles, String template) async {
    final missing = tiles.where((tile) => !memory.containsKey(tile.key)).toList();
    for (var index = 0; index < missing.length; index += 4) {
      final batch = missing.skip(index).take(4);
      await Future.wait(batch.map((tile) => _loadOne(tile, template)));
    }
  }

  Future<void> _loadOne(TileCoord tile, String template) async {
    if (memory.containsKey(tile.key)) return;
    final file = File('${directory.path}/${tile.z}_${tile.x}_${tile.y}.png');
    final expiry = File('${file.path}.expiry');
    Uint8List? bytes;
    if (file.existsSync() && expiry.existsSync()) {
      final until = int.tryParse(expiry.readAsStringSync().trim()) ?? 0;
      if (until > DateTime.now().millisecondsSinceEpoch) bytes = await file.readAsBytes();
    }
    var maxAge = const Duration(days: 7);
    if (bytes == null) {
      final client = _PassthroughOverrides().createHttpClient(null);
      try {
        final url = template.replaceAll('{z}', '${tile.z}').replaceAll('{x}', '${tile.x}').replaceAll('{y}', '${tile.y}');
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set(HttpHeaders.userAgentHeader, userAgent);
        final response = await request.close();
        if (response.statusCode != 200) {
          await response.drain<void>();
          _noteFetchFailure(tile);
          return;
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response) {
          builder.add(chunk);
        }
        bytes = builder.takeBytes();
        maxAge = _maxAge(response.headers.value(HttpHeaders.cacheControlHeader));
        await file.writeAsBytes(bytes, flush: true);
        await expiry.writeAsString('${DateTime.now().add(maxAge).millisecondsSinceEpoch}');
      } on Object {
        _noteFetchFailure(tile);
        return;
      } finally {
        client.close(force: true);
      }
    }
    if (bytes.length < 32) {
      _noteFetchFailure(tile);
      return;
    }
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    failedKeys.remove(tile.key);
    memory[tile.key] = frame.image;
  }

  void _noteFetchFailure(TileCoord tile) {
    failedKeys.add(tile.key);
    onFetchFailure?.call();
  }

  Duration _maxAge(String? header) {
    if (header == null) return const Duration(days: 7);
    final match = RegExp(r'max-age=(\d+)').firstMatch(header);
    final seconds = match == null ? null : int.tryParse(match.group(1)!);
    if (seconds == null || seconds <= 0) return const Duration(days: 7);
    return Duration(seconds: seconds);
  }
}

Future<void> warmSampleMap() async {
  final style = await OsmStyleSource.load();
  const points = [
    GeoPoint(31.2435, 121.4912),
    GeoPoint(31.2408, 121.5012),
    GeoPoint(31.2273, 121.4924),
    GeoPoint(31.2357, 121.4810),
    GeoPoint(31.2335, 121.4888),
  ];
  const focus = GeoPoint(31.2408, 121.5012);
  const sizes = <ui.Size>[
    ui.Size(390, 240),
    ui.Size(390, 260),
    ui.Size(390, 300),
    ui.Size(400, 240),
    ui.Size(560, 260),
    ui.Size(700, 900),
    ui.Size(943, 260),
    ui.Size(943, 1000),
    ui.Size(1114, 260),
    ui.Size(470, 1100),
  ];
  final tiles = <String, TileCoord>{};
  for (final size in sizes) {
    for (final tile in chooseCamera(points, size).tiles) {
      tiles[tile.key] = tile;
    }
    for (final tile in chooseCamera(points, size, focus: focus).tiles) {
      tiles[tile.key] = tile;
    }
  }
  await OsmTileStore.instance.load(tiles.values.toList(), style.template);
}
