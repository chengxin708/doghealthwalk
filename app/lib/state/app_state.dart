import 'dart:async';

import 'package:flutter/material.dart';
import 'package:walk_core/walk_core.dart';

class Member {
  const Member(this.id, this.name, this.color);
  final String id;
  final String name;
  final Color color;
}

/// 正在进行的遛狗。原型阶段用模拟速度累计距离,下一步换成 GPS 轨迹。
class ActiveWalk {
  ActiveWalk(this.id, this.memberId, this.dogIds, this.start);
  final String id;
  final String memberId;
  final List<String> dogIds;
  final DateTime start;
  double distanceKm = 0;
}

/// 原型阶段的内存数据。接入 Supabase 后由它同步给全家。
class AppState extends ChangeNotifier {
  AppState({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _seedDemo();
  }

  final DateTime Function() _clock;

  final members = const [
    Member('me', '我', Color(0xFF2E7D6B)),
    Member('partner', '家人', Color(0xFFD9822B)),
  ];
  String currentMemberId = 'me';

  final List<Dog> dogs = [];
  final List<DogWalkResult> results = [];
  final Map<String, Activity> activityByDog = {};

  ActiveWalk? active;
  Timer? _ticker;
  int _seq = 0;

  /// 模拟步行速度(m/s),约 4.7 km/h。
  static const simulatedSpeedMps = 1.3;

  Member member(String id) => members.firstWhere((m) => m.id == id);
  Dog dog(String id) => dogs.firstWhere((d) => d.id == id);

  void switchMember(String id) {
    currentMemberId = id;
    notifyListeners();
  }

  void addDog({required String name, required double weightKg, double? strideM}) {
    dogs.add(Dog(id: 'dog${++_seq}', name: name, weightKg: weightKg, strideM: strideM));
    notifyListeners();
  }

  void updateDog(Dog updated) {
    final i = dogs.indexWhere((d) => d.id == updated.id);
    if (i >= 0) dogs[i] = updated;
    notifyListeners();
  }

  void setActivity(String dogId, Activity a) {
    activityByDog[dogId] = a;
    notifyListeners();
  }

  void startWalk(List<String> dogIds) {
    if (active != null || dogIds.isEmpty) return;
    active = ActiveWalk('walk${++_seq}', currentMemberId, dogIds, _clock());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      active!.distanceKm += simulatedSpeedMps / 1000;
      notifyListeners();
    });
    notifyListeners();
  }

  /// 原型用:一键快进 10 分钟。
  void fastForward(Duration d) {
    final a = active;
    if (a == null) return;
    a.distanceKm += simulatedSpeedMps * d.inSeconds / 1000;
    _offset += d;
    notifyListeners();
  }

  Duration _offset = Duration.zero;

  Duration get activeElapsed =>
      active == null ? Duration.zero : _clock().difference(active!.start) + _offset;

  void finishWalk() {
    final a = active;
    if (a == null) return;
    _ticker?.cancel();
    results.addAll(resultsForWalk(
      walkId: a.id,
      memberId: a.memberId,
      start: a.start,
      end: a.start.add(activeElapsed),
      distanceKm: a.distanceKm,
      dogs: [for (final id in a.dogIds) dog(id)],
      activityByDog: activityByDog,
    ));
    active = null;
    _offset = Duration.zero;
    notifyListeners();
  }

  void cancelWalk() {
    _ticker?.cancel();
    active = null;
    _offset = Duration.zero;
    notifyListeners();
  }

  /// 去重后的全部记录(地图和历史用,被去重的仍显示)。
  List<DogWalkResult> get deduped => dedupe(results);

  List<DailyDogSummary> get today {
    final now = _clock();
    return dailySummaries(results)
        .where((s) => s.day == DateTime(now.year, now.month, now.day))
        .toList();
  }

  void _seedDemo() {
    addDog(name: '小白', weightKg: 5);
    addDog(name: '大熊', weightKg: 32);
    final now = _clock();
    final morning = DateTime(now.year, now.month, now.day, 7, 30);
    // 早上家人带两只狗遛了 30 分钟
    results.addAll(resultsForWalk(
      walkId: 'seed1', memberId: 'partner', start: morning,
      end: morning.add(const Duration(minutes: 30)), distanceKm: 2.1,
      dogs: dogs.toList(),
    ));
    // 更早我单独带大熊跑了一圈,演示两人数据合并
    final early = DateTime(now.year, now.month, now.day, 6, 45);
    results.addAll(resultsForWalk(
      walkId: 'seed0', memberId: 'me', start: early,
      end: early.add(const Duration(minutes: 15)), distanceKm: 1.0,
      dogs: [dogs.last], activityByDog: {dogs.last.id: Activity.wild},
    ));
    // 同一时间我也开了 App,带着小白,会被自动去重
    results.addAll(resultsForWalk(
      walkId: 'seed2', memberId: 'me', start: morning.add(const Duration(minutes: 1)),
      end: morning.add(const Duration(minutes: 29)), distanceKm: 1.9,
      dogs: [dogs.first],
    ));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
