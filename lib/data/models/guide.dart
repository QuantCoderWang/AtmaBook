import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/thumb_binding.dart';
import 'map_source.dart';

/// 地点标记富媒体外链
class GeoLink {
  const GeoLink(this.title, this.url);
  final String title;
  final String url;

  Map<String, dynamic> toJson() => {'title': title, 'url': url};

  factory GeoLink.fromJson(dynamic raw) {
    final j = (raw as Map).cast<String, dynamic>();
    return GeoLink((j['title'] as String?) ?? '链接', (j['url'] as String?) ?? '');
  }
}

/// GPS 地点标记：图文 + 坐标 + 分类 + 必去规则，全部信息挂在一个对象上（JSON 同体关联）
class Place {
  const Place({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.lat,
    required this.lng,
    this.mustVisit = false,
    this.description = '',
    this.images = const [],
    this.links = const [],
    this.colorValue,
    this.iconPath,
  });

  final String id;
  final String title;
  final String categoryId;

  /// 统一 WGS-84 十进制度存储；渲染时按底图坐标系换算
  final double lat;
  final double lng;

  /// 必去 / 选去（必去参与片区聚类与推荐路径）
  final bool mustVisit;
  final String description;

  /// 图片相对路径（`pics/<guideId>/` 下），M6 前为占位
  final List<String> images;
  final List<GeoLink> links;

  /// 自定义 Pin 颜色（0xAARRGGBB）；为空时取分类默认色
  final int? colorValue;

  /// 自定义 Pin 图标（相对路径 `pics/icons/*`；仅图标式 Pin 显示）
  final String? iconPath;

  MarkerCategory get category => MarkerCategory.of(categoryId);
  Color get pinColor =>
      colorValue != null ? Color(colorValue!) : category.color;

  Place copyWith({
    String? title,
    String? categoryId,
    double? lat,
    double? lng,
    bool? mustVisit,
    String? description,
    List<String>? images,
    List<GeoLink>? links,
    int? colorValue,
    String? iconPath,
    bool clearColor = false,
    bool clearIcon = false,
  }) {
    return Place(
      id: id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      mustVisit: mustVisit ?? this.mustVisit,
      description: description ?? this.description,
      images: images ?? this.images,
      links: links ?? this.links,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      iconPath: clearIcon ? null : (iconPath ?? this.iconPath),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'categoryId': categoryId,
        'lat': lat,
        'lng': lng,
        'mustVisit': mustVisit,
        'description': description,
        'images': images,
        'links': [for (final l in links) l.toJson()],
        'color': colorValue,
        'iconPath': iconPath,
      };

  factory Place.fromJson(dynamic raw) {
    final j = (raw as Map).cast<String, dynamic>();
    return Place(
      id: (j['id'] as String?) ?? newId('mk'),
      title: (j['title'] as String?) ?? '未命名地点',
      categoryId: (j['categoryId'] as String?) ?? MarkerCategory.other.id,
      lat: (j['lat'] as num?)?.toDouble() ?? 0,
      lng: (j['lng'] as num?)?.toDouble() ?? 0,
      mustVisit: j['mustVisit'] as bool? ?? false,
      description: (j['description'] as String?) ?? '',
      images: [for (final e in (j['images'] as List? ?? const [])) e as String],
      links: [
        for (final e in (j['links'] as List? ?? const [])) GeoLink.fromJson(e),
      ],
      colorValue: (j['color'] as num?)?.toInt(),
      iconPath: j['iconPath'] as String?,
    );
  }
}

/// 一篇攻略（生成一个 JSON 文件；含标记、照片墙照片与聚类结果）
class Guide {
  const Guide({
    required this.id,
    required this.title,
    required this.summary,
    required this.region,
    required this.sourceId,
    required this.createdAt,
    required this.updatedAt,
    this.coverImage,
    this.originName,
    this.originLat,
    this.originLng,
    this.markers = const [],
    this.photos = const [],
    this.clusters = const [],
    this.settings = const GuideSettings(),
    this.shared = false,
    this.sharedOriginal = false,
    this.shareKey,
  });

  final String id;
  final String title;
  final String summary;
  final GuideRegion region;

  /// 当前使用的地图源
  final String sourceId;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 封面（相对路径：桌面 `pics/<id>/cover.*`；Web 缓存 `pics/covers/<id>.bin`）
  final String? coverImage;

  /// 创建向导选定的范围（城市 / 地点检索结果；WGS-84）
  final String? originName;
  final double? originLat;
  final double? originLng;

  final List<Place> markers;

  /// 照片墙：带 EXIF GPS 的照片
  final List<PhotoItem> photos;

  /// 片区（开发时使用演示假数据）
  final List<ClusterZone> clusters;
  final GuideSettings settings;

  /// 分享攻略标识（分享文件导入后恒为 true；本地创建为 false）
  final bool shared;

  /// 原片包标识（policy=original 的分享包导入后为 true）。
  /// 也代表该攻略可再次导出原片（备份链可延续）；
  /// 共享的「不进接收方地理相册」隔离口径与 [shared] 完全一致。
  final bool sharedOriginal;

  /// 导入时的分享内容指纹（重复导入查重用；本地攻略为 null）
  final String? shareKey;

  int get mustVisitCount => markers.where((m) => m.mustVisit).length;

  Guide copyWith({
    String? title,
    String? summary,
    String? sourceId,
    String? coverImage,
    bool clearCover = false,
    String? originName,
    double? originLat,
    double? originLng,
    DateTime? updatedAt,
    List<Place>? markers,
    List<PhotoItem>? photos,
    List<ClusterZone>? clusters,
    GuideSettings? settings,
    bool? shared,
    bool? sharedOriginal,
  }) {
    return Guide(
      id: id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      region: region,
      sourceId: sourceId ?? this.sourceId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverImage: clearCover ? null : (coverImage ?? this.coverImage),
      originName: originName ?? this.originName,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      markers: markers ?? this.markers,
      photos: photos ?? this.photos,
      clusters: clusters ?? this.clusters,
      settings: settings ?? this.settings,
      shared: shared ?? this.shared,
      sharedOriginal: sharedOriginal ?? this.sharedOriginal,
      shareKey: shareKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'region': region.name,
        'sourceId': sourceId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'coverImage': coverImage,
        'originName': originName,
        'originLat': originLat,
        'originLng': originLng,
        'markers': [for (final m in markers) m.toJson()],
        'photos': [for (final p in photos) p.toJson()],
        'clusters': [for (final z in clusters) z.toJson()],
        'settings': settings.toJson(),
        'shared': shared,
        if (sharedOriginal) 'sharedOriginal': true,
        if (shareKey != null) 'shareKey': shareKey,
      };

  factory Guide.fromJson(dynamic raw) {
    final j = (raw as Map).cast<String, dynamic>();
    final region = GuideRegion.values
        .firstWhere((r) => r.name == j['region'], orElse: () => GuideRegion.china);
    return Guide(
      id: (j['id'] as String?) ?? newId('gd'),
      title: (j['title'] as String?) ?? '未命名攻略',
      summary: (j['summary'] as String?) ?? '',
      region: region,
      sourceId: (j['sourceId'] as String?) ??
          MapSources.forRegion(region).id,
      createdAt: _date(j['createdAt']),
      updatedAt: _date(j['updatedAt']),
      coverImage: j['coverImage'] as String?,
      originName: j['originName'] as String?,
      originLat: _doubleOf(j['originLat']),
      originLng: _doubleOf(j['originLng']),
      markers: [
        for (final m in (j['markers'] as List? ?? const []))
          Place.fromJson(m),
      ],
      photos: [
        for (final p in (j['photos'] as List? ?? const []))
          PhotoItem.fromJson(p),
      ],
      clusters: [
        for (final z in (j['clusters'] as List? ?? const []))
          ClusterZone.fromJson(z),
      ],
      settings: GuideSettings.fromJson(
          (j['settings'] as Map?)?.cast<String, dynamic>() ?? const {}),
      shared: j['shared'] as bool? ?? false,
      sharedOriginal: j['sharedOriginal'] as bool? ?? false,
      shareKey: j['shareKey'] as String?,
    );
  }

  static DateTime _date(dynamic v) {
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static double? _doubleOf(dynamic v) =>
      v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
}

/// 攻略级片区参数：
/// - 片区半径 / 最少点数默认**跟随通用设置**（设置页）；
/// - 本攻略重设后（覆写值非空）以攻略自身为准，不再随通用设置变化；
/// - `showRoutes` 沿用旧存储键：语义改为「是否显示片区范围圈」；
/// - 旧版 JSON 的 `clusterRadiusM`/`minPts` 为占位值（曾恒等于通用默认），不再读取。
class GuideSettings {
  const GuideSettings({
    this.zoneRadiusOverrideM,
    this.zoneMinPtsOverride,
    this.showRoutes = true,
  });

  /// 片区半径覆写（米）；null = 跟随通用设置
  final double? zoneRadiusOverrideM;

  /// 单簇最少地点数覆写；null = 跟随通用设置
  final int? zoneMinPtsOverride;

  final bool showRoutes;

  GuideSettings copyWith({
    double? radiusOverrideM,
    int? minPtsOverride,
    bool? showRoutes,
    bool clearOverrides = false,
  }) =>
      GuideSettings(
        zoneRadiusOverrideM: clearOverrides
            ? null
            : (radiusOverrideM ?? zoneRadiusOverrideM),
        zoneMinPtsOverride:
            clearOverrides ? null : (minPtsOverride ?? zoneMinPtsOverride),
        showRoutes: showRoutes ?? this.showRoutes,
      );

  Map<String, dynamic> toJson() => {
        if (zoneRadiusOverrideM != null)
          'radiusOverrideM': zoneRadiusOverrideM,
        if (zoneMinPtsOverride != null) 'minPtsOverride': zoneMinPtsOverride,
        'showRoutes': showRoutes,
      };

  factory GuideSettings.fromJson(Map<String, dynamic> j) => GuideSettings(
        zoneRadiusOverrideM: (j['radiusOverrideM'] as num?)?.toDouble(),
        zoneMinPtsOverride: (j['minPtsOverride'] as num?)?.toInt(),
        showRoutes: j['showRoutes'] as bool? ?? true,
      );
}

/// 照片墙照片：
/// - `file`/`thumb` 为原图与缩略图的相对路径（旧演示数据为空串，仍走渐变占位）；
/// - `lat`/`lng` 由 EXIF GPS 解析（无定位为 null，进「未定位」栏手动绑定标记）；
/// - `placeId` 绑定的标记；`name` 自定义显示名（空则展示拍摄时间）。
class PhotoItem {
  const PhotoItem({
    required this.id,
    required this.takenAt,
    this.lat,
    this.lng,
    this.gradientIndex = 0,
    this.caption = '',
    this.file = '',
    this.thumb = '',
    this.placeId,
    this.name = '',
    this.kind = 'photo',
    this.durationMs = 0,
  });

  final String id;

  /// EXIF GPS 位置（未提取到权限为 null）
  final double? lat;
  final double? lng;
  final DateTime takenAt;

  /// 旧演示数据的渐变索引（无真实文件时仍用于占位渲染）
  final int gradientIndex;
  final String caption;

  /// 原图 / 缩略图相对路径（pics/photowall/…）
  final String file;
  final String thumb;

  /// 绑定的标记 id（未定位照片手动绑定后可与攻略联动）
  final String? placeId;

  /// 自定义显示名（重命名后使用）
  final String name;

  /// 媒体类型：'photo'（默认，旧数据缺键兼容）/'video'
  final String kind;

  /// 视频时长（毫秒；视频展示 mm:ss 角标，照片恒 0）
  final int durationMs;

  bool get isVideo => kind == 'video';

  bool get hasGps => lat != null && lng != null;

  bool get hasFile => file.isNotEmpty;

  /// 锁定缩略绑定：本条目**自带**的「文件名↔缩略图名」配对——
  /// 缩略来源唯一正解；渲染端禁止按位序/index 推断
  /// （口径唯一定义点见 `core/utils/thumb_binding.dart`）。
  String get thumbBinding =>
      resolveThumbBinding(isVideo: isVideo, thumb: thumb, file: file);

  Map<String, dynamic> toJson() => {
        'id': id,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'takenAt': takenAt.toIso8601String(),
        'gradientIndex': gradientIndex,
        'caption': caption,
        'file': file,
        'thumb': thumb,
        if (placeId != null) 'placeId': placeId,
        'name': name,
        if (kind != 'photo') 'kind': kind,
        if (durationMs > 0) 'durationMs': durationMs,
      };

  factory PhotoItem.fromJson(dynamic raw) {
    final j = (raw as Map).cast<String, dynamic>();
    return PhotoItem(
      id: (j['id'] as String?) ?? newId('ph'),
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      takenAt: DateTime.tryParse(j['takenAt'] as String? ?? '') ??
          DateTime.now(),
      gradientIndex: (j['gradientIndex'] as num?)?.toInt() ?? 0,
      caption: (j['caption'] as String?) ?? '',
      file: (j['file'] as String?) ?? '',
      thumb: (j['thumb'] as String?) ?? '',
      placeId: j['placeId'] as String?,
      name: (j['name'] as String?) ?? '',
      kind: (j['kind'] as String?) ?? 'photo',
      durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
    );
  }

  PhotoItem copyWith({
    double? lat,
    double? lng,
    DateTime? takenAt,
    int? gradientIndex,
    String? caption,
    String? file,
    String? thumb,
    String? placeId,
    bool clearPlace = false,
    String? name,
    String? kind,
    int? durationMs,
  }) =>
      PhotoItem(
        id: id,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        takenAt: takenAt ?? this.takenAt,
        gradientIndex: gradientIndex ?? this.gradientIndex,
        caption: caption ?? this.caption,
        file: file ?? this.file,
        thumb: thumb ?? this.thumb,
        placeId: clearPlace ? null : (placeId ?? this.placeId),
        name: name ?? this.name,
        kind: kind ?? this.kind,
        durationMs: durationMs ?? this.durationMs,
      );
}

/// 片区（聚类簇）：成员、色环配色与覆盖范围
class ClusterZone {
  const ClusterZone({
    required this.id,
    required this.label,
    required this.colorValue,
    required this.memberIds,
    required this.center,
    required this.radiusMeters,
    this.isolated = false,
  });

  final String id;
  final String label;
  final int colorValue;

  final List<String> memberIds;
  final LatLng center;
  final double radiusMeters;

  /// 孤立点成簇（不参与片区间衔接线）
  final bool isolated;

  Color get color => Color(colorValue);

  ClusterZone copyWithRadius(double r) => ClusterZone(
        id: id,
        label: label,
        colorValue: colorValue,
        memberIds: memberIds,
        center: center,
        radiusMeters: r,
        isolated: isolated,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'color': colorValue,
        'members': memberIds,
        'center': [center.latitude, center.longitude],
        'radiusMeters': radiusMeters,
        'isolated': isolated,
      };

  factory ClusterZone.fromJson(dynamic raw) {
    final j = (raw as Map).cast<String, dynamic>();

    final centerRaw = j['center'] as List?;
    final center = (centerRaw != null && centerRaw.length >= 2)
        ? LatLng((centerRaw[0] as num).toDouble(),
            (centerRaw[1] as num).toDouble())
        : const LatLng(0, 0);
    return ClusterZone(
      id: (j['id'] as String?) ?? newId('zn'),
      label: (j['label'] as String?) ?? '片区',
      colorValue: (j['color'] as num?)?.toInt() ?? 0xFF1E88E5,
      memberIds: [
        for (final e in (j['members'] as List? ?? const [])) e as String,
      ],
      center: center,
      radiusMeters: (j['radiusMeters'] as num?)?.toDouble() ?? 5000,
      isolated: j['isolated'] as bool? ?? false,
    );
  }
}

/// 离线瓦片包（初版展示占位）
class TilePack {
  const TilePack({
    required this.id,
    required this.name,
    required this.sourceId,
    required this.bboxLabel,
    required this.zoomMin,
    required this.zoomMax,
    required this.tileCount,
    required this.sizeMb,
    this.centerLat,
    this.centerLng,
    this.completedAt,
    this.ext = 'png',
  });

  final String id;
  final String name;
  final String sourceId;
  final String bboxLabel;
  final int zoomMin;
  final int zoomMax;
  final int tileCount;
  final double sizeMb;

  /// 范围中心（WGS-84），创建向导据此做「所在区域已有离线包」真实检查
  final double? centerLat;
  final double? centerLng;
  final DateTime? completedAt;

  /// 瓦片文件扩展名（矢量源 png / 卫星源 jpg；Provider 按此取本地文件）
  final String ext;

  /// packId（无 'pack:' 前缀）
  static String packKey(String id) => 'pack:$id';

  /// guide.sourceId 中解析出的 packId；非离线源返回 null
  static String? parsePackId(String sourceId) =>
      sourceId.startsWith('pack:') ? sourceId.substring(5) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sourceId': sourceId,
        'bboxLabel': bboxLabel,
        'zoomMin': zoomMin,
        'zoomMax': zoomMax,
        'tileCount': tileCount,
        'sizeMb': sizeMb,
        'centerLat': centerLat,
        'centerLng': centerLng,
        'completedAt': completedAt?.toIso8601String(),
        'ext': ext,
      };

  factory TilePack.fromJson(dynamic raw) {
    final j = (raw as Map).cast<String, dynamic>();
    return TilePack(
      id: (j['id'] as String?) ?? newId('tp'),
      name: (j['name'] as String?) ?? '未命名地图包',
      sourceId: (j['sourceId'] as String?) ?? 'osm',
      bboxLabel: (j['bboxLabel'] as String?) ?? '',
      zoomMin: (j['zoomMin'] as num?)?.toInt() ?? 3,
      zoomMax: (j['zoomMax'] as num?)?.toInt() ?? 17,
      tileCount: (j['tileCount'] as num?)?.toInt() ?? 0,
      sizeMb: (j['sizeMb'] as num?)?.toDouble() ?? 0,
      centerLat: (j['centerLat'] as num?)?.toDouble(),
      centerLng: (j['centerLng'] as num?)?.toDouble(),
      completedAt: DateTime.tryParse(j['completedAt'] as String? ?? ''),
      ext: (j['ext'] as String?) ?? 'png',
    );
  }
}
