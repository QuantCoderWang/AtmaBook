import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/i18n_names.dart';
import '../../core/io/storage_adapter.dart';
import '../../core/utils/thumb_binding.dart';
import '../../core/utils/wall_layout.dart' show WallPhotoPoint;
import '../../data/models/guide.dart';
import '../../data/models/map_source.dart';
import '../../data/models/wall_photo.dart';
import '../../data/repos/wall_photo_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/media_store.dart';
import '../../services/video_import_service.dart';
import '../../services/wall_photo_service.dart';
import '../../services/wall_scan_types.dart' show assignGuideByNearest;
import 'video_player_page.dart';
import '../../state/guides_provider.dart';
import '../widgets/photo_thumb.dart';
import '../widgets/tooltip_barrier.dart';

/// 地理相册（原「照片墙」板块，按反馈重做）：
/// - 全部照片按 **真实地理坐标** 铺在地图上（EXIF GPS，WGS-84）；
/// - **动态加载**：仅渲染当前视口内的照片；放大后立即呈现更小区域的更多照片；
///   低缩放级时相邻照片聚合为「数量气泡」，点气泡自动放大到该组；
/// - **进入定位**：请求用户位置作为默认视野（geolocator；用户手动挪图后不抢焦点）；
/// - 底图为免 Key 的 Esri 街道源（全平台可用）；
/// - 照片两条途径入册：**批量导入**（桌面相册文件夹 / Web 批量多选）
///   + **精选加入**（逐张勾选确认）——均在右上角 ⋮ 菜单；
/// - 右上角「相册库」：全部照片清单（GPS 状态 + 地图显示开关；
///   隐藏登记持久化于账本 `hidden` 键）；
/// - 点照片缩略图 → 全黑虚拟空间查看（左右翻页；逐张剔除；无 GPS 照片
///   可「设置地理标识」→ 点选地图写入经纬度）。
class PhotoWallGalleryPage extends StatefulWidget {
  const PhotoWallGalleryPage({super.key});

  @override
  State<PhotoWallGalleryPage> createState() => _PhotoWallGalleryPageState();
}

/// 相册条目（统一视图取回）
class _Entry {
  const _Entry({
    required this.uid,
    required this.point,
    required this.rel,
    required this.fullRel,
    this.gradientIndex = 0,
    this.guideId,
    this.guidePhotoId,
    this.ledgerId,
    this.isVideo = false,
    this.durationMs = 0,
  });

  final String uid; // g:<gid>:<pid> 或 w:<wid>
  final WallPhotoPoint point;
  final String rel; // 缩略图（miss 时用原图）
  final String fullRel; // 原图
  final int gradientIndex;
  final String? guideId;
  final String? guidePhotoId;
  final String? ledgerId;

  /// 视频条目：缩略上叠 ▶ 角标 + 时长
  final bool isVideo;
  final int durationMs;

  double get lat => point.lat!;
  double get lng => point.lng!;
  bool get hasGps => point.hasGps;
}

/// 视频插入收集统计（photos 批量链的 WallScanReport 对位物的视频版）
class _VideoInsertAcc {
  int imported = 0;
  int duplicates = 0;
  int failed = 0;
  bool full = false;

  String banner(AppLocalizations t) =>
      t.videoInsertBanner(
          imported,
          duplicates > 0 ? t.videoDupPart(duplicates) : '',
          failed > 0 ? t.videoFailPart(failed) : '',
          full ? t.videoFullPart : '',
          imported > 0 ? t.videoTailPart : '');
}

/// 统一视图纯组装：各攻略 `Guide.photos`（uid=`g:gid:pid`）+ 相册账本（uid=`w:wid`），
/// 按拍摄时间取最新 [cap] 张；隐藏过滤由调用方按 uid 判断。
List<_Entry> _unitedAlbumEntries({
  required List<Guide> guides,
  required List<WallPhoto> ledger,
  required int cap,
}) {
  final service = WallPhotoService(activeStorage);
  // 分享攻略的照片只随攻略可见，不进入用户自己的地理相册
  final ownGuides = [
    for (final g in guides)
      if (!g.shared) g,
  ];
  final points = service.collectPoints(
    guides: ownGuides,
    ledger: ledger,
    cap: cap,
  );
  final entries = <_Entry>[];
  for (final pt in points) {
    if (pt.uid.startsWith('g:')) {
      final parts = pt.uid.split(':'); // g:<gid>:<pid>
      if (parts.length != 3) continue;
      final g = guides.where((x) => x.id == parts[1]).firstOrNull;
      PhotoItem? p;
      for (final x in g?.photos ?? const <PhotoItem>[]) {
        if (x.id == parts[2]) p = x;
      }
      if (g == null || p == null) continue;
      // 视频：rel 只取首帧缩略（缺缩略直走占位），绝不退化到视频原件路径
      // —— 否则各行卡/地图缩略会误把视频字节当图片解码（Invalid image data）
      // rel 一律取条目**自带**的锁定配对（thumbBinding），不再内联推导
      entries.add(_Entry(
        uid: pt.uid,
        point: pt,
        rel: p.thumbBinding,
        fullRel: p.file,
        gradientIndex: p.gradientIndex,
        guideId: g.id,
        guidePhotoId: p.id,
        isVideo: p.isVideo,
        durationMs: p.durationMs,
      ));
    } else if (pt.uid.startsWith('w:')) {
      final w = ledger.where((x) => x.id == pt.uid.substring(2)).firstOrNull;
      if (w == null) continue;
      entries.add(_Entry(
        uid: pt.uid,
        point: pt,
        rel: w.thumbBinding,
        fullRel: w.file,
        gradientIndex: 0,
        guideId: w.guideId,
        ledgerId: w.id,
        isVideo: w.isVideo,
        durationMs: w.durationMs,
      ));
    }
  }
  return entries;
}

/// —— 相册操作共享（地理相册页 / 相册库页均用）———

/// 从地理相册剔除一张照片：
/// - 攻略照片：删除照片文件并从攻略 `Guide.photos` 移除（与地图照片同步）；
/// - 相册账本照片：从账本移除（连文件）。
/// 返回是否实际剔除（用户取消 = false）。
Future<bool> _removeAlbumPhoto(BuildContext context, _Entry entry) async {
  final guides = Provider.of<GuidesProvider>(context, listen: false);
  final t = AppLocalizations.of(context);
  if (entry.uid.startsWith('g:')) {
    final g = guides.byId(entry.guideId ?? '');
    PhotoItem? p;
    for (final x in g?.photos ?? const <PhotoItem>[]) {
      if (x.id == entry.guidePhotoId) p = x;
    }
    if (g == null || p == null) return false;
    final photo = p;
    final fixedGuide = g;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.removePhotoTitle),
        content: Text(t.removeGuidePhotoContent(
            photo.name.isNotEmpty ? photo.name : t.photoUnnamed)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.removePhotoBtn),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    for (final rel in [photo.file, photo.thumb]) {
      if (rel.isNotEmpty) MediaStore.deleteImage(rel);
    }
    await guides.replace(fixedGuide.copyWith(
      photos: fixedGuide.photos.where((x) => x.id != photo.id).toList(),
      updatedAt: DateTime.now(),
    ));
    return true;
  } else {
    final wid = entry.ledgerId ?? entry.uid.substring(2);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.removePhotoTitle),
        content: Text(t.removeLedgerPhotoContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.removePhotoBtn),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await WallPhotoService(activeStorage).removeLedgerPhoto(wid);
    return true;
  }
}

/// 把选定的经纬度写入照片（攻略照片 / 相册账本照片），不弹提示不刷 UI。
/// 返回是否写入成功（找不到原条目 = false）。
Future<bool> _writeGeoToEntry(BuildContext context, _Entry entry, LatLng loc) async {
  final guides = Provider.of<GuidesProvider>(context, listen: false);
  if (entry.uid.startsWith('g:')) {
    final g = guides.byId(entry.guideId ?? '');
    PhotoItem? p;
    for (final x in g?.photos ?? const <PhotoItem>[]) {
      if (x.id == entry.guidePhotoId) p = x;
    }
    if (g == null || p == null) return false;
    final photo = p;
    final fixedGuide = g;
    final updated = <PhotoItem>[
      for (final x in fixedGuide.photos)
        x.id == photo.id
            ? x.copyWith(lat: loc.latitude, lng: loc.longitude)
            : x,
    ];
    await guides.replace(fixedGuide.copyWith(
      photos: updated,
      updatedAt: DateTime.now(),
    ));
    return true;
  } else {
    final wid = entry.ledgerId ?? entry.uid.substring(2);
    final list = await WallPhotoRepository(activeStorage).load();
    // 补写地理位置同时按就近规则归属攻略（≤5km 内最近标记所在攻略）；
    // 视频条目依赖此处定位后才会与照片一致出现在归属攻略的地图照片层。
    final target = assignGuideByNearest(
        loc.latitude, loc.longitude, guides.guides);
    final updated = <WallPhoto>[
      for (final w in list)
        w.id == wid
            ? w.copyWith(lat: loc.latitude, lng: loc.longitude,
                guideId: target)
            : w,
    ];
    await WallPhotoRepository(activeStorage).save(updated);
    return true;
  }
}

class _PhotoWallGalleryPageState extends State<PhotoWallGalleryPage> {
  final MapController _map = MapController();
  List<WallPhoto> _ledger = [];
  bool _busy = true;

  // 视口动态加载状态
  List<_Entry> _visible = [];
  double _zoomBucket = -1;
  bool _mapReady = false;

  // 相册库登记：被手动隐藏（不在地图/查看器显示）的照片 uid
  Set<String> _hidden = {};

  // 用户定位（进入时默认视野）；用户手动挪过镜头后不再自动抢焦点
  LatLng? _lastUserLoc;
  bool _userAdjusted = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _reloadLedgerAndMaybeScan();
    _locateUser(initial: true);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // —— 数据加载 / 隐藏登记 ——
  Future<List<WallPhoto>> _readLedger() async =>
      WallPhotoRepository(activeStorage).load();

  Future<void> _reloadLedger() async {
    final ledger = await _readLedger();
    final hidden = await WallPhotoRepository(activeStorage).loadHidden();
    if (!mounted) return;
    setState(() {
      _ledger = ledger;
      _hidden = hidden;
    });
    _refreshVisible();
  }

  Future<void> _reloadLedgerAndMaybeScan() async {
    final ledger = await _readLedger();
    final hidden = await WallPhotoRepository(activeStorage).loadHidden();
    if (!mounted) return;
    setState(() {
      _ledger = ledger;
      _hidden = hidden;
      _busy = false;
    });
    // 账本是异步到的（onMapReady 往往先发生）：不补这次刷新，
    // 相册账本条目（w:）要等第一次手势事件才进 _visible。
    _refreshVisible();
  }

  // —— 用户定位 ——

  Future<void> _locateUser({bool initial = false}) async {
    if (_locating) return;
    _locating = true;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw StateError('no permission');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      _lastUserLoc = LatLng(pos.latitude, pos.longitude);
      if (_mapReady && !_userAdjusted) {
        _map.move(_lastUserLoc!, 15);
      }
    } catch (_) {
      if (!initial && mounted) {
        _snack(AppLocalizations.of(context).locateFailSnack);
      }
    } finally {
      _locating = false;
    }
  }

  // —— 批量导入（桌面：相册文件夹；Web：批量多选）——
  Future<void> _scanFolder() async {
    if (kIsWeb) {
      // Web 无本地目录权限，降级为批量多选（同一导入链）
      await _pickManyAndImport();
      return;
    }
    final ctrl = TextEditingController(text: '');
    final t = AppLocalizations.of(context);
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.scanFolderTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: t.scanFolderLabel,
            hintText: t.scanFolderHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(ctrl.text.trim()),
            child: Text(t.startImport),
          ),
        ],
      ),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final report = await WallPhotoService(activeStorage).importDefaultFolder(
      dirPath: chosen,
      guides: context.read<GuidesProvider>().guides,
      cap: kAlbumDisplayCap,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _afterImport(report.banner);
    _maybeAimCamera();
  }

  /// 手动批量多选（Web 亦可走同一导入链）
  Future<void> _pickManyAndImport() async {
    final files = await ImagePicker().pickMultiImage(limit: 30);
    if (files.isEmpty) return;
    final payloads = <Uint8List>[];
    for (final f in files) {
      final b = await f.readAsBytes();
      if (b.isNotEmpty) payloads.add(b);
    }
    if (payloads.isEmpty) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final report = await WallPhotoService(activeStorage).importManual(
      payloads: payloads,
      guides: context.read<GuidesProvider>().guides,
      cap: kAlbumDisplayCap,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final t2 = AppLocalizations.of(context);
    await _afterImport(report.ok
        ? '${t2.batchImportStats(report.imported, report.duplicates)}'
            '${report.noGps > 0 ? t2.noGpsTail(report.noGps) : ''}'
            '${report.full ? t2.capReachedPart(report.cap) : ''}'
        : report.message);
    _maybeAimCamera();
  }

  /// 精选加入：多选 → 预览勾选（逐张确认）→ 只导入勾选照片
  Future<void> _curateImport() async {
    final files = await ImagePicker().pickMultiImage(limit: 30);
    if (files.isEmpty) return;
    final payloads = <Uint8List>[];
    for (final f in files) {
      final b = await f.readAsBytes();
      if (b.isNotEmpty) payloads.add(b);
    }
    if (payloads.isEmpty || !mounted) return;
    final chosen = await showDialog<List<int>>(
      context: context,
      builder: (_) => _CurateSheet(payloads: payloads),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final report = await WallPhotoService(activeStorage).importManual(
      payloads: [for (final i in chosen) payloads[i]],
      guides: context.read<GuidesProvider>().guides,
      cap: kAlbumDisplayCap,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _afterImport(AppLocalizations.of(context)
        .curateImportStats(report.imported, report.duplicates));
    _maybeAimCamera();
  }

  Future<void> _afterImport(String banner) async {
    _snack(banner);
    await _reloadLedger();
  }

  // —— 插入视频（仅可使用地理相册入口；批量多选 / 一张张点选）——
  /// 插入视频：先选收集方式（批量多选 / 逐个挑选），
  /// 收集文件路径 → 逐个素材化（流式复制 + 时长/首帧缩略）→
  /// 账本判重 + 上限 → 落库；视频入册**不带 GPS**，
  /// 提示用户到【相册库】点开每个视频补写地理位置（与照片补位同流程）。
  Future<void> _insertVideos() async {
    final t = AppLocalizations.of(context);
    final batch = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.insertVideosTitle),
        content: Text(t.insertVideosContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(t.cancel)),
          OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.pickOneByOne)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.pickBatch)),
        ],
      ),
    );
    if (batch == null || !mounted) return;

    // —— 收集路径 ——
    final group = XTypeGroup(
        label: t.videoTypeGroup,
        extensions: ['mp4', 'mov', 'webm', 'mkv', 'avi', 'm4v']);
    final paths = <String>[];
    try {
      if (batch) {
        if (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          // Android/iOS：pickVideo 逐支循环（挑选自然连续，取消即结束）；
          // 移动端统一用系统照片库选择器（体验一致、带原生缩略 UI）
          for (;;) {
            final x = await ImagePicker().pickVideo(source: _vpickSource());
            if (x == null) break;
            paths.add(x.path);
          }
        } else {
          final files = await openFiles(acceptedTypeGroups: [group]);
          paths.addAll(files.map((f) => f.path));
        }
      } else {
        // —— 逐个：一支一支选，每次插入后询问是否继续 ——
        for (;;) {
          String? one;
          if (kIsWeb ||
              defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS) {
            final x = await ImagePicker().pickVideo(source: _vpickSource());
            one = x?.path;
          } else {
            final file = await openFile(acceptedTypeGroups: [group]);
            one = file?.path;
          }
          if (one == null) break;
          paths.add(one);
          if (!mounted) break;
          final t2 = AppLocalizations.of(context);
          final more = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(t2.collectedOne),
              content: Text(t2.pickNextAsk),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(t2.startInsertNow)),
                FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(t2.keepPicking)),
              ],
            ),
          );
          if (more != true) break;
        }
      }
    } catch (e) {
      if (!mounted) return;
      _snack(AppLocalizations.of(context).pickVideoFail('$e'));
      return;
    }
    if (paths.isEmpty || !mounted) return;

    // —— 素材化 + 判重 + 落库 ——
    setState(() => _busy = true);
    final report = _VideoInsertAcc();
    final added = <WallPhoto>[];
    for (final path in paths) {
      if (_ledger.length + added.length >= kAlbumDisplayCap) {
        report.full = true;
        break;
      }
      final (mat, err) = await VideoLedgerService().materialize(path);
      if (err != null || mat == null) {
        report.failed++;
        continue;
      }
      if (VideoLedgerService.alreadyInLedger(
          [..._ledger, ...added], mat.rel)) {
        report.duplicates++;
        continue;
      }
      added.add(mat.item);
      report.imported++;
    }
    if (added.isNotEmpty) {
      await WallPhotoRepository(activeStorage).save([..._ledger, ...added]);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _afterImport(report.banner(AppLocalizations.of(context)));
    _maybeAimCamera();
  }

  ImageSource _vpickSource() => ImageSource.gallery;  // —— 剔除（照片墙 + 地图照片 同步移除）——

  Future<void> _removeEntry(_Entry entry) async {
    final removed = await _removeAlbumPhoto(context, entry);
    if (!removed || !mounted) return;
    _snack(AppLocalizations.of(context).removedToast);
    await _reloadLedger();
  }

  // —— 手动写入地理标识（查看器点选地图位置）——
  /// 把选定的经纬度写入照片（攻略照片 / 相册账本照片），成功后回到地图
  Future<void> _applyGeo(_Entry entry, LatLng loc) async {
    final ok = await _writeGeoToEntry(context, entry, loc);
    if (!ok || !mounted) return;
    _snack(AppLocalizations.of(context).geoWritten(
        '${loc.latitude.toStringAsFixed(6)}, '
        '${loc.longitude.toStringAsFixed(6)}'));
    await _reloadLedger();
    // 写入后镜头聚焦新位置，便于确认落点
    if (_mapReady) {
      _map.move(loc, 15);
    }
  }

  // —— 汇聚视图 ——
  /// 统一视图（含被手动隐藏的照片：过滤发生在 _collect，地图/查看器均适用）
  List<_Entry> _collect() {
    final guides = context.read<GuidesProvider>().guides;
    return _unitedAlbumEntries(
      guides: guides,
      ledger: _ledger,
      cap: kAlbumDisplayCap,
    ).where((e) => !_hidden.contains(e.uid)).toList();
  }

  List<_Entry> get _allEntries => _collect();

  void _openViewer(List<_Entry> entries, int index) {
    if (entries.isEmpty) return;
    // 选点地图默认打开中心：照片群均值；无则用用户位置
    LatLng? pickCenter;
    var la = 0.0;
    var lo = 0.0;
    var n = 0;
    for (final e in entries) {
      if (e.hasGps) {
        la += e.lat;
        lo += e.lng;
        n++;
      }
    }
    if (n > 0) {
      pickCenter = LatLng(la / n, lo / n);
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _WallViewerPage(
        entries: entries,
        initialIndex: index.clamp(0, entries.length - 1),
        onRemoveEntry: _removeEntry,
        onGeoSet: _applyGeo,
        pickInitCenter: _lastUserLoc ?? pickCenter,
      ),
    ));
  }

  // —— 视口动态加载 ——
  /// 相机事件 → 重算视口内照片（集合未变时不 setState，避免拖动中闪跳）
  void _onMapEvent(MapEvent event) {
    if (!_mapReady) return;
    // 程序化 move 不算「用户已手动调整」
    if (event.source != MapEventSource.mapController) {
      _userAdjusted = true;
    }
    _refreshVisible();
  }

  void _refreshVisible() {
    if (!_mapReady) return;
    final cam = _map.camera;
    final zoomBucket = cam.zoom.floorToDouble();
    final located = _collect().where((e) => e.hasGps).toList();
    final b = cam.visibleBounds;
    final laSpan = (b.north - b.south).abs().clamp(0.0001, 180.0) * 0.15;
    final loSpan = (b.east - b.west).abs().clamp(0.0001, 360.0) * 0.15;
    final inView = located
        .where((e) => e.lat >= b.south - laSpan &&
            e.lat <= b.north + laSpan &&
            e.lng >= b.west - loSpan &&
            e.lng <= b.east + loSpan)
        .toList();
    if (zoomBucket == _zoomBucket && _sameUids(_visible, inView)) {
      return;
    }
    _zoomBucket = zoomBucket;
    if (mounted) {
      setState(() => _visible = inView);
    } else {
      _visible = inView;
    }
  }

  static bool _sameUids(List<_Entry> a, List<_Entry> b) {
    if (a.length != b.length) return false;
    final ids = {for (final e in a) e.uid};
    for (final e in b) {
      if (!ids.contains(e.uid)) return false;
    }
    return true;
  }

  /// 首次出现带定位照片后把镜头对准照片群
  void _maybeAimCamera() {
    if (!_mapReady) return;
    if (_visible.isNotEmpty) return;
    final loc = _allEntries.where((e) => e.hasGps).toList();
    if (loc.isEmpty) return;
    var la = 0.0;
    var lo = 0.0;
    for (final e in loc) {
      la += e.lat;
      lo += e.lng;
    }
    _map.move(LatLng(la / loc.length, lo / loc.length), 12);
  }

  // —— 界面 ——
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final all = _allEntries;
    final located = all.where((e) => e.hasGps).toList();
    final unlocated = all.length - located.length;
    located.sort((a, b) => b.point.takenAt.compareTo(a.point.takenAt));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(t.menuGallery,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          TooltipBarrier(
            child: IconButton(
              tooltip: t.albumLibTooltip,
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const _AlbumLibraryPage(),
                ));
                _reloadLedger();
              },
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (v) {
              if (v == 'curate') _curateImport();
              if (v == 'batch') _scanFolder();
              if (v == 'insertVideos') _insertVideos();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'batch', child: Text(t.menuBatchImport)),
              PopupMenuItem(value: 'curate', child: Text(t.menuCurate)),
              PopupMenuItem(
                  value: 'insertVideos', child: Text(t.menuInsertVideos)),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _initialCenter(located),
                initialZoom: 3.8, // 中国全境视野（不再因照片群怼到街道级）
                minZoom: 3,
                maxZoom: 18,
                onMapEvent: _onMapEvent,
                onMapReady: () {
                  _mapReady = true;
                  if (_lastUserLoc != null && !_userAdjusted) {
                    _map.move(_lastUserLoc!, 15);
                  }
                  _refreshVisible();
                },
              ),
              children: [
                const _BaseTile(),
                MarkerLayer(
                  markers: _buildMarkers(located),
                ),
              ],
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x22000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: _Notice(
              text: all.isEmpty
                  ? t.noticeEmpty
                  : unlocated > 0
                      ? '${t.noticeOnMap(located.length)} · '
                          '${t.noticeMissing(unlocated)}'
                      : t.noticeAllShown(located.length),
            ),
          ),
          Positioned(
            right: 12,
            top: 52,
            child: Column(
              children: [
                _MapFab(icon: Icons.zoom_in, onTap: () => _zoomBy(1)),
                const SizedBox(height: 8),
                _MapFab(icon: Icons.zoom_out, onTap: () => _zoomBy(-1)),
                const SizedBox(height: 8),
                _MapFab(icon: Icons.my_location, onTap: () => _locateUser()),
                const SizedBox(height: 8),
                _MapFab(icon: Icons.center_focus_strong, onTap: _aimAll),
              ],
            ),
          ),
          Positioned(
            left: 10,
            bottom: 2,
            child: ValueListenableBuilder<String>(
              valueListenable: _baseAttributionNote,
              builder: (_, note, _) => Text(
                note,
                style: const TextStyle(
                    fontSize: 9.5,
                    color: Colors.black54,
                    backgroundColor: Color(0x66FFFFFF)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LatLng _initialCenter(List<_Entry> located) {
    // **默认打开中国全境**——不再以定位照片均值做初始中心
    // （照片群均值会直接怼到街道级视野）。进入后可用「聚焦全部」按钮
    // 一键落到照片群；用户定位授权时的自动回位逻辑不受影响。
    return const LatLng(35.0, 104.05); // 中国全境几何中心
  }

  void _zoomBy(int d) {
    if (!_mapReady) return;
    _map.move(_map.camera.center, (_map.camera.zoom + d).clamp(3.0, 18.0));
  }

  void _aimAll() {
    if (!_mapReady) return;
    final loc = _allEntries.where((e) => e.hasGps).toList();
    if (loc.isEmpty) return;
    if (loc.length == 1) {
      _map.move(LatLng(loc.first.lat, loc.first.lng), 15);
      return;
    }
    var north = loc.first.lat;
    var south = loc.first.lat;
    var east = loc.first.lng;
    var west = loc.first.lng;
    for (final e in loc) {
      north = math.max(north, e.lat);
      south = math.min(south, e.lat);
      east = math.max(east, e.lng);
      west = math.min(west, e.lng);
    }
    _map.move(
      LatLng((north + south) / 2, (east + west) / 2),
      _fitResolution(north, south, east, west),
    );
  }

  double _fitResolution(double n, double s, double e, double w) {
    final laSpan = (n - s).abs().clamp(0.0001, 180.0);
    final loSpan = (e - w).abs().clamp(0.0001, 360.0);
    final fx = math.log(360 * 0.85 / loSpan) / math.ln2;
    final fy = math.log(180 * 0.85 / laSpan) / math.ln2;
    return math.max(3.0, math.min(fx, fy)) - 0.6;
  }

  /// 当前视口/缩放级别的标记（动态加载）：
  /// - 视口内每张照片 → 缩略图标记；聚合格内 ≥2 张 → 数量气泡；
  /// - 图元完全由 [_visible]（视口动态加载结果）驱动，不重复校验；
  /// - 点缩略图进查看器（全集 [located] 时间倒序翻页）。
  List<Marker> _buildMarkers(List<_Entry> located) {
    if (!_mapReady || _visible.isEmpty) return const [];
    final cam = _map.camera;
    // 聚合格边长（经纬度）：格 ≈ 64px
    final cellDeg = 360.0 * 64 / (256 * math.pow(2, cam.zoom));
    final groups = <String, List<_Entry>>{};
    for (final e in _visible) {
      if (!e.hasGps) continue;
      final key = '${(e.lat / cellDeg).floor()}:'
          '${(e.lng / cellDeg).floor()}';
      (groups[key] ??= []).add(e);
    }
    final markers = <Marker>[];
    // 锁死配套两道：
    // 格键升序产出——同一缩放档位下标记集合与顺序可重现，缩放重排时同条目倾向命中同一槽位；
    // 条目 child 自带 uid+配对数据键——State 被串到别的条目的可能性归零。
    final groupKeys = groups.keys.toList()..sort();
    for (final gk in groupKeys) {
      final members = groups[gk]!;
      final point = LatLng(
        members.map((e) => e.lat).reduce((a, b) => a + b) / members.length,
        members.map((e) => e.lng).reduce((a, b) => a + b) / members.length,
      );
      if (members.length == 1) {
        final e = members.first;
        markers.add(Marker(
          point: point,
          width: 50,
          height: 50,
          child: _MapThumb(
            // 数据身份键：缩放重排后条目↔缩略配对按数据锁死
            key: ValueKey(thumbBindingKey(e.uid, e.rel)),
            entry: e,
            onTap: () => _openViewer(
              located,
              located
                  .indexWhere((x) => x.uid == e.uid)
                  .clamp(0, located.length - 1),
            ),
          ),
        ));
      } else {
        markers.add(Marker(
          point: point,
          width: 44,
          height: 44,
          child: _ClusterBubble(
            count: members.length,
            onTap: () {
              final nearestZoom = (cam.zoom + 2.5).clamp(3.0, 18.0);
              _map.move(point, nearestZoom);
            },
          ),
        ));
      }
    }
    return markers;
  }
}

/// —— 地图缩略图 ———
class _MapThumb extends StatefulWidget {
  const _MapThumb({super.key, required this.entry, required this.onTap});

  final _Entry entry;
  final VoidCallback onTap;

  @override
  State<_MapThumb> createState() => _MapThumbState();
}

class _MapThumbState extends State<_MapThumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MapThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    final o = oldWidget.entry, n = widget.entry;
    // 锁死：缩放/重排导致 State 复用到别的条目时，
    // 绑定变化即按**新条目自带配对**重读——不同缩放档位缩略主观测问题根治点
    if (o.uid != n.uid || o.rel != n.rel || o.fullRel != n.fullRel) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.entry.rel.isNotEmpty) {
      final b = await MediaStore.load(widget.entry.rel);
      if (b != null && mounted) {
        setState(() => _bytes = b);
        return;
      }
    }
    // 视频条目：原件绝对不当图片解码（Invalid image data 防线）；缺缩略走占位
    if (widget.entry.isVideo) return;
    if (widget.entry.fullRel.isNotEmpty &&
        widget.entry.fullRel != widget.entry.rel) {
      final f = await MediaStore.load(widget.entry.fullRel);
      if (f != null && mounted) setState(() => _bytes = f);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(width: 2.5, color: Colors.white),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.5),
          child: _bytes != null
              ? Image.memory(_bytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity)
              : PhotoThumb(
                  gradientIndex: widget.entry.gradientIndex,
                  radius: 6.5,
                  iconSize: 20,
                ),
        ),
      ),
    );
  }
}

/// 底图降级链：默认高德矢量；连续失败自动回退 Esri，再失败回退 OSM
final ValueNotifier<String> _baseAttributionNote = ValueNotifier<String>('');

class _BaseTile extends StatefulWidget {
  const _BaseTile();

  @override
  State<_BaseTile> createState() => _BaseTileState();
}

class _BaseTileState extends State<_BaseTile> {
  static const _chain = [MapSources.amapVector, MapSources.esriStreet, MapSources.osm];
  int _level = 0;
  int _errs = 0;
  bool _noteInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_noteInit) {
      _noteInit = true;
      final note = AppLocalizations.of(context).baseMapAmap;
      // 首帧 build 期间不能同步写 ValueNotifier（监听中的 ValueListenableBuilder
      // 会在 build 阶段收到通知触发 setState 断言），推迟到帧末写入。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _baseAttributionNote.value != note) {
          _baseAttributionNote.value = note;
        }
      });
    }
  }

  void _onTileError() {
    _errs++;
    if (_errs >= 4 && _level < _chain.length - 1) {
      _level++;
      _errs = 0;
      final t = AppLocalizations.of(context);
      _baseAttributionNote.value = _level == 1 ? t.baseMapEsri : t.baseMapOsm;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t.baseSwitchSnack(mapSourceName(t, _chain[_level]))),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final src = _chain[_level];
    return TileLayer(
      key: ValueKey('base_${src.id}_$_level'),
      urlTemplate: src.urlTemplate,
      subdomains: src.subdomains,
      userAgentPackageName: 'com.example.atma_book',
      maxNativeZoom: 19,
      errorTileCallback: (tile, error, trace) => _onTileError(),
    );
  }
}

/// —— 数量气泡（低缩放聚合）———
class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// —— 固定层提示（pill）———
class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(18),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: AppColors.ink),
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// —— 地图控制按钮 ———
class _MapFab extends StatelessWidget {
  const _MapFab({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}

/// —— 相册库（全部照片清单：GPS 状态 + 地图显示开关）———
class _AlbumLibraryPage extends StatefulWidget {
  const _AlbumLibraryPage();

  @override
  State<_AlbumLibraryPage> createState() => _AlbumLibraryPageState();
}

class _AlbumLibraryPageState extends State<_AlbumLibraryPage> {
  bool _loading = true;
  List<Guide> _guides = [];
  List<WallPhoto> _ledger = [];
  Set<String> _hidden = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final guides = context.read<GuidesProvider>().guides;
    final ledger = await WallPhotoRepository(activeStorage).load();
    final hidden = await WallPhotoRepository(activeStorage).loadHidden();
    if (!mounted) return;
    setState(() {
      _guides = guides;
      _ledger = ledger;
      _hidden = hidden;
      _loading = false;
    });
  }

  /// 时间新→旧排列的照片（已剔除的不显示；取样上限不适用于相册库）
  List<_Entry> get _rows {
    final rows = _unitedAlbumEntries(
      guides: _guides,
      ledger: _ledger,
      cap: 1000000,
    )
        .where((e) => !_hidden.contains(e.uid))
        .toList();
    rows.sort((a, b) => b.point.takenAt.compareTo(a.point.takenAt));
    return rows;
  }

  /// 已剔除条目（管理恢复用），同样时间新→旧
  List<_Entry> get _removedRows {
    final rows = _unitedAlbumEntries(
      guides: _guides,
      ledger: _ledger,
      cap: 1000000,
    );
    final removed = [
      for (final e in rows)
        if (_hidden.contains(e.uid)) e,
    ]..sort((a, b) => b.point.takenAt.compareTo(a.point.takenAt));
    return removed;
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// 选点地图默认打开中心（已定位照片均值）
  LatLng? _pickCenter() {
    var la = 0.0;
    var lo = 0.0;
    var n = 0;
    for (final e in _rows) {
      if (e.hasGps) {
        la += e.lat;
        lo += e.lng;
        n++;
      }
    }
    return n > 0 ? LatLng(la / n, lo / n) : null;
  }

  /// 已定位条目**修改地理定位**（相册库行长按弹层进入）：选点地图**以该条
  /// 原定位为中心打开**（正在看的城市不再跳走），确认后覆盖原值并重算归属
  Future<void> _editGeo(_Entry e) async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => _GeoPickPage(initCenter: LatLng(e.lat, e.lng)),
      ),
    );
    if (picked == null) return;
    if (!mounted) return;
    await _writeGeoToEntry(context, e, picked);
    if (!mounted) return;
    _snack(AppLocalizations.of(context).geoUpdated);
    _load();
  }

  /// 点某个照片 → 全黑查看器（库全集翻页；可补地理标识 / 剔除），返回后刷新
  Future<void> _openViewer(int index) async {
    final rows = _rows;
    if (rows.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _WallViewerPage(
        entries: rows,
        initialIndex: index.clamp(0, rows.length - 1),
        onRemoveEntry: (e) async {
          final removed = await _removeAlbumPhoto(context, e);
          if (removed && mounted) {
            _snack(AppLocalizations.of(context).removedToast);
          }
        },
        onGeoSet: (e, loc) => _writeGeoToEntry(context, e, loc),
        pickInitCenter: _pickCenter(),
      ),
    ));
    _load(); // 返回相册库时刷新（地理标识 / 剔除后的行状态）
  }

  String _sourceLabel(_Entry e, AppLocalizations t) {
    if (e.guideId == null) return t.sourceAlbumImport;
    for (final g in _guides) {
      if (g.id == e.guideId) return t.sourceGuide(g.title);
    }
    return t.sourceGuidePhoto;
  }

  Future<void> _toggle(_Entry e, bool show) async {
    setState(() {
      if (show) {
        _hidden.remove(e.uid);
      } else {
        _hidden.add(e.uid);
      }
    });
    await WallPhotoRepository(activeStorage).saveHidden(_hidden);
  }

  /// 行级「剔除」：从相册显示项移除（相册库列表 / 地理相册地图 / 查看器），
  /// **不删除原始文件**；SnackBar 提供「撤销」，后续恢复走「管理已剔除」。
  Future<void> _remove(_Entry e) async {
    await _toggle(e, false);
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t.removedToastKeep),
      action: SnackBarAction(
        label: t.undoBtn,
        onPressed: () => _toggle(e, true),
      ),
    ));
  }

  /// 已剔除条目管理面板：逐条恢复 / 全部恢复
  Future<void> _openRemovedSheet() async {
    final removed = _removedRows;
    if (removed.isEmpty || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => _RemovedSheet(
        removed: removed,
        onRestore: (e) async {
          Navigator.of(sheetCtx).pop();
          await _toggle(e, true);
          if (mounted) {
            _snack(AppLocalizations.of(context).restoredToastN(1));
          }
        },
        onRestoreAll: () async {
          Navigator.of(sheetCtx).pop();
          for (final e in removed) {
            await _toggle(e, true);
          }
          if (mounted) {
            _snack(AppLocalizations.of(context).restoredToastN(removed.length));
          }
        },
      ),
    );
    _load(); // 恢复后刷新主列表
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final rows = _loading ? const <_Entry>[] : _rows;
    final removedCount = _loading ? 0 : _removedRows.length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          _loading
              ? t.albumLibTitle
              : '${t.albumLibTitle}'
                  '${removedCount > 0 ? t.removedCountSuffix(removedCount) : ''}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (removedCount > 0)
            TooltipBarrier(
              child: IconButton(
                tooltip: t.removedActionTip,
                icon: const Icon(Icons.visibility_off_outlined, size: 20),
                onPressed: _openRemovedSheet,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined,
                          size: 42, color: AppColors.inkSoft),
                      const SizedBox(height: 10),
                      Text(t.albumLibEmpty,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(t.albumLibEmptyHint,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkSoft)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: rows.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final e = rows[index];
                    return _AlbumRow(
                      // 数据身份键：uid+锁定缩略配对——条目挪位/新条目
                      // 插顶绝不复用他人 State 缓存（缩略串绑根治点之一）
                      key: ValueKey(thumbBindingKey(e.uid, e.rel)),
                      entry: e,
                      sourceLabel: _sourceLabel(e, t),
                      onRemove: () => _remove(e),
                      onOpen: () => _openViewer(index),
                      onEditGeo:
                          e.hasGps ? () => _editGeo(e) : null,
                    );
                  },
                ),
    );
  }
}

/// 相册库行：缩略图 + 名称/时间/来源 + GPS 状态 + 剔除（点行进入查看）
/// **长按已定位行 → 下方弹层「修改地理定位」**（视频已定位同样适用）：
/// 进入与补位同一选点地图重选，新选点直接覆盖原定位。
/// 行尾「剔除」= 从相册显示项移除（原文件保留），恢复走 AppBar「管理已剔除」。
class _AlbumRow extends StatefulWidget {
  const _AlbumRow({
    super.key,
    required this.entry,
    required this.sourceLabel,
    required this.onRemove,
    required this.onOpen,
    this.onEditGeo,
  });

  final _Entry entry;
  final String sourceLabel;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  /// 长按「修改地理定位」入口（null = 未定位，不提供长按——走查看器补写流程）
  final VoidCallback? onEditGeo;

  @override
  State<_AlbumRow> createState() => _AlbumRowState();
}

class _AlbumRowState extends State<_AlbumRow> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AlbumRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final o = oldWidget.entry, n = widget.entry;
    // 锁死：即便 State 被意外复用到别的条目（键缺位兜底），
    // 数据绑定一经变化即按**新条目自带配对**重读，绝不沿用旧缓存
    if (o.uid != n.uid || o.rel != n.rel || o.fullRel != n.fullRel) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.entry.rel.isNotEmpty) {
      final b = await MediaStore.load(widget.entry.rel);
      if (b != null && mounted) {
        setState(() => _bytes = b);
        return;
      }
    }
    // 视频：只显示首帧缩略；原件字节不进内存（播放走文件路径，S2）
    if (widget.entry.isVideo) return;
    if (widget.entry.fullRel.isNotEmpty) {
      final f = await MediaStore.load(widget.entry.fullRel);
      if (f != null && mounted) setState(() => _bytes = f);
    }
  }

  String _fmtTime(DateTime t) =>
      '${t.year}/${t.month}/${t.day} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 长按已定位行 → 下方弹层「修改地理定位」（照片/视频同款）。
  /// 选项确认后弹层收起 → 父页回调（push 选点地图，空图重选覆盖原定位）。
  void _showEditGeoSheet() {
    final cb = widget.onEditGeo;
    final e = widget.entry;
    if (cb == null) return;
    final t = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: _bytes != null
                          ? Image.memory(_bytes!, fit: BoxFit.cover)
                          : PhotoThumb(
                              gradientIndex: e.gradientIndex,
                              radius: 6,
                              iconSize: 14,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.currentGeoLabel('${e.lat.toStringAsFixed(4)}, '
                          '${e.lng.toStringAsFixed(4)}'),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_location_alt,
                  color: AppColors.primary),
              title: Text(
                t.editGeoTitle,
                style:
                    TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                t.editGeoHint,
                style: TextStyle(fontSize: 11.5),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                cb();
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final e = widget.entry;
    final t0 = e.point.takenAt;
    // 行标题：照片 = 拍摄时间；视频 = 「时间 · 视频 · 时长」（原先视频行只有「视频 · 时长」，拍摄时间被顶掉，与照片行信息不对称）。
    final title = e.isVideo
        ? '${_fmtTime(t0)} · ${t.videoRowTitle(e.durationMs > 0 ? ' · ${(e.durationMs / 60000).floor()}:${(e.durationMs % 60000 ~/ 1000).toString().padLeft(2, '0')}' : '')}'
        : _fmtTime(t0);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onOpen,
        onLongPress:
            widget.onEditGeo != null ? _showEditGeoSheet : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _bytes != null
                        ? Image.memory(_bytes!, fit: BoxFit.cover)
                        : PhotoThumb(
                            gradientIndex: e.gradientIndex,
                            radius: 8,
                            iconSize: 20,
                          ),
                    if (e.isVideo)
                      const Positioned(
                        right: 2,
                        bottom: 2,
                        child: Icon(Icons.play_circle_fill,
                            color: Colors.white, size: 16,
                            shadows: [Shadow(blurRadius: 3)]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.sourceLabel} · '
                    '${e.hasGps ? t.rowGps('${e.lat.toStringAsFixed(4)}, ${e.lng.toStringAsFixed(4)}') : (e.isVideo ? t.rowNoGeoVideo : t.rowNoGps)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: e.hasGps ? AppColors.inkSoft : AppColors.accent,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TooltipBarrier(
              child: IconButton(
                tooltip: t.removeRowTooltip,
                icon: const Icon(Icons.visibility_off_outlined,
                    size: 20, color: AppColors.inkSoft),
                onPressed: widget.onRemove,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// —— 已剔除条目管理面板（恢复显示；不删除原文件）———
class _RemovedSheet extends StatelessWidget {
  const _RemovedSheet({
    required this.removed,
    required this.onRestore,
    required this.onRestoreAll,
  });

  final List<_Entry> removed;
  final void Function(_Entry) onRestore;
  final VoidCallback onRestoreAll;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      child: SizedBox(
        height: 440,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 2),
              child: Row(children: [
                const Icon(Icons.visibility_off_outlined,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Text(t.removedActionTip,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(t.removedSheetHint,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ),
            ),
            Expanded(
              child: removed.isEmpty
                  ? Center(
                      child: Text(t.removedListEmpty,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.inkSoft)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: removed.length,
                      itemBuilder: (context, index) => _RemovedRow(
                        key: ValueKey(thumbBindingKey(
                            removed[index].uid, removed[index].rel)),
                        entry: removed[index],
                        onRestore: () => onRestore(removed[index]),
                      ),
                    ),
            ),
            if (removed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onRestoreAll,
                    child: Text(t.restoreAllBtn),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 已剔除面板的行：缩略 + 时间/视频 + GPS 状态 + 「恢复显示」
class _RemovedRow extends StatefulWidget {
  const _RemovedRow({super.key, required this.entry, required this.onRestore});

  final _Entry entry;
  final VoidCallback onRestore;

  @override
  State<_RemovedRow> createState() => _RemovedRowState();
}

class _RemovedRowState extends State<_RemovedRow> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _RemovedRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final o = oldWidget.entry, n = widget.entry;
    // 锁死：同 _AlbumRow / _MapThumb——绑定变化即重读
    if (o.uid != n.uid || o.rel != n.rel || o.fullRel != n.fullRel) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final e = widget.entry;
    if (e.rel.isNotEmpty) {
      final b = await MediaStore.load(e.rel);
      if (b != null && mounted) {
        setState(() => _bytes = b);
        return;
      }
    }
    // 视频：只显示首帧缩略；原件字节不进内存（播放走文件路径）
    if (e.isVideo) return;
    if (e.fullRel.isNotEmpty) {
      final f = await MediaStore.load(e.fullRel);
      if (f != null && mounted) setState(() => _bytes = f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final e = widget.entry;
    final t0 = e.point.takenAt;
    final title = e.isVideo
        ? AppLocalizations.of(context)
            .videoRowTitle(e.durationMs > 0
                ? ' · ${(e.durationMs / 60000).floor()}:${(e.durationMs % 60000 ~/ 1000).toString().padLeft(2, '0')}'
                : '')
        : '${t0.year}/${t0.month}/${t0.day} '
            '${t0.hour.toString().padLeft(2, '0')}:${t0.minute.toString().padLeft(2, '0')}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 44,
          height: 44,
          child: _bytes != null
              ? Image.memory(_bytes!, fit: BoxFit.cover)
              : PhotoThumb(
                  gradientIndex: e.gradientIndex,
                  radius: 6,
                  iconSize: 16,
                ),
        ),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: e.hasGps
          ? Text(
              '${e.lat.toStringAsFixed(3)}, ${e.lng.toStringAsFixed(3)}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: TextButton(
        onPressed: widget.onRestore,
        child: Text(t.restoreBtn,
            style: TextStyle(fontSize: 12.5, color: AppColors.primary)),
      ),
    );
  }
}

/// —— 精选加入确认面板（逐张勾选）———
class _CurateSheet extends StatefulWidget {
  const _CurateSheet({required this.payloads});

  final List<Uint8List> payloads;

  @override
  State<_CurateSheet> createState() => _CurateSheetState();
}

class _CurateSheetState extends State<_CurateSheet> {
  final _chosen = <int>{};

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.curateTitle),
      content: SizedBox(
        width: 440,
        height: 420,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: widget.payloads.length,
          itemBuilder: (context, index) {
            final chosen = _chosen.contains(index);
            return GestureDetector(
              onTap: () => setState(() {
                chosen ? _chosen.remove(index) : _chosen.add(index);
              }),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            width: chosen ? 2.5 : 0,
                            color: chosen
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Image.memory(widget.payloads[index],
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  if (chosen)
                    const Positioned(
                      right: 3,
                      bottom: 3,
                      child: Icon(Icons.check_circle,
                          size: 16, color: AppColors.primary),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.of(context).pop(_chosen.toList()),
          child: Text(t.curateAdd(_chosen.length)),
        ),
      ],
    );
  }
}

/// —— 全黑虚拟空间查看（翻页 + 剔除 + 补地理标识）———
class _WallViewerPage extends StatefulWidget {
  const _WallViewerPage({
    required this.entries,
    required this.initialIndex,
    required this.onRemoveEntry,
    required this.onGeoSet,
    this.pickInitCenter,
  });

  final List<_Entry> entries;
  final int initialIndex;
  final Future<void> Function(_Entry entry) onRemoveEntry;
  final Future<void> Function(_Entry entry, LatLng loc) onGeoSet;

  /// 选点地图的打开中心（当前照片群均值 / 用户位置）
  final LatLng? pickInitCenter;

  @override
  State<_WallViewerPage> createState() => _WallViewerPageState();
}

class _WallViewerPageState extends State<_WallViewerPage> {
  late final PageController _page;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  String _fmtTime(DateTime t) =>
      '${t.year}/${t.month}/${t.day} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 无地理标识照片=补写（首次定位，打开中心=当前定位/全库均值）/
  /// 已定位=修改（打开中心=**该条原定位**）：打开点选地图 → 确认 → 返回上级
  /// （刷新后可见新落点；原有定位被新选点直接覆盖）
  Future<void> _geoFlow(_Entry e) async {
    // 预捕获导航器：写入后无需再触碰跨异步的 context
    final nav = Navigator.of(context);
    // 已定位 → 以原坐标为中心（改点场景）；无定位 → 当前定位/群均值兜底
    final center = e.hasGps
        ? LatLng(e.lat, e.lng)
        : (widget.pickInitCenter ?? const LatLng(35.0, 108.0));
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => _GeoPickPage(initCenter: center),
      ),
    );
    if (picked == null || !mounted) return;
    await widget.onGeoSet(e, picked);
    if (!mounted) return;
    // 写入完成：收起查看器，回到打开它的页面（地图新落点 / 相册库刷新）
    if (nav.canPop()) {
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final n = widget.entries.length;
    final safe = n == 0 ? -1 : _index.clamp(0, n - 1);
    // 预捕获导航器：剔除后收起查看器无需触碰跨异步的 context
    final nav = Navigator.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          n == 0
              ? t.viewPhotosTitle
              : '${safe + 1} / $n · ${_fmtTime(widget.entries[safe].point.takenAt)}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: n == 0
          ? const SizedBox()
          : PageView.builder(
              controller: _page,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: n,
              itemBuilder: (context, index) {
                final e = widget.entries[index];
                return _BlackCard(
                  entry: e,
                  onRemove: () async {
                    await widget.onRemoveEntry(e);
                    if (!mounted) return;
                    if (widget.entries.isEmpty) {
                      if (nav.canPop()) {
                        nav.pop();
                      }
                    } else {
                      setState(() {
                        _index = _index.clamp(0, widget.entries.length - 1);
                      });
                    }
                  },
                  hasGeo: e.hasGps,
                  onPickGeo: () => _geoFlow(e), // 无定位=补写 / 已定位=修改（同一选图流程）
                );
              },
            ),
    );
  }
}

/// —— 全黑虚拟空间查看卡片 ———
/// 视频小 ▶ 角标（查看器/行卡共用）
class _VideoMiniBadge extends StatelessWidget {
  const _VideoMiniBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
    );
  }
}

class _BlackCard extends StatelessWidget {
  const _BlackCard({
    required this.entry,
    required this.onRemove,
    required this.hasGeo,
    required this.onPickGeo,
  });

  final _Entry entry;
  final VoidCallback onRemove;
  final bool hasGeo;
  final VoidCallback? onPickGeo;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // 视频条目：**不加载视频原件字节**（大文件会撑爆内存）——
    // 只显示首帧缩略 + ▶ 角标/时长；播放页在后面接入。geo 补位流程同照片。
    final rel = entry.isVideo && entry.rel.isNotEmpty
        ? entry.rel
        : (entry.fullRel.isNotEmpty ? entry.fullRel : entry.rel);
    final media = entry.isVideo
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FutureBuilder<Uint8List?>(
                      future: MediaStore.load(rel),
                      builder: (context, snap) {
                        if (snap.data != null) {
                          return Image.memory(snap.data!,
                              fit: BoxFit.contain);
                        }
                        return PhotoThumb(
                          gradientIndex: entry.gradientIndex,
                          radius: 12,
                          iconSize: 42,
                          width: 250,
                          height: 250,
                        );
                      },
                    ),
                  ),
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: _VideoMiniBadge(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  if (entry.fullRel.isEmpty) return;
                  final t = entry.point.takenAt;
                  final stamp =
                      '${t.year}/${t.month}/${t.day} '
                      '${t.hour.toString().padLeft(2, '0')}:'
                      '${t.minute.toString().padLeft(2, '0')}';
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VideoPlayerPage(
                      relPath: entry.fullRel,
                      title: stamp,
                    ),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow, size: 17),
                      const SizedBox(width: 4),
                      Text(
                        entry.durationMs > 0
                            ? t.playWithDuration('${(entry.durationMs / 60000).floor()}:'
                                '${(entry.durationMs % 60000 ~/ 1000).toString().padLeft(2, '0')}')
                            : t.playVideoBtn,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : null;
    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: entry.isVideo && media != null
                  ? media
                  : FutureBuilder<Uint8List?>(
                      future: MediaStore.load(rel),
                      builder: (context, snap) {
                        if (snap.data != null) {
                          return Image.memory(snap.data!, fit: BoxFit.contain);
                        }
                        return FutureBuilder<Uint8List?>(
                          future: MediaStore.load(entry.rel),
                          builder: (context, snap2) {
                            if (snap2.data != null) {
                              return Image.memory(snap2.data!,
                                  fit: BoxFit.contain);
                            }
                            return PhotoThumb(
                              gradientIndex: entry.gradientIndex,
                              radius: 12,
                              iconSize: 42,
                              width: 250,
                              height: 250,
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 20,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasGeo)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: onPickGeo,
                    icon: const Icon(Icons.add_location_alt, size: 17),
                    label: Text(t.geoTagTitle,
                        style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              if (hasGeo)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: onPickGeo, // 已定位 → 同一选点流程（重选覆盖）
                    icon: const Icon(Icons.edit_location_alt, size: 17),
                    label: Text(t.editGeoTitle,
                        style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                onPressed: onRemove,
                icon: const Icon(Icons.auto_delete_outlined, size: 17),
                label:
                    Text(t.removeThisPhoto, style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// —— 地理标识点选页：缩放找位、点击落点、底部经纬度 + 确认 ———
class _GeoPickPage extends StatefulWidget {
  const _GeoPickPage({required this.initCenter});

  final LatLng initCenter;

  @override
  State<_GeoPickPage> createState() => _GeoPickPageState();
}

class _GeoPickPageState extends State<_GeoPickPage> {
  final MapController _map = MapController();
  LatLng? _picked;

  void _zoomBy(int d) {
    _map.move(_map.camera.center, (_map.camera.zoom + d).clamp(3.0, 18.0));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(t.geoTagTitle,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: widget.initCenter,
                initialZoom: 13,
                minZoom: 3,
                maxZoom: 18,
                onTap: (tapPos, latlng) => setState(() => _picked = latlng),
              ),
              children: [
                const _BaseTile(),
                if (_picked != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _picked!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border:
                                Border.all(width: 2.5, color: Colors.white),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.location_on,
                              size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _MapFab(icon: Icons.zoom_in, onTap: () => _zoomBy(1)),
                const SizedBox(height: 8),
                _MapFab(icon: Icons.zoom_out, onTap: () => _zoomBy(-1)),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _picked == null
                          ? t.pickHint
                          : t.pickedHint,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _picked == null
                                ? t.noLocationYet
                                : '${_picked!.latitude.toStringAsFixed(6)}, '
                                    '${_picked!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: _picked == null
                              ? null
                              : () => Navigator.of(context).pop(_picked),
                          child: Text(t.confirmLocation),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 2,
            child: ValueListenableBuilder<String>(
              valueListenable: _baseAttributionNote,
              builder: (_, note, _) => Text(
                note,
                style: const TextStyle(
                    fontSize: 9.5,
                    color: Colors.black54,
                    backgroundColor: Color(0x66FFFFFF)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
