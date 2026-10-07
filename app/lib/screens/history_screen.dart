import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'footprint_map.dart';
import 'format.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final rows = state.deduped..sort((a, b) => b.start.compareTo(a.start));
    if (rows.isEmpty) return const Center(child: Text('还没有遛狗记录'));
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = rows[i];
        final m = state.member(r.memberId);
        return ListTile(
          leading: CircleAvatar(backgroundColor: m.color, child: Text(m.name.characters.first)),
          title: Text('${state.dog(r.dogId).name} · ${km(r.distanceKm)} · ${r.dogSteps} 步 · ${kcal(r.kcal)}'),
          subtitle: Text('${m.name} ${hm(r.start)}–${hm(r.end)}'
              '${r.deduped ? ' · 与家人记录重叠,未重复计入' : ''}'),
          enabled: !r.deduped,
          trailing: state.tracks.containsKey(r.walkId) ? const Icon(Icons.map_outlined) : null,
          onTap: state.tracks.containsKey(r.walkId)
              ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _WalkDetail(state: state, walkId: r.walkId),
                  ))
              : null,
        );
      },
    );
  }
}

class _WalkDetail extends StatelessWidget {
  const _WalkDetail({required this.state, required this.walkId});
  final AppState state;
  final String walkId;

  @override
  Widget build(BuildContext context) {
    final rows = state.deduped.where((r) => r.walkId == walkId).toList();
    final first = rows.first;
    final m = state.member(first.memberId);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('${m.name} ${hm(first.start)}–${hm(first.end)}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        FootprintMap(tracks: [MapTrack(state.tracks[walkId]!, m.color)], height: 320),
        const SizedBox(height: 16),
        Text('${km(first.distanceKm)} · ${mins(first.duration)}', style: t.titleLarge),
        const SizedBox(height: 8),
        for (final r in rows)
          ListTile(
            leading: const Icon(Icons.pets),
            title: Text(state.dog(r.dogId).name),
            subtitle: Text('${r.dogSteps} 步 · ${kcal(r.kcal)}'
                '${r.deduped ? ' · 与家人记录重叠,未重复计入' : ''}'),
          ),
      ]),
    );
  }
}
