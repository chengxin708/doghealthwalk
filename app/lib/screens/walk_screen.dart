import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'footprint_map.dart';
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
      return ListView(padding: const EdgeInsets.all(16), children: [
        FootprintMap(
          tracks: [MapTrack(a.track, s.member(a.memberId).color)],
          follow: true,
          height: 280,
        ),
        const SizedBox(height: 16),
        Center(child: Text(clock(s.activeElapsed), style: theme.textTheme.displayMedium)),
        Center(child: Text(km(a.distanceKm), style: theme.textTheme.headlineSmall)),
        const SizedBox(height: 4),
        Center(
          child: Text(
              '${s.member(a.memberId).name}带着 ${a.dogIds.map((id) => s.dog(id).name).join('、')} · ${a.sourceLabel}定位'),
        ),
        if (s.locationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(s.locationError!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: 24),
        if (s.canFastForward) ...[
          OutlinedButton.icon(
            onPressed: () => s.fastForward(const Duration(minutes: 10)),
            icon: const Icon(Icons.fast_forward),
            label: const Text('快进 10 分钟(演示)'),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: s.finishWalk,
          icon: const Icon(Icons.stop),
          label: const Text('结束遛狗'),
        ),
        TextButton(onPressed: s.cancelWalk, child: const Text('放弃这次')),
      ]);
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('这次带谁出门?', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final d in s.dogs)
        CheckboxListTile(
          value: _selected.contains(d.id),
          onChanged: (v) => setState(() => v! ? _selected.add(d.id) : _selected.remove(d.id)),
          title: Text(d.name),
          subtitle: Text('${d.weightKg} kg · 步长 ${d.isCalibrated ? '${d.strideM} m(已校准)' : '按体型默认'}'),
        ),
      SwitchListTile(
        value: s.useSimulated,
        onChanged: s.setUseSimulated,
        title: const Text('模拟定位'),
        subtitle: const Text('不出门也能演示,路线按 4.7 km/h 自动生成'),
      ),
      if (s.locationError != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(s.locationError!, style: TextStyle(color: theme.colorScheme.error)),
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
