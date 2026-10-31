import 'dart:typed_data';

import '../core/i18n_service.dart';
import '../core/io/storage_adapter.dart';
import '../core/utils/exif_gps.dart';
import '../core/utils/ids.dart';
import '../core/utils/wall_layout.dart';
import '../data/models/guide.dart';
import '../data/models/wall_photo.dart';
import '../data/repos/wall_photo_repository.dart';
import 'media_store.dart';
import 'wall_folder_scan.dart';

/// 年度照片墙快照种子：与白板布局同一 seed 保持一致
const int kWallLayoutSeed = 20261020;

/// 照片墙白板库服务：
/// - 汇聚统一视图：各攻略 `Guide.photos`（uid=g:guideId:photoId）+ 白板数据（uid=w:id）；
/// - 取样上限：合并去重后按拍摄时间取最新 [cap] 张（设置可调，默认 200）；
/// - 自动读取：桌面扫描「设置 → 默认相册目录」→ 与手动导入走同一条
///   解析→判重→记录→归属→账本链；Web 端降级为手动导入与提示。
class WallPhotoService {
  WallPhotoService(this.storage);

  final StorageAdapter storage;

  WallPhotoRepository get _repo => WallPhotoRepository(storage);

  // —— 汇聚视图 ——

  List<WallPhotoPoint> collectPoints({
    required List<Guide> guides,
    required List<WallPhoto> ledger,
    required int cap,
  }) {
    final points = <WallPhotoPoint>[];
    for (final g in guides) {
      for (final p in g.photos) {
        points.add(WallPhotoPoint(
          uid: 'g:${g.id}:${p.id}',
          lat: p.lat,
          lng: p.lng,
          takenAt: p.takenAt,
        ));
      }
    }
    for (final w in ledger) {
      points.add(WallPhotoPoint(
        uid: 'w:${w.id}',
        lat: w.lat,
        lng: w.lng,
        takenAt: w.takenAt,
      ));
    }
    final seen = <String>{};
    final uniq = [
      for (final p in points)
        if (seen.add(p.uid)) p,
    ];
    uniq.sort((a, b) => a.takenAt.compareTo(b.takenAt));
    final over = uniq.length - cap;
    return over > 0 ? uniq.sublist(over) : uniq;
  }

  // —— 导入链 ——

  /// 自动读取默认相册目录（桌面端；Web 返回不支持的提示报告）
  Future<WallScanReport> importDefaultFolder({
    required String dirPath,
    required List<Guide> guides,
    required int cap,
  }) async {
    final ledger = await _repo.load();
    final candidates = await readFolderPhotoCandidates(
      dirPath,
      limit: (cap - ledger.length).clamp(0, cap),
    );
    if (!candidates.ok) {
      return WallScanReport(ok: false, message: candidates.note, cap: cap);
    }
    if (candidates.payloads.isEmpty) {
      return WallScanReport(
          ok: false, message: I18nService.t.ledgerFull, cap: cap);
    }
    return _importPayloads(
      payloads: candidates.payloads,
      guides: guides,
      ledger: ledger,
      cap: cap,
    );
  }

  /// 手动多选导入（Web 亦可），与自动读取走同一链路
  Future<WallScanReport> importManual({
    required List<Uint8List> payloads,
    required List<Guide> guides,
    required int cap,
  }) async {
    final ledger = await _repo.load();
    return _importPayloads(
      payloads: payloads,
      guides: guides,
      ledger: ledger,
      cap: cap,
    );
  }

  /// 通用导入链：EXIF → 判重（存量账本+攻略照片）→ 记录 → 缩略图 → 归属 → 账本
  Future<WallScanReport> _importPayloads({
    required List<Uint8List> payloads,
    required List<Guide> guides,
    required List<WallPhoto> ledger,
    required int cap,
  }) async {
    final existedFiles = <String>{
      ...ledger.map((w) => w.file),
      for (final g in guides)
        for (final p in g.photos) ...[p.file, p.thumb],
    }..removeWhere((e) => e.isEmpty);

    var full = false;
    var imported = 0;
    var duplicates = 0;
    var noGps = 0;
    var assignedCount = 0;
    final created = <WallPhoto>[];

    for (final bytes in payloads) {
      if (ledger.length + created.length >= cap) {
        full = true;
        break;
      }
      if (bytes.isEmpty) continue;
      final exif = parseExif(bytes);
      final rel = await MediaStore.savePhotowallImage(bytes);
      if (existedFiles.contains(rel)) {
        duplicates++;
        continue;
      }
      existedFiles.add(rel);
      final thumbRel = await MediaStore.makeWallThumb(bytes);
      final guideId = assignGuideByNearest(exif.lat, exif.lng, guides);
      created.add(WallPhoto(
        id: newId('wp'),
        lat: exif.lat,
        lng: exif.lng,
        guideId: guideId,
        takenAt: exif.takenAt ?? DateTime.now(),
        file: rel,
        thumb: thumbRel,
      ));
      imported++;
      if (guideId != null) assignedCount++;
      if (!exif.hasLocation) noGps++;
    }

    if (created.isNotEmpty) {
      ledger.addAll(created);
      await _repo.save(ledger);
    }
    return WallScanReport(
      ok: imported > 0 || duplicates > 0 || full,
      message:
          imported == 0 && duplicates == 0 && !full ? I18nService.t.nothingImported : '',
      imported: imported,
      duplicates: duplicates,
      noGps: noGps,
      assigned: assignedCount,
      full: full,
      cap: cap,
    );
  }

  // —— 账本编辑 ——

  /// 重建「每一年的照片墙结果」快照并落库（墙布局与白板同 seed 同输入 → 一致）：
  /// 每年记录当年照片 uid + 各自摆放（x/y/角度/尺寸）+ 地理团划分，
  /// 为以后按年导出可分享照片墙准备数据。
  Future<Map<int, WallYearRecord>> rebuildYearIndex({
    required List<Guide> guides,
    required int cap,
  }) async {
    final ledger = await _repo.load();
    final points = collectPoints(guides: guides, ledger: ledger, cap: cap);
    final layout = layoutWallPhotos(points, seed: kWallLayoutSeed);
    final byUid = {for (final p in layout.placements) p.uid: p};
    final yearOfUid = {for (final p in points) p.uid: p.takenAt.year};

    final map = <int, WallYearRecord>{};
    for (final p in points) {
      final y = p.takenAt.year;
      final place = byUid[p.uid];
      if (place == null) continue;
      map
          .putIfAbsent(
            y,
            () => WallYearRecord(year: y, placements: {}, clusters: []),
          )
          .placements[p.uid] = WallPos.fromPlacement(place);
    }
    for (final c in layout.clusters) {
      final byYear = <int, List<String>>{};
      for (final uid in c.members) {
        final y = yearOfUid[uid];
        if (y != null) byYear.putIfAbsent(y, () => []).add(uid);
      }
      for (final e in byYear.entries) {
        final rec = map[e.key];
        if (rec == null) continue;
        rec.clusters.add(WallClusterRecord(
          id: c.id,
          lat: c.lat,
          lng: c.lng,
          members: e.value,
        ));
      }
    }
    await _repo.saveYears(map);
    return map;
  }

  /// 未定位条目绑定标记：归属该标记所在攻略 + 以标记位置补定位
  Future<void> bindToMarker({
    required String wallPhotoId,
    required Guide guide,
    required Place place,
  }) async {
    final ledger = await _repo.load();
    final i = ledger.indexWhere((w) => w.id == wallPhotoId);
    if (i < 0) return;
    ledger[i] = ledger[i].copyWith(
      guideId: guide.id,
      lat: place.lat,
      lng: place.lng,
    );
    await _repo.save(ledger);
  }

  /// 删除白板条目（连原图与缩略图；静默清理）
  Future<void> removeLedgerPhoto(String wallPhotoId) async {
    final ledger = await _repo.load();
    final i = ledger.indexWhere((w) => w.id == wallPhotoId);
    if (i < 0) return;
    final w = ledger[i];
    for (final rel in [w.file, w.thumb]) {
      if (rel.isEmpty) continue;
      try {
        await storage.deleteFile(rel);
      } catch (_) {}
    }
    ledger.removeAt(i);
    await _repo.save(ledger);
  }

  /// 清空账本（不删除与攻略照片重复的文件；仅清账本）
  Future<void> clearLedger() async => _repo.save([]);
}
