import 'package:test/test.dart';
import 'package:walk_core/walk_core.dart';

void main() {
  final t0 = DateTime(2026, 10, 7, 8);
  const small = Dog(id: 'mochi', name: '小白', weightKg: 5);
  const big = Dog(id: 'bear', name: '大熊', weightKg: 40);

  group('距离', () {
    test('GPS 轨迹约 1.11 km(纬度 0.01°)', () {
      final pts = [
        for (var i = 0; i <= 10; i++)
          GeoPoint(40 + i * 0.001, -74, time: t0.add(Duration(seconds: 90 * i))),
      ];
      expect(trackDistanceKm(pts), closeTo(1.112, 0.01));
    });

    test('过滤精度差和跳点', () {
      final pts = [
        GeoPoint(40, -74, time: t0),
        GeoPoint(40.01, -74, time: t0.add(const Duration(seconds: 10))), // 跳点
        GeoPoint(40.0005, -74, accuracyM: 100, time: t0.add(const Duration(seconds: 20))),
        GeoPoint(40.001, -74, time: t0.add(const Duration(seconds: 90))),
      ];
      expect(trackDistanceKm(pts), closeTo(0.111, 0.005));
    });

    test('边走边算与整条轨迹结果一致,噪点不被采用', () {
      final pts = [
        GeoPoint(40, -74, time: t0),
        GeoPoint(40.0005, -74, time: t0.add(const Duration(seconds: 45))),
        GeoPoint(40.01, -74, time: t0.add(const Duration(seconds: 50))), // 跳点
        GeoPoint(40.0007, -74, accuracyM: 80, time: t0.add(const Duration(seconds: 60))),
        GeoPoint(40.001, -74, time: t0.add(const Duration(seconds: 90))),
      ];
      final acc = TrackAccumulator();
      expect(pts.map(acc.add), [true, true, false, false, true]);
      expect(acc.distanceKm, closeTo(trackDistanceKm(pts), 1e-12));
      expect(acc.distanceKm, closeTo(0.111, 0.005));
    });

    test('GPS 有距离时不用步数,GPS 为 0 时用步数', () {
      expect(pickDistanceKm(gpsKm: 0.5, humanSteps: 2000), 0.5);
      expect(pickDistanceKm(gpsKm: 0, humanSteps: 2000), closeTo(1.4, 1e-9));
      expect(pickDistanceKm(gpsKm: 0), 0);
    });

    test('没有 GPS 时用人的步数兜底', () {
      expect(walkDistanceKm(humanSteps: 2000, humanStrideM: 0.7), closeTo(1.4, 1e-9));
    });
  });

  group('狗步数与卡路里', () {
    test('小狗步数比大狗多', () {
      expect(dogSteps(small, 1, activity: Activity.calm), 2857);
      expect(dogSteps(big, 1, activity: Activity.calm), 1333);
    });

    test('校准步长优先', () {
      final s = calibrateStrideM(distanceM: 20, steps: 50);
      expect(s, 0.4);
      final d = Dog(id: 'x', name: 'x', weightKg: 5, strideM: s);
      expect(dogSteps(d, 1, activity: Activity.calm), 2500);
    });

    test('kcal/km 与方案中的粗算一致', () {
      expect(kcalPerKm(5), closeTo(8, 1));
      expect(kcalPerKm(20), closeTo(20, 1));
      expect(kcalPerKm(40), closeTo(32, 1.5));
    });

    test('一次遛多只狗,各自计算', () {
      final r = resultsForWalk(
        walkId: 'w1', memberId: 'A', start: t0,
        end: t0.add(const Duration(minutes: 30)), distanceKm: 2, dogs: [small, big],
      );
      expect(r.map((e) => e.dogId), ['mochi', 'bear']);
      expect(r[0].dogSteps, greaterThan(r[1].dogSteps));
      expect(r[1].kcal, greaterThan(r[0].kcal));
    });
  });

  group('家庭合并', () {
    DogWalkResult w(String id, String member, int startMin, int mins, double km) =>
        resultsForWalk(
          walkId: id, memberId: member, start: t0.add(Duration(minutes: startMin)),
          end: t0.add(Duration(minutes: startMin + mins)), distanceKm: km, dogs: [small],
        ).single;

    test('A 和 B 一起遛同一只狗只算一次', () {
      final out = dedupe([w('a', 'A', 0, 30, 2.0), w('b', 'B', 2, 30, 2.1)]);
      expect(out.where((e) => !e.deduped).single.walkId, 'b');
    });

    test('早上 A 遛、晚上 B 遛,合并成一天', () {
      final s = dailySummaries([w('a', 'A', 0, 30, 2.0), w('b', 'B', 600, 20, 1.0)]);
      expect(s, hasLength(1));
      expect(s.single.distanceKm, closeTo(3.0, 1e-9));
      expect(s.single.byMember.keys, unorderedEquals(['A', 'B']));
      expect(s.single.duration, const Duration(minutes: 50));
    });
  });
}
