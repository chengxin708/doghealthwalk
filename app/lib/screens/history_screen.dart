import 'package:flutter/material.dart';

import '../state/app_state.dart';
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
        );
      },
    );
  }
}
