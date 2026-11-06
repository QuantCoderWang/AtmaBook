import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../core/io/storage_adapter.dart';
import '../data/models/guide.dart';
import '../data/models/map_source.dart';
import '../data/repos/tile_repository.dart';
import '../services/cluster_service.dart';
import '../services/media_store.dart';
import '../services/offline_tile_provider.dart';
import 'guides_provider.dart';
import 'settings_provider.dart';

/// 一篇攻略的地图编辑态：图层开关 / 当前地图源 / 选中标记。
/// 所有攻略内容改动都经 [checkpoint] 数据仓库。
class GuideEditor extends ChangeNotifier {
  GuideEditor(this.guide, {GuidesProvider? guides, AppSettings? settings})
      : source = MapSources.byId(guide.sourceId) ??
            MapSources.forRegion(guide.region),
        showZones = guide.settings.showRoutes {
    _guides = guides;
    _settings = settings;
    _lastRadiusKm = settings?.clusterRadiusKm;
    _lastMinPts = settings?.clusterMinPoints;
    settings?.addListener(_onSettingsChanged);
    _prefetchMedia();
    fireAndForget(restoreOfflineSource());
  }

  late final GuidesProvider? _guides;
  late final AppSettings? _settings;

  double? _lastRadiusKm;
  int? _lastMinPts;
  bool _recomputing = false;
  bool _recomputePending = false;

  Guide guide;

  MapSource source;

  /// 离线包源（guide.sourceId 形如 pack 前缀 id 时非空）
  TilePack? offlinePack;

  /// 离线 Provider 缓存（按 packId+刷新版本失效；避免每次重绘重扫目录）
  OfflineTileProvider? offlineProvider;
  String? _providerPackId;

  bool showMarkers = true;
  bool showZones;
  bool showPhotos = true;
  bool showLegend = false;

  Place? selectedPlace;

  /// 攻略内容检查点：写回 provider（即写回 JSON 仓库）并通知界面
  Guide _commit(Guide updated) {
    guide = updated;
    final p = _guides;
    if (p != null) {
      p.replace(updated); // provider 会异步写 JSON
    }
    notifyListeners();
    return updated;
  }

  void _prefetchMedia() {
    // 把标记图片与自定义图标预读入内存缓存（best effort，不阻塞启动）
    for (final m in guide.markers) {
      for (final rel in m.images) {
        fireAndForget(MediaStore.load(rel));
      }
      if (m.iconPath != null) {
        fireAndForget(MediaStore.load(m.iconPath!));
      }
    }
    // 分类自定义图片图标（设置页上传）预读：PinWidget /
    // CategoryIcon 走 cacheBytes 同步取图，未预热会闪回退图标
    for (final c in MarkerCategory.all) {
      if (c.image != null) {
        fireAndForget(MediaStore.load(c.image!));
      }
    }
  }

  // 标记增删改（必去或位置变化时自动重聚类）

  void addPlace(Place p) {
    _commit(guide.copyWith(
      markers: [...guide.markers, p],
      updatedAt: DateTime.now(),
    ));
    fireAndForget(recomputeClusters());
  }

  void updatePlace(Place updated) {
    final before = byPlaceId(updated.id);
    final relevant = before == null ||
        before.mustVisit != updated.mustVisit ||
        before.lat != updated.lat ||
        before.lng != updated.lng;
    _commit(guide.copyWith(
      markers: [
        for (final m in guide.markers)
          if (m.id == updated.id) updated else m,
      ],
      updatedAt: DateTime.now(),
    ));
    if (relevant) {
      fireAndForget(recomputeClusters());
    }
  }

  /// 删除标记：断链照片清理（文件 best effort）后落库
  void removePlace(String placeId) {
    final place = byPlaceId(placeId);
    if (place == null) return;
    for (final rel in place.images) {
      fireAndForget(MediaStore.deleteImage(rel));
    }
    if (place.iconPath != null) {
      fireAndForget(MediaStore.deleteImage(place.iconPath!));
    }
    final nextSelected =
        selectedPlace?.id == placeId ? null : selectedPlace;
    selectedPlace = nextSelected;
    _commit(guide.copyWith(
      markers: guide.markers.where((m) => m.id != placeId).toList(),
      updatedAt: DateTime.now(),
    ));
    fireAndForget(recomputeClusters());
  }

  /// 切换必去 / 选去（图例与首页统计即时联动）
  void toggleMustVisit(String placeId) {
    final p = byPlaceId(placeId);
    if (p == null) return;
    updatePlace(p.copyWith(mustVisit: !p.mustVisit));
  }

  Place? byPlaceId(String id) {
    for (final m in guide.markers) {
      if (m.id == id) return m;
    }
    return null;
  }

  // 地图源

  /// 在构造时恢复离线包源状态（sourceId 带 pack 前缀则回填 offlinePack）
  Future<void> restoreOfflineSource() async {
    final packId = TilePack.parsePackId(guide.sourceId);
    if (packId == null) return;
    final packs = await TileRepository(activeStorage).loadPacks();
    final p = packs.where((x) => x.id == packId).toList();
    if (p.isNotEmpty) {
      offlinePack = p.first;
      notifyListeners();
    }
  }

  /// 选择离线包作为底图
  void setPackSource(TilePack pack) {
    offlinePack = pack;
    _providerPackId = null; // 触发重建 Provider
    _commit(guide.copyWith(
      sourceId: TilePack.packKey(pack.id),
      updatedAt: DateTime.now(),
    ));
  }

  /// 选择源并持久化到攻略本体（天地图 key 校验由调用方处理）
  void setSource(MapSource s) {
    source = s;
    offlinePack = null;
    _commit(guide.copyWith(sourceId: s.id, updatedAt: DateTime.now()));
  }

  /// 取（必要时构建）离线 Provider；纯离线模式 fallback=false
  Future<OfflineTileProvider?> ensureOfflineProvider(
      {required bool onlineFallback}) async {
    final pack = offlinePack;
    if (pack == null) return null;
    if (_providerPackId != pack.id || offlineProvider == null) {
      offlineProvider = await OfflineTileProvider.load(
        [pack],
        onlineFallback: onlineFallback,
      );
      _providerPackId = pack.id;
    }
    return offlineProvider;
  }

  /// 攻略信息（标题/简介/封面）修改后由攻略信息弹层回写
  void applyGuide(Guide g) {
    guide = g;
    notifyListeners();
  }

  void select(Place? p) {
    selectedPlace = p;
    notifyListeners();
  }

  void toggleMarkers() => _set(() => showMarkers = !showMarkers);
  void toggleZones() => _set(() => showZones = !showZones);
  void togglePhotos() => _set(() => showPhotos = !showPhotos);
  void toggleLegend() => _set(() => showLegend = !showLegend);

  void _set(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  // 照片库：增加、更新、删除、预读

  /// 导入完成后的批量落库（新照片在清单尾部）
  void addPhotos(List<PhotoItem> items) {
    if (items.isEmpty) return;
    _commit(guide.copyWith(
      photos: [...guide.photos, ...items],
      updatedAt: DateTime.now(),
    ));
    for (final p in items) {
      if (p.file.isNotEmpty) fireAndForget(MediaStore.load(p.file));
      if (p.thumb.isNotEmpty) fireAndForget(MediaStore.load(p.thumb));
    }
  }

  /// 更新单张（重命名 / 手动绑定标记）
  void updatePhoto(PhotoItem updated) {
    _commit(guide.copyWith(
      photos: [
        for (final p in guide.photos)
          if (p.id == updated.id) updated else p,
      ],
      updatedAt: DateTime.now(),
    ));
  }

  /// 删除照片（连原图与缩略图文件；失败静默）
  void removePhoto(String photoId) {
    for (final p in guide.photos) {
      if (p.id != photoId) continue;
      if (p.file.isNotEmpty) fireAndForget(MediaStore.deleteImage(p.file));
      if (p.thumb.isNotEmpty) fireAndForget(MediaStore.deleteImage(p.thumb));
    }
    _commit(guide.copyWith(
      photos: guide.photos.where((p) => p.id != photoId).toList(),
      updatedAt: DateTime.now(),
    ));
  }

  /// 半径/最少点数变化 → 自动重聚类
  /// 本攻略若已完全自管（两项参数均覆写），通用设置变化不再影响本攻略。
  void _onSettingsChanged() {
    final s = _settings;
    if (s == null) return;
    final changed = s.clusterRadiusKm != _lastRadiusKm ||
        s.clusterMinPoints != _lastMinPts;
    _lastRadiusKm = s.clusterRadiusKm;
    _lastMinPts = s.clusterMinPoints;
    if (!changed) return;
    final g = guide.settings;
    if (g.zoneRadiusOverrideM != null && g.zoneMinPtsOverride != null) {
      return; // 攻略已自管参数，通用设置与本攻略无关
    }
    recomputeClusters();
  }

  /// 重设本攻略的片区参数：
  /// - [clearOverride] = true 恢复「跟随通用设置」；
  /// - 保存后立即按新参数重算片区。
  void setZoneParams({double? radiusOverrideM, int? minPtsOverride,
      bool clearOverride = false}) {
    _commit(guide.copyWith(
      settings: guide.settings.copyWith(
        radiusOverrideM: radiusOverrideM,
        minPtsOverride: minPtsOverride,
        clearOverrides: clearOverride,
      ),
      updatedAt: DateTime.now(),
    ));
    fireAndForget(recomputeClusters());
  }

  /// 重算片区（仅有片区，无路线；不联网）：
  /// - 标记增删/必去切换/参数变化/手动入口均触发；
  /// - 有效参数：攻略覆写值优先，未覆写的项跟随通用设置；
  /// - 并发重算合并：运行中再来请求则完成后补跑一次。
  Future<void> recomputeClusters() async {
    if (_recomputing) {
      _recomputePending = true;
      return;
    }
    _recomputing = true;
    try {
      final gs = guide.settings;
      final eps = gs.zoneRadiusOverrideM ??
          ((_settings?.clusterRadiusKm ??
                  AppDefaults.clusterRadiusMeters / 1000) *
              1000);
      final minPts = gs.zoneMinPtsOverride ??
          _settings?.clusterMinPoints ??
          AppDefaults.clusterMinPoints;
      final result = await ClusterService.buildZones(
        guide: guide,
        epsMeters: eps,
        minPts: minPts,
      );
      _commit(guide.copyWith(clusters: result.zones));
    } finally {
      _recomputing = false;
      if (_recomputePending) {
        _recomputePending = false;
        // 忽略: discarded_futures
        recomputeClusters();
      }
    }
  }

  /// 标记所在片区
  ClusterZone? zoneOf(Place p) {
    for (final z in guide.clusters) {
      if (z.memberIds.contains(p.id)) return z;
    }
    return null;
  }

  String get zoneBalanceLabel => '${guide.clusters.length}';

  /// 初始视野：有标记则落在第一个标记
  LatLng get initialCenter {
    if (guide.markers.isEmpty) return const LatLng(30.2489, 120.1432);
    final first = guide.markers.first;
    return LatLng(first.lat, first.lng);
  }

  @override
  void dispose() {
    _settings?.removeListener(_onSettingsChanged);
    super.dispose();
  }
}

/// 触发一个不关心结果与错误的 Future
void fireAndForget<T>(Future<T> future) {
  future.ignore();
}
