import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'format.dart';

class WalkScreen extends StatefulWidget {
  const WalkScreen({super.key, required this.state});
  final AppState state;

  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final theme = Theme.of(context);
    final a = s.active;

    if (a != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Spacer(),
          Text(clock(s.activeElapsed), style: theme.textTheme.displayLarge),
          Text(km(a.distanceKm), style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${s.member(a.memberId).name}带着 ${a.dogIds.map((id) => s.dog(id).name).join('、')}'),
          const SizedBox(height: 4),
          Text('原型:距离按 4.7 km/h 模拟,下一步接 GPS', style: theme.textTheme.bodySmall),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => s.fastForward(const Duration(minutes: 10)),
            icon: const Icon(Icons.fast_forward),
            label: const Text('快进 10 分钟(演示)'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: s.finishWalk,
            icon: const Icon(Icons.stop),
            label: const Text('结束遛狗'),
          ),
          TextButton(onPressed: s.cancelWalk, child: const Text('放弃这次')),
        ]),
      );
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('这次带谁出门?', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final d in s.dogs)
        CheckboxListTile(
          value: _selected.contains(d.id),
          onChanged: (v) => setState(() => v! ? _selected.add(d.id) : _selected.remove(d.id)),
          title: Text(d.name),
          subtitle: Text('${d.weightKg} kg · 步长 ${(d.strideM ?? 0) > 0 ? '${d.strideM} m(已校准)' : '按体型默认'}'),
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: _selected.isEmpty ? null : () => s.startWalk(_selected.toList()),
        icon: const Icon(Icons.play_arrow),
        label: Text('${s.member(s.currentMemberId).name}开始遛狗'),
      ),
    ]);
  }
}
