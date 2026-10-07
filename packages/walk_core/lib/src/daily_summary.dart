import 'dedupe.dart';
import 'models.dart';

class MemberShare {
  MemberShare(this.memberId);
  final String memberId;
  double distanceKm = 0;
  int dogSteps = 0;
  double kcal = 0;
  Duration duration = Duration.zero;
}

class DailyDogSummary {
  DailyDogSummary(this.dogId, this.day);
  final String dogId;
  final DateTime day;
  double distanceKm = 0;
  int dogSteps = 0;
  double kcal = 0;
  Duration duration = Duration.zero;
  final Map<String, MemberShare> byMember = {};
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// 按天、按狗汇总(先去重),并拆分“谁遛了多少”。按开始时间的本地日期归天。
List<DailyDogSummary> dailySummaries(List<DogWalkResult> results) {
  final map = <(String, DateTime), DailyDogSummary>{};
  for (final r in dedupe(results)) {
    if (r.deduped) continue;
    final day = _day(r.start.toLocal());
    final s = map.putIfAbsent((r.dogId, day), () => DailyDogSummary(r.dogId, day));
    final m = s.byMember.putIfAbsent(r.memberId, () => MemberShare(r.memberId));
    s
      ..distanceKm += r.distanceKm
      ..dogSteps += r.dogSteps
      ..kcal += r.kcal
      ..duration += r.duration;
    m
      ..distanceKm += r.distanceKm
      ..dogSteps += r.dogSteps
      ..kcal += r.kcal
      ..duration += r.duration;
  }
  return map.values.toList()
    ..sort((a, b) => a.day.compareTo(b.day));
}
