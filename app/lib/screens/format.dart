String km(double v) => '${v.toStringAsFixed(2)} km';
String kcal(double v) => '${v.round()} kcal';
String mins(Duration d) => '${d.inMinutes} 分钟';
String clock(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
String hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
