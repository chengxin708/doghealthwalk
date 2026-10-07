import 'package:flutter/material.dart';

import '../location/sources.dart';
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
          const SizedBox(height: 16),
          _GpsStatusCard(state: s, walk: a),
          const Spacer(),
          if (s.isSimulated) ...[
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

/// 定位状态:正常时显示精度,出问题时说明原因并给出补救按钮。
class _GpsStatusCard extends StatelessWidget {
  const _GpsStatusCard({required this.state, required this.walk});
  final AppState state;
  final ActiveWalk walk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = walk.humanSteps;
    final fallback = switch (walk.source) {
      DistanceSource.steps => '距离改用手机步数估算(已走 $steps 步)',
      _ when walk.stepsAvailable == true => '距离改用手机步数估算,等待计步数据',
      _ => '暂时记录不到距离,结束后只记时长',
    };

    final (IconData icon, String title, String? detail, List<Widget> actions) = switch (walk.gps) {
      GpsStatus.starting => (Icons.gps_not_fixed, '正在定位…', null, const []),
      GpsStatus.ok when walk.points.isEmpty => (Icons.gps_not_fixed, '等待 GPS 信号…', null, const []),
      GpsStatus.ok => (
          Icons.gps_fixed,
          state.isSimulated ? '模拟定位(演示)' : 'GPS 定位中',
          walk.accuracyM == null ? null : '精度约 ±${walk.accuracyM!.round()} 米',
          const [],
        ),
      GpsStatus.denied => (
          Icons.location_disabled,
          '没有定位权限',
          fallback,
          [TextButton(onPressed: state.retryGps, child: const Text('重新授权'))],
        ),
      GpsStatus.deniedForever => (
          Icons.location_disabled,
          '定位权限已关闭',
          '$fallback。可到系统设置里打开定位权限,回来后点“重试”。',
          _settingsThenRetry(walk.gps),
        ),
      GpsStatus.serviceOff => (
          Icons.location_off,
          '手机定位没有打开',
          fallback,
          _settingsThenRetry(walk.gps),
        ),
      GpsStatus.lost => (Icons.gps_off, 'GPS 信号中断', '已记录的距离会保留,恢复后继续累计', const []),
    };

    final warn = walk.gps != GpsStatus.ok && walk.gps != GpsStatus.starting;
    return Card(
      color: warn ? theme.colorScheme.errorContainer : null,
      child: Column(children: [
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: detail == null ? null : Text(detail),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 4),
            child: OverflowBar(alignment: MainAxisAlignment.end, children: actions),
          ),
      ]),
    );
  }

  List<Widget> _settingsThenRetry(GpsStatus status) => [
        TextButton(
          onPressed: () => state.location.openSettings(status),
          child: const Text('去设置'),
        ),
        TextButton(onPressed: state.retryGps, child: const Text('重试')),
      ];
}
