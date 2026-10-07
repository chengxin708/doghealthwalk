import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:walk_core/walk_core.dart';

import 'sources.dart';

/// 手机 GPS。锁屏或切到后台也继续记录:
/// Android 用前台服务(通知栏常驻“正在记录遛狗”),iOS 用后台定位模式。
class DeviceLocation extends LocationSource {
  @override
  Future<GpsStatus> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return GpsStatus.serviceOff;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return switch (p) {
      LocationPermission.whileInUse || LocationPermission.always => GpsStatus.ok,
      LocationPermission.deniedForever => GpsStatus.deniedForever,
      _ => GpsStatus.denied,
    };
  }

  @override
  Stream<GeoPoint> watch() => Geolocator.getPositionStream(locationSettings: _settings())
      .map((p) => GeoPoint(p.latitude, p.longitude, accuracyM: p.accuracy, time: p.timestamp));

  @override
  Future<void> openSettings(GpsStatus status) async {
    if (status == GpsStatus.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  /// 每走 5 米报一次点,站着不动时不累计 GPS 漂移。
  static const _distanceFilterM = 5;

  LocationSettings _settings() => switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: _distanceFilterM,
            intervalDuration: const Duration(seconds: 2),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: '正在记录遛狗',
              notificationText: '遛狗健康正在记录路线和距离',
              enableWakeLock: true,
              setOngoing: true,
            ),
          ),
        TargetPlatform.iOS => AppleSettings(
            accuracy: LocationAccuracy.best,
            activityType: ActivityType.fitness,
            distanceFilter: _distanceFilterM,
            pauseLocationUpdatesAutomatically: false,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
          ),
        _ => const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: _distanceFilterM,
          ),
      };
}

/// 手机计步器。Android 10+ 要“身体活动”权限;iOS 首次读取时系统自己弹窗。
class DeviceSteps extends StepSource {
  @override
  Future<bool> requestAccess() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return (await Permission.activityRecognition.request()).isGranted;
  }

  @override
  Stream<int> watch() => Pedometer.stepCountStream.map((e) => e.steps);
}
