import 'dart:async';

import 'package:walk_core/walk_core.dart';

/// 定位状态,遛狗页据此提示用户。
enum GpsStatus {
  /// 正在申请权限或等第一个定位点。
  starting,
  ok,
  denied,

  /// 用户选了“不再询问”,只能去系统设置里打开。
  deniedForever,

  /// 手机的定位总开关没开。
  serviceOff,

  /// 遛狗途中定位出错或中断。
  lost,
}

/// 位置来源。真机用 GPS,网页版和测试用模拟来源。
abstract class LocationSource {
  /// 申请权限;返回 [GpsStatus.ok] 才能调用 [watch]。
  Future<GpsStatus> requestAccess();

  /// 持续推送位置点,取消订阅即停止定位。
  Stream<GeoPoint> watch();

  /// 打开系统设置(权限被永久拒绝或定位关闭时用)。
  Future<void> openSettings(GpsStatus status) async {}
}

/// 人的步数来源(手机计步器),GPS 不可用时兜底。
abstract class StepSource {
  Future<bool> requestAccess();

  /// 推送计步器的累计读数(开机以来的总步数),由调用方减去起点。
  Stream<int> watch();
}

/// 模拟位置:以 [speedMps] 匀速向北走,每秒一个点。网页版演示和测试用。
class SimulatedLocation extends LocationSource {
  SimulatedLocation({
    DateTime Function()? clock,
    this.speedMps = 1.3,
    this.origin = const (31.2304, 121.4737),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final double speedMps;
  final (double, double) origin;

  /// 纬度 1 度约 111.2 km。
  static const _mPerDegLat = 111195.0;

  Duration _skipped = Duration.zero;
  DateTime? _t0;
  StreamController<GeoPoint>? _ctrl;

  @override
  Future<GpsStatus> requestAccess() async => GpsStatus.ok;

  @override
  Stream<GeoPoint> watch() {
    Timer? timer;
    late final StreamController<GeoPoint> ctrl;
    ctrl = StreamController<GeoPoint>(
      onListen: () {
        _t0 = _clock();
        _skipped = Duration.zero;
        _ctrl = ctrl;
        _emit();
        timer = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
      },
      onCancel: () {
        timer?.cancel();
        if (_ctrl == ctrl) _ctrl = null;
      },
    );
    return ctrl.stream;
  }

  /// 演示用:假装又走了 [d]。
  void fastForward(Duration d) {
    _skipped += d;
    _emit();
  }

  void _emit() {
    final ctrl = _ctrl;
    final t0 = _t0;
    if (ctrl == null || t0 == null) return;
    final now = _clock().add(_skipped);
    final metres = speedMps * now.difference(t0).inMilliseconds / 1000;
    ctrl.add(GeoPoint(origin.$1 + metres / _mPerDegLat, origin.$2, accuracyM: 5, time: now));
  }
}
