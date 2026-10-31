import 'dart:math' as math;

/// WGS-84 ↔ GCJ-02 偏移换算（国测局标准近似算法）
/// - 仅在中国境内产生实际偏移，境外原样返回；
/// - 单向近似换算往返误差 < 1m，满足攻略显示需求；
/// - 存储统一 WGS-84，高德（GCJ-02）底图渲染前调用 wgs84ToGcj02。
const double _pi = math.pi;

bool _outOfChina(double lat, double lng) {
  // 中国大陆/港澳台粗略包围盒
  return lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;
}

double _transformLat(double x, double y) {
  var ret = -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x * _pi) + 20.0 * math.sin(2.0 * x * _pi)) *
      2.0 /
      3.0;
  ret += (20.0 * math.sin(y * _pi) + 40.0 * math.sin(y / 3.0 * _pi)) * 2.0 / 3.0;
  ret +=
      (160.0 * math.sin(y / 12.0 * _pi) + 320 * math.sin(y * _pi / 30.0)) * 2.0 /
          3.0;
  return ret;
}

double _transformLng(double x, double y) {
  var ret =
      300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x * _pi) + 20.0 * math.sin(2.0 * x * _pi)) *
      2.0 /
      3.0;
  ret += (20.0 * math.sin(x * _pi) + 40.0 * math.sin(x / 3.0 * _pi)) * 2.0 / 3.0;
  ret +=
      (150.0 * math.sin(x / 12.0 * _pi) + 300.0 * math.sin(x / 30.0 * _pi)) *
          2.0 /
          3.0;
  return ret;
}

(double, double) _offset(double lat, double lng) {
  const ee = 0.00669342162296594323;
  var dLat = _transformLat(lng - 105.0, lat - 35.0);
  var dLng = _transformLng(lng - 105.0, lat - 35.0);
  final radLat = lat / 180.0 * _pi;
  var magic = math.sin(radLat);
  magic = 1 - ee * magic * magic;
  final sqrtMagic = math.sqrt(magic);
  dLat = (dLat * 180.0) /
      (((6378245.0 * (1 - ee)) / (magic * sqrtMagic)) / _pi * 180.0);
  dLng = (dLng * 180.0) /
      (((6378245.0 / sqrtMagic) * math.cos(radLat)) / _pi * 180.0);
  return (dLat, dLng);
}

/// WGS-84 → GCJ-02（高德底图渲染用）
(double lat, double lng) wgs84ToGcj02(double wgsLat, double wgsLng) {
  if (_outOfChina(wgsLat, wgsLng)) return (wgsLat, wgsLng);
  final (dLat, dLng) = _offset(wgsLat, wgsLng);
  return (wgsLat + dLat, wgsLng + dLng);
}

/// GCJ-02 → WGS-84（高德检索结果落库前换算用，一次迭代近似）
(double lat, double lng) gcj02ToWgs84(double gcjLat, double gcjLng) {
  if (_outOfChina(gcjLat, gcjLng)) return (gcjLat, gcjLng);
  final (dLat, dLng) = _offset(gcjLat, gcjLng);
  final wLat = gcjLat - dLat;
  final wLng = gcjLng - dLng;
  // 二次迭代减小残差
  final (dLat2, dLng2) = _offset(wLat, wLng);
  return (gcjLat - dLat2, gcjLng - dLng2);
}

