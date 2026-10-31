import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/io/storage_adapter.dart';
import '../widgets/tooltip_barrier.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/guide.dart';
import '../../data/models/wall_photo.dart';
import '../../data/repos/wall_photo_repository.dart';
import '../../services/media_store.dart';
import '../../services/offline_tile_provider.dart';
import '../../state/guide_editor.dart';
import '../../state/guides_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/pin_widget.dart';
import 'guide_info_edit_sheet.dart';
import 'legend_card.dart';
import 'map_source_sheet.dart';
import 'marker_detail_sheet.dart';
import 'marker_edit_page.dart';
import 'marker_list_drawer.dart';
import '../share/share_export_sheet.dart';
import '../photos/photo_viewer_page.dart';
import '../photos/video_player_page.dart';
import '../notes/guide_notes_page.dart';
import '../widgets/photo_map_badge.dart';

/// 攻略地图页：底图切换 / 图层控制 / 真实标记增删改，长按放点、列表抽屉
class GuideMapPage extends StatelessWidget {
  const GuideMapPage({super.key, required this.guide});

  final Guide guide;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          GuideEditor(guide,
              guides: ctx.read<GuidesProvider>(),
              settings: ctx.read<AppSettings>()),
      child: const _GuideMapView(),
    );
  }
}

class _GuideMapView extends StatefulWidget {
  const _GuideMapView();

  @override
  State<_GuideMapView> createState() => _GuideMapViewState();
}

class _GuideMapViewState extends State<_GuideMapView> {
  final MapController _map = MapController();

  /// 地理相册：归属本攻略的照片在攻略地图照片层合并展示。
  /// 进入地图页时读一次快照（导入照片须从首页进入相册页，地图页生命周期内无变更）。
  List<WallPhoto> _ledger = [];

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    try {
      final l = await WallPhotoRepository(activeStorage).load();
      if (mounted) setState(() => _ledger = l);
    } catch (_) {}
  }

  /// 账本中归属本攻略的定位照片（就近5km 自动归属），转换为展示用 PhotoItem
  /// （id 加 `w:` 前缀与攻略内照片区分，只读展示不参与攻略编辑）。
  Iterable<PhotoItem> _ledgerPhotosFor(String guideId) sync* {
    for (final w in _ledger) {
      if (w.guideId != guideId || !w.hasGps) continue;
      yield PhotoItem(
        id: 'w:${w.id}',
        lat: w.lat,
        lng: w.lng,
        takenAt: w.takenAt,
        file: w.file,
        thumb: w.thumb,
        name: w.name,
        kind: w.kind,
        durationMs: w.durationMs,
      );
    }
  }

  void _zoom(double delta) {
    final camera = MapCamera.of(context);
    _map.move(camera.center, camera.zoom + delta);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  ClusterZone? _zoneOf(GuideEditor ed, Place p) => ed.zoneOf(p);

  void _openDetail(BuildContext context, GuideEditor ed, Place place) {
    final zone = _zoneOf(ed, place);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) =>
          MarkerDetailSheet(place: place, editor: ed, zone: zone),
    );
  }

  /// 新增标记（长按坐标 / FAB 地图中心）
  Future<void> _newMarkerAt(GuideEditor ed, LatLng point) async {
    final place = Place(
      id: '',
      title: '',
      categoryId: MarkerCategory.scenic.id,
      lat: point.latitude,
      lng: point.longitude,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarkerEditPage(
          editor: ed,
          place: place,
          isNew: true,
        ),
      ),
    );
  }

  void _openInfoSheet(BuildContext context, GuideEditor ed) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) => GuideInfoEditSheet(editor: ed),
    );
  }

  /// 重设本攻略的游览区域参数（右上角 ⋮ 菜单入口；默认值 = 通用设置范围）
  void _openZoneParamsDialog(BuildContext context, GuideEditor ed) {
    final t = AppLocalizations.of(context);
    final gs = ed.guide.settings;
    // 当前生效值：攻略覆写优先，未覆写项读【通用设置】的真实值（而非内置默认）
    final settings = context.read<AppSettings>();
    double radiusKm = (gs.zoneRadiusOverrideM != null
            ? gs.zoneRadiusOverrideM! / 1000
            : settings.clusterRadiusKm)
        .clamp(1, 20);
    int minPts = gs.zoneMinPtsOverride ?? settings.clusterMinPoints;
    final followGlobal =
        gs.zoneRadiusOverrideM == null && gs.zoneMinPtsOverride == null;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(t.zoneDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(t.zoneRadiusDialogTitle,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${radiusKm.round()} km',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ],
              ),
              Slider(
                value: radiusKm,
                min: 1,
                max: 20,
                divisions: 19,
                label: '${radiusKm.round()} km',
                activeColor: AppColors.primary,
                onChanged: (v) => setDialogState(() => radiusKm = v),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(t.zoneMinPtsLabel,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 2, label: Text('2')),
                      ButtonSegment(value: 3, label: Text('3')),
                      ButtonSegment(value: 4, label: Text('4')),
                    ],
                    selected: {minPts},
                    onSelectionChanged: (s) =>
                        setDialogState(() => minPts = s.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                        visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                t.zoneDialogFoot,
                style: const TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.5),
              ),
              Text(
                followGlobal
                    ? t.zoneDialogFollowState
                    : t.zoneDialogOverridden,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.inkSoft, height: 1.5),
              ),
            ],
          ),
          actions: [
            if (gs.zoneRadiusOverrideM != null ||
                gs.zoneMinPtsOverride != null)
              TextButton(
                onPressed: () {
                  ed.setZoneParams(clearOverride: true);
                  Navigator.of(dialogCtx).pop();
                  _snack(t.snackZoneRestored);
                },
                child: Text(t.btnRestoreGlobal),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () {
                ed.setZoneParams(
                  radiusOverrideM: radiusKm * 1000,
                  minPtsOverride: minPts,
                );
                Navigator.of(dialogCtx).pop();
                _snack(t.snackZoneApplied);
              },
              child: Text(t.btnApplyRecalc),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ed = context.watch<GuideEditor>();
    final simplified =
        context.watch<AppSettings>().pinMode == PinDisplayMode.colored;
    final guide = ed.guide;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(guide.title,
            style: const TextStyle(
                fontSize: 16.5, fontWeight: FontWeight.bold)),
        actions: [
          TooltipBarrier(
            child: IconButton(
              tooltip: t.legendTitle,
              icon: Icon(
                Icons.legend_toggle,
                color: ed.showLegend ? AppColors.primary : AppColors.inkSoft,
              ),
              onPressed: ed.toggleLegend,
            ),
          ),
          TooltipBarrier(
            child: IconButton(
              tooltip: t.mapTooltipLayers,
              icon: const Icon(Icons.layers_outlined),
              onPressed: () => _showLayersSheet(context, ed),
            ),
          ),
          TooltipBarrier(
            child: IconButton(
              tooltip: t.mapTooltipSource,
              icon: const Icon(Icons.public),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => MapSourceSheet(editor: ed),
              ),
            ),
          ),
          TooltipBarrier(
            child: PopupMenuButton<String>(
              tooltip: t.mapTooltipMore,
              icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'info') {
                _openInfoSheet(context, ed);
              } else if (v == 'notes') {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GuideNotesPage(guide: ed.guide),
                ));
              } else if (v == 'zoneset') {
                _openZoneParamsDialog(context, ed);
              } else if (v == 'share') {
                openShareExportSheet(context, guide);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.guideActionInfo,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  )),
              PopupMenuItem(
                  value: 'notes',
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.mapMenuNotes,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  )),
              PopupMenuItem(
                  value: 'zoneset',
                  child: Row(
                    children: [
                      const Icon(Icons.tune, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.mapMenuZoneParams,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  )),
              PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      const Icon(Icons.ios_share, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.mapMenuShare,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  )),
            ],
          ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: ed.initialCenter,
              initialZoom: 13,
              onLongPress: (tapPos, point) => _newMarkerAt(ed, point),
            ),
            children: _mapLayers(context, ed, simplified: simplified),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _MapFab(icon: Icons.zoom_in, onTap: () => _zoom(1)),
                const SizedBox(height: 8),
                _MapFab(icon: Icons.zoom_out, onTap: () => _zoom(-1)),
                const SizedBox(height: 8),
                _MapFab(
                  icon: Icons.my_location,
                  onTap: () => _snack(t.mapFabLocate),
                ),
              ],
            ),
          ),
          if (ed.showLegend)
            Positioned(
              left: 12,
              bottom: 16,
              child: LegendCard(guide: guide),
            ),
          if (!ed.showLegend)
            Positioned(
              left: 12,
              bottom: 16,
              child: Center(
                child: _HintPill(text: t.mapHintPill),
              ),
            ),
        ],
      ),
      endDrawer: MarkerListDrawer(
        editor: ed,
        onOpen: (p) {
          Navigator.pop(context); // 关抽屉
          final cam = _map.camera;
          _map.move(LatLng(p.lat, p.lng), cam.zoom);
          _openDetail(context, ed, p);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_location_alt),
        label: Text(t.mapFabMarkers),
        onPressed: () => _newMarkerAt(ed, _map.camera.center),
      ),
    );
  }

  List<Widget> _mapLayers(BuildContext context, GuideEditor ed,
      {required bool simplified}) {
    final guide = ed.guide;
    final tk = context.read<AppSettings>().tiandituKey;
    final layers = <Widget>[
      _BaseTileLayer(
        editor: ed,
        tiandituKey: tk,
      ),
    ];

    // 片区范围圈（色带）
    if (ed.showZones) {
      layers.add(
        CircleLayer(
          circles: [
            for (final zone in guide.clusters)
              CircleMarker(
                point: zone.center,
                radius: zone.radiusMeters,
                useRadiusInMeter: true,
                color: zone.color.withValues(alpha: 0.07),
                borderStrokeWidth: 1.5,
                borderColor: zone.color.withValues(alpha: 0.45),
              ),
          ],
        ),
      );
    }

    // GPS 照片（真实文件缩略图，点开大图；无定位不上图）。
    // 来源合并：
    // 攻略内照片（Guide.photos，可编辑/绑定标记）；
    // 地理相册账本中归属本攻略的照片（就近规则自动归，只读查看）
    if (ed.showPhotos) {
      layers.add(
        MarkerLayer(
          markers: [
            for (final photo in guide.photos)
              if (photo.hasGps ||
                  (photo.placeId != null &&
                      guide.markers.any((m) => m.id == photo.placeId)))
                Marker(
                  point: photo.hasGps
                      ? LatLng(photo.lat!, photo.lng!)
                      : LatLng(
                          guide.markers
                              .firstWhere((m) => m.id == photo.placeId)
                              .lat,
                          guide.markers
                              .firstWhere((m) => m.id == photo.placeId)
                              .lng,
                        ),
                  width: 46,
                  height: 46,
                  child: GestureDetector(
                    onTap: () =>
                        // 视频条目点播；照片保持照片查看器
                        photo.isVideo
                            ? VideoPlayerPage.openWith(context, photo)
                            : Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PhotoViewerPage(photo: photo, ed: ed),
                                ),
                              ),
                    child: PhotoMapBadge(photo: photo),
                  ),
                ),
            // 相册照片（只读大图：不支持改名/删除/绑定——管理钧在地理相册页）
            for (final photo in _ledgerPhotosFor(guide.id))
              Marker(
                point: LatLng(photo.lat!, photo.lng!),
                width: 46,
                height: 46,
                child: GestureDetector(
                  onTap: () => photo.isVideo
                      ? VideoPlayerPage.openWith(context, photo)
                      : Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PhotoViewerPage(
                                photo: photo, ed: ed, readOnly: true),
                          ),
                        ),
                  child: PhotoMapBadge(photo: photo),
                ),
              ),
          ],
        ),
      );
    }

    // 地点标记 Pin
    if (ed.showMarkers) {
      layers.add(
        MarkerLayer(
          markers: [
            for (final place in guide.markers)
              Marker(
                point: LatLng(place.lat, place.lng),
                width: 44,
                height: 58,
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {
                    ed.select(place);
                    _openDetail(context, ed, place);
                  },
                  child: PinWidget(
                    color: place.pinColor,
                    icon: place.category.icon,
                    // Pin 图：分类自定义图标（可定制）
                    iconBytes: MediaStore.cacheBytes(
                        place.iconPath ?? place.category.image),
                    size: 38,
                    mustVisit: place.mustVisit,
                    ringColor: ed.zoneOf(place)?.color,
                    simplified: simplified,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return layers;
  }

  void _showLayersSheet(BuildContext context, GuideEditor ed) {
    final t = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SingleChildScrollView(
        // 底板限高小于内容时可滚动
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(t.layersTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              dense: true,
            ),
            StatefulBuilder(
              builder: (sheetCtx, setSheetState) => Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.push_pin_outlined),
                    title: Text(t.layerMarkers),
                    subtitle: Text(t.layerMarkersSub),
                    value: ed.showMarkers,
                    onChanged: (_) {
                      ed.toggleMarkers();
                      setSheetState(() {});
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.blur_on),
                    title: Text(t.layerZoneCircles),
                    subtitle: Text(t.layerZoneCirclesSub),
                    value: ed.showZones,
                    onChanged: (_) {
                      ed.toggleZones();
                      setSheetState(() {});
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.photo_outlined),
                    title: Text(t.layerPhotosTitle),
                    subtitle: Text(t.layerPhotosSub),
                    value: ed.showPhotos,
                    onChanged: (_) {
                      ed.togglePhotos();
                      setSheetState(() {});
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.legend_toggle_outlined),
                    title: Text(t.legendTitle),
                    value: ed.showLegend,
                    onChanged: (_) {
                      ed.toggleLegend();
                      // 收起菜单，让用户查看地图上图例的显隐
                      Navigator.pop(sheetCtx);
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.refresh_outlined),
                    title: Text(t.recalcTitle),
                    subtitle: Text(
                      t.recalcSub,
                      style: const TextStyle(fontSize: 11),
                    ),
                    dense: true,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      fireAndForget(ed.recomputeClusters());
                      _snack(t.snackRecalcRunning);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底图瓦片层：离线包源 → 离线 Provider（缺失片在线回退/灰块）；
/// 在线源 → urlTemplate（天地图源注入设置页 tk）
class _BaseTileLayer extends StatelessWidget {
  const _BaseTileLayer({required this.editor, required this.tiandituKey});

  final GuideEditor editor;
  final String tiandituKey;

  @override
  Widget build(BuildContext context) {
    final ed = editor;
    if (ed.offlinePack != null) {
      return FutureBuilder<OfflineTileProvider?>(
        future: ed.ensureOfflineProvider(onlineFallback: true),
        builder: (context, snap) {
          final provider = snap.data;
          if (provider == null) {
            return const SizedBox.shrink(); // 扫描中：短暂无底图（灰底兜底）
          }
          return TileLayer(
            tileProvider: provider,
            maxNativeZoom: 19,
          );
        },
      );
    }
    return TileLayer(
      urlTemplate: ed.source.needsKey
          ? ed.source.urlTemplate.replaceFirst('{key}', tiandituKey)
          : ed.source.urlTemplate,
      subdomains: ed.source.subdomains,
      userAgentPackageName: 'com.example.atma_book',
      maxNativeZoom: 19,
    );
  }
}

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

class _HintPill extends StatelessWidget {
  const _HintPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
    );
  }
}
