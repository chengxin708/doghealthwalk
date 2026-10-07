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

/// GPS 轨迹长度(公里)。丢掉精度差于 [maxAccuracyM] 的点,
/// 以及隐含速度超过 [maxSpeedMps] 的跳点(人遛狗不会超过约 3 m/s)。
double trackDistanceKm(
  List<GeoPoint> points, {
  double maxAccuracyM = 30,
  double maxSpeedMps = 3.5,
}) {
  final good = points.where((p) => p.accuracyM <= maxAccuracyM).toList();
  var total = 0.0;
  GeoPoint? prev;
  for (final p in good) {
    if (prev != null) {
      final d = haversineM(prev, p);
      final secs = p.time.difference(prev.time).inMilliseconds / 1000;
      if (secs > 0 && d / secs > maxSpeedMps) continue; // 跳点,跳过但保留 prev
      total += d;
    }
    prev = p;
  }
  return total / 1000;
}

/// 没有 GPS 时的兜底:人的步数 × 人的步长。
double distanceFromHumanStepsKm(int humanSteps, {double humanStrideM = 0.7}) =>
    humanSteps * humanStrideM / 1000;

/// 优先用 GPS;GPS 轨迹太短(少于 2 个有效点或 0 距离)时用步数兜底。
double walkDistanceKm({
  List<GeoPoint> track = const [],
  int? humanSteps,
  double humanStrideM = 0.7,
}) {
  final gps = track.length >= 2 ? trackDistanceKm(track) : 0.0;
  if (gps > 0) return gps;
  if (humanSteps != null) {
    return distanceFromHumanStepsKm(humanSteps, humanStrideM: humanStrideM);
  }
  return 0;
}
