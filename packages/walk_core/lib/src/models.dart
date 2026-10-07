/// 狗的体型分档,用于未校准时的默认步长。
enum DogSize { small, medium, large }

/// 活跃度系数:狗会嗅闻、绕圈、松绳跑,实际走的比人多。
enum Activity {
  calm(1.0),
  normal(1.2),
  wild(1.5);

  const Activity(this.factor);
  final double factor;
}

class Dog {
  const Dog({
    required this.id,
    required this.name,
    required this.weightKg,
    this.strideM,
  });

  final String id;
  final String name;
  final double weightKg;

  /// 校准过的步长(米);为空时按体型给默认值。
  final double? strideM;

  DogSize get size => weightKg < 10
      ? DogSize.small
      : weightKg <= 25
          ? DogSize.medium
          : DogSize.large;

  bool get isCalibrated => strideM != null;
}

class GeoPoint {
  const GeoPoint(this.lat, this.lng, {this.accuracyM = 0, required this.time});

  final double lat;
  final double lng;
  final double accuracyM;
  final DateTime time;
}

/// 一次遛狗中某一只狗的结果(对应 walk_dog 表)。
class DogWalkResult {
  const DogWalkResult({
    required this.walkId,
    required this.memberId,
    required this.dogId,
    required this.start,
    required this.end,
    required this.distanceKm,
    required this.dogSteps,
    required this.kcal,
    this.deduped = false,
  });

  final String walkId;
  final String memberId;
  final String dogId;
  final DateTime start;
  final DateTime end;
  final double distanceKm;
  final int dogSteps;
  final double kcal;

  /// 与另一位家人的记录重叠,不计入每日汇总(地图上仍显示)。
  final bool deduped;

  Duration get duration => end.difference(start);

  DogWalkResult copyWith({bool? deduped}) => DogWalkResult(
        walkId: walkId,
        memberId: memberId,
        dogId: dogId,
        start: start,
        end: end,
        distanceKm: distanceKm,
        dogSteps: dogSteps,
        kcal: kcal,
        deduped: deduped ?? this.deduped,
      );
}
