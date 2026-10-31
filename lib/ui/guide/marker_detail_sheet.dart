import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/i18n_names.dart';
import '../../data/models/guide.dart';
import '../../l10n/app_localizations.dart';
import '../../services/media_store.dart';
import '../../services/navigator_service.dart';
import '../../state/guide_editor.dart';
import '../../state/settings_provider.dart';
import '../widgets/category_icon.dart';
import '../widgets/pin_widget.dart';
import '../widgets/tooltip_barrier.dart';
import '../widgets/rel_image.dart';
import 'marker_edit_page.dart';

/// 标记点详情弹层：
/// 标题/分类/片区、真实图片浏览、链接可点击、坐标与「导航/编辑/删除」按钮
class MarkerDetailSheet extends StatelessWidget {
  const MarkerDetailSheet({
    super.key,
    required this.place,
    required this.editor,
    this.zone,
  });

  final Place place;
  final GuideEditor editor;
  final ClusterZone? zone;

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final simplified =
        context.watch<AppSettings>().pinMode == PinDisplayMode.colored;
    final cat = MarkerCategory.of(place.categoryId);
    // Pin 图：分类自定义图标
    final iconBytes =
        MediaStore.cacheBytes(place.iconPath ?? cat.image);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PinWidget(
                color: place.pinColor,
                icon: cat.icon,
                iconBytes: iconBytes,
                size: 34,
                mustVisit: place.mustVisit,
                ringColor: zone?.color,
                simplified: simplified,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          label: categoryName(t, cat),
                          color: cat.color,
                          lead: CategoryIcon(
                              cat: cat,
                              iconSize: 12,
                              imageBox: 14,
                              color: Colors.white),
                        ),
                        if (zone != null)
                          _MetaChip(
                            // 持久化标签：「游览区域 N」
                            label: zoneDisplayName(
                                t, zone!, editor.guide.clusters.indexOf(zone!)),
                            color: zone!.color,
                          ),
                        _MetaChip(
                          label: place.mustVisit ? t.mustVisitTag : t.optionalTag,
                          color: place.mustVisit
                              ? AppColors.accent
                              : AppColors.inkSoft,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (place.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              place.description,
              style: const TextStyle(
                  fontSize: 13.5, color: AppColors.ink, height: 1.6),
            ),
          ],
          const SizedBox(height: 16),
          _SectionLabel(t.photosSection(place.images.length)),
          const SizedBox(height: 8),
          if (place.images.isNotEmpty)
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: place.images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _PhotoThumb(
                  rel: place.images[i],
                  onTap: () => _openImagePreview(context, place.images[i]),
                ),
              ),
            )
          else
            Text(t.noPhotosHint,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          const SizedBox(height: 16),
          _SectionLabel(t.groupLinks),
          const SizedBox(height: 4),
          for (final link in place.links)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => NavigatorService.openUrl(
                  link.url, (m) => _snack(context, m)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F2E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(link.title,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 1),
                          Text(link.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          _SectionLabel(t.gpsCoordTitle),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${place.lat >= 0 ? t.latNorth : t.latSouth} ${place.lat.abs().toStringAsFixed(6)} · '
                  '${place.lng >= 0 ? t.lngEast : t.lngWest} ${place.lng.abs().toStringAsFixed(6)}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
              TooltipBarrier(
                child: IconButton(
                  tooltip: t.copyCoords,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                        text:
                            '${place.lat.toStringAsFixed(6)}, ${place.lng.toStringAsFixed(6)}'));
                    _snack(context, t.coordsCopied);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.navigation, size: 17),
                  label: Text(t.navHere),
                  onPressed: () => NavigatorService.openPlace(
                      context, place, (m) => _snack(context, m)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: Text(t.editDetails),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MarkerEditPage(
                          editor: editor,
                          place: place,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Color(0x33D32F2F)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: Text(t.btnDelete),
                  onPressed: () => _confirmDelete(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openImagePreview(BuildContext context, String rel) {
    showDialog<void>(
      context: context,
      builder: (_) => _ImagePreviewDialog(rel: rel),
    );
  }

  void _confirmDelete(BuildContext context) {
    final t = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteMarkerTitle),
        content: Text(t.deleteMarkerContent(place.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              editor.removePlace(place.id);
              Navigator.pop(ctx); // 关确认
              Navigator.of(context).pop(); // 关详情弹层
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(AppLocalizations.of(context)
                          .markerDeletedToast(place.title))));
            },
            child: Text(t.btnDelete),
          ),
        ],
      ),
    );
  }
}

/// 大图浏览（映射真实照片位置文件）
class _ImagePreviewDialog extends StatelessWidget {
  const _ImagePreviewDialog({required this.rel});

  final String rel;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 26),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 12 / 9,
                    child: Container(
                      color: const Color(0xFF2B2926),
                      child: RelImage(
                        rel: rel,
                        placeholder: const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: Colors.white24, size: 48),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.rel, required this.onTap});

  final String rel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: RelImage(
        rel: rel,
        width: 82,
        height: 82,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: AppColors.inkSoft));
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color, this.lead});

  final String label;
  final Color color;
  final Widget? lead;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lead != null) ...[lead!, const SizedBox(width: 4)],
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.ink,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
