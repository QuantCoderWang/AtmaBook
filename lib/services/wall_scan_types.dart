import 'dart:math' as math;
import 'dart:typed_data';

import '../../data/models/guide.dart';
import '../core/i18n_service.dart';

/// 目录扫描结果候选（字节列表 + 提示）：
/// 扫描层只负责字节读取；EXIF/去重/缩略图/归属统一由 WallPhotoService 执行。
class WallFolderCandidates {
  const WallFolderCandidates({this.payloads = const [], this.note = ''});

  /// 读到的照片字节（读取失败为空列表 + note 说明）
  final List<Uint8List> payloads;

  /// 非空 = 读取失败说明（如目录不存在、Web 不支持）
  final String note;

  bool get ok => note.isEmpty;
}

typedef ReadFolderPhotoCandidates = Future<WallFolderCandidates> Function(
  String dirPath, {
  required int limit,
});

/// 目录扫描报告
class WallScanReport {
  WallScanReport({
    required this.ok,
    required this.message,
    this.imported = 0,
    this.duplicates = 0,
    this.noGps = 0,
    this.assigned = 0,
    this.full = false,
    required this.cap,
  });

  final bool ok;
  final String message;
  final int imported;
  final int duplicates;
  final int noGps;
  final int assigned;
  final bool full;
  final int cap;

  String get banner {
    if (!ok) return message;
    final t = I18nService.t;
    var s = t.autoImportStats(imported, duplicates);
    if (noGps > 0) s += t.noGpsTail(noGps);
    if (assigned > 0) s += t.assignedTail(assigned);
    if (full) {
      s += t.capAdjustTail(cap);
    }
    return s;
  }
}

/// 就近归属（有 GPS 且距某攻略最近标记 ≤5km → guideId；否则 null）
String? assignGuideByNearest(double? lat, double? lng, List<Guide> guides) {
  if (lat == null || lng == null) return null;
  String? best;
  var bestD = 5000.0;
  for (final g in guides) {
    for (final m in g.markers) {
      final d = distM(lat, lng, m.lat, m.lng);
      if (d < bestD) {
        bestD = d;
        best = g.id;
      }
    }
  }
  return best;
}

/// 半正弦球面距离（米）
double distM(double la1, double lo1, double la2, double lo2) {
  const r = 6371000.0;
  final rad = math.pi / 180;
  final dLa = (la2 - la1) * rad;
  final dLo = (lo2 - lo1) * rad;
  final a = math.pow(math.sin(dLa / 2), 2) +
      math.cos(la1 * rad) *
          math.cos(la2 * rad) *
          math.pow(math.sin(dLo / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}
