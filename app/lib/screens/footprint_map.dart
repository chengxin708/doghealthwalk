import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:walk_core/walk_core.dart';

/// 地图上的一条遛狗路线。
class MapTrack {
  const MapTrack(this.points, this.color, {this.faded = false});
  final List<GeoPoint> points;
  final Color color;

  /// 被去重的记录画成虚一点的线。
  final bool faded;
}

LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lng);

/// 足迹地图:按主人分颜色画路线,起点圆点、终点爪印。
/// [follow] 为 true 时镜头跟着最后一个点(遛狗进行中)。
class FootprintMap extends StatefulWidget {
  const FootprintMap({super.key, required this.tracks, this.follow = false, this.height = 220});

  final List<MapTrack> tracks;
  final bool follow;
  final double height;

  @override
  State<FootprintMap> createState() => _FootprintMapState();
}

class _FootprintMapState extends State<FootprintMap> {
  final _controller = MapController();
  bool _ready = false;

  List<LatLng> get _all => [for (final t in widget.tracks) ...t.points.map(_ll)];

  @override
  void didUpdateWidget(FootprintMap old) {
    super.didUpdateWidget(old);
    if (widget.follow && _ready && _all.isNotEmpty) {
      _controller.move(_all.last, _controller.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = _all;
    final MapOptions options;
    if (all.length >= 2 && !widget.follow) {
      options = MapOptions(
        initialCameraFit: CameraFit.coordinates(
            coordinates: all, padding: const EdgeInsets.all(28), maxZoom: 17),
        onMapReady: () => _ready = true,
      );
    } else {
      options = MapOptions(
        initialCenter: all.isEmpty ? const LatLng(40.7812, -73.9665) : all.last,
        initialZoom: 16,
        onMapReady: () => _ready = true,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: ColoredBox(
          // 瓦片加载失败时(例如离线)仍能看到路线
          color: scheme.surfaceContainerHighest,
          child: FlutterMap(
            mapController: _controller,
            options: options,
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.doghealthwalk.doghealthwalk',
              ),
              PolylineLayer(polylines: [
                for (final t in widget.tracks)
                  if (t.points.length >= 2)
                    Polyline(
                      points: t.points.map(_ll).toList(),
                      color: t.faded ? t.color.withValues(alpha: 0.35) : t.color,
                      strokeWidth: t.faded ? 3 : 5,
                      borderColor: Colors.white,
                      borderStrokeWidth: t.faded ? 0 : 1.5,
                    ),
              ]),
              MarkerLayer(markers: [
                for (final t in widget.tracks)
                  if (t.points.isNotEmpty && !t.faded) ...[
                    Marker(
                      point: _ll(t.points.first),
                      width: 14,
                      height: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.color, width: 3),
                        ),
                      ),
                    ),
                    Marker(
                      point: _ll(t.points.last),
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(color: t.color, shape: BoxShape.circle),
                        child: const Icon(Icons.pets, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
              ]),
              const SimpleAttributionWidget(source: Text('OpenStreetMap')),
            ],
          ),
        ),
      ),
    );
  }
}
