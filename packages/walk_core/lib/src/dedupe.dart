import 'models.dart';

/// 两段时间的重叠占较短一段的比例(0–1)。
double overlapRatio(DogWalkResult a, DogWalkResult b) {
  final start = a.start.isAfter(b.start) ? a.start : b.start;
  final end = a.end.isBefore(b.end) ? a.end : b.end;
  final overlap = end.difference(start);
  if (overlap <= Duration.zero) return 0;
  final shorter = a.duration < b.duration ? a.duration : b.duration;
  if (shorter <= Duration.zero) return 0;
  return overlap.inMilliseconds / shorter.inMilliseconds;
}

/// 同一只狗、不同成员的记录时间重叠超过 [threshold] 时视为同一次遛狗,
/// 只保留距离较长的一条,其余标记为 deduped。
List<DogWalkResult> dedupe(List<DogWalkResult> results, {double threshold = 0.5}) {
  final out = [...results];
  for (var i = 0; i < out.length; i++) {
    for (var j = i + 1; j < out.length; j++) {
      final a = out[i], b = out[j];
      if (a.dogId != b.dogId || a.memberId == b.memberId) continue;
      if (a.deduped || b.deduped) continue;
      if (overlapRatio(a, b) <= threshold) continue;
      if (a.distanceKm >= b.distanceKm) {
        out[j] = b.copyWith(deduped: true);
      } else {
        out[i] = a.copyWith(deduped: true);
      }
    }
  }
  return out;
}
