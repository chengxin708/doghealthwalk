# 遛狗健康 App 原型

不用硬件,只用手机按每只狗估算步数和卡路里,并把家里几个人的遛狗记录合成一份。
产品方案:https://claude.ai/code/artifact/fb2795b9-724d-4153-b9bc-3e5dfac8814b

## 目录

| 路径 | 内容 |
| --- | --- |
| `packages/walk_core` | 纯 Dart 核心算法:GPS 距离、狗步数、卡路里、校准、家庭去重、每日汇总 |
| `app` | Flutter App(iOS / Android / Web),依赖 `walk_core` |
| `screenshots` | 网页版截图 |

## 运行

```bash
# 算法测试
cd packages/walk_core && dart pub get && dart test

# App
cd app && flutter pub get && flutter test
flutter run            # 连手机或模拟器
flutter run -d chrome  # 浏览器
```

## 原型现状

- 数据在内存里,带示例数据(小白 5 kg、大熊 32 kg),重启后重置。
- 右上角“我 / 家人”切换身份,演示两人数据合并和重叠去重。
- **手机上用真 GPS** 记录遛狗距离(`app/lib/location/device_sources.dart`):
  - 锁屏、切后台也继续记录:Android 用前台服务(通知栏显示“正在记录遛狗”),iOS 用后台定位模式。
  - 每 5 米报一个点;精度差于 30 米的点和速度超过 3.5 m/s 的跳点会被丢掉。
  - 没有定位权限或 GPS 记不到距离时,用手机计步器(人的步数 × 0.7 米)兜底;遛狗页会说明原因,并提供“重新授权 / 去设置”。
  - 每次遛狗的轨迹点存在 `AppState.tracks`,给足迹地图用。
- **网页版用模拟定位**(约 4.7 km/h 匀速),保留“快进 10 分钟”按钮方便演示。

## 下一步

1. 真机试走一圈:核对 GPS 距离、锁屏后台记录、权限被拒时的提示
2. 足迹地图(flutter_map + OpenStreetMap)
3. Supabase:登录、家庭组邀请、实时同步
