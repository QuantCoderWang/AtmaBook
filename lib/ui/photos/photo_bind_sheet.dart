import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../data/models/guide.dart';
import '../../l10n/app_localizations.dart';
import '../../state/guide_editor.dart';

/// 照片 ↔ 标记 手动绑定弹层。
/// 返回值约定：null = 用户取消；'' = 解除绑定；其他 = 新绑定的标记 id。
Future<String?> showPhotoBindSheet(
  BuildContext context,
  GuideEditor ed, {
  required PhotoItem photo,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _PhotoBindSheet(ed: ed, photo: photo),
  );
}

class _PhotoBindSheet extends StatelessWidget {
  const _PhotoBindSheet({required this.ed, required this.photo});

  final GuideEditor ed;
  final PhotoItem photo;

  /// 到某标记的球面距离（无 GPS 时不显示）
  String _distanceLabel(double la, double lo) {
    const r = 6371000.0;
    final rad = math.pi / 180;
    final dLa = (la - photo.lat!) * rad;
    final dLo = (lo - photo.lng!) * rad;
    final a = math.pow(math.sin(dLa / 2), 2) +
        math.cos(photo.lat! * rad) *
            math.cos(la * rad) *
            math.pow(math.sin(dLo / 2), 2);
    final d = 2 * r * math.asin(math.sqrt(a));
    return d >= 1000 ? '${(d / 1000).toStringAsFixed(1)} km' : '${d.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final places = ed.guide.markers;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
              child: Text(
                photo.placeId == null
                    ? t.bindToMarker
                    : t.changeBindTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            if (places.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.bindNoMarkers,
                    style: TextStyle(
                        color: AppColors.inkSoft, fontSize: 12.5)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: places.length,
                  itemBuilder: (context, i) {
                    final p = places[i];
                    final selected = photo.placeId == p.id;
                    final dist =
                        photo.hasGps ? _distanceLabel(p.lat, p.lng) : null;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        p.mustVisit
                            ? Icons.star_rounded
                            : Icons.push_pin_outlined,
                        size: 19,
                        color: selected ? AppColors.primary : AppColors.inkSoft,
                      ),
                      title: Text(p.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: dist == null
                          ? null
                          : Text(t.distToShot(dist),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.inkSoft)),
                      trailing: selected
                          ? const Icon(Icons.check_rounded,
                              size: 18, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, p.id),
                    );
                  },
                ),
              ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.link_off, size: 18),
              title: Text(t.unbindLine,
                  style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
              enabled: photo.placeId != null,
              onTap: photo.placeId == null
                  ? null
                  : () => Navigator.pop(context, ''),
            ),
          ],
        ),
      ),
    );
  }
}
