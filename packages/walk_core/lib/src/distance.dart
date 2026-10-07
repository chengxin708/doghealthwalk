import 'dart:math' as math;

import 'models.dart';

const _earthRadiusM = 6371000.0;

/// 两点间大圆距离(米)。
double haversineM(GeoPoint a, GeoPoint b) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.sqrt(h));
}

/// 边走边算的 GPS 轨迹长度。丢掉精度差于 [maxAccuracyM] 的点,
/// 以及隐含速度超过 [maxSpeedMps] 的跳点(人遛狗不会超过约 3 m/s)。
class TrackAccumulator {
  TrackAccumulator({this.maxAccuracyM = 30, this.maxSpeedMps = 3.5});

  final double maxAccuracyM;
  final double maxSpeedMps;

  double _totalM = 0;
  GeoPoint? _prev;

  double get distanceKm => _totalM / 1000;

  /// 加入一个点,返回它是否被采用(没被当成噪点丢掉)。
  bool add(GeoPoint p) {
    if (p.accuracyM > maxAccuracyM) return false;
    final prev = _prev;
    if (prev != null) {
      final d = haversineM(prev, p);
      final secs = p.time.difference(prev.time).inMilliseconds / 1000;
      if (secs > 0 && d / secs > maxSpeedMps) return false; // 跳点,跳过但保留 prev
      _totalM += d;
    }
    _prev = p;
    return true;
  }
}

/// 整条 GPS 轨迹的长度(公里),过滤规则见 [TrackAccumulator]。
double trackDistanceKm(
  List<GeoPoint> points, {
  double maxAccuracyM = 30,
  double maxSpeedMps = 3.5,
}) {
  final acc = TrackAccumulator(maxAccuracyM: maxAccuracyM, maxSpeedMps: maxSpeedMps);
  points.forEach(acc.add);
  return acc.distanceKm;
}

/// 没有 GPS 时的兜底:人的步数 × 人的步长。
double distanceFromHumanStepsKm(int humanSteps, {double humanStrideM = 0.7}) =>
    humanSteps * humanStrideM / 1000;

/// 优先用 GPS 距离;GPS 为 0(没权限、没信号)时用人的步数兜底。
double pickDistanceKm({
  required double gpsKm,
  int? humanSteps,
  double humanStrideM = 0.7,
}) {
  if (gpsKm > 0) return gpsKm;
  if (humanSteps != null) {
    return distanceFromHumanStepsKm(humanSteps, humanStrideM: humanStrideM);
  }
  return 0;
}

/// 优先用 GPS;GPS 轨迹太短(少于 2 个有效点或 0 距离)时用步数兜底。
double walkDistanceKm({
  List<GeoPoint> track = const [],
  int? humanSteps,
  double humanStrideM = 0.7,
}) =>
    pickDistanceKm(
      gpsKm: track.length >= 2 ? trackDistanceKm(track) : 0,
      humanSteps: humanSteps,
      humanStrideM: humanStrideM,
    );
