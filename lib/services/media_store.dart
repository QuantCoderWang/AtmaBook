import 'dart:typed_data';

import '../core/io/storage_adapter.dart';
import 'package:image/image.dart' as img;

/// 媒体缓存：相对路径 → 字节的进程级内存镜像。
/// UI 统一通过 [MediaStore.cacheBytes] 同步取图，miss 时用 [load] 异步填充。
class MediaCache {
  static final Map<String, Uint8List> _map = {};

  static Uint8List? bytesFor(String rel) => _map[rel];

  static void put(String rel, Uint8List bytes) => _map[rel] = bytes;

  static void evict(String rel) => _map.remove(rel);
}

/// 图片入系统方式与读取：
/// - 标记图片：`pics/<guideId>/m_<内容哈希>.<ext>`（内容使用哈希值天然去重，避免导入相同图片）；
/// - 自定义 Pin 图标：`pics/icons/i_<内容哈希>.<ext>`；
/// - 桌面真实文件；Web 降级偏好设置/内存（≤1MB 可跨会话）。
class MediaStore {
  /// 异步读取（结果入缓存；视频原件 pics/videos/ 不入镜像——播放走文件路径，
  /// 防大文件撑爆内存缓存）
  static Future<Uint8List?> load(String rel) async {
    final cached = MediaCache.bytesFor(rel);
    if (cached != null) return cached;
    try {
      final bytes = await activeStorage.readBytes(rel);
      if (bytes != null && !rel.startsWith('pics/videos/')) {
        MediaCache.put(rel, bytes);
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// 同步取（未命中返回 null；调用方需自行异步 load）
  static Uint8List? cacheBytes(String? rel) =>
      rel == null ? null : MediaCache.bytesFor(rel);

  /// 保存标记位置图片，返回相对路径；相同内容自动命中同一文件
  static Future<String> savePlaceImage(String guideId, Uint8List bytes) =>
      _save('pics/$guideId', 'm', bytes);

  /// 保存自定义 Pin 图标（全局 icon 目录）
  static Future<String> savePinIcon(Uint8List bytes) =>
      _save('pics/icons', 'i', bytes);

  /// 照片墙原图（内容哈希命名，同内容天然去重）
  static Future<String> savePhotowallImage(Uint8List bytes) =>
      _save('pics/photowall', 'p', bytes);

  /// 照片墙缩略图
  static Future<String> savePhotowallThumb(Uint8List bytes) =>
      _save('pics/photowall/thumbs', 't', bytes);

  /// 视频首帧缩略图（JPEG，与照片缩略同规格同目录 —— 复用全部取图缓存链）
  static Future<String> saveVideoThumb(Uint8List bytes) =>
      _save('pics/photowall/thumbs', 't', bytes);

  /// 解码原图并生成 ≤512px JPEG 缩略图（`image` 包；解码失败返回空串 → UI 回退占位）
  static Future<String> makeWallThumb(Uint8List bytes) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return '';
      final longest = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      var out = decoded;
      if (longest > 512) {
        final scale = 512 / longest;
        out = img.copyResize(
          decoded,
          width: (decoded.width * scale).round(),
          height: (decoded.height * scale).round(),
          interpolation: img.Interpolation.average,
        );
      }
      final jpg = img.encodeJpg(out, quality: 82);
      return await savePhotowallThumb(Uint8List.fromList(jpg));
    } catch (_) {
      return '';
    }
  }

  static Future<String> _save(String dir, String prefix, Uint8List bytes) async {
    final name = '${prefix}_${_fnv1a(bytes)}${_extension(bytes)}';
    final rel = '$dir/$name';
    try {
      await activeStorage.writeBytes(rel, bytes);
    } catch (_) {
      // Web 大文件时机降级为仅内存缓存，非web环境下用不上，仅为测试期使用，不需要可删除
    }
    MediaCache.put(rel, bytes);
    return rel;
  }

  /// 删除（同步清缓存；文件删除失败静默）
  static Future<void> deleteImage(String rel) async {
    MediaCache.evict(rel);
    try {
      await activeStorage.deleteFile(rel);
    } catch (_) {}
  }

  static String _extension(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return '.jpg';
    }
    if (bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50) {
      return '.png';
    }
    if (bytes.length >= 4 && bytes[0] == 0x52 && bytes[1] == 0x49) {
      return '.webp';
    }
    return '.gif';
  }
}

/// FNV-1a 32 位内容哈希（快速、无需依赖 crypto 包）
int _fnv1a(Uint8List bytes) {
  const int prime = 0x01000193;
  int hash = 0x811C9DC5;
  final step = bytes.length > 2048 ? bytes.length ~/ 2048 : 1;
  for (var i = 0; i < bytes.length; i += step) {
    hash ^= bytes[i];
    hash = (hash * prime) & 0xFFFFFFFF;
  }
  return hash;
}
