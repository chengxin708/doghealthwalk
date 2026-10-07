import 'dart:math' as math;

import 'models.dart';

/// 未校准时的默认步长(米),粗估值,见产品方案“核心算法”一节。
double defaultStrideM(DogSize size) => switch (size) {
      DogSize.small => 0.35,
      DogSize.medium => 0.55,
      DogSize.large => 0.75,
    };

double strideFor(Dog dog) => dog.strideM ?? defaultStrideM(dog.size);

/// 校准:带狗走一段已知距离并数步数。
double calibrateStrideM({required double distanceM, required int steps}) {
  if (steps <= 0 || distanceM <= 0) {
    throw ArgumentError('distanceM 和 steps 必须大于 0');
  }
  return distanceM / steps;
}

/// 狗步数 = 距离 ÷ 步长 × 活跃度系数。
int dogSteps(Dog dog, double distanceKm, {Activity activity = Activity.normal}) =>
    (distanceKm * 1000 / strideFor(dog) * activity.factor).round();

/// 每公里净消耗(kcal/km),Taylor, Heglund & Maloiy 1982:
/// 运动净成本 ≈ 10.7 × M^-0.316 J/(kg·m)。系数待核对原文。
double kcalPerKm(double weightKg) =>
    10.7 * math.pow(weightKg, -0.316) * weightKg * 1000 / 4184;

double dogKcal(Dog dog, double distanceKm, {Activity activity = Activity.normal}) =>
    kcalPerKm(dog.weightKg) * distanceKm * activity.factor;

/// 把一次遛狗换算成每只狗的结果。
List<DogWalkResult> resultsForWalk({
  required String walkId,
  required String memberId,
  required DateTime start,
  required DateTime end,
  required double distanceKm,
  required List<Dog> dogs,
  Map<String, Activity> activityByDog = const {},
}) =>
    [
      for (final dog in dogs)
        DogWalkResult(
          walkId: walkId,
          memberId: memberId,
          dogId: dog.id,
          start: start,
          end: end,
          distanceKm: distanceKm,
          dogSteps: dogSteps(dog, distanceKm,
              activity: activityByDog[dog.id] ?? Activity.normal),
          kcal: dogKcal(dog, distanceKm,
              activity: activityByDog[dog.id] ?? Activity.normal),
        ),
    ];
