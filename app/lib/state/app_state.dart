import 'dart:async';

import 'package:flutter/material.dart';
import 'package:walk_core/walk_core.dart';

import '../location/sources.dart';

class Member {
  const Member(this.id, this.name, this.color);
  final String id;
  final String name;
  final Color color;
}

/// 距离来自哪里,遛狗页据此提示。
enum DistanceSource { gps, steps, none }

/// 正在进行的遛狗。
class ActiveWalk {
  ActiveWalk(this.id, this.memberId, this.dogIds, this.start);
  final String id;
  final String memberId;
  final List<String> dogIds;
  final DateTime start;

  final track = TrackAccumulator();

  /// 被采用的轨迹点,结束后存进 [AppState.tracks] 给足迹地图用。
  final points = <GeoPoint>[];

  GpsStatus gps = GpsStatus.starting;

  /// 最近一个定位点的精度(米)。
  double? accuracyM;

  /// 计步器是否可用;null 表示还在申请或本平台没有计步器。
  bool? stepsAvailable;
  int? _stepBase;

  /// 这次遛狗中人走的步数(计步器读数减去起点)。
  int? humanSteps;

  double get distanceKm => pickDistanceKm(gpsKm: track.distanceKm, humanSteps: humanSteps);

  DistanceSource get source => track.distanceKm > 0
      ? DistanceSource.gps
      : humanSteps != null
          ? DistanceSource.steps
          : DistanceSource.none;
}

/// 原型阶段的内存数据。接入 Supabase 后由它同步给全家。
class AppState extends ChangeNotifier {
  /// [location] 默认用模拟位置;真机由 main.dart 传入 GPS 和计步器。
  AppState({DateTime Function()? clock, LocationSource? location, this.steps})
      : _clock = clock ?? DateTime.now,
        location = location ?? SimulatedLocation(clock: clock) {
    _seedDemo();
  }

  final DateTime Function() _clock;
  final LocationSource location;
  final StepSource? steps;

  final members = const [
    Member('me', '我', Color(0xFF2E7D6B)),
    Member('partner', '家人', Color(0xFFD9822B)),
  ];
  String currentMemberId = 'me';

  final List<Dog> dogs = [];
  final List<DogWalkResult> results = [];
  final Map<String, Activity> activityByDog = {};

  /// 每次遛狗的轨迹点,按 walkId 存。
  final Map<String, List<GeoPoint>> tracks = {};

  ActiveWalk? active;
  Timer? _ticker;
  StreamSubscription<GeoPoint>? _gpsSub;
  StreamSubscription<int>? _stepSub;
  int _seq = 0;

  /// 比开始时间早这么多的定位点视为系统缓存的旧位置,丢掉。
  static const _staleFix = Duration(seconds: 30);

  bool get isSimulated => location is SimulatedLocation;

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

  /// 立即开始计时,同时申请定位和计步权限;拒绝了也照样能遛,只是距离改用步数估算。
  Future<void> startWalk(List<String> dogIds) async {
    if (active != null || dogIds.isEmpty) return;
    final a = ActiveWalk('walk${++_seq}', currentMemberId, dogIds, _clock());
    active = a;
    // 每秒刷新一次计时
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    notifyListeners();
    await _startGps(a);
    await _startSteps(a);
  }

  /// 权限被拒或定位关闭后,用户点“重试”。
  Future<void> retryGps() async {
    final a = active;
    // starting 表示上一次申请还没回来,避免重复订阅
    if (a == null || a.gps == GpsStatus.ok || a.gps == GpsStatus.starting) return;
    a.gps = GpsStatus.starting;
    notifyListeners();
    await _startGps(a);
  }

  Future<void> _startGps(ActiveWalk a) async {
    final status = await location.requestAccess();
    if (active != a) return; // 等权限期间已经结束或放弃
    a.gps = status;
    notifyListeners();
    if (status != GpsStatus.ok) return;
    _gpsSub?.cancel();
    _gpsSub = location.watch().listen(
      (p) => _onPoint(a, p),
      onError: (Object _) {
        a.gps = GpsStatus.lost;
        notifyListeners();
      },
    );
  }

  void _onPoint(ActiveWalk a, GeoPoint p) {
    if (active != a || p.time.isBefore(a.start.subtract(_staleFix))) return;
    a
      ..gps = GpsStatus.ok
      ..accuracyM = p.accuracyM;
    if (a.track.add(p)) a.points.add(p);
    notifyListeners();
  }

  Future<void> _startSteps(ActiveWalk a) async {
    final src = steps;
    if (src == null) return;
    final ok = await src.requestAccess();
    if (active != a) return;
    a.stepsAvailable = ok;
    notifyListeners();
    if (!ok) return;
    _stepSub = src.watch().listen(
      (total) {
        if (active != a) return;
        final base = a._stepBase ??= total;
        a.humanSteps = total - base;
        notifyListeners();
      },
      onError: (Object _) {
        a.stepsAvailable = false;
        notifyListeners();
      },
    );
  }

  /// 原型用:模拟定位下一键快进。
  void fastForward(Duration d) {
    final loc = location;
    if (active == null || loc is! SimulatedLocation) return;
    _offset += d;
    loc.fastForward(d);
    notifyListeners();
  }

  Duration _offset = Duration.zero;

  Duration get activeElapsed =>
      active == null ? Duration.zero : _clock().difference(active!.start) + _offset;

  void finishWalk() {
    final a = active;
    if (a == null) return;
    final end = a.start.add(activeElapsed);
    _endWalk();
    tracks[a.id] = List.unmodifiable(a.points);
    results.addAll(resultsForWalk(
      walkId: a.id,
      memberId: a.memberId,
      start: a.start,
      end: end,
      distanceKm: a.distanceKm,
      dogs: [for (final id in a.dogIds) dog(id)],
      activityByDog: activityByDog,
    ));
    notifyListeners();
  }

  void cancelWalk() {
    _endWalk();
    notifyListeners();
  }

  void _endWalk() {
    _ticker?.cancel();
    _gpsSub?.cancel();
    _stepSub?.cancel();
    _ticker = null;
    _gpsSub = null;
    _stepSub = null;
    active = null;
    _offset = Duration.zero;
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
    _endWalk();
    super.dispose();
  }
}
