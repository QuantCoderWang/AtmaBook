import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/geo.dart';
import '../../core/i18n_names.dart';
import '../../data/models/guide.dart';
import '../../l10n/app_localizations.dart';
import '../../services/guide_notes_service.dart';
import '../../services/navigator_service.dart';
import '../../state/settings_provider.dart';
import '../widgets/category_icon.dart';
import '../widgets/photo_thumb.dart';
import '../widgets/tooltip_barrier.dart';
import '../widgets/rel_image.dart';

/// 攻略笔记（自动生成，不额外占存储）：
/// 片区来自攻略聚类结果，没有聚类时按攻略覆写或通用设置临时重算，不落库。
/// 顺序：有住宿按到片区中心的距离升序（推荐住宿默认选中）；
/// 无住宿按片区游览点数降序。
/// 片区卡里依次是范围标记、景点（必去在前、选去附挂），
/// 再是圈内餐饮/购物推荐（全量）；图文或照片缺失标「暂缺」。
/// 坐标都能点导航（桌面默认高德，公交，见 NavigatorService）。
class GuideNotesPage extends StatefulWidget {
  const GuideNotesPage({super.key, required this.guide});

  final Guide guide;

  @override
  State<GuideNotesPage> createState() => _GuideNotesPageState();
}

class _GuideNotesPageState extends State<GuideNotesPage> {
  NotesModel? _model;
  bool _loading = true;
  int? _selectedHotel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = context.read<AppSettings>();
    final m = await GuideNotesService.build(
      widget.guide,
      epsFallbackM: widget.guide.settings.zoneRadiusOverrideM ??
          settings.clusterRadiusKm * 1000,
      minPtsFallback: widget.guide.settings.zoneMinPtsOverride ??
          settings.clusterMinPoints,
    );
    if (!mounted) return;
    setState(() {
      _model = m;
      _loading = false;
      _selectedHotel = m.recommendedHotelIdx >= 0 ? m.recommendedHotelIdx : null;
    });
  }

  /// 当前游览起点（用户选择 > 推荐住宿；无住宿 = null）
  Place? get _startHotel {
    final m = _model;
    if (m == null || !m.hasHotel) return null;
    final idx = (_selectedHotel ?? m.recommendedHotelIdx)
        .clamp(0, m.hotels.length - 1);
    return m.hotels[idx];
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _km(double m) => (m / 1000).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final m = _model;
    if (_loading || m == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.notesTitle)),
        body: const Center(
            child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }

    if (widget.guide.markers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(t.notesTitle)),
        body: Center(
          child: Text(t.notesEmptyHint,
              style: TextStyle(color: AppColors.inkSoft)),
        ),
      );
    }

    final start = _startHotel;
    final zoneList = m.orderedZones(start);
    final scenicTotal =
        m.zones.fold<int>(0, (s, z) => s + z.poiCount);
    // 分类全量统计（含交通/其他，覆盖攻略全部标记）
    final markers = widget.guide.markers;
    int cnt(String cat) =>
        markers.where((p) => p.categoryId == cat).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.notesTitle),
        actions: [
          TooltipBarrier(
            child: IconButton(
              tooltip: t.viewOnMapTip,
              icon: const Icon(Icons.map_outlined),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 总览（写全：区域、游览点、全类别标记数）
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _OverviewChip(t.zoneCountChip('${m.zones.length}')),
                _OverviewChip(t.scenicCountChip('$scenicTotal')),
                _OverviewChip(
                    '${t.catNameHotel} ${cnt(MarkerCategory.hotel.id)}'),
                _OverviewChip(
                    '${t.catNameDining} ${cnt(MarkerCategory.dining.id)}'),
                _OverviewChip(
                    '${t.catNameShopping} ${cnt(MarkerCategory.shopping.id)}'),
                _OverviewChip(
                    '${t.catNameTransport} ${cnt(MarkerCategory.transport.id)}'),
                _OverviewChip(
                    '${t.catNameOther} ${cnt(MarkerCategory.other.id)}'),
              ],
            ),
          ),
          // 多住宿选择器（推荐住宿默认选中）
          if (m.hasHotel && m.hotels.length > 1)
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                scrollDirection: Axis.horizontal,
                itemCount: m.hotels.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final h = m.hotels[i];
                  final sel = _selectedHotel == i;
                  return ChoiceChip(
                    selected: sel,
                    label: Text(
                      '${h.title}${i == m.recommendedHotelIdx ? t.recommendedTail : ''}',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.w500),
                    ),
                    selectedColor: AppColors.primary.withValues(alpha: 0.14),
                    checkmarkColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _selectedHotel = i),
                  );
                },
              ),
            ),
          // 片区缺失说明 / 正文
          Expanded(
            child: zoneList.isEmpty
                ? _FlatNotes(model: m, snack: _snack)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    children: [
                      if (start != null)
                        _StartHotelCard(hotel: start, snack: _snack),
                      // 顺序展示编号：游览区域 1..n（孤立片区同样编号，不出现「孤立」字样）
                      for (var i = 0; i < zoneList.length; i++)
                        _ZoneCard(
                            z: zoneList[i],
                            label: t.zoneLabelN('${i + 1}'),
                            start: start,
                            km: _km,
                            snack: _snack),
                      if (m.otherPois.isNotEmpty)
                        _OtherPoiSection(
                          pois: m.otherPois,
                          snack: _snack,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ———————————————————— 总览 chip ————————————————————
class _OverviewChip extends StatelessWidget {
  const _OverviewChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style:
              const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

// 片区卡

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.z,
    required this.label,
    required this.start,
    required this.km,
    required this.snack,
  });

  final NotesZone z;
  final String label;
  final Place? start;
  final String Function(double m) km;
  final void Function(String) snack;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final dist = start == null
        ? null
        : haversineMeters(
            LatLng(start!.lat, start!.lng), z.center);
    final emptyAll =
        z.members.isEmpty && z.attached.isEmpty && z.dining.isEmpty && z.shopping.isEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        // 方框卡片：以片区配色勾边，让整块内容一眼可辨
        border: Border.all(
            color: Color(z.zone.colorValue).withValues(alpha: 0.45),
            width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：区域名统一写作「游览区域 N」（单个游览点也用正式编号）
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(z.zone.colorValue)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 范围标记（半径 + 面积）和到起点的距离
            Row(
              children: [
                const Icon(Icons.radio_button_checked,
                    size: 12, color: AppColors.inkSoft),
                const SizedBox(width: 4),
                Text(
                  t.zoneRange(_zKm(z),
                      z.areaKm2.toStringAsFixed(1)),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.inkSoft),
                ),
                const Spacer(),
                if (dist != null)
                  Text(t.kmFromStart(km(dist)),
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0x14101010)),
            const SizedBox(height: 8),
            if (emptyAll)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.zoneEmpty,
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              )
            else ...[
              if (z.members.isNotEmpty || z.attached.isNotEmpty)
                _ZonePoiList(z: z, snack: snack, km: km),
              if (z.dining.isNotEmpty) ...[
                _SectionTip(t.secDiningRec, Icons.restaurant, z.dining.length),
                ...[for (final p in z.dining) _PlaceItem(place: p, snack: snack)],
              ],
              if (z.shopping.isNotEmpty) ...[
                const SizedBox(height: 6),
                _SectionTip(t.secShoppingRec, Icons.shopping_bag, z.shopping.length),
                ...[
                  for (final p in z.shopping) _PlaceItem(place: p, snack: snack)
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _zKm(NotesZone z) => '${z.radiusKm.toStringAsFixed(1)} km';
}

/// 片区内景点列表（必去成员在前 → 选去附挂在后）
class _ZonePoiList extends StatelessWidget {
  const _ZonePoiList({required this.z, required this.snack, required this.km});

  final NotesZone z;
  final void Function(String) snack;
  final String Function(double m) km;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < z.members.length; i++) {
      items.add(_PlaceItem(place: z.members[i], snack: snack));
    }
    if (z.attached.isNotEmpty) {
      for (final p in z.attached) {
        items.add(_PlaceItem(place: p, snack: snack));
      }
    }
    return Column(children: [
      _SectionTip(
          AppLocalizations.of(context).secScenic, Icons.place, z.poiCount),
      ...items,
    ]);
  }
}

/// 分区小节标题行
class _SectionTip extends StatelessWidget {
  const _SectionTip(this.label, this.icon, this.count);

  final String label;
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text('$label ${count > 0 ? '· $count' : ''}',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ———————————————————— 地点条目（景点/餐饮/购物/住宿通用） ————————————————————

class _PlaceItem extends StatelessWidget {
  const _PlaceItem({required this.place, required this.snack});

  final Place place;
  final void Function(String) snack;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cat = MarkerCategory.of(place.categoryId);
    final desc = place.description.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 缩略图（无照片就占位 + 文案）
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: place.images.isNotEmpty
                      ? RelImage(
                          rel: place.images.first,
                          width: 62,
                          height: 62,
                          fit: BoxFit.cover,
                          placeholder: PhotoThumb(
                              gradientIndex: place.id.hashCode,
                              width: 62,
                              height: 62,
                              radius: 10,
                              iconSize: 22),
                        )
                      : PhotoThumb(
                          gradientIndex: place.id.hashCode,
                          width: 62,
                          height: 62,
                          radius: 10,
                          iconSize: 22),
                ),
              ),
              if (place.images.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(t.photosTotalN('${place.images.length}'),
                      style: const TextStyle(
                          fontSize: 9.5, color: AppColors.inkSoft)),
                ),
              if (place.images.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(t.noPhotoYet,
                      style: TextStyle(
                          fontSize: 9.5, color: AppColors.inkSoft)),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CategoryIcon(cat: cat, iconSize: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${place.title}'
                        '${place.mustVisit ? t.mustVisitStar : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (!place.mustVisit)
                      Text(categoryName(t, cat),
                          style: TextStyle(
                              fontSize: 10, color: cat.color.withValues(alpha: 0.9))),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc.isEmpty ? t.descMissing : desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: desc.isEmpty ? FontStyle.italic : FontStyle.normal,
                    color: desc.isEmpty
                        ? AppColors.inkSoft
                        : AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 4),
                // 坐标 + 导航（桌面默认高德，公交）
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${place.lat.toStringAsFixed(4)}, '
                        '${place.lng.toStringAsFixed(4)}',
                        style: const TextStyle(
                            fontSize: 10.5, color: AppColors.inkSoft),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 30),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () =>
                          NavigatorService.openPlace(context, place, snack),
                      icon: const Icon(Icons.navigation_outlined,
                          size: 14, color: AppColors.primary),
                      label: Text(t.navBtnShort,
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 起点住宿卡
class _StartHotelCard extends StatelessWidget {
  const _StartHotelCard({required this.hotel, required this.snack});

  final Place hotel;
  final void Function(String) snack;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hotel, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(t.stayHead,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const Spacer(),
                Text(t.stayPlan,
                    style: TextStyle(
                        fontSize: 10.5, color: AppColors.inkSoft)),
              ],
            ),
            const SizedBox(height: 4),
            _PlaceItem(place: hotel, snack: snack),
          ],
        ),
      ),
    );
  }
}

// 其他推荐（圈外餐饮/购物/交通/其他）
class _OtherPoiSection extends StatelessWidget {
  const _OtherPoiSection({required this.pois, required this.snack});

  final List<Place> pois;
  final void Function(String) snack;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final dining = pois
        .where((p) => p.categoryId == MarkerCategory.dining.id)
        .toList();
    final shopping = pois
        .where((p) => p.categoryId == MarkerCategory.shopping.id)
        .toList();
    final scenics = pois
        .where((p) => p.categoryId == MarkerCategory.scenic.id)
        .toList()
      ..sort((a, b) => b.mustVisit == a.mustVisit ? 0 : (b.mustVisit ? 1 : -1));
    final rest = pois
        .where((p) =>
            p.categoryId != MarkerCategory.dining.id &&
            p.categoryId != MarkerCategory.shopping.id &&
            p.categoryId != MarkerCategory.scenic.id)
        .toList();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.more_horiz, size: 14, color: AppColors.inkSoft),
              const SizedBox(width: 5),
              Text(t.otherRecTitle,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft)),
            ]),
            const SizedBox(height: 6),
            if (scenics.isNotEmpty) _SectionTip(t.secScenic, Icons.place, scenics.length),
            ...[for (final p in scenics) _PlaceItem(place: p, snack: snack)],
            if (dining.isNotEmpty)
              _SectionTip(t.secDining, Icons.restaurant, dining.length),
            ...[for (final p in dining) _PlaceItem(place: p, snack: snack)],
            if (shopping.isNotEmpty)
              _SectionTip(t.secShopping, Icons.shopping_bag, shopping.length),
            ...[for (final p in shopping) _PlaceItem(place: p, snack: snack)],
            if (rest.isNotEmpty)
              _SectionTip(t.secOther, Icons.bookmark_border, rest.length),
            ...[for (final p in rest) _PlaceItem(place: p, snack: snack)],
          ],
        ),
      ),
    );
  }
}

// 无片区平铺视图（没有必去点时）
class _FlatNotes extends StatelessWidget {
  const _FlatNotes({required this.model, required this.snack});

  final NotesModel model;
  final void Function(String) snack;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final pois = model.otherPois;
    final scenics = pois
        .where((p) => p.categoryId == MarkerCategory.scenic.id)
        .toList()
      ..sort((a, b) => b.mustVisit == a.mustVisit ? 0 : (b.mustVisit ? 1 : -1));
    final dining =
        pois.where((p) => p.categoryId == MarkerCategory.dining.id).toList();
    final shopping =
        pois.where((p) => p.categoryId == MarkerCategory.shopping.id).toList();
    final rest = pois
        .where((p) =>
            p.categoryId != MarkerCategory.dining.id &&
            p.categoryId != MarkerCategory.shopping.id &&
            p.categoryId != MarkerCategory.scenic.id)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            t.flatBanner,
            style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
          ),
        ),
        if (model.hotels.isNotEmpty)
          for (final h in model.hotels) _StartHotelCard(hotel: h, snack: snack),
        if (scenics.isNotEmpty) _SectionTip(t.secScenic, Icons.place, scenics.length),
        ...[for (final p in scenics) _PlaceItem(place: p, snack: snack)],
        if (dining.isNotEmpty) _SectionTip(t.secDining, Icons.restaurant, dining.length),
        ...[for (final p in dining) _PlaceItem(place: p, snack: snack)],
        if (shopping.isNotEmpty)
          _SectionTip(t.secShopping, Icons.shopping_bag, shopping.length),
        ...[for (final p in shopping) _PlaceItem(place: p, snack: snack)],
        if (rest.isNotEmpty) _SectionTip(t.secOther, Icons.bookmark_border, rest.length),
        ...[for (final p in rest) _PlaceItem(place: p, snack: snack)],
      ],
    );
  }
}
