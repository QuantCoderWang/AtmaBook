import '../data/models/guide.dart';
import '../data/models/map_source.dart';
import '../l10n/app_localizations.dart';
import 'constants.dart';

/// 数据层名称 → 界面显示名的取名助手（i18n 取词层）。
///
/// 约定：下面这些中文常量只做内部标识持久化，不直接进界面：
/// - [MarkerCategory.label]（景点/餐饮/…，分享 JSON 字段）；
/// - [MapSource.label]（高德矢量/…，内置地图源清单）；
/// - [ClusterZone.label]（`片区 N` / `孤立 · 地名`，聚类时持久化进攻略 JSON）。
/// 界面一律经由本文件的取词函数显示；旧数据（含旧前缀标签）也能正确映射。
/// 标记详情、列表抽屉与离线地图页复用同批函数。

/// 地点分类显示名（按 id 映射；数据层 label 仅内部使用）
String categoryName(AppLocalizations t, MarkerCategory cat) {
  switch (cat.id) {
    case 'scenic':
      return t.catNameScenic;
    case 'dining':
      return t.catNameDining;
    case 'hotel':
      return t.catNameHotel;
    case 'shopping':
      return t.catNameShopping;
    case 'transport':
      return t.catNameTransport;
    default:
      return t.catNameOther;
  }
}

/// 片区/游览区域展示名：统一「游览区域 N」说法，不再出现「片区」「孤立」。
/// - 非孤立：`游览区域 N`（编号 = 列表位置，与 ClusterService 按成员数降序的
///   生成序一致，ZoneLayout 不改变相对次序）；
/// - 孤立（旧数据 label 形如 `孤立 · 地名`）：`游览区域 N（地名）`，剥掉旧前缀。
String zoneDisplayName(AppLocalizations t, ClusterZone zone, int index) {
  if (zone.isolated) {
    final name = zone.label
        .replaceFirst(RegExp(r'^孤立\s*[·•]\s*'), '')
        .trim();
    if (name.isNotEmpty) return t.legendZoneNamed(index + 1, name);
  }
  return t.legendZoneNumbered(index + 1);
}

/// 地图源显示名（按 id 映射；数据层 label 仅内部使用）
String mapSourceName(AppLocalizations t, MapSource source) {
  switch (source.id) {
    case 'amap_vector':
      return t.srcAmapVector;
    case 'amap_satellite':
      return t.srcAmapSatellite;
    case 'osm':
      return t.srcOsm;
    case 'esri_street':
      return t.srcEsriStreet;
    case 'esri_topo':
      return t.srcEsriTopo;
    case 'esri_gray':
      return t.srcEsriGray;
    case 'esri':
      return t.srcEsriSatellite;
    case 'tianditu':
      return t.srcTianditu;
    default:
      return source.label; // 未知源（老数据等）：数据层名兜底
  }
}

/// 底图类型名（替换数据层 kindLabel；坐标系标签 GCJ-02/WGS-84 为纯 ASCII 直用）
String mapKindName(AppLocalizations t, MapSource source) =>
    source.kind == MapKind.satellite ? t.srcKindSatellite : t.srcKindVector;
