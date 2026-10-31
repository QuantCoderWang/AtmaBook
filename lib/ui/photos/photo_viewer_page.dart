import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../data/models/guide.dart';
import '../../l10n/app_localizations.dart';
import '../../services/media_store.dart';
import '../../state/guide_editor.dart';
import '../widgets/photo_thumb.dart';
import '../widgets/tooltip_barrier.dart';
import 'photo_bind_sheet.dart';
import 'video_player_page.dart';

/// 视频预览卡（照片查看器内的视频条目）：首帧缩略 + 中央播放按钮
class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.photo, required this.onPlay});

  final PhotoItem photo;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FutureBuilder<Uint8List?>(
                future: photo.thumb.isNotEmpty
                    ? MediaStore.load(photo.thumb)
                    : null,
                builder: (context, snap) => snap.data != null
                    ? Image.memory(snap.data!, fit: BoxFit.contain)
                    : PhotoThumb(
                        gradientIndex: photo.gradientIndex,
                        width: 260,
                        height: 320,
                        radius: 18,
                        iconSize: 56,
                      ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                  iconSize: 40,
                  color: Colors.white,
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 照片大图浏览：
/// - InteractiveViewer 看原图（缩略图 miss 时也回原图）；
/// - 顶栏：名称/拍摄时间 · 重命名 / 删除（连文件）；
/// - 底栏：经纬度 + 绑定标记名 · 更改绑定（未定位照片在此手动绑定）；
/// - readOnly = 相册账本照片（`w:` 前缀，返回攻略展示）：只看不改——
///   改名/删除/绑定归地理相册页管理。
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({
    super.key,
    required this.photo,
    required this.ed,
    this.readOnly = false,
  });

  final PhotoItem photo;
  final GuideEditor ed;

  /// 只读模式：隐藏改名 / 删除 / 更改绑定（账本照片只上图不转写攻略库）
  final bool readOnly;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late PhotoItem _p;

  @override
  void initState() {
    super.initState();
    _p = widget.photo;
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _fmtTime(DateTime t) =>
      '${t.year}/${t.month}/${t.day} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 当前照片的实时状态（编辑器里被更新后取新值）
  PhotoItem get _current {
    for (final p in widget.ed.guide.photos) {
      if (p.id == _p.id) return p;
    }
    return _p;
  }

  Future<void> _rename(PhotoItem p) async {
    final t = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.renamePhotoTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
              hintText: t.renamePhotoHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(t.btnSave),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    widget.ed.updatePhoto(p.copyWith(name: name));
    final t2 = AppLocalizations.of(context);
    _snack(name.isEmpty ? t2.nameReset : t2.renamedTo(name));
  }

  Future<void> _delete(PhotoItem p) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deletePhotoTitle),
        content: Text(t.deletePhotoContent(
            p.name.isNotEmpty ? p.name : _fmtTime(p.takenAt))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.btnDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    widget.ed.removePhoto(p.id);
    if (!mounted) return;
    Navigator.of(context).pop(); // 返回照片墙
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).photoDeleted)));
  }

  Future<void> _rebind(PhotoItem p) async {
    final placeId = await showPhotoBindSheet(context, widget.ed, photo: p);
    if (placeId == null || !mounted) return; // 返回 null = 用户取消
    final t2 = AppLocalizations.of(context);
    if (placeId.isEmpty) {
      // 传入空串代表解除绑定
      widget.ed.updatePhoto(p.copyWith(clearPlace: true));
      _snack(t2.unboundToast);
    } else {
      widget.ed.updatePhoto(p.copyWith(placeId: placeId));
      final place = widget.ed.byPlaceId(placeId);
      _snack(t2.boundToast(place?.title ?? '--'));
    }
    setState(() => _p = _current);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = _current;
    final place = p.placeId == null ? null : widget.ed.byPlaceId(p.placeId!);
    final title = p.name.isNotEmpty ? p.name : _fmtTime(p.takenAt);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14)),
        actions: [
          if (!widget.readOnly) ...[
            TooltipBarrier(
              child: IconButton(
                tooltip: t.renameTip,
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _rename(p),
              ),
            ),
            TooltipBarrier(
              child: IconButton(
                tooltip: t.btnDelete,
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _delete(p),
              ),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 4.0,
              child: Center(
                child: p.isVideo
                    ? _VideoPreview(
                        photo: p,
                        onPlay: () => VideoPlayerPage.openWith(context, p),
                      )
                    : FutureBuilder<Uint8List?>(
                        future: p.hasFile ? MediaStore.load(p.file) : null,
                        builder: (context, snap) {
                          final bytes = snap.data;
                          if (bytes != null) {
                            return Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => _placeholder(p),
                            );
                          }
                          return _placeholder(p);
                        },
                      ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            color: const Color(0xFF101010),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        p.hasGps
                            ? Icons.my_location
                            : Icons.location_disabled,
                        size: 15,
                        color: p.hasGps ? AppColors.accent : Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p.hasGps
                              ? t.latLngLine(p.lat!.toStringAsFixed(5),
                                  p.lng!.toStringAsFixed(5))
                              : t.noExifLine(place != null
                                  ? t.exifFollowTail
                                  : ''),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ),
                      if (!widget.readOnly)
                        TextButton(
                          onPressed: () => _rebind(p),
                          child: Text(t.changeBindBtn,
                              style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  if (place != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.push_pin_outlined,
                              size: 15, color: Colors.white54),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                          t.boundMarkerLine(place.title,
                              p.placeId != null && !p.hasGps
                                  ? t.shownAtMarkerTail
                                  : ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(PhotoItem p) => PhotoThumb(
        gradientIndex: p.gradientIndex,
        width: 260,
        height: 320,
        radius: 18,
        iconSize: 56,
      );
}
