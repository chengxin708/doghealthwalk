import 'package:flutter/material.dart';

import 'screens/dogs_screen.dart';
import 'screens/history_screen.dart';
import 'screens/today_screen.dart';
import 'screens/walk_screen.dart';
import 'state/app_state.dart';

void main() => runApp(DogHealthWalkApp(state: AppState()));

class DogHealthWalkApp extends StatelessWidget {
  const DogHealthWalkApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '遛狗健康',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D6B),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D6B),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomeShell(state: state),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});
  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final pages = [
          TodayScreen(state: s),
          WalkScreen(state: s),
          HistoryScreen(state: s),
          DogsScreen(state: s),
        ];
        return Scaffold(
          appBar: AppBar(
            title: const Text('遛狗健康'),
            actions: [
              // 原型用:切换“我/家人”,演示两人数据合并
              SegmentedButton<String>(
                segments: [
                  for (final m in s.members)
                    ButtonSegment(value: m.id, label: Text(m.name)),
                ],
                selected: {s.currentMemberId},
                onSelectionChanged: (v) => s.switchMember(v.first),
                showSelectedIcon: false,
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: pages[_tab],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.today), label: '今天'),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: s.active != null,
                  child: const Icon(Icons.directions_walk),
                ),
                label: '遛狗',
              ),
              const NavigationDestination(icon: Icon(Icons.history), label: '记录'),
              const NavigationDestination(icon: Icon(Icons.pets), label: '狗狗'),
            ],
          ),
        );
      },
    );
  }
}
