import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/i18n_service.dart';
import '../core/utils/coord.dart';

/// 地理检索结果（WGS-84）
class GeoPlaceResult {
  const GeoPlaceResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;
}

/// 真实地理检索：
/// - 境外 / 无高德 Key：Nominatim（免密钥，遵守使用政策带 UA，限 1 req/s 由 UI 防抖保证）；
/// - 境内 + 设置页已配高德 Web 服务 Key（不输入也可以使用）：优先高德 POI 检索（GCJ-02 结果换算回 WGS-84），
///   失败自动回退 Nominatim。
class GeocodeService {
  static const _ua = 'AtmaBook/0.1 (offline travel guide; demo)';

  Future<List<GeoPlaceResult>> search({
    required String query,
    required bool china,
    String? amapKey,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    if (china && (amapKey?.trim().isNotEmpty ?? false)) {
      try {
        final amap = await _amap(q, amapKey!.trim());
        if (amap.isNotEmpty) return amap;
      } catch (_) {// 回退 Nominatim
      }
    }
    return _nominatim(q);
  }

  Future<List<GeoPlaceResult>> _nominatim(String q) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '8',
      'accept-language': 'zh-CN',
    });
    final resp = await http
        .get(uri, headers: {'User-Agent': _ua, 'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Nominatim ${resp.statusCode}');
    }
    final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
    return [
      for (final e in list)
        if (e is Map)
          GeoPlaceResult(
            name:
                (e['name'] as String?)?.isNotEmpty == true
                    ? e['name'] as String
                    : ((e['display_name'] as String?) ?? I18nService.t.unknownPlace)
                    .split(',')
                    .first,
            address: (e['display_name'] as String?) ?? '',
            lat: _double(e['lat']),
            lng: _double(e['lon']),
          ),
    ];
  }

  Future<List<GeoPlaceResult>> _amap(String q, String key) async {
    final uri = Uri.https('restapi.amap.com', '/v3/place/text', {
      'key': key,
      'keywords': q,
      'offset': '8',
      'page': '1',
      'extensions': 'base',
    });
    final resp = await http.get(
        uri,
        headers: const {'Accept': 'application/json'}
      ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Amap ${resp.statusCode}');
    }
    final j =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<dynamic, dynamic>;
    if (j['status'] != '1') {
      throw Exception('Amap ${j['info']}');
    }
    final pois = (j['pois'] as List? ?? const []);
    return [
      for (final e in pois)
        if (e is Map) ...[
          () {
            final (lat, lng) = _toWgs(e['location']);
            return GeoPlaceResult(
              name: (e['name'] as String?) ?? I18nService.t.unknownPlace,
              address:
                  '${e['pname'] ?? ''}${e['cityname'] ?? ''}${e['adname'] ?? ''} ${e['address'] ?? ''}'
                      .trim(),
              lat: lat,
              lng: lng,
            );
          }(),
        ],
    ];
  }

  static double _double(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0;

  /// 高德 location 格式 "lng,lat"（GCJ-02）→ WGS-84（两轴联合换算）
  static (double lat, double lng) _toWgs(dynamic location) {
    final parts = (location?.toString() ?? '').split(',');
    final gcjLng = double.tryParse(parts.first) ?? 0;
    final gcjLat =
        parts.length > 1 ? double.tryParse(parts[1]) ?? 0.0 : 0.0;
    return gcj02ToWgs84(gcjLat, gcjLng);
  }
}
