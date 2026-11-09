import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../map/osm_tiles.dart';
import 'trip_controller.dart';

/// 연결 상태를 읽는 주입 지점. 테스트에서는 [FakeConnectivityPort]를 쓴다.
abstract class ConnectivityPort {
  Stream<bool> get online;

  Future<bool> checkOnline();
}

class ConnectivityPlusPort implements ConnectivityPort {
  ConnectivityPlusPort([Connectivity? plugin]) : _plugin = plugin ?? Connectivity();

  final Connectivity _plugin;

  static bool resultsOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  Stream<bool> get online => _plugin.onConnectivityChanged.map(resultsOnline);

  @override
  Future<bool> checkOnline() async => resultsOnline(await _plugin.checkConnectivity());
}

class FakeConnectivityPort implements ConnectivityPort {
  FakeConnectivityPort({bool online = true}) : _online = online;

  bool _online;
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get online => _controller.stream;

  @override
  Future<bool> checkOnline() async => _online;

  void setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    _controller.add(value);
  }

  @visibleForTesting
  void dispose() => _controller.close();
}

/// `connectivity_plus`와 타일 요청 실패를 묶어 [TripController.offline]을 갱신한다.
class TripConnectivity {
  TripConnectivity({required this.controller, required this.port});

  final TripController controller;
  final ConnectivityPort port;

  StreamSubscription<bool>? _sub;

  void start() {
    OsmTileStore.instance.onFetchFailure = _onFetchFailure;
    _sub = port.online.listen(_applyLink);
    port.checkOnline().then(_applyLink);
  }

  void dispose() {
    _sub?.cancel();
    if (identical(OsmTileStore.instance.onFetchFailure, _onFetchFailure)) {
      OsmTileStore.instance.onFetchFailure = null;
    }
  }

  void _applyLink(bool online) {
    controller.setOffline(!online);
  }

  void _onFetchFailure() {
    controller.setOffline(true);
  }
}
