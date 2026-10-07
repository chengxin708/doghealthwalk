import 'dart:async';

import 'package:doghealthwalk/location/sources.dart';
import 'package:doghealthwalk/main.dart';
import 'package:doghealthwalk/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walk_core/walk_core.dart';

/// 可控的定位来源:测试里手动推点、决定权限结果。
class FakeLocation extends LocationSource {
  FakeLocation([this.status = GpsStatus.ok]);
  GpsStatus status;
  Completer<void>? gate;
  final ctrl = StreamController<GeoPoint>.broadcast();
  int requests = 0;

  @override
  Future<GpsStatus> requestAccess() async {
    requests++;
    await gate?.future;
    return status;
  }

  @override
  Stream<GeoPoint> watch() => ctrl.stream;
}

class FakeSteps extends StepSource {
  FakeSteps({this.granted = true});
  final bool granted;
  final ctrl = StreamController<int>.broadcast();

  @override
  Future<bool> requestAccess() async => granted;

  @override
  Stream<int> watch() => ctrl.stream;
}

void main() {
  final now = DateTime(2026, 10, 7, 12);
  DateTime at(int secs) => now.add(Duration(seconds: secs));
  // 纬度 0.001° ≈ 111 米
  GeoPoint pt(double dLat, int secs, {double acc = 5}) =>
      GeoPoint(31 + dLat, 121, accuracyM: acc, time: at(secs));

  test('GPS 点累计成距离,结束后存下轨迹', () async {
    final loc = FakeLocation();
    final state = AppState(clock: () => now, location: loc);
    await state.startWalk([state.dogs.first.id]);
    final a = state.active!;
    expect(a.gps, GpsStatus.ok);

    loc.ctrl
      ..add(pt(0, 0))
      ..add(pt(0.001, 90))
      ..add(pt(0.05, 95)) // 跳点
      ..add(pt(0.002, 180));
    await pumpEventQueue();
    expect(a.distanceKm, closeTo(0.222, 0.005));
    expect(a.source, DistanceSource.gps);
    expect(a.points, hasLength(3));

    state.finishWalk();
    expect(state.tracks[a.id], hasLength(3));
    expect(state.results.last.distanceKm, closeTo(0.222, 0.005));
    expect(loc.ctrl.hasListener, isFalse);
  });

  test('丢掉系统缓存的旧位置', () async {
    final loc = FakeLocation();
    final state = AppState(clock: () => now, location: loc);
    await state.startWalk([state.dogs.first.id]);
    loc.ctrl
      ..add(pt(-0.01, -600)) // 10 分钟前的缓存点
      ..add(pt(0, 0))
      ..add(pt(0.001, 90));
    await pumpEventQueue();
    expect(state.active!.points, hasLength(2));
    expect(state.active!.distanceKm, closeTo(0.111, 0.005));
    state.cancelWalk();
  });

  test('没有定位权限时用步数兜底,授权后改回 GPS', () async {
    final loc = FakeLocation(GpsStatus.denied);
    final steps = FakeSteps();
    final state = AppState(clock: () => now, location: loc, steps: steps);
    await state.startWalk([state.dogs.first.id]);
    final a = state.active!;
    expect(a.gps, GpsStatus.denied);
    expect(a.stepsAvailable, isTrue);

    steps.ctrl
      ..add(50000) // 开机以来的累计步数,作为起点
      ..add(51000);
    await pumpEventQueue();
    expect(a.humanSteps, 1000);
    expect(a.source, DistanceSource.steps);
    expect(a.distanceKm, closeTo(0.7, 1e-9));

    loc.status = GpsStatus.ok;
    await state.retryGps();
    loc.ctrl
      ..add(pt(0, 0))
      ..add(pt(0.001, 90));
    await pumpEventQueue();
    expect(a.source, DistanceSource.gps);
    expect(a.distanceKm, closeTo(0.111, 0.005));
    state.cancelWalk();
    expect(steps.ctrl.hasListener, isFalse);
  });

  test('定位中断后标记为 lost,已走距离保留', () async {
    final loc = FakeLocation();
    final state = AppState(clock: () => now, location: loc);
    await state.startWalk([state.dogs.first.id]);
    loc.ctrl
      ..add(pt(0, 0))
      ..add(pt(0.001, 90))
      ..addError(Exception('location service disabled'));
    await pumpEventQueue();
    expect(state.active!.gps, GpsStatus.lost);
    expect(state.active!.distanceKm, closeTo(0.111, 0.005));
    state.cancelWalk();
  });

  test('等权限弹窗时放弃遛狗,不会再开始定位', () async {
    final loc = FakeLocation()..gate = Completer();
    final state = AppState(clock: () => now, location: loc);
    final starting = state.startWalk([state.dogs.first.id]);
    expect(state.active!.gps, GpsStatus.starting);
    state.cancelWalk();
    loc.gate!.complete();
    await starting;
    expect(state.active, isNull);
    expect(loc.ctrl.hasListener, isFalse);
  });

  testWidgets('权限被拒时遛狗页提示原因,点“重新授权”再申请', (tester) async {
    final loc = FakeLocation(GpsStatus.denied);
    final state = AppState(clock: () => now, location: loc);
    await tester.pumpWidget(DogHealthWalkApp(state: state));
    await tester.tap(find.text('遛狗'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('小白'));
    await tester.pump();
    await tester.tap(find.text('我开始遛狗'));
    await tester.pump();

    expect(find.text('没有定位权限'), findsOneWidget);
    expect(find.text('暂时记录不到距离,结束后只记时长'), findsOneWidget);
    expect(find.text('快进 10 分钟(演示)'), findsNothing);

    loc.status = GpsStatus.ok;
    await tester.tap(find.text('重新授权'));
    await tester.pump();
    expect(loc.requests, 2);
    expect(find.text('等待 GPS 信号…'), findsOneWidget);

    loc.ctrl.add(pt(0, 0, acc: 8));
    await tester.pump();
    expect(find.text('GPS 定位中'), findsOneWidget);
    expect(find.text('精度约 ±8 米'), findsOneWidget);

    await tester.tap(find.text('放弃这次'));
    await tester.pump();
  });
}
