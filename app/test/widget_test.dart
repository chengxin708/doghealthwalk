import 'package:doghealthwalk/main.dart';
import 'package:doghealthwalk/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppState demo() => AppState(clock: () => DateTime(2026, 10, 7, 12), preferSimulated: true);

  testWidgets('今天页显示示例狗狗,重叠记录只算一次', (tester) async {
    await tester.pumpWidget(DogHealthWalkApp(state: demo()));
    expect(find.text('小白'), findsOneWidget);
    expect(find.text('大熊'), findsOneWidget);
    // 小白:家人 2.1 km 与我 1.9 km 重叠,只计 2.1 km
    expect(find.text('2.10 km'), findsOneWidget);
    // 大熊:我早上 1.0 km + 家人 2.1 km
    expect(find.text('3.10 km'), findsOneWidget);
    expect(find.text('今天的足迹'), findsOneWidget);
  });

  testWidgets('模拟定位遛两只狗,距离来自轨迹,结束后保存路线', (tester) async {
    final state = demo();
    await tester.pumpWidget(DogHealthWalkApp(state: state));
    await tester.tap(find.text('遛狗'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('小白'));
    await tester.tap(find.text('大熊'));
    await tester.pump();
    await tester.tap(find.text('我开始遛狗'));
    await tester.pump();
    expect(state.active, isNotNull);
    await tester.ensureVisible(find.text('快进 10 分钟(演示)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('快进 10 分钟(演示)'));
    await tester.pump();
    expect(state.active!.distanceKm, closeTo(0.78, 0.02));
    await tester.ensureVisible(find.text('结束遛狗'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('结束遛狗'));
    await tester.pumpAndSettle();
    expect(state.active, isNull);

    final mine = state.results.where((r) => r.walkId.startsWith('walk')).toList();
    expect(mine, hasLength(2));
    expect(mine.first.distanceKm, closeTo(0.78, 0.02));
    expect(mine.first.duration, greaterThanOrEqualTo(const Duration(minutes: 10)));
    expect(state.tracks[mine.first.walkId], isNotEmpty);
  });
}
