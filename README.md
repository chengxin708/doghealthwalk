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
- 遛狗距离来自定位轨迹:手机上用 GPS(锁屏后继续记录),网页版默认用“模拟定位”,可一键快进 10 分钟。
- 足迹地图:今天页显示全家今天的路线(按主人分颜色),遛狗中实时画线,记录页点开可看单次路线。
- 地图用 OpenStreetMap 瓦片;正式上线前需要换成有使用许可的瓦片服务(OSM 官方瓦片不允许商用大流量)。

## 下一步

1. Supabase:登录、家庭组邀请、实时同步
2. 没有 GPS 时用人的步数兜底(HealthKit / Health Connect)
3. 遛狗中的实时状态通知给家人
