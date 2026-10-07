import 'package:flutter/material.dart';
import 'package:walk_core/walk_core.dart';

import '../state/app_state.dart';

class DogsScreen extends StatelessWidget {
  const DogsScreen({super.key, required this.state});
  final AppState state;

  static const _sizeLabel = {DogSize.small: '小型', DogSize.medium: '中型', DogSize.large: '大型'};
  static const _activityLabel = {Activity.calm: '慢悠悠', Activity.normal: '普通', Activity.wild: '很疯'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final d in state.dogs)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name, style: Theme.of(context).textTheme.titleLarge),
                Text('${d.weightKg} kg · ${_sizeLabel[d.size]} · 步长 '
                    '${strideFor(d).toStringAsFixed(2)} m${d.isCalibrated ? '(已校准)' : '(默认)'}'
                    ' · 约 ${kcalPerKm(d.weightKg).round()} kcal/km'),
                const SizedBox(height: 12),
                SegmentedButton<Activity>(
                  segments: [
                    for (final a in Activity.values)
                      ButtonSegment(value: a, label: Text(_activityLabel[a]!)),
                  ],
                  selected: {state.activityByDog[d.id] ?? Activity.normal},
                  onSelectionChanged: (v) => state.setActivity(d.id, v.first),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _calibrate(context, d),
                  icon: const Icon(Icons.straighten),
                  label: const Text('校准步长'),
                ),
              ]),
            ),
          ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDog(context),
        icon: const Icon(Icons.add),
        label: const Text('添加狗狗'),
      ),
    );
  }

  Future<void> _addDog(BuildContext context) async {
    final name = TextEditingController();
    final weight = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('添加狗狗'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: '名字')),
          TextField(
            controller: weight,
            decoration: const InputDecoration(labelText: '体重 (kg)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('添加')),
        ],
      ),
    );
    final w = double.tryParse(weight.text);
    if (ok == true && name.text.trim().isNotEmpty && w != null && w > 0) {
      state.addDog(name: name.text.trim(), weightKg: w);
    }
  }

  Future<void> _calibrate(BuildContext context, Dog d) async {
    final steps = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('校准${d.name}的步长'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('牵着狗走 20 米,数它一侧前腿落地的次数 × 2。'),
          TextField(
            controller: steps,
            decoration: const InputDecoration(labelText: '步数'),
            keyboardType: TextInputType.number,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('保存')),
        ],
      ),
    );
    final n = int.tryParse(steps.text);
    if (ok == true && n != null && n > 0) {
      state.updateDog(Dog(
        id: d.id,
        name: d.name,
        weightKg: d.weightKg,
        strideM: calibrateStrideM(distanceM: 20, steps: n),
      ));
    }
  }
}
