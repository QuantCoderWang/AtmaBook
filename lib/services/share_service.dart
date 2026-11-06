import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' as ar;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/i18n_service.dart';
import '../core/io/storage_adapter.dart';
import '../core/utils/ids.dart';
import '../data/models/guide.dart';
import '../data/models/wall_photo.dart';
import 'ffmpeg_runner.dart';
import 'share_download.dart';
import 'share_temp.dart' as share_temp;
import 'video_transcoder.dart';
import 'watermark.dart';

/// 攻略分享服务：导出、导入、视频、原片。
///
/// 导出一个 `.tgshare`（ZIP）：manifest.json、guide.json、cover.jpg，
/// 以及 photos/、thumbs/、images/、videos/ 和 videos.json；导入时全量重映射 id。
/// 图片按水印模式缩放，视频转 ≤720p 再叠水印；原片模式按原件字节入包。
/// 指纹取 FNV-1a64(guide.json UTF-8)，导入时用来查重。
/// 读取端兼容旧版本格式。
class ShareService {
  ShareService(this.storage);

  final StorageAdapter storage;

  static const format = 'tgshare';
  static const formatVersion = 3;

  /// 原片包体积上限（1 GB；按字节算，和文件管理器显示的一致）
  static const originalCapBytes = 1024 * 1024 * 1024;

  /// 构建 .tgshare 字节。
  /// [videos]：本文攻略的视频条目（账本中 guideId 命中者，导出弹窗负责筛选）；
  /// [policy]：watermarked（默认，副本降质 + 烧录水印）/ original（原片字节
  /// 直接入包，不缩放不转码不加水印；受 [originalCapBytes] 硬上限约束，超限由
  /// 导出弹窗先「剔除条目 / 降质」后再调进，进入本函数即要求已达标）。
  /// [excludeIds]：照片/视频挑选后剔除的条目 id 集合（原片模式筛选栏）；
  /// [degrade]：原片模式超限后的降质档（副本在内存合成，原图文件不落副本不被更改）。
  /// [onProgress]：done/total/label 逐项回调；[isCancelled] 返回 true 即中止（返回 null）。
  Future<ShareExportResult?> build({
    required Guide guide,
    required bool includePhotos,
    required String watermarkText,
    List<WallPhoto> videos = const <WallPhoto>[],
    ShareExportPolicy policy = ShareExportPolicy.watermarked,
    Set<String> excludeIds = const <String>{},
    ShareExportDegrade degrade = ShareExportDegrade.none,
    List<PhotoItem> extraPhotos = const <PhotoItem>[],
    void Function(int done, int total, String label)? onProgress,
    bool Function()? isCancelled,
  }) async {
    // 账本归属照片合并：经地理相册归属进攻略的照片不会写入 Guide.photos
    // （账本 guideId 绑定），分享时需显式注入：进 guide.json（接收端照常
    // 全量重映射落盘）+ 进媒体条目循环；id 冲突的条目跳过，保证幂等。
    final knownIds = {for (final p in guide.photos) p.id};
    final mergedExtras = [
      for (final p in extraPhotos)
        // add 返回 false = 已存在（攻略内重复 / extraPhotos 列表内部重复）
        if (p.file.isNotEmpty && knownIds.add(p.id)) p,
    ];
    final exportGuide = mergedExtras.isEmpty
        ? guide
        : guide.copyWith(photos: [...guide.photos, ...mergedExtras]);
    if (policy == ShareExportPolicy.original) {
      return _buildOriginal(
        guide: exportGuide,
        includePhotos: includePhotos,
        videos: videos,
        excludeIds: excludeIds,
        degrade: degrade,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    }
    final photos = includePhotos
        ? [
            for (final p in exportGuide.photos)
              if (p.file.isNotEmpty && !excludeIds.contains(p.id)) p,
          ]
        : const <PhotoItem>[];
    final videoItems = includePhotos
        ? [
            for (final v in videos)
              if (v.file.isNotEmpty && !excludeIds.contains(v.id)) v,
          ]
        : const <WallPhoto>[];
    // 每条视频权重 11：转码 10（按帧进度细分）+ 缩略 1
    final items = photos.length * 2 +
        (guide.coverImage != null ? 1 : 0) +
        2 +
        videoItems.length * 11;
    var done = 0;
    void tick(String label) {
      done++;
      onProgress?.call(done, items, label);
    }

    // guide.json 与指纹（指纹 = 剥离时间戳的 guide 内容
    //     + 视频锚段（id+内容哈希，排序后拼串）；视频增删/换件都会换代）——
    final guideJson = jsonEncode(exportGuide.toJson());
    final fingerprint = fingerprintOf(exportGuide, videos: videoItems);
    tick(I18nService.t.progStructured);

    final manifest = jsonEncode({
      'format': format,
      'formatVersion': formatVersion,
      'fingerprint': fingerprint,
      'policy': 'watermarked',
      'sourceGuideId': guide.id,
      'exportedAt': DateTime.now().toIso8601String(),
      'watermarkText': watermarkText,
      'includesPhotos': includePhotos,
      'counts': {
        'markers': guide.markers.length,
        'photos': photos.length,
        'videos': videoItems.length,
        'clusters': guide.clusters.length,
        'images': includePhotos
            ? guide.markers.fold<int>(0, (n, m) => n + m.images.length)
            : 0,
      },
    });
    tick(I18nService.t.progManifest);

    final archive = ar.Archive();
    archive.addFile(ar.ArchiveFile.string('manifest.json', manifest));
    archive.addFile(ar.ArchiveFile.string('guide.json', guideJson));
    var skipped = 0;

    final coverRel = guide.coverImage;
    if (coverRel != null && coverRel.isNotEmpty) {
      final src = await _bytesOf(coverRel);
      if (src != null) {
        final out = await WatermarkComposer.compose(
          srcBytes: src,
          text: watermarkText,
          maxSide: 1280,
          quality: 78,
        );
        if (out != null) {
          archive.addFile(ar.ArchiveFile.bytes('cover.jpg', out));
          tick(I18nService.t.progCover);
        } else {
          skipped++;
        }
      } else {
        skipped++;
      }
    }

    // 照片 + 缩略（视频条目在下方单独转码）
    for (final p in photos.where((p) => !p.isVideo)) {
      if (isCancelled?.call() ?? false) return null;
      final src = await _bytesOf(p.file);
      if (src != null) {
        final out = await WatermarkComposer.compose(
          srcBytes: src,
          text: watermarkText,
          maxSide: 960,
          quality: 72,
        );
        if (out != null) {
          archive.addFile(ar.ArchiveFile.bytes('photos/${p.id}.jpg', out));
        } else {
          skipped++;
        }
      } else {
        skipped++;
      }
      tick(I18nService.t
          .progPhoto(p.name.isNotEmpty ? p.name : p.id));

      final thumbSrc = p.thumb.isNotEmpty ? await _bytesOf(p.thumb) : null;
      Uint8List? thumbOut;
      if (thumbSrc != null) {
        thumbOut = await WatermarkComposer.compose(
          srcBytes: thumbSrc,
          text: watermarkText,
          maxSide: 256,
          quality: 70,
        );
      }
      if (thumbOut == null && src != null) {
        // 无缩略文件时从副本原图降采样兜底
        thumbOut = await WatermarkComposer.compose(
          srcBytes: src,
          text: watermarkText,
          maxSide: 256,
          quality: 70,
        );
      }
      if (thumbOut != null) {
        archive.addFile(ar.ArchiveFile.bytes('thumbs/${p.id}.jpg', thumbOut));
      } else {
        skipped++;
      }
      tick(I18nService.t
          .progThumb(p.name.isNotEmpty ? p.name : p.id));
    }

    // 标记插图（攻略中插入的照片）：images/<mkId>_<index>.jpg
    if (includePhotos) {
      for (final m in guide.markers) {
        for (var i = 0; i < m.images.length; i++) {
          if (isCancelled?.call() ?? false) return null;
          final src = await _bytesOf(m.images[i]);
          if (src == null) {
            skipped++;
          } else {
            final out = await WatermarkComposer.compose(
              srcBytes: src,
              text: watermarkText,
              maxSide: 960,
              quality: 72,
            );
            if (out == null) {
              skipped++;
            } else {
              archive.addFile(
                  ar.ArchiveFile.bytes('images/${m.id}_$i.jpg', out));
            }
          }
          tick(I18nService.t.progImage(m.title));
        }
      }
    }

    // 视频：≤720p 转码 + 整版平铺水印一次性烧录
    final videosJson = <Map<String, dynamic>>[];
    for (final v in videoItems) {
      if (isCancelled?.call() ?? false) return null;
      final label = v.name.isNotEmpty ? v.name : v.id;
      final src = await _bytesOf(v.file);
      if (src != null) {
        final base = done;
        var last = -1;
        final out = await VideoTranscoder.transcode(
          absInputPath: storage.absolutePath(v.file),
          watermarkText: watermarkText,
          onProgress: (frac) {
            final cur = (frac * 10).round();
            if (cur != last) {
              last = cur;
              onProgress?.call(
                  (base + cur).clamp(0, items).toInt(), items,
                  I18nService.t.progTranscode(label));
            }
          },
          isCancelled: isCancelled,
        );
        if (out != null) {
          archive.addFile(ar.ArchiveFile.bytes('videos/${v.id}.mp4', out));
          videosJson.add({
            'id': v.id,
            if (v.lat != null) 'lat': v.lat,
            if (v.lng != null) 'lng': v.lng,
            'takenAt': v.takenAt.toIso8601String(),
            'name': v.name,
            if (v.durationMs > 0) 'durationMs': v.durationMs,
          });
        } else {
          skipped++;
        }
      } else {
        skipped++;
      }
      done += 10; // 转码段权重收口（无论成败）
      onProgress?.call(done, items, I18nService.t.progVideo(label));

      // 缩略：第 11 权重位
      Uint8List? thumbOut;
      final thumbSrc = v.thumb.isNotEmpty ? await _bytesOf(v.thumb) : null;
      if (thumbSrc != null) {
        thumbOut = await WatermarkComposer.compose(
          srcBytes: thumbSrc,
          text: watermarkText,
          maxSide: 256,
          quality: 70,
        );
      }
      if (thumbOut == null) {
        // 无账本缩略 → 从原视频重提首帧再缩
        final frame = await FFmpegRunner.extractFirstFrame(
            storage.absolutePath(v.file));
        if (frame != null) {
          thumbOut = await WatermarkComposer.compose(
            srcBytes: frame,
            text: watermarkText,
            maxSide: 256,
            quality: 70,
          );
        }
      }
      if (thumbOut != null) {
        archive.addFile(ar.ArchiveFile.bytes('thumbs/${v.id}.jpg', thumbOut));
      }
      tick(I18nService.t.progThumb(label));
    }
    if (videosJson.isNotEmpty) {
      archive.addFile(ar.ArchiveFile.string(
          'videos.json', jsonEncode(videosJson)));
    }

    final zip = Uint8List.fromList(ar.ZipEncoder().encode(archive));
    return ShareExportResult(
      filename: '${safeName(guide.title)}-'
          '${dateStamp(DateTime.now())}.tgshare',
      bytes: zip,
      fingerprint: fingerprint,
      photoCount: photos.length,
      videoCount: videosJson.length,
      skippedCount: skipped,
      includesPhotos: includePhotos,
    );
  }

  /// 输出到平台分享位置（桌面=下载目录；Web=浏览器下载），返回可读路径描述。
  /// 原片模式的流式产物经 tempPath 搬移（目标位置写完即删临时文件——
  /// 临时目录内的“副本”不留残留）。
  Future<String> saveExported(ShareExportResult result) async {
    if (result.tempPath != null) {
      return saveShareFileAt(result.filename, result.tempPath!);
    }
    return saveShareFile(result.filename, result.bytes);
  }

  // ================= 导入链 =================

  /// 解析 .tgshare 字节 → 校验白名单条目 / manifest / guide.json。
  /// 任何不合法（非 ZIP、未知条目、版本不符、guide 解析失败）返回 null。
  static ShareParseResult? parseShare(Uint8List bytes) {
    // ZIP 魔数 PK\x03\x04（快速拒绝非压缩包）
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) return null;
    try {
      final archive = ar.ZipDecoder().decodeBytes(bytes);
      final entries = <String, Uint8List>{};
      for (final f in archive.files) {
        if (!f.isFile) continue;
        final name = f.name;
        if (!_entrySafe(name)) return null; // 白名单外条目 → 拒收
        entries[name] = Uint8List.fromList(f.readBytes() ?? const []);
      }
      if (!entries.containsKey('manifest.json') ||
          !entries.containsKey('guide.json')) {
        return null;
      }
      final manifest =
          jsonDecode(utf8.decode(entries['manifest.json']!)) as Map;
      if (manifest['format'] != format) return null;
      // formatVersion 范围 1–3；v2 起含 videos/，v3 为原片包（policy 字段）。
      final vInt = (manifest['formatVersion'] as num?)?.toInt() ?? 0;
      if (vInt < 1 || vInt > formatVersion) {
        return null;
      }
      final guide = Guide.fromJson(jsonDecode(utf8.decode(
          entries['guide.json']!)));
      final videosRaw =
          (entries['videos.json'] != null)
              ? jsonDecode(utf8.decode(entries['videos.json']!))
              : null;
      // 封面条目：cover.jpg，原片模式可带原扩展名
      String? coverName;
      for (final ext in const ['jpg', ..._imgExts]) {
        final n = 'cover.$ext';
        if (entries.containsKey(n)) {
          coverName = n;
          break;
        }
      }
      return ShareParseResult(
        manifest: manifest,
        guide: guide,
        coverBytes: coverName != null ? entries[coverName] : null,
        coverName: coverName,
        entries: entries,
        fingerprint: (manifest['fingerprint'] as String?) ?? '',
        videosMeta: [
          for (final raw in (videosRaw as List? ?? const []))
            if (raw is Map) raw.cast<String, dynamic>(),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  /// 应用导入：全量重映射 id + 内部引用重写 + 图片落盘（经写队列原子写）。
  /// 返回可直接入库的新攻略与封面字节（供首页内存镜像立即可见）。
  /// [onProgress]：done/total/label 分阶段回调（正在生成地图 / 正在传入照片…）；
  /// [isCancelled] 为 true 时中止（返回 null），已落盘的半成品目录由调用方清理。
  Future<ShareImported?> applyImport(
    ShareParseResult parsed, {
    void Function(int done, int total, String label)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final src = parsed.guide;
    final entries = parsed.entries;
    final now = DateTime.now();
    final newGd = newId('gd');

    var step = 0;
    final totalSteps = (parsed.coverBytes != null ? 1 : 0) +
        src.markers.fold<int>(0, (n, m) => n + 1 + m.images.length) +
        src.photos.length * 2 +
        parsed.videosMeta.length * 3 +
        2; // 封面 + 标记(含插图) + 照片(副本+缩略) + 视频(传入+缩略+挂入) + 片区重建 + 入库
    void tick(String label) {
      step++;
      onProgress?.call(step, totalSteps, label);
    }

    bool cancelled() => isCancelled?.call() ?? false;

    // id 映射表
    final mkMap = <String, String>{for (final m in src.markers) m.id: newId('mk')};
    final phMap = <String, String>{for (final p in src.photos) p.id: newId('ph')};
    final znMap = <String, String>{for (final z in src.clusters) z.id: newId('zn')};

    String? newCoverRel;
    final coverBytes = parsed.coverBytes;
    if (coverBytes != null) {
      if (cancelled()) return null;
      final coverExt = parsed.coverName != null &&
              parsed.coverName!.contains('.')
          ? parsed.coverName!.split('.').last.toLowerCase()
          : 'jpg';
      newCoverRel = 'pics/$newGd/cover.$coverExt';
      try {
        await storage.writeBytes(newCoverRel, coverBytes);
      } catch (_) {
        newCoverRel = null;
      }
      tick(I18nService.t.progWriteCover);
    }

    // 标记（含插图重映射）
    final newMarkers = <Place>[];
    for (final m in src.markers) {
      if (cancelled()) return null;
      final newMk = mkMap[m.id]!;
      final newImages = <String>[];
      for (var i = 0; i < m.images.length; i++) {
        final bytes = entries['images/${m.id}_$i.jpg'];
        if (bytes == null) continue; // 缺失插图 → 剔除（不破坏其余）
        final rel = 'pics/$newGd/shared/${newMk}_$i.jpg';
        try {
          await storage.writeBytes(rel, bytes);
          newImages.add(rel);
        } catch (_) {}
        tick(I18nService.t.progImportImage(m.title));
      }
      newMarkers.add(Place(
        id: newMk,
        title: m.title,
        categoryId: m.categoryId,
        lat: m.lat,
        lng: m.lng,
        mustVisit: m.mustVisit,
        description: m.description,
        images: newImages,
        links: m.links,
        colorValue: m.colorValue,
        iconPath: m.iconPath,
      ));
      tick(I18nService.t.progGenMap(m.title));
    }

    final newPhotos = <PhotoItem>[];
    for (final p in src.photos) {
      if (cancelled()) return null;
      final newPh = phMap[p.id]!;
      final label = p.name.isNotEmpty ? p.name : p.takenAt.toString().substring(0, 10);
      var file = '';
      var thumb = '';
      // 照片条目：多方言扩展名探测（原片模式保留原扩展名）
      final foundPhoto = _findEntry(entries, 'photos', p.id, _imgExts);
      final pt = entries['thumbs/${p.id}.jpg'];
      if (foundPhoto != null) {
        file = 'pics/$newGd/shared/$newPh.${foundPhoto.key}';
        try {
          await storage.writeBytes(file, foundPhoto.value);
        } catch (_) {
          file = '';
        }
      }
      tick(I18nService.t.progImportPhoto(label));
      if (pt != null) {
        thumb = 'pics/$newGd/shared/${newPh}_t.jpg';
        try {
          await storage.writeBytes(thumb, pt);
        } catch (_) {
          thumb = '';
        }
      }
      tick(I18nService.t.progGenThumb(label));
      newPhotos.add(PhotoItem(
        id: newPh,
        lat: p.lat,
        lng: p.lng,
        takenAt: p.takenAt,
        gradientIndex: p.gradientIndex,
        caption: p.caption,
        file: file,
        thumb: thumb,
        placeId: p.placeId != null ? mkMap[p.placeId] : null,
        name: p.name,
      ));
    }

    // 视频：直接挂进本攻略的照片列表，不写用户地理相册账本
    // （分享三默策略：shared 攻略的媒体不进接收方地理相册；同名视频条目按新 id 重映射）
    for (final meta in parsed.videosMeta) {
      if (cancelled()) return null;
      final name = (meta['name'] as String?) ?? '';
      final label = name.isNotEmpty ? name : I18nService.t.videoTypeGroup;
      final newPv = newId('pv');
      var file = '';
      var thumb = '';
      // 视频条目：多方言扩展名探测（原片模式保留原扩展名）
      final foundVideo = _findEntry(entries, 'videos', '${meta['id']}', _vidExts);
      final tb = entries['thumbs/${meta['id']}.jpg'];
      if (foundVideo != null) {
        file = 'pics/$newGd/shared/$newPv.${foundVideo.key}';
        try {
          await storage.writeBytes(file, foundVideo.value);
        } catch (_) {
          file = '';
        }
      }
      tick(I18nService.t.progImportVideo(label));
      if (tb != null) {
        thumb = 'pics/$newGd/shared/${newPv}_t.jpg';
        try {
          await storage.writeBytes(thumb, tb);
        } catch (_) {
          thumb = '';
        }
      }
      tick(I18nService.t.progGenThumb(label));
      if (file.isEmpty) continue; // 视频字节缺失 → 整条放弃（不占空壳位）
      newPhotos.add(PhotoItem(
        id: newPv,
        lat: (meta['lat'] as num?)?.toDouble(),
        lng: (meta['lng'] as num?)?.toDouble(),
        takenAt: DateTime.tryParse(meta['takenAt'] as String? ?? '') ?? now,
        gradientIndex: 0,
        caption: '',
        file: file,
        thumb: thumb,
        name: name,
        kind: 'video',
        durationMs: (meta['durationMs'] as num?)?.toInt() ?? 0,
      ));
      tick(I18nService.t.progAttachGuide(label));
    }

    // 片区（成员引用重写；悬空成员剔除）
    final newClusters = <ClusterZone>[];
    for (final z in src.clusters) {
      final members = [
        for (final old in z.memberIds)
          if (mkMap[old] != null) mkMap[old]!,
      ];
      newClusters.add(ClusterZone(
        id: znMap[z.id]!,
        label: z.label,
        colorValue: z.colorValue,
        memberIds: members,
        center: z.center,
        radiusMeters: z.radiusMeters,
        isolated: z.isolated,
      ));
    }
    tick(I18nService.t.progRebuildZones);

    final imported = Guide(
      id: newGd,
      title: src.title,
      summary: src.summary,
      region: src.region,
      sourceId: src.sourceId,
      createdAt: now,
      updatedAt: now,
      coverImage: newCoverRel,
      originName: src.originName,
      originLat: src.originLat,
      originLng: src.originLng,
      markers: newMarkers,
      photos: newPhotos,
      clusters: newClusters,
      settings: src.settings,
      shared: true,
      // 原片包（policy=original）导入 → 允许再次导出原片（备份链可延续）
      sharedOriginal: parsed.isOriginal,
      shareKey: parsed.fingerprint.isEmpty ? null : parsed.fingerprint,
    );
    tick(I18nService.t.progWriteLibrary);
    return ShareImported(guide: imported, coverBytes: coverBytes);
  }

  /// ZIP 条目白名单：仅允许信封固定文件与图片/视频三层目录，拒绝一切穿越。
  /// 原片模式：媒体条目保留原扩展名（常见图/视频扩展名白名单内）。
  static bool _entrySafe(String name) {
    if (name == 'manifest.json' ||
        name == 'guide.json' ||
        name == 'videos.json') {
      return true;
    }
    // 封面：固定名 cover.jpg，原片模式可带原扩展名
    if (RegExp(r'^cover\.(jpg|jpeg|png|webp|gif)$').hasMatch(name)) {
      return true;
    }
    // 视频条目：.mp4，原片模式保留导入时原扩展名
    final reVid =
        RegExp(r'^videos/[A-Za-z0-9_.-]+\.(mp4|mov|mkv|webm|avi|m4v)$');
    if (reVid.hasMatch(name)) return true;
    final re = RegExp(
        r'^(photos|thumbs|images)/[A-Za-z0-9_.-]+\.(jpg|jpeg|png|webp|gif)$');
    return re.hasMatch(name);
  }

  /// 按候选扩展名探测条目：返回 `(ext, bytes)`；不存在返回 null。
  /// 首选 jpg，其余按白名单顺序。
  static MapEntry<String, Uint8List>? _findEntry(
    Map<String, Uint8List> entries,
    String dir,
    String id,
    List<String> exts,
  ) {
    Uint8List? hitBytes;
    String? hitExt;
    for (final ext in exts) {
      final name = '$dir/$id.$ext';
      if (entries.containsKey(name)) {
        hitBytes = entries[name];
        hitExt = ext;
        break;
      }
    }
    if (hitBytes == null || hitExt == null) return null;
    return MapEntry(hitExt, hitBytes);
  }

  Future<Uint8List?> _bytesOf(String rel) async {
    try {
      return await storage.readBytes(rel);
    } catch (_) {
      return null;
    }
  }

  static String safeName(String title) {
    final t = title.trim().isEmpty ? I18nService.t.guideFallback : title.trim();
    final cleaned = t.replaceAll(
        RegExp(r'[\\/:*?"<>|]'), '_');
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  static String dateStamp(DateTime t) =>
      '${t.year}${t.month.toString().padLeft(2, '0')}'
      '${t.day.toString().padLeft(2, '0')}';

  // 原片导出链

  /// 相对路径 → 扩展名小写（无扩展名返回空串）
  static String _extOfRel(String rel) {
    final i = rel.lastIndexOf('.');
    return i < 0 ? '' : rel.substring(i + 1).toLowerCase();
  }

  /// 包内媒体条目允许的扩展名（原片模式保留原扩展名）
  static const _imgExts = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
  static const _vidExts = ['mp4', 'mov', 'mkv', 'webm', 'avi', 'm4v'];

  /// 原片高清包：媒体按原件字节直接入包（不缩放/不转码/不烧水印）。
  /// 流式实现：超限主因（视频原件）经 InputFileStream 逐块读入、ZIP 经
  /// OutputFileStream 写临时文件，超大文件不整驻内存；写完即交给
  /// saveExported 搬移至目标位置并清理临时目录（原图文件全程只读）。
  ///
  /// [degrade] 非 none 时：超过降质档长边的照片与封面/插图在内存中
  /// 合成降质副本（解析→缩放→JPEG，无水印），合成产物仅出现在包内——
  /// 原图文件不产生落盘副本。媒体条目缓存使用 CompressionType.none 存入
  /// （媒体已是压缩格式，deflate 只耗时间近乎无收益）。
  ///
  /// 进入本函数即默认调用方已把体积压回 [originalCapBytes] 以内；
  /// [onProgress] 沿用 done/total/label 分阶段回调，[isCancelled] 中止返回 null。
  Future<ShareExportResult?> _buildOriginal({
    required Guide guide,
    required bool includePhotos,
    required List<WallPhoto> videos,
    required Set<String> excludeIds,
    required ShareExportDegrade degrade,
    void Function(int done, int total, String label)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (kIsWeb) {
      throw StateError('原片打包模式不支持 Web（无文件系统）');
    }
    final t = I18nService.t;
    final photos = includePhotos
        ? [
            for (final p in guide.photos)
              if (p.file.isNotEmpty && !excludeIds.contains(p.id)) p,
          ]
        : const <PhotoItem>[];
    final videoItems = includePhotos
        ? [
            for (final v in videos)
              if (v.file.isNotEmpty && !excludeIds.contains(v.id)) v,
          ]
        : const <WallPhoto>[];

    final items = photos.length * 2 +
        (guide.coverImage != null ? 1 : 0) +
        2 +
        videoItems.length;
    var done = 0;
    bool cancelled() => isCancelled?.call() ?? false;
    void tick(String label) {
      done++;
      onProgress?.call(
          done.clamp(0, items).toInt(), items, label);
    }

    // guide.json 与指纹（和水印模式同一内容，两款包的指纹一致）
    final guideJson = jsonEncode(guide.toJson());
    final fingerprint = fingerprintOf(guide, videos: videoItems);
    tick(t.progStructured);

    final manifest = jsonEncode({
      'format': format,
      'formatVersion': formatVersion,
      'fingerprint': fingerprint,
      'policy': 'original',
      'sourceGuideId': guide.id,
      'exportedAt': DateTime.now().toIso8601String(),
      'watermarkText': '',
      'includesPhotos': includePhotos,
      'counts': {
        'markers': guide.markers.length,
        'photos': photos.length,
        'videos': videoItems.length,
        'images':
            [for (final m in guide.markers) m.images.length]
                .fold<int>(0, (a, b) => a + b),
      },
    });
    final manifestBytes = utf8.encode(manifest);
    tick(t.progManifest);

    // —— 临时目录：流式写 ZIP，失败或取消时统一清理 ——
    final workDir = await share_temp.createTempWorkDir('tgshare_orig');
    final tempZip = '$workDir/package.tgshare';
    final output = ar.OutputFileStream(tempZip, bufferSize: 1024 * 1024);
    final encoder = ar.ZipEncoder();
    encoder.startEncode(output);
    var failed = false;
    var skipped = 0;
    try {
      encoder.add(_bytesEntry('manifest.json', manifestBytes));
      encoder.add(_bytesEntry('guide.json', utf8.encode(guideJson)));

      // 封面：原片字节（降质档时在内存合成 ≤maxSide 的 JPEG 副本，
      //     条目名随之改为 cover.jpg 与内容一致）——
      final coverRel = guide.coverImage;
      if (coverRel != null && coverRel.isNotEmpty) {
        if (cancelled()) return null;
        final name = degrade.maxSide != null
            ? 'cover.jpg'
            : 'cover.${_extOfRel(coverRel)}';
        final added = await _addMediaEntry(
          encoder,
          name: name,
          rel: coverRel,
          degradeMaxSide: degrade.maxSide,
        );
        if (!added) skipped++;
        tick(t.progCover);
      }

      // 照片：photos/<id>.<原扩展名>，缩略固定为 thumbs/<id>.jpg（无水印）
      // 降质档输出恒为 JPEG → 条目名随之改 .jpg（与内容一致）
      for (final p in photos) {
        if (cancelled()) return null;
        final added = await _addMediaEntry(
          encoder,
          name: degrade.maxSide != null
              ? 'photos/${p.id}.jpg'
              : 'photos/${p.id}.${_extOfRel(p.file)}',
          rel: p.file,
          degradeMaxSide: degrade.maxSide,
        );
        if (!added) skipped++;
        tick(t.progPhoto(p.name.isNotEmpty ? p.name : p.id));

        // 缩略：优先复用已有 ≤512px 缩略文件（小图快），缺失再从原件降采样
        Uint8List? thumbOut;
        if (p.thumb.isNotEmpty) {
          thumbOut = await _thumbNoWm(p.thumb, maxSide: 256);
        }
        thumbOut ??= await _thumbNoWm(p.file, maxSide: 256);
        if (thumbOut != null) {
          encoder.add(
              (ar.ArchiveFile.bytes('thumbs/${p.id}.jpg', thumbOut)));
        } else {
          skipped++;
        }
        tick(t.progThumb(p.name.isNotEmpty ? p.name : p.id));
      }

      // 标记插图：images/<mkId>_<n>.<原扩展名>（和照片同一套规则）
      if (includePhotos) {
        for (final m in guide.markers) {
          for (var i = 0; i < m.images.length; i++) {
            if (cancelled()) return null;
            final added = await _addMediaEntry(
              encoder,
              name: degrade.maxSide != null
                  ? 'images/${m.id}_$i.jpg'
                  : 'images/${m.id}_$i.${_extOfRel(m.images[i])}',
              rel: m.images[i],
              degradeMaxSide: degrade.maxSide,
            );
            if (!added) skipped++;
            tick(t.progImage(m.title));
          }
        }
      }

      // 视频：videos/<id>.<原扩展名> 原件字节流式入包（不转码、不加水印；
      // ffmpeg 不可用（如 Android）也可完成——这正是原片模式的额外优势）——
      final videosJson = <Map<String, dynamic>>[];
      for (final v in videoItems) {
        if (cancelled()) return null;
        final label = v.name.isNotEmpty ? v.name : v.id;
        final ext = _extOfRel(v.file);
        final added = await _addStreamEntry(
          encoder,
          name: 'videos/${v.id}.$ext',
          rel: v.file,
        );
        if (added) {
          videosJson.add({
            'id': v.id,
            if (v.lat != null) 'lat': v.lat,
            if (v.lng != null) 'lng': v.lng,
            'takenAt': v.takenAt.toIso8601String(),
            'name': v.name,
            if (v.durationMs > 0) 'durationMs': v.durationMs,
          });
        } else {
          skipped++;
        }
        done++; // 原片模式视频权重 1（无转码段）
        onProgress?.call(
            done.clamp(0, items).toInt(), items, t.progVideo(label));

        // 缩略：优先已有首帧文件；缺失不依赖 ffmpeg（跳过，接收端降级占位）
        Uint8List? thumbOut;
        if (v.thumb.isNotEmpty) {
          thumbOut = await _thumbNoWm(v.thumb, maxSide: 256);
        }
        if (thumbOut != null) {
          encoder
              .add(ar.ArchiveFile.bytes('thumbs/${v.id}.jpg', thumbOut));
        }
        tick(t.progThumb(label));
      }
      if (videosJson.isNotEmpty) {
        encoder.add(_bytesEntry('videos.json', utf8.encode(
            jsonEncode(videosJson))));
      }
      if (cancelled()) return null;
      encoder.endEncode();
    } catch (_) {
      failed = true;
      rethrow;
    } finally {
      output.flush();
      output.closeSync();
      if (failed || _cancelledFlag(isCancelled)) {
        await share_temp.deleteTempWorkDir(workDir);
      }
    }

    int size = 0;
    try {
      size = await share_temp.fileSizeBytes(tempZip);
    } catch (_) {}

    return ShareExportResult(
      filename: '${safeName(guide.title)}-'
          '${dateStamp(DateTime.now())}.tgshare',
      bytes: Uint8List(0),
      tempPath: tempZip,
      fingerprint: fingerprint,
      photoCount: photos.length,
      videoCount: videoItems.length,
      skippedCount: skipped,
      includesPhotos: includePhotos,
      sizeOverrideBytes: size,
    );
  }

  bool _cancelledFlag(bool Function()? isCancelled) =>
      (isCancelled?.call() ?? false);

  /// 内存条目（deflate；小体量 JSON/缩略适用）
  ar.ArchiveFile _bytesEntry(String name, List<int> data) =>
      ar.ArchiveFile.bytes(name, Uint8List.fromList(data));

  /// 无水印缩略（≤maxSide JPEG）：合成失败返回 null（上层按缺失处理）
  Future<Uint8List?> _thumbNoWm(String rel, {required int maxSide}) async {
    final src = await _bytesOf(rel);
    if (src == null) return null;
    return WatermarkComposer.compose(
        srcBytes: src, text: '', maxSide: maxSide, quality: 70);
  }

  /// 媒体条目：优先原件流式（内存占用 O(1)）；降质档生效或流式不可用时
  /// 回退内存合成/内存字节。返回 false = 条目缺失（计入 skipped）。
  Future<bool> _addMediaEntry(
    ar.ZipEncoder encoder, {
    required String name,
    required String rel,
    required int? degradeMaxSide,
  }) async {
    // 降质档：内存合成 ≤maxSide 的 JPEG 副本（原图大于该档才需要缩放，
    // image 包的 compose 对小图也会重编码，统一走它省得分叉）
    if (degradeMaxSide != null) {
      final src = await _bytesOf(rel);
      if (src == null) return false;
      final out = await WatermarkComposer.compose(
          srcBytes: src,
          text: '',
          maxSide: degradeMaxSide,
          quality: ShareExportDegrade.high.maxSide == degradeMaxSide
              ? ShareExportDegrade.high.quality
              : ShareExportDegrade.small.quality);
      if (out == null) return false;
      encoder.add(ar.ArchiveFile.bytes(name, out));
      return true;
    }
    // 原件直通：文件系统可用 → 流式（超限主因视频大文件不驻内存）
    try {
      final abs = storage.absolutePath(rel);
      final stream = ar.InputFileStream(abs, bufferSize: 1024 * 1024);
      try {
        final entry = ar.ArchiveFile.stream(name, stream)
          ..compression = ar.CompressionType.none;
        encoder.add(entry, autoClose: true);
        return true;
      } catch (_) {
        stream.closeSync();
        // 流式失败（如内存存储测试桩）→ 回退内存字节
        final bytes = await _bytesOf(rel);
        if (bytes == null) return false;
        encoder.add(
            (ar.ArchiveFile.bytes(name, bytes)
              ..compression = ar.CompressionType.none));
        return true;
      }
    } on UnsupportedError {
      // Web/内存存储：无文件系统路径 → 内存字节直通
      final bytes = await _bytesOf(rel);
      if (bytes == null) return false;
      encoder.add(
          (ar.ArchiveFile.bytes(name, bytes)
            ..compression = ar.CompressionType.none));
      return true;
    } on StateError {
      final bytes = await _bytesOf(rel);
      if (bytes == null) return false;
      encoder.add(
          (ar.ArchiveFile.bytes(name, bytes)
            ..compression = ar.CompressionType.none));
      return true;
    }
  }

  /// 视频原件流式条目（不降质）；先探测绝对路径可用性再挂流式管。
  Future<bool> _addStreamEntry(
    ar.ZipEncoder encoder, {
    required String name,
    required String rel,
  }) async {
    String abs;
    try {
      abs = storage.absolutePath(rel);
    } catch (_) {
      final bytes = await _bytesOf(rel);
      if (bytes == null) return false;
      encoder.add(
          (ar.ArchiveFile.bytes(name, bytes)
            ..compression = ar.CompressionType.none));
      return true;
    }
    final stream = ar.InputFileStream(abs, bufferSize: 1024 * 1024);
    try {
      final entry = ar.ArchiveFile.stream(name, stream)
        ..compression = ar.CompressionType.none;
      encoder.add(entry, autoClose: true);
      return true;
    } catch (_) {
      stream.closeSync();
      final bytes = await _bytesOf(rel);
      if (bytes == null) return false;
      encoder.add(
          (ar.ArchiveFile.bytes(name, bytes)
            ..compression = ar.CompressionType.none));
      return true;
    }
  }

  /// 原片包体积预估（桌面/移动读磁盘尺寸求和；内存存储按字节求和）。
  /// 粗估常数：manifest+guide.json ~8KB、缩略 24KB/条（收窄误差用）。
  Future<int> estimateOriginalBytes({
    required Guide guide,
    List<WallPhoto> videos = const <WallPhoto>[],
    List<PhotoItem> extraPhotos = const <PhotoItem>[],
    Set<String> excludeIds = const <String>{},
    bool includePhotos = true,
  }) async {
    // 账本归属照片和攻略内照片用同一套规则
    final knownIds = {for (final p in guide.photos) p.id};
    final merged = [
      ...guide.photos,
      for (final p in extraPhotos)
        if (p.file.isNotEmpty && knownIds.add(p.id)) p,
    ];
    var total = 8 * 1024;
    if (includePhotos) {
      final coverRel = guide.coverImage;
      if (coverRel != null && coverRel.isNotEmpty) {
        total += await _sizeOfRel(coverRel);
      }
      for (final m in guide.markers) {
        for (final img in m.images) {
          total += await _sizeOfRel(img);
        }
      }
      for (final p in merged) {
        if (p.file.isEmpty || excludeIds.contains(p.id)) continue;
        total += await _sizeOfRel(p.file);
        total += 24 * 1024; // 缩略粗估
      }
    }
    for (final v in videos) {
      if (v.file.isEmpty || excludeIds.contains(v.id)) continue;
      total += await _sizeOfRel(v.file);
      total += 24 * 1024;
    }
    return total;
  }

  Future<int> _sizeOfRel(String rel) async {
    if (rel.isEmpty) return 0;
    String abs = '';
    try {
      abs = storage.absolutePath(rel);
    } catch (_) {}
    if (abs.isNotEmpty) {
      try {
        return await share_temp.fileSizeBytes(abs);
      } catch (_) {}
    }
    final b = await _bytesOf(rel);
    return b?.length ?? 0;
  }

  /// 内容指纹计算（公开给测试用）：
  /// 基础 = FNV-1a64(guide.json，剥离易变时间戳)；
  /// 视频扩展 = 追加视频锚段（每条 `videoId:内容哈希文件名`，排序后
  /// 以空格衔接）——视频增删/换件都会换代指纹，条目顺序不敏感。
  static String fingerprintOf(
    Guide guide, {
    List<WallPhoto> videos = const <WallPhoto>[],
  }) {
    final source = {...guide.toJson()}
      ..remove('updatedAt')
      ..remove('createdAt');
    final base = jsonEncode(source);
    if (videos.isEmpty) return _fnv64Hex(base);
    final anchor = <String>[
      for (final v in videos) '${v.id}:${v.file}',
    ]..sort();
    return _fnv64Hex('$base ${anchor.join(' ')}');
  }
}

/// 打包模式：
/// - [watermarked]：现行方案——照片 ≤960px JPEG q72、封面 ≤1280px、视频 ≤720p
///   转码，全部烧录水印（不可逆）；
/// - [original]：原片高清——媒体按原件字节直接入包（不缩放、不转码、不烧水印），
///   受 1 GB 上限约束；导入后攻略标记 [Guide.sharedOriginal]，允许再导出。
enum ShareExportPolicy { watermarked, original }

/// 原片包超限后的照片降质档（副本在内存合成；原图文件不落副本、不被更改）。
enum ShareExportDegrade {
  /// 不降质（不进入降质流程）
  none,

  /// 高清优先：长边 ≤2048 / JPEG q85
  high,

  /// 体积优先：长边 ≤1080 / JPEG q80
  small;
}

extension ShareExportDegradeX on ShareExportDegrade {
  int? get maxSide => switch (this) {
        ShareExportDegrade.none => null,
        ShareExportDegrade.high => 2048,
        ShareExportDegrade.small => 1080,
      };
  int get quality => switch (this) {
        ShareExportDegrade.high => 85,
        ShareExportDegrade.small => 80,
        _ => 0,
      };
}

/// 导出结果（字节 + 元信息；落盘交给 [ShareService.saveExported]）
class ShareExportResult {
  const ShareExportResult({
    required this.filename,
    required this.bytes,
    required this.fingerprint,
    required this.photoCount,
    required this.skippedCount,
    required this.includesPhotos,
    this.videoCount = 0,
    this.tempPath,
    this.sizeOverrideBytes = 0,
  });

  final String filename;
  final Uint8List bytes;
  final String fingerprint;
  final int photoCount;
  final int videoCount;
  final int skippedCount;
  final bool includesPhotos;

  /// 原片模式的流式产物：ZIP 已写至该临时文件（saveExported 负责搬移并清理）。
  /// 非空时 [bytes] 允许为空字节——尺寸以 [sizeOverrideBytes] 为准。
  final String? tempPath;

  /// 流式产物实际的包体积（字节；0 = 按 [bytes] 长度计）
  final int sizeOverrideBytes;

  int get sizeBytes =>
      bytes.isNotEmpty ? bytes.length : sizeOverrideBytes;
}

/// FNV-1a 64bit → 16 位十六进制（指纹/查重；非加密用途）。
/// Dart int 是 64 位有符号：掩掉符号位保证非负且恰好 16 位以内。
String _fnv64Hex(String text) {
  var hash = 0xcbf29ce484222325;
  for (final b in utf8.encode(text)) {
    hash ^= b;
    hash = (hash * 0x100000001b3) & 0x7FFFFFFFFFFFFFFF;
  }
  final hex = hash.toRadixString(16).padLeft(16, '0');
  return hex;
}

/// 解析成功的分享文件：
/// manifest 元信息 + 原始攻略 + 全部白名单条目字节（重映射阶段取用）。
class ShareParseResult {
  const ShareParseResult({
    required this.manifest,
    required this.guide,
    required this.entries,
    required this.fingerprint,
    this.coverBytes,
    this.coverName,
    this.videosMeta = const <Map<String, dynamic>>[],
  });

  final Map manifest;
  final Guide guide;

  /// ZIP 全部条目字节（键=条目名）
  final Map<String, Uint8List> entries;

  /// manifest 声明的内容指纹（空串=旧格式缺字段）
  final String fingerprint;

  final Uint8List? coverBytes;

  /// 封面条目名（原片模式可携原扩展名；null = 包内无封面）
  final String? coverName;

  /// 打包模式：policy=original → true（无 policy 字段视为水印版）
  bool get isOriginal => (manifest['policy'] as String?) == 'original';

  /// 视频元数据列表：
  /// {id, takenAt, lat?, lng?, name?, durationMs?}
  final List<Map<String, dynamic>> videosMeta;
}

/// 完成落盘的重映射结果：新攻略（shared=true / shareKey=指纹）+ 封面字节
class ShareImported {
  const ShareImported({required this.guide, this.coverBytes});

  final Guide guide;
  final Uint8List? coverBytes;
}
