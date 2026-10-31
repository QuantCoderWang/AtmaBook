import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' as ar;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/i18n_service.dart';
import '../core/io/storage_adapter.dart';
import '../data/models/guide.dart';
import '../data/models/wall_photo.dart';
import 'share_service.dart';
import 'share_temp.dart' as share_temp;

/// 全量导出包服务：
/// 把攻略本里全体攻略逐个按「原片模式」展示（媒体原件字节直通——不缩放、
/// 不转码、不烧水印，含攻略内照片 + 账本归属照片/视频）打包成内层 `.tgshare`，
/// 再装入**单个**外层 ZIP 容器 `.tgbundle`：
/// ```
/// manifest.json  {"format":"tgbundle","formatVersion":1,"guides":[内层名…],"exportedAt":…}
/// 001_<名>-<日期>.tgshare  第 1 篇（外层 CompressionType.none 存储——内层本身已是 ZIP）
/// 002_<名>-<日期>.tgshare  第 2 篇 …
/// ```
/// 与单包结构差异：**不限制总体积**（1 GB 上限是单包分享的 UI 侧口径，此不复用）；
/// 内层文件名带三位序号前缀避免同名攻略 / 同日命名冲突。
/// 导入：`ZipDirectory.read` 只读中央目录 → 对每个内层条目按需
/// `ZipFile.getStream()`（archive 4.5 的懒读取——文件后端字节视图，逐条取出，
/// 同一时刻只有一个内层包驻留内存），随后照常 `parseShare` + `applyImport`。
class ShareBundleService {
  ShareBundleService(this.storage);

  final StorageAdapter storage;

  static const bundleFormat = 'tgbundle';

  static const bundleFormatVersion = 1;

  /// 内层条目名白名单：`001_安全名-20261023.tgshare`（序号_内容名.tgshare）
  static final RegExp innerEntryReg = RegExp(r'^\d{3}_[^/\\]+\.tgshare$');

  // ================= 导出链（全量打包） =================

  /// 打包全部攻略为单个 `.tgbundle`（流式写临时文件，落盘交给
  /// [ShareService.saveExported]）。
  /// [guides]：全体攻略（调用方按当前顺序传入）；[ledger]：相册账本（用于
  /// 挂接 `guideId` 归属的照片与视频）；
  /// [onProgress]：done/total = 已完成篇数，[title] = 刚打完/正在打包的攻略名；
  /// [isCancelled]：返回 true 即中止（已写入部分与临时目录一并清理，返回 null）。
  Future<ShareExportResult?> buildAll({
    required List<Guide> guides,
    List<WallPhoto> ledger = const <WallPhoto>[],
    void Function(int done, int total, String title)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('export bundle requires a file system');
    }
    if (guides.isEmpty) return null;
    final share = ShareService(storage);
    final t = I18nService.t;

    bool cancelled() => isCancelled?.call() ?? false;

    final workDir = await share_temp.createTempWorkDir('bundle');
    final tempZip = '$workDir/bundle.tgbundle';
    final output = ar.OutputFileStream(tempZip, bufferSize: 1024 * 1024);
    final encoder = ar.ZipEncoder();
    encoder.startEncode(output);
    var failed = false;
    final now = DateTime.now();

    try {
      // 内层文件名：三位序号防撞 + 单包同口径安全名/日期戳
      final names = <String>[
        for (var i = 0; i < guides.length; i++)
          '${(i + 1).toString().padLeft(3, '0')}_'
              '${_safeName(guides[i].title)}-${_dateStamp(now)}.tgshare',
      ];
      final manifestBytes = utf8.encode(jsonEncode(<String, dynamic>{
        'format': bundleFormat,
        'formatVersion': bundleFormatVersion,
        'guides': names,
        'exportedAt': now.toIso8601String(),
      }));
      encoder.add(
          ar.ArchiveFile.bytes('manifest.json', Uint8List.fromList(manifestBytes)));

      for (var i = 0; i < guides.length; i++) {
        final g = guides[i];
        if (cancelled()) return null;
        final res = await share.build(
          guide: g,
          includePhotos: true,
          watermarkText: '',
          policy: ShareExportPolicy.original,
          videos: boundVideos(ledger, g.id),
          extraPhotos: extraPhotosFor(ledger, g),
          // 全量包进度到篇级即可（内层逐项细节不外抛）
          isCancelled: isCancelled,
        );
        if (res == null) return null; // 内层取消：其临时目录已自行清理
        // 内层包以「存储」方式写入外层（内层已是 ZIP，再压无收益）
        final stream = ar.InputFileStream(res.tempPath!, bufferSize: 1024 * 1024);
        final entry = ar.ArchiveFile.stream(names[i], stream)
          ..compression = ar.CompressionType.none;
        encoder.add(entry, autoClose: true);
        await share_temp.deleteTempWorkDir(_dirOf(res.tempPath!));
        onProgress?.call(i + 1, guides.length, g.title);
      }

      if (cancelled()) return null;
      encoder.endEncode();
    } catch (_) {
      failed = true;
      rethrow;
    } finally {
      output.flush();
      output.closeSync();
      if (failed || cancelled()) {
        await share_temp.deleteTempWorkDir(workDir);
      }
    }

    int size = 0;
    try {
      size = await share_temp.fileSizeBytes(tempZip);
    } catch (_) {}

    return ShareExportResult(
      filename:
          '${t.bundleFileName}-${_dateStamp(now)}.tgbundle',
      bytes: Uint8List(0),
      fingerprint: '', // 全量包不做攻略级指纹查重（查重逐条在内层导入时进行）
      photoCount: 0,
      videoCount: 0,
      skippedCount: 0,
      includesPhotos: true,
      tempPath: tempZip,
      sizeOverrideBytes: size,
    );
  }

  // ================= 导入链（全量恢复） =================

  /// 从 `.tgbundle` 流式读取并逐条导入：
  /// 先校验外层 manifest（格式/版本/条目白名单），再对内层 `.tgshare` 逐条
  /// `parseShare` + [onGuide]（同一时刻仅一个内层包驻留内存——十 GB 级大包
  /// 可安全导入）。[onGuide] 返回 applied=已落实 / skipped=查重跳过 /
  /// cancelled=用户中止。
  /// 返回 null = 不是有效的全量包；返回报告 = 逐条统计（含 cancelled 标记）。
  Future<ShareBundleReport?> importAll({
    required String absPath,
    required Future<ShareBundleGuideResult> Function(ShareParseResult parsed)
        onGuide,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('import bundle requires a file system');
    }
    final input = ar.InputFileStream(absPath, bufferSize: 1024 * 1024);
    try {
      final dir = ar.ZipDirectory();
      try {
        dir.read(input);
      } catch (_) {
        return null; // 连 ZIP 结构都不成立
      }
      Map? manifest;
      final inners = <ar.ZipFile>[];
      for (final h in dir.fileHeaders) {
        final zf = h.file;
        if (zf == null) return null;
        if (zf.filename == 'manifest.json') {
          try {
            manifest =
                jsonDecode(utf8.decode(zf.getStream().toUint8List()));
          } catch (_) {
            return null; // manifest 缺失/损坏
          }
        } else if (innerEntryReg.hasMatch(zf.filename)) {
          inners.add(zf);
        } else {
          return null; // 白名单外条目 → 拒收（伪装 / 篡改包体）
        }
      }
      if (manifest is! Map ||
          manifest['format'] != bundleFormat ||
          inners.isEmpty) {
        return null;
      }
      final vInt = (manifest['formatVersion'] as num?)?.toInt() ?? 0;
      if (vInt < 1 || vInt > bundleFormatVersion) return null;

      var applied = 0;
      var skipped = 0;
      var failed = 0;
      var cancelled = false;
      for (final zf in inners) {
        if (cancelled) break;
        // 逐条加载（懒读取：文件后端字节视图 → 单条驻留）
        final Uint8List bytes;
        try {
          bytes = zf.getStream().toUint8List();
        } catch (_) {
          failed++;
          continue;
        }
        final parsed = ShareService.parseShare(bytes);
        if (parsed == null) {
          failed++;
          continue;
        }
        ShareBundleGuideResult r;
        try {
          r = await onGuide(parsed);
        } catch (_) {
          failed++;
          continue;
        }
        switch (r) {
          case ShareBundleGuideResult.applied:
            applied++;
          case ShareBundleGuideResult.skipped:
            skipped++;
          case ShareBundleGuideResult.cancelled:
            cancelled = true;
        }
      }
      return ShareBundleReport(
        applied: applied,
        skipped: skipped,
        failed: failed,
        cancelled: cancelled,
      );
    } finally {
      await input.close();
    }
  }

  // ================= 账本归属媒体拆分 =================

  /// 账本中归属该攻略的视频条目（guideId 绑定、文件在册）。
  static List<WallPhoto> boundVideos(List<WallPhoto> ledger, String guideId) =>
      [
        for (final w in ledger)
          if (w.isVideo && w.guideId == guideId && w.file.isNotEmpty) w,
      ];

  /// 账本中归属该攻略的照片 → 导出用 PhotoItem（id 沿用账本原 id，
  /// 接收端照常全量重映射；ShareService.build 内部按 id 幂等去重）。
  static List<PhotoItem> extraPhotosFor(List<WallPhoto> ledger, Guide guide) =>
      [
        for (final w in ledger)
          if (!w.isVideo && w.guideId == guide.id && w.file.isNotEmpty)
            PhotoItem(
              id: w.id,
              lat: w.lat,
              lng: w.lng,
              takenAt: w.takenAt,
              file: w.file,
              thumb: w.thumb,
              name: w.name,
              kind: w.kind,
              durationMs: w.durationMs,
            ),
      ];

  /// 文件路径 → 所在目录（Windows / POSIX 双兼容；不依赖 dart:io）
  static String _dirOf(String filePath) {
    final i = filePath.lastIndexOf('/');
    final j = filePath.lastIndexOf('\\');
    final cut = i > j ? i : j;
    return cut <= 0 ? filePath : filePath.substring(0, cut);
  }

  /// 与单包 `_safeName` 同口径（文件系统非法字符 → _，超长截 40）
  static String _safeName(String title) {
    final s = title.trim().isEmpty ? I18nService.t.guideFallback : title.trim();
    final cleaned = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  static String _dateStamp(DateTime t) =>
      '${t.year}${t.month.toString().padLeft(2, '0')}'
      '${t.day.toString().padLeft(2, '0')}';
}

/// 逐条导入结果（[ShareBundleService.importAll] 的 onGuide 返回值）
enum ShareBundleGuideResult { applied, skipped, cancelled }

/// 全量包导入报告
class ShareBundleReport {
  const ShareBundleReport({
    required this.applied,
    required this.skipped,
    required this.failed,
    required this.cancelled,
  });

  /// 新导入成功篇数
  final int applied;

  /// 指纹查重跳过篇数
  final int skipped;

  /// 解析失败篇数
  final int failed;

  /// 用户中途取消
  final bool cancelled;
}
