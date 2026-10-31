import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../core/i18n_service.dart';
import '../core/utils/ids.dart';
import '../core/utils/exif_gps.dart';
import '../data/models/guide.dart';
import 'media_store.dart';

/// 导入结果统计
class PhotoImportReport {
  int imported = 0;
  int located = 0; // 有 GPS
  int noGps = 0; // 无定位（进未定位栏，可手动绑定）
  int duplicates = 0; // 内容与已有照片重复
  final List<PhotoItem> created = [];

  String get banner {
    final t = I18nService.t;
    return '${t.photoImportStats(imported, located, noGps)}'
        '${duplicates > 0 ? t.photoDupTail(duplicates) : ''}';
  }
}

/// 照片导入操作顺序：
/// 1. EXIF 白名单解析（GPS + DateTimeOriginal）；
/// 2. 原图内容哈希化（重复内容不再新增文件，与已有照片重复计入 duplicates）；
/// 3. `image` 包生成 ≤512px JPEG 缩略图；
/// 4. 有 GPS 时自动绑定 300m 内最近的标记（如有错误可手动修改）。
class PhotoImportService {
  PhotoImportService(this.guide, {this.bindMeters = 300});

  final Guide guide;

  /// 就近自动绑定阈值（米）
  final double bindMeters;

  /// 批量导入原始字节
  Future<PhotoImportReport> import(List<Uint8List> payloads) async {
    final report = PhotoImportReport();
    final taken = <PhotoItem>[];
    for (final bytes in payloads) {
      if (bytes.isEmpty) continue;

      final exif = parseExif(bytes);
      final rel = await MediaStore.savePhotowallImage(bytes);

      // 内容哈希去重：同一张（同字节）再次导入不重复落库
      if (guide.photos.any((p) => p.file == rel) ||
          taken.any((p) => p.file == rel)) {
        report.duplicates++;
        continue;
      }

      final thumbRel = await _makeThumb(bytes);

      // 自动绑定：有 GPS 且 300m 内有标记
      String? placeId;
      final hasGps = exif.hasLocation;
      if (hasGps) {
        placeId = _nearestPlace(exif.lat!, exif.lng!);
      }

      taken.add(PhotoItem(
        id: newId('ph'),
        lat: exif.lat,
        lng: exif.lng,
        takenAt: exif.takenAt ?? DateTime.now(),
        gradientIndex: guide.photos.length + taken.length,
        file: rel,
        thumb: thumbRel,
        placeId: placeId,
      ));
      report.imported++;
      hasGps ? report.located++ : report.noGps++;
    }
    report.created.addAll(taken);
    return report;
  }

  /// 最近标记（未超阈值则返回 null）
  String? _nearestPlace(double lat, double lng) {
    String? best;
    var bestM = bindMeters;
    for (final p in guide.markers) {
      final m = _distM(lat, lng, p.lat, p.lng);
      if (m < bestM) {
        bestM = m;
        best = p.id;
      }
    }
    return best;
  }

  /// 半正弦球面距离（米）
  double _distM(double la1, double lo1, double la2, double lo2) {
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
}

Future<String> _makeThumb(Uint8List bytes) async {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return '';
    var decodedImage = decoded;
    final longest = decodedImage.width > decodedImage.height
        ? decodedImage.width
        : decodedImage.height;
    if (longest > 512) {
      final scale = 512 / longest;
      decodedImage = img.copyResize(
        decodedImage,
        width: (decodedImage.width * scale).round(),
        height: (decodedImage.height * scale).round(),
        interpolation: img.Interpolation.average,
      );
    }
    final jpg = img.encodeJpg(decodedImage, quality: 82);
    return await MediaStore.savePhotowallThumb(Uint8List.fromList(jpg));
  } catch (_) {
    return '';
  }
}
