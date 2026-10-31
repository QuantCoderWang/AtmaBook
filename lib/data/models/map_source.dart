/// 坐标系与底图类型
enum CoordSystem { wgs84, gcj02 }

enum MapKind { vector, satellite }

/// 单个瓦片地图源（离线包复用同一config，最后实现本地 Provider）
class MapSource {
  const MapSource({
    required this.id,
    required this.label,
    required this.urlTemplate,
    this.subdomains = const [],
    required this.coordSystem,
    required this.kind,
    this.recommendedChina = false,
    this.recommendedOverseas = false,
    this.needsKey = false,
  });

  final String id;
  final String label;
  final String urlTemplate;
  final List<String> subdomains;
  final CoordSystem coordSystem;
  final MapKind kind;
  final bool recommendedChina;
  final bool recommendedOverseas;
  final bool needsKey;

  String get coordLabel => coordSystem == CoordSystem.gcj02 ? 'GCJ-02' : 'WGS-84';
  String get kindLabel => kind == MapKind.satellite ? '卫星影像' : '矢量底图';
}

/// 内置地图源清单
class MapSources {
  /// 高德矢量（境内默认，GCJ-02，渲染时 WGS84 换算）
  static const MapSource amapVector = MapSource(
    id: 'amap_vector',
    label: '高德矢量',
    urlTemplate:
        'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&style=8&x={x}&y={y}&z={z}',
    subdomains: ['1', '2', '3', '4'],
    coordSystem: CoordSystem.gcj02,
    kind: MapKind.vector,
    recommendedChina: true,
  );

  static const MapSource amapSatellite = MapSource(
    id: 'amap_satellite',
    label: '高德卫星',
    urlTemplate:
        'https://webst0{s}.is.autonavi.com/appmaptile?style=6&x={x}&y={y}&z={z}',
    subdomains: ['1', '2', '3', '4'],
    coordSystem: CoordSystem.gcj02,
    kind: MapKind.satellite,
    recommendedChina: true,
  );

  /// OpenStreetMap（境外默认，全球）
  static const MapSource osm = MapSource(
    id: 'osm',
    label: 'OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    coordSystem: CoordSystem.wgs84,
    kind: MapKind.vector,
    recommendedOverseas: true,
  );

  /// Esri 街道矢量（ArcGIS Online，免密钥、支持 CORS，通常境内可达，
  /// Web 预览下载首选备份）
  static const MapSource esriStreet = MapSource(
    id: 'esri_street',
    label: 'Esri 街道（免 Key）',
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
    coordSystem: CoordSystem.wgs84,
    kind: MapKind.vector,
  );

  /// Esri 地形（World_Topo_Map，免密钥）
  static const MapSource esriTopo = MapSource(
    id: 'esri_topo',
    label: 'Esri 地形（免 Key）',
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
    coordSystem: CoordSystem.wgs84,
    kind: MapKind.vector,
  );

  /// Esri 浅灰底图（Canvas/World_Light_Gray_Base，免密钥）
  static const MapSource esriGray = MapSource(
    id: 'esri_gray',
    label: 'Esri 浅灰（免 Key）',
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
    coordSystem: CoordSystem.wgs84,
    kind: MapKind.vector,
  );

  static const MapSource esriSatellite = MapSource(
    id: 'esri',
    label: 'Esri 卫星',
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    coordSystem: CoordSystem.wgs84,
    kind: MapKind.satellite,
  );

  static const MapSource tianditu = MapSource(
    id: 'tianditu',
    label: '天地图',
    urlTemplate:
        'https://t{s}.tianditu.gov.cn/DataServer?T=vec_w&x={x}&y={y}&l={z}&tk={key}',
    subdomains: ['0', '1', '2', '3'],
    coordSystem: CoordSystem.wgs84,
    kind: MapKind.vector,
    needsKey: true,
  );

  static const List<MapSource> all = [
    amapVector, amapSatellite, esriStreet, esriTopo, esriGray,
    esriSatellite, osm, tianditu,
  ];

  static MapSource? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 按攻略区域给出默认源：境内→高德，境外→OSM
  static MapSource forRegion(GuideRegion region) =>
      region == GuideRegion.china ? amapVector : osm;
}

/// 攻略区域（默认地图源）
enum GuideRegion {
  china('中国境内', '默认高德地图（GCJ-02 自动换算）'),
  overseas('中国境外', '默认 OpenStreetMap（WGS-84）');

  const GuideRegion(this.label, this.sourceDesc);
  final String label;
  final String sourceDesc;
}
