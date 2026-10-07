import 'package:doghealthwalk/main.dart';
import 'package:doghealthwalk/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('今天页显示示例狗狗,重叠记录只算一次', (tester) async {
    final state = AppState(clock: () => DateTime(2026, 10, 7, 12));
    await tester.pumpWidget(DogHealthWalkApp(state: state));
    expect(find.text('小白'), findsOneWidget);
    expect(find.text('大熊'), findsOneWidget);
    // 小白:家人 2.1 km 与我 1.9 km 重叠,只计 2.1 km
    expect(find.text('2.10 km'), findsOneWidget);
    // 大熊:我早上 1.0 km + 家人 2.1 km
    expect(find.text('3.10 km'), findsOneWidget);
  });

  testWidgets('一次遛两只狗,结束后今天的总量增加', (tester) async {
    final state = AppState(clock: () => DateTime(2026, 10, 7, 12));
    await tester.pumpWidget(DogHealthWalkApp(state: state));
    await tester.tap(find.text('遛狗'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('小白'));
    await tester.tap(find.text('大熊'));
    await tester.pump();
    await tester.tap(find.text('我开始遛狗'));
    await tester.pump();
    await tester.tap(find.text('快进 10 分钟(演示)'));
    await tester.pump();
    await tester.tap(find.text('结束遛狗'));
    await tester.pump();
    expect(state.results.where((r) => r.memberId == 'me' && r.walkId.startsWith('walk')), hasLength(2));
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    // 各加 0.78 km
    expect(find.text('2.88 km'), findsOneWidget);
    expect(find.text('3.88 km'), findsOneWidget);
  });
}
