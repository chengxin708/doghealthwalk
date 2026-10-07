import 'package:flutter/material.dart';
import 'package:walk_core/walk_core.dart';

import '../state/app_state.dart';
import 'format.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final byDog = {for (final s in state.today) s.dogId: s};
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.active != null) _LiveBanner(state: state),
        Text('今天每只狗的运动量', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('步数和卡路里为估算值。两位家人同时遛同一只狗只算一次。',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        for (final dog in state.dogs) _DogCard(state: state, dog: dog, summary: byDog[dog.id]),
      ],
    );
  }
}

class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final a = state.active!;
    final names = a.dogIds.map((id) => state.dog(id).name).join('、');
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.directions_walk),
        title: Text('$names 正在外面'),
        subtitle: Text(
            '${state.member(a.memberId).name}在遛 · 已走 ${state.activeElapsed.inMinutes} 分钟 · ${km(a.distanceKm)}'),
      ),
    );
  }
}

class _DogCard extends StatelessWidget {
  const _DogCard({required this.state, required this.dog, this.summary});
  final AppState state;
  final Dog dog;
  final DailyDogSummary? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.pets),
              const SizedBox(width: 8),
              Text(dog.name, style: theme.textTheme.titleLarge),
              const Spacer(),
              Text('${dog.weightKg.toStringAsFixed(dog.weightKg % 1 == 0 ? 0 : 1)} kg',
                  style: theme.textTheme.bodySmall),
            ]),
            const SizedBox(height: 12),
            if (s == null)
              const Text('今天还没出门')
            else ...[
              Row(children: [
                _Stat('距离', km(s.distanceKm)),
                _Stat('狗步数', '${s.dogSteps}'),
                _Stat('卡路里', kcal(s.kcal)),
                _Stat('时长', mins(s.duration)),
              ]),
              const SizedBox(height: 12),
              _MemberBar(state: state, summary: s),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: t.titleMedium),
        Text(label, style: t.bodySmall),
      ]),
    );
  }
}

/// 谁遛了多少:按时长拆分的条形。
class _MemberBar extends StatelessWidget {
  const _MemberBar({required this.state, required this.summary});
  final AppState state;
  final DailyDogSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.duration.inSeconds;
    final shares = summary.byMember.values.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 8,
          child: Row(children: [
            for (final m in shares)
              Expanded(
                flex: total == 0 ? 1 : m.duration.inSeconds.clamp(1, total),
                child: Container(color: state.member(m.memberId).color),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 12, children: [
        for (final m in shares)
          Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(radius: 4, backgroundColor: state.member(m.memberId).color),
            const SizedBox(width: 4),
            Text('${state.member(m.memberId).name} ${mins(m.duration)}'),
          ]),
      ]),
    ]);
  }
}
