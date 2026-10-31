import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/i18n_names.dart';
import '../../data/models/guide.dart';
import '../../l10n/app_localizations.dart';
import '../../state/guide_editor.dart';

import '../widgets/category_icon.dart';

/// 标记列表侧抽屉：分类筛选 / 游览区域分组排序 / 点击定位 / 长按删除
class MarkerListDrawer extends StatefulWidget {
  const MarkerListDrawer({
    super.key,
    required this.editor,
    required this.onOpen,
  });

  final GuideEditor editor;
  final void Function(Place place) onOpen;

  @override
  State<MarkerListDrawer> createState() => _MarkerListDrawerState();
}

class _MarkerListDrawerState extends State<MarkerListDrawer> {
  String? _filterCategory; // null = 全部
  String _sort = 'sortCategory'; // sortCategory / sortZone / sortTime

  GuideEditor get ed => widget.editor;

  /// zone 排序键：按片区在聚类列表中的位置（与图例「游览区域 N」编号同序）；
  /// 未分组的标记排最后
  int _zoneIndex(Guide guide, Place p) {
    final z = ed.zoneOf(p);
    if (z == null) return guide.clusters.length;
    return guide.clusters.indexOf(z);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final guide = ed.guide;
    var places = [...guide.markers];
    if (_filterCategory != null) {
      places = places.where((p) => p.categoryId == _filterCategory).toList();
    }
    switch (_sort) {
      case 'sortZone':
        places.sort((a, b) {
          final c =
              _zoneIndex(guide, a).compareTo(_zoneIndex(guide, b));
          return c != 0 ? c : b.mustVisit == a.mustVisit ? 0 : b.mustVisit ? 1 : -1;
        });
        break;
      case 'sortTime':
        places = places.reversed.toList();
        break;
      default:
        places.sort((a, b) {
          final c = _orderOf(a.categoryId).compareTo(_orderOf(b.categoryId));
          return c != 0
              ? c
              : (b.mustVisit == a.mustVisit ? 0 : b.mustVisit ? 1 : -1);
        });
    }

    return SafeArea(
      child: Drawer(
        backgroundColor: AppColors.bg,
        child: Column(
          children: [
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 4),
              child: Text(t.drawerTitle(guide.markers.length),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  _FilterChip(
                    label: t.filterAll,
                    selected: _filterCategory == null,
                    color: AppColors.primary,
                    onTap: () => setState(() => _filterCategory = null),
                  ),
                  for (final cat in MarkerCategory.all)
                    _FilterChip(
                      label: categoryName(t, cat),
                      selected: _filterCategory == cat.id,
                      color: cat.color,
                      onTap: () => setState(() =>
                          _filterCategory = _filterCategory == cat.id
                              ? null
                              : cat.id),
                    ),
                  const SizedBox(width: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'sortCategory', label: Text(t.sortCategory)),
                      ButtonSegment(
                          value: 'sortZone', label: Text(t.sortZone)),
                      ButtonSegment(
                          value: 'sortTime', label: Text(t.sortTime)),
                    ],
                    selected: {_sort},
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                        visualDensity: VisualDensity.compact),
                    onSelectionChanged: (s) => setState(() => _sort = s.first),
                  ),
                ],
              ),
            ),
            Expanded(
              child: places.isEmpty
                  ? Center(
                      child: Text(t.drawerEmpty,
                          style:
                              const TextStyle(color: AppColors.inkSoft)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 2, 10, 16),
                      itemCount: places.length,
                      itemBuilder: (context, i) {
                        final p = places[i];
                        final cat = MarkerCategory.of(p.categoryId);
                        final zone = ed.zoneOf(p);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onLongPress: () => _confirmDelete(context, p),
                            onTap: () => widget.onOpen(p),
                            leading: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cat.color,
                              ),
                              child: CategoryIcon(
                                  cat: cat,
                                  iconSize: 16,
                                  imageBox: 34,
                                  color: Colors.white),
                            ),
                            title: Text(p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${p.mustVisit ? t.mustVisitTag : t.optionalTag}'
                              ' · ${categoryName(t, cat)}'
                              '${zone != null ? ' · ${zoneDisplayName(t, zone, guide.clusters.indexOf(zone))}' : ''}'
                              '${p.images.isNotEmpty ? ' · ${t.imageCount(p.images.length)}' : ''}',
                              style: const TextStyle(
                                  fontSize: 10.5, color: AppColors.inkSoft),
                            ),
                            trailing: const Icon(Icons.chevron_right,
                                size: 16, color: AppColors.inkSoft),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int _orderOf(String categoryId) {
    final i = MarkerCategory.all.indexWhere((c) => c.id == categoryId);
    return i < 0 ? 99 : i;
  }

  void _confirmDelete(BuildContext context, Place p) {
    final t = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteMarkerTitle),
        content: Text(t.deleteMarkerContent(p.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ed.removePlace(p.id);
            },
            child: Text(t.btnDelete),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11.5)),
        selected: selected,
        selectedColor: color,
        backgroundColor: color.withValues(alpha: 0.08),
        labelStyle: TextStyle(
            fontSize: 11.5,
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w600),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
