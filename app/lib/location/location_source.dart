import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:walk_core/walk_core.dart';

/// 遛狗时的位置来源。真机用 GPS,网页 / 演示用模拟轨迹。
abstract class LocationSource {
  /// 开始推送位置点。权限被拒或不可用时抛 [LocationUnavailable]。
  Future<Stream<GeoPoint>> start();
  Future<void> stop();
  String get label;
}

class LocationUnavailable implements Exception {
  LocationUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

class GpsLocationSource implements LocationSource {
  StreamSubscription<Position>? _sub;
  StreamController<GeoPoint>? _out;

  @override
  String get label => 'GPS';

  @override
  Future<Stream<GeoPoint>> start() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationUnavailable('手机定位服务没开');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw LocationUnavailable('没有定位权限');
    }

    final settings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
          // 锁屏后继续记录,系统通知栏会显示“正在遛狗”
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: '正在遛狗',
            notificationText: '遛狗健康正在记录路线',
            enableWakeLock: true,
          ),
        ),
      TargetPlatform.iOS => AppleSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
          activityType: ActivityType.fitness,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
          pauseLocationUpdatesAutomatically: false,
        ),
      _ => const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
    };

    _out = StreamController<GeoPoint>();
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) => _out?.add(GeoPoint(p.latitude, p.longitude,
          accuracyM: p.accuracy, time: p.timestamp)),
      onError: (Object e) => _out?.addError(e),
    );
    return _out!.stream;
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    unawaited(_out?.close());
    _sub = null;
    _out = null;
  }
}

/// 沿着一条绕圈的路线按固定速度走,用于网页演示和没有 GPS 的情况。
class SimulatedLocationSource implements LocationSource {
  SimulatedLocationSource({
    this.centerLat = 40.7812,
    this.centerLng = -73.9665,
    this.speedMps = 1.3,
    this.tick = const Duration(seconds: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final double centerLat;
  final double centerLng;
  final double speedMps;
  final Duration tick;
  final DateTime Function() _clock;

  Timer? _timer;
  StreamController<GeoPoint>? _out;
  double _travelledM = 0;
  late DateTime _virtualNow;

  @override
  String get label => '模拟';

  /// 一圈约 1.1 km 的不规则环线(半径随角度变化,看起来像街区散步)。
  GeoPoint _pointAt(double metres, DateTime time) {
    final loopM = _loopPerimeterM(1);
    final theta = 2 * math.pi * (metres % loopM) / loopM;
    final r = 160 + 40 * math.sin(3 * theta);
    final dLat = r * math.cos(theta) / 111320;
    final dLng = r * math.sin(theta) / (111320 * math.cos(centerLat * math.pi / 180));
    return GeoPoint(centerLat + dLat, centerLng + dLng, accuracyM: 5, time: time);
  }

  @override
  Future<Stream<GeoPoint>> start() async {
    _out = StreamController<GeoPoint>();
    _travelledM = 0;
    _virtualNow = _clock();
    _out!.add(_pointAt(0, _virtualNow));
    _timer = Timer.periodic(tick, (_) => _advance(tick));
    return _out!.stream;
  }

  /// 往前走 [d] 的路程,每 10 米发一个点,保证轨迹平滑且不会被当成跳点。
  void _advance(Duration d) {
    final metres = speedMps * d.inMilliseconds / 1000;
    final steps = math.max(1, (metres / 10).ceil());
    final from = _virtualNow;
    for (var i = 1; i <= steps; i++) {
      _travelledM += metres / steps;
      _out?.add(_pointAt(_travelledM, from.add(d * (i / steps))));
    }
    _virtualNow = from.add(d);
  }

  /// 演示用:立刻走完一段时间的路程。
  void fastForward(Duration d) => _advance(d);

  @override
  Future<void> stop() async {
    _timer?.cancel();
    unawaited(_out?.close());
    _timer = null;
    _out = null;
  }
}

/// 环线 r(θ) = (160 + 40·sin 3θ)·scale 的实际周长(米),
/// 让“走过的米数”和轨迹长度一致。
double _loopPerimeterM(double scale) {
  const n = 720;
  var total = 0.0;
  double x(double t) => (160 + 40 * math.sin(3 * t)) * scale * math.cos(t);
  double y(double t) => (160 + 40 * math.sin(3 * t)) * scale * math.sin(t);
  for (var i = 0; i < n; i++) {
    final a = 2 * math.pi * i / n, b = 2 * math.pi * (i + 1) / n;
    total += math.sqrt(math.pow(x(b) - x(a), 2) + math.pow(y(b) - y(a), 2));
  }
  return total;
}

/// 生成一条完整的模拟轨迹(示例数据用)。[radiusScale] 让不同的路线大小不一样。
List<GeoPoint> simulatedTrack({
  required DateTime start,
  required double distanceKm,
  required Duration duration,
  double centerLat = 40.7812,
  double centerLng = -73.9665,
  double radiusScale = 1.0,
  double phase = 0,
}) {
  final n = math.max(2, (distanceKm * 100).round()); // 每 10 米一个点
  final loopM = _loopPerimeterM(radiusScale);
  return [
    for (var i = 0; i <= n; i++)
      () {
        final m = distanceKm * 1000 * i / n;
        final theta = phase + 2 * math.pi * m / loopM;
        final r = (160 + 40 * math.sin(3 * theta)) * radiusScale;
        return GeoPoint(
          centerLat + r * math.cos(theta) / 111320,
          centerLng + r * math.sin(theta) / (111320 * math.cos(centerLat * math.pi / 180)),
          accuracyM: 5,
          time: start.add(duration * (i / n)),
        );
      }(),
  ];
}
