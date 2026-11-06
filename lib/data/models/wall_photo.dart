import '../../core/utils/ids.dart';
import '../../core/utils/thumb_binding.dart';
import '../../core/utils/wall_layout.dart';

/// 照片墙白板库照片/视频：
/// 全局数据 `data/wall_photos.json`，与各攻略内的 `Guide.photos` 互不影响
/// （攻略内照片的常规导入路径不变；白板墙在此基础上汇聚展示）。
/// 视频条目（kind='video'）只从地理相册插入：没有 EXIF GPS，入册后
/// 在查看器手动点选地图补写地理位置（同照片补位流程），归属按就近规则。
class WallPhoto {
  const WallPhoto({
    required this.id,
    required this.takenAt,
    this.lat,
    this.lng,
    this.guideId,
    this.file = '',
    this.thumb = '',
    this.name = '',
    this.kind = 'photo',
    this.durationMs = 0,
  });

  final String id;

  /// EXIF GPS（无定位=null，白板上落空位，可绑定标记补位）
  final double? lat;
  final double? lng;

  /// 归属攻略（定位照片按就近 5km 规则自动归；未归属=null）
  final String? guideId;
  final DateTime takenAt;

  /// 原图 / 缩略图相对路径
  final String file;
  final String thumb;
  final String name;

  /// 媒体类型：'photo'（默认，旧数据缺键兼容）/'video'（需手动补定位）
  final String kind;

  /// 视频时长（毫秒；照片恒 0）
  final int durationMs;

  bool get hasGps => lat != null && lng != null;
  bool get isVideo => kind == 'video';

  /// 缩略图配对（规则见 `core/utils/thumb_binding.dart`）
  String get thumbBinding =>
      resolveThumbBinding(isVideo: isVideo, thumb: thumb, file: file);

  Map<String, dynamic> toJson() => {
        'id': id,
        'takenAt': takenAt.toIso8601String(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (guideId != null) 'guideId': guideId,
        'file': file,
        'thumb': thumb,
        'name': name,
        if (kind != 'photo') 'kind': kind,
        if (durationMs > 0) 'durationMs': durationMs,
      };

  factory WallPhoto.fromJson(dynamic raw) {
    final j = (raw as Map).cast<String, dynamic>();
    return WallPhoto(
      id: (j['id'] as String?) ?? newId('wp'),
      takenAt: DateTime.tryParse(j['takenAt'] as String? ?? '') ??
          DateTime.now(),
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      guideId: j['guideId'] as String?,
      file: (j['file'] as String?) ?? '',
      thumb: (j['thumb'] as String?) ?? '',
      name: (j['name'] as String?) ?? '',
      kind: (j['kind'] as String?) ?? 'photo',
      durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
    );
  }

  WallPhoto copyWith({
    double? lat,
    double? lng,
    String? guideId,
    DateTime? takenAt,
    String? file,
    String? thumb,
    String? name,
    String? kind,
    int? durationMs,
  }) =>
      WallPhoto(
        id: id,
        takenAt: takenAt ?? this.takenAt,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        guideId: guideId ?? this.guideId,
        file: file ?? this.file,
        thumb: thumb ?? this.thumb,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        durationMs: durationMs ?? this.durationMs,
      );
}

/// 单张贴片记录（年墙快照用：坐标 + 倾斜 + 尺寸档）
class WallPos {
  const WallPos({
    required this.x,
    required this.y,
    required this.angleDeg,
    required this.sizeIndex,
  });

  final double x; // 0..1（白板横向比例）
  final double y; // 0..1（白板纵向比例）
  final double angleDeg;
  final int sizeIndex;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'a': angleDeg,
        's': sizeIndex,
      };

  factory WallPos.fromJson(dynamic raw) {
    final j = (raw as Map).cast<String, dynamic>();
    return WallPos(
      x: (j['x'] as num?)?.toDouble() ?? 0.5,
      y: (j['y'] as num?)?.toDouble() ?? 0.5,
      angleDeg: (j['a'] as num?)?.toDouble() ?? 0,
      sizeIndex: (j['s'] as num?)?.toInt() ?? 1,
    );
  }

  factory WallPos.fromPlacement(WallPlacement p) => WallPos(
        x: p.x,
        y: p.y,
        angleDeg: p.angleDeg,
        sizeIndex: p.sizeIndex,
      );
}

/// 一个地理团在年墙快照里的记录（含当年成员；簇心保留）
class WallClusterRecord {
  const WallClusterRecord({
    required this.id,
    this.lat,
    this.lng,
    this.members = const [],
  });

  final String id;
  final double? lat;
  final double? lng;
  final List<String> members;

  Map<String, dynamic> toJson() => {
        'id': id,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'members': members,
      };

  factory WallClusterRecord.fromJson(dynamic raw) {
    final j = (raw as Map).cast<String, dynamic>();
    return WallClusterRecord(
      id: (j['id'] as String?) ?? '',
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      members: [
        for (final m in (j['members'] as List? ?? const [])) m as String,
      ],
    );
  }
}

/// 年度照片墙：
/// 汇聚生成墙时按拍摄年分组快照——当年照片 uid + 各自贴片摆放 + 地理团划分。
class WallYearRecord {
  const WallYearRecord({
    required this.year,
    this.placements = const {},
    this.clusters = const [],
  });

  final int year;

  /// uid → 摆放（x/y/角度/尺寸档）
  final Map<String, WallPos> placements;

  /// 当年涉及的地理团（members 为当年成员子集）
  final List<WallClusterRecord> clusters;

  Map<String, dynamic> toJson() => {
        'year': year,
        'placements': {
          for (final e in placements.entries) e.key: e.value.toJson(),
        },
        'clusters': [for (final c in clusters) c.toJson()],
      };

  factory WallYearRecord.fromJson(dynamic raw) {
    final j = (raw as Map).cast<String, dynamic>();
    final pl = (j['placements'] as Map? ?? {}).cast<String, dynamic>();
    return WallYearRecord(
      year: (j['year'] as num?)?.toInt() ?? 0,
      placements: {
        for (final e in pl.entries) e.key: WallPos.fromJson(e.value),
      },
      clusters: [
        for (final c in (j['clusters'] as List? ?? const []))
          WallClusterRecord.fromJson(c),
      ],
    );
  }
}
