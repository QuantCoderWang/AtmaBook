import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../core/i18n_service.dart';
import '../core/io/storage_adapter.dart';
import '../core/utils/tile_math.dart';
import '../data/models/map_source.dart';

/// 下载取消令牌（向导页面持有；置位即生效）
class TileDownloadToken {
  bool cancelled = false;
}

/// 下载结果统计（成功 / 跳过 / 失败 / 体积 / 耗时 / 是否被取消）
class TileDownloadReport {
  const TileDownloadReport({
    required this.ok,
    required this.skipped,
    required this.failed,
    required this.bytesWritten,
    required this.elapsed,
    required this.cancelled,
    this.earlyAborted = false,
  });

  final int ok;
  final int skipped;
  final int failed;
  final int bytesWritten;
  final Duration elapsed;
  final bool cancelled;

  /// 连续 6 片下载零成功 → 提前中止（web下多为跨域被拦 / 断网）
  final bool earlyAborted;

  bool get allDone => !cancelled && failed == 0;

  bool get blockedCompletely => earlyAborted || (ok + skipped == 0 && failed > 0);

  int get total => ok + skipped + failed;

  @override
  String toString() => I18nService.t
      .dlReport(ok, skipped, failed, (bytesWritten / 1024 / 1024).toStringAsFixed(1));
}

/// 瓦片下载器：
/// - 并发 4、每片失败重试 2 次（指数退避）、UA 标识、subdomain 轮询；
/// - 已存在直接跳过（计数 skipped）→ 中断重进可续传；
/// - 落盘 `tiles/<packId>/{z}/{x}/{y}.<ext>`（桌面真实文件 / Web ≤1MB 降级）；
/// - 取消令牌在每片开始前检查，立即停止不再发新请求。
class TileDownloader {
  TileDownloader({
    required this.source,
    required this.storage,
    this.tiandituKey = '',
    this.userAgent = 'AtmaBook/0.4 (offline travel guide)',
    this.concurrency = 4,
    this.retries = 2,
  });

  final MapSource source;
  final StorageAdapter storage;
  final String tiandituKey;
  final String userAgent;
  final int concurrency;
  final int retries;

  /// 单瓦片 URL（含 subdomain 轮询与天地图 tk 注入；
  /// GCJ 源的瓦片行列号要传换算后的 z/x/y）
  String tileUrl(int z, int x, int y, int variant) {
    var url = source.urlTemplate;
    if (source.subdomains.isNotEmpty) {
      final sub = source.subdomains[variant % source.subdomains.length];
      url = url.replaceFirst('{s}', sub);
    } else {
      url = url.replaceFirst('{s}', '');
    }
    url = url
        .replaceFirst('{z}', '$z')
        .replaceFirst('{x}', '$x')
        .replaceFirst('{y}', '$y')
        .replaceFirst('{key}', tiandituKey);
    return url;
  }

  String relOf(String packId, TileCoord t, String ext) =>
      'tiles/$packId/${t.z}/${t.x}/${t.y}.$ext';

  /// 下载前连通性探测：取一片真实瓦片，报告可达性/耗时。
  /// 返回 `(ok, httpStatus, elapsedMs)`；异常时 status = -1。
  static Future<(bool, int, int)> probe(
    MapSource source,
    TileCoord tile, {
    String tiandituKey = '',
    String userAgent = 'AtmaBook/0.4 (offline travel guide)',
    Duration timeout = const Duration(seconds: 6),
  }) async {
    var url = source.urlTemplate;
    if (source.subdomains.isNotEmpty) {
      url = url.replaceFirst(
          '{s}', source.subdomains.first);
    }
    url = url
        .replaceFirst('{z}', '${tile.z}')
        .replaceFirst('{x}', '${tile.x}')
        .replaceFirst('{y}', '${tile.y}')
        .replaceFirst('{key}', tiandituKey);
    final headers = kIsWeb ? null : {'User-Agent': userAgent};
    final sw = Stopwatch()..start();
    try {
      final resp =
          await http.get(Uri.parse(url), headers: headers).timeout(timeout);
      sw.stop();
      return (
        resp.statusCode == 200 && resp.bodyBytes.isNotEmpty,
        resp.statusCode,
        sw.elapsedMilliseconds
      );
    } catch (_) {
      return (false, -1, sw.elapsedMilliseconds);
    }
  }

  /// 批量下载；进度回调在每片结束时触发（done 含历次成功+跳过）
  Future<TileDownloadReport> download({
    required String packId,
    required List<TileCoord> tiles,
    required String fileExt,
    required TileDownloadToken token,
    void Function(int done, int total, int okBytes)? onProgress,
  }) async {
    final sw = Stopwatch()..start();
    var ok = 0, skipped = 0, failed = 0, bytes = 0;
    var done = 0;
    final total = tiles.length;
    var next = 0;
    var variantSeed = math.Random()
        .nextInt(source.subdomains.isEmpty ? 1 : source.subdomains.length);
    var earlyAbort = false;
    var consecutiveFails = 0;

    // Web 内不自定义 UA：避免触发 CORS 预检（多数瓦片源不响应 OPTIONS）
    final headers = kIsWeb ? null : {'User-Agent': userAgent};

    Future<void> worker() async {
      while (next < tiles.length && !token.cancelled && !earlyAbort) {
        final tile = tiles[next++];
        final rel = relOf(packId, tile, fileExt);
        if (await storage.exists(rel)) {
          skipped++;
          done++;
          consecutiveFails = 0;
          onProgress?.call(done, total, bytes);
          continue;
        }
        var succeeded = false;
        for (var attempt = 0; attempt <= retries; attempt++) {
          if (token.cancelled || earlyAbort) break;
          if (attempt > 0) {
            await Future<void>.delayed(
                Duration(milliseconds: 300 * (1 << (attempt - 1))));
          }
          try {
            final resp = await http.get(
              Uri.parse(tileUrl(tile.z, tile.x, tile.y,
                  variantSeed + tile.x * 31 + tile.y)),
              headers: headers,
            );
            if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
              await storage.writeBytes(rel, resp.bodyBytes);
              bytes += resp.bodyBytes.length;
              succeeded = true;
              break;
            }
          } catch (_) {
            // 网络异常 / 跨域拦截 → 重试（由整批快速中止兜底）
          }
        }
        if (succeeded) {
          ok++;
          consecutiveFails = 0;
        } else if (!token.cancelled) {
          failed++;
          consecutiveFails++;
          // 一片未成功时已尝试 3 次请求 → 连续 2 片全败即判定为环境阻断，
          // 快速结束批次并告知用户原因，避免海量重试把进度条钉死在 0
          if (ok == 0 && skipped == 0 && consecutiveFails >= 2) {
            earlyAbort = true;
          }
        }
        done++;
        onProgress?.call(done, total, bytes);
      }
    }

    await Future.wait(
        [for (var i = 0; i < concurrency; i++) worker()]);
    sw.stop();
    return TileDownloadReport(
      ok: ok,
      skipped: skipped,
      failed: failed,
      bytesWritten: bytes,
      elapsed: sw.elapsed,
      cancelled: token.cancelled,
      earlyAborted: earlyAbort,
    );
  }
}

/// GCJ-02 源的瓦片文件扩展名约定（落盘即用，Provider 与清单一致）
String tileExtFor(MapSource source) =>
    source.kind == MapKind.satellite ? 'jpg' : 'png';
