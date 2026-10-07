import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:walk_core/walk_core.dart';

import '../location/location_source.dart';

class Member {
  const Member(this.id, this.name, this.color);
  final String id;
  final String name;
  final Color color;
}

/// 正在进行的遛狗:累积位置点,距离由 GPS 轨迹算出。
class ActiveWalk {
  ActiveWalk(this.id, this.memberId, this.dogIds, this.start, this.sourceLabel);
  final String id;
  final String memberId;
  final List<String> dogIds;
  final DateTime start;
  final String sourceLabel;
  final List<GeoPoint> track = [];

  double get distanceKm => track.length < 2 ? 0 : trackDistanceKm(track);

  DateTime get lastTime => track.isEmpty ? start : track.last.time;
}

/// 原型阶段的内存数据。接入 Supabase 后由它同步给全家。
class AppState extends ChangeNotifier {
  AppState({
    DateTime Function()? clock,
    LocationSource Function()? gpsFactory,
    bool? preferSimulated,
  })  : _clock = clock ?? DateTime.now,
        _gpsFactory = gpsFactory ?? GpsLocationSource.new,
        useSimulated = preferSimulated ?? kIsWeb {
    _seedDemo();
  }

  final DateTime Function() _clock;
  final LocationSource Function() _gpsFactory;

  /// 网页版默认用模拟轨迹;手机上可以在遛狗页切换,方便在室内演示。
  bool useSimulated;

  final members = const [
    Member('me', '我', Color(0xFF2E7D6B)),
    Member('partner', '家人', Color(0xFFD9822B)),
  ];
  String currentMemberId = 'me';

  final List<Dog> dogs = [];
  final List<DogWalkResult> results = [];
  final Map<String, List<GeoPoint>> tracks = {};
  final Map<String, Activity> activityByDog = {};

  ActiveWalk? active;
  String? locationError;
  LocationSource? _source;
  StreamSubscription<GeoPoint>? _sub;
  Timer? _ticker;
  int _seq = 0;

  Member member(String id) => members.firstWhere((m) => m.id == id);
  Dog dog(String id) => dogs.firstWhere((d) => d.id == id);

  void switchMember(String id) {
    currentMemberId = id;
    notifyListeners();
  }

  void setUseSimulated(bool v) {
    useSimulated = v;
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

  Future<void> startWalk(List<String> dogIds) async {
    if (active != null || dogIds.isEmpty) return;
    locationError = null;
    final source = useSimulated ? SimulatedLocationSource(clock: _clock) : _gpsFactory();
    final Stream<GeoPoint> stream;
    try {
      stream = await source.start();
    } on LocationUnavailable catch (e) {
      locationError = '$e,可以先用模拟模式试试';
      notifyListeners();
      return;
    }
    _source = source;
    final walk = ActiveWalk('walk${++_seq}', currentMemberId, dogIds, _clock(), source.label);
    active = walk;
    _sub = stream.listen((p) {
      walk.track.add(p);
      notifyListeners();
    }, onError: (Object e) {
      locationError = '定位出错:$e';
      notifyListeners();
    });
    // GPS 没有新点时也刷新计时
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    notifyListeners();
  }

  bool get canFastForward => _source is SimulatedLocationSource;

  /// 模拟模式下一键快进。
  void fastForward(Duration d) {
    final s = _source;
    if (s is SimulatedLocationSource) s.fastForward(d);
  }

  Duration get activeElapsed {
    final a = active;
    if (a == null) return Duration.zero;
    final real = _clock().difference(a.start);
    final byTrack = a.lastTime.difference(a.start);
    return real > byTrack ? real : byTrack;
  }

  /// 停止定位。不等待底层流关闭,结束按钮要立刻有反应。
  void _stopSource() {
    _ticker?.cancel();
    unawaited(_sub?.cancel());
    unawaited(_source?.stop());
    _ticker = null;
    _sub = null;
    _source = null;
  }

  void finishWalk() {
    final a = active;
    if (a == null) return;
    final end = a.start.add(activeElapsed);
    _stopSource();
    tracks[a.id] = List.unmodifiable(a.track);
    results.addAll(resultsForWalk(
      walkId: a.id,
      memberId: a.memberId,
      start: a.start,
      end: end,
      distanceKm: walkDistanceKm(track: a.track),
      dogs: [for (final id in a.dogIds) dog(id)],
      activityByDog: activityByDog,
    ));
    active = null;
    notifyListeners();
  }

  void cancelWalk() {
    _stopSource();
    active = null;
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

  /// 今天每次遛狗的路线(一次遛多只狗只画一条线;被去重的重复记录不画)。
  List<({String walkId, String memberId, List<GeoPoint> track})> get todayTracks {
    final now = _clock();
    final day = DateTime(now.year, now.month, now.day);
    final seen = <String>{};
    return [
      for (final r in deduped)
        if (!r.deduped &&
            DateTime(r.start.year, r.start.month, r.start.day) == day &&
            tracks.containsKey(r.walkId) &&
            seen.add(r.walkId))
          (walkId: r.walkId, memberId: r.memberId, track: tracks[r.walkId]!),
    ];
  }

  void _seed(String walkId, String memberId, DateTime start, Duration dur, double km,
      List<Dog> walkDogs, {double scale = 1, double phase = 0, Map<String, Activity> act = const {}}) {
    tracks[walkId] = simulatedTrack(
        start: start, distanceKm: km, duration: dur, radiusScale: scale, phase: phase);
    results.addAll(resultsForWalk(
      walkId: walkId, memberId: memberId, start: start, end: start.add(dur),
      distanceKm: km, dogs: walkDogs, activityByDog: act,
    ));
  }

  void _seedDemo() {
    addDog(name: '小白', weightKg: 5);
    addDog(name: '大熊', weightKg: 32);
    final now = _clock();
    final early = DateTime(now.year, now.month, now.day, 6, 45);
    final morning = DateTime(now.year, now.month, now.day, 7, 30);
    // 更早我单独带大熊跑了一圈,演示两人数据合并
    _seed('seed0', 'me', early, const Duration(minutes: 15), 1.0, [dogs.last],
        scale: 0.6, phase: 1.5, act: {dogs.last.id: Activity.wild});
    // 早上家人带两只狗遛了 30 分钟
    _seed('seed1', 'partner', morning, const Duration(minutes: 30), 2.1, dogs.toList(),
        scale: 1.4);
    // 同一时间我也开了 App,带着小白,会被自动去重
    _seed('seed2', 'me', morning.add(const Duration(minutes: 1)),
        const Duration(minutes: 28), 1.9, [dogs.first], scale: 1.35, phase: 0.1);
  }

  @override
  void dispose() {
    _stopSource();
    super.dispose();
  }
}
