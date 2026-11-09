import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../map/osm_tiles.dart';
import '../model/models.dart';
import 'city_lookup.dart';

/// City location lookup. Production uses Nominatim with an offline sample fallback.
abstract class CityGeocoder {
  Future<List<GeoCandidate>> search(String query, {String? countryCode});
}

/// Bundled 상하이·충밍 sample used when offline or the network fails.
class OfflineSampleGeocoder implements CityGeocoder {
  @override
  Future<List<GeoCandidate>> search(String query, {String? countryCode}) async {
    return offlineCandidatesForCity(query);
  }
}

class NominatimGeocoder implements CityGeocoder {
  NominatimGeocoder({HttpClient Function()? clientFactory, this.minInterval = const Duration(seconds: 1)})
    : _clientFactory = clientFactory ?? (() => HttpClient());

  final HttpClient Function() _clientFactory;
  final Duration minInterval;
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  static const _endpoint = 'nominatim.openstreetmap.org';

  Future<void> _throttle() async {
    final wait = minInterval - DateTime.now().difference(_lastRequest);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    _lastRequest = DateTime.now();
  }

  @override
  Future<List<GeoCandidate>> search(String query, {String? countryCode}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    await _throttle();
    final params = <String, String>{'q': trimmed, 'format': 'jsonv2', 'limit': '8'};
    final code = countryCode?.trim().toUpperCase();
    if (code != null && code.length == 2) params['countrycodes'] = code.toLowerCase();
    final uri = Uri.https(_endpoint, '/search', params);
    final client = _clientFactory();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, OsmTileStore.userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('Nominatim ${response.statusCode}');
      }
      final decoded = jsonDecode(body);
      if (decoded is! List) return const [];
      final results = <GeoCandidate>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final id = item['place_id'];
        final lat = double.tryParse('${item['lat']}');
        final lon = double.tryParse('${item['lon']}');
        if (lat == null || lon == null) continue;
        final label = _shortLabel('${item['display_name'] ?? trimmed}');
        final address = item['address'];
        String? countryCode;
        String? cityName;
        if (address is Map) {
          final raw = address['country_code'];
          if (raw != null && '$raw'.length == 2) countryCode = '$raw'.toUpperCase();
          cityName = _pickCityName(address, '${item['name'] ?? ''}'.trim());
        }
        results.add(
          GeoCandidate(
            id: 'osm-$id',
            label: label,
            coordinateLabel: _coordLabel(lat, lon),
            sourceName: 'OpenStreetMap Nominatim',
            cityName: cityName?.isEmpty == true ? null : cityName,
            countryCode: countryCode,
          ),
        );
      }
      return results;
    } finally {
      client.close(force: true);
    }
  }

  String _shortLabel(String full) {
    final parts = full.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    if (parts.length <= 3) return full;
    return parts.take(3).join(', ');
  }

  String _pickCityName(Map address, String fallback) {
    for (final key in const ['city', 'town', 'village', 'municipality', 'county', 'state_district']) {
      final value = address[key];
      if (value != null && '$value'.trim().isNotEmpty) return '$value'.trim();
    }
    return fallback;
  }
}

class CompositeCityGeocoder implements CityGeocoder {
  CompositeCityGeocoder({CityGeocoder? online, CityGeocoder? offline})
    : _online = online ?? NominatimGeocoder(),
      _offline = offline ?? OfflineSampleGeocoder();

  final CityGeocoder _online;
  final CityGeocoder _offline;

  @override
  Future<List<GeoCandidate>> search(String query, {String? countryCode}) async {
    final sample = await _offline.search(query, countryCode: countryCode);
    try {
      final remote = await _online.search(query, countryCode: countryCode);
      return _merge(remote, sample);
    } catch (_) {
      return sample;
    }
  }

  List<GeoCandidate> _merge(List<GeoCandidate> primary, List<GeoCandidate> extra) {
    final seen = <String>{};
    final merged = <GeoCandidate>[];
    for (final candidate in [...primary, ...extra]) {
      final key = candidate.coordinateLabel;
      if (seen.add(key)) merged.add(candidate);
    }
    return merged;
  }
}

String _coordLabel(double lat, double lon) => '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
