import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../widgets/category_icon.dart';
import '../../core/i18n_names.dart';
import '../../data/models/guide.dart';
import '../../l10n/app_localizations.dart';

/// 左下角图例卡片：游览区域配色 + 地点分类
class LegendCard extends StatelessWidget {
  const LegendCard({super.key, required this.guide, this.note});

  final Guide guide;

  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.legend_toggle, size: 14, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Text(t.legendTitle,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 8),
          // 片区标签，显示统一映射为「游览区域 N」
          for (var i = 0; i < guide.clusters.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: guide.clusters[i].color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      zoneDisplayName(t, guide.clusters[i], i),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                  Text(
                    t.legendZonePoints(guide.clusters[i].memberIds.length),
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          const Divider(height: 14),
          if (note != null) ...[
            Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: AppColors.inkSoft),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(note!,
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.inkSoft)),
                ),
              ],
            ),
            const Divider(height: 14),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final cat in MarkerCategory.all)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CategoryIcon(cat: cat, iconSize: 12),
                    const SizedBox(width: 3),
                    Text(categoryName(t, cat),
                        style: const TextStyle(fontSize: 10.5)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
