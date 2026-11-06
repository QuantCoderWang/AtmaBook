import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../core/i18n_names.dart';
import '../../data/models/guide.dart';
import '../../core/utils/ids.dart';
import '../../l10n/app_localizations.dart';
import '../../services/media_store.dart';
import '../../services/navigator_service.dart';
import '../../state/guide_editor.dart';
import '../widgets/category_icon.dart';
import '../widgets/rel_image.dart';
import 'pick_point_page.dart';
import '../widgets/tooltip_barrier.dart';

/// 地点标记编辑页：
/// 名称 / 分类 / Pin 颜色与自定义图标 / 必去 / 坐标（可重新选点）/ 图文 / 多照片 / 链接
/// 新建（长按地图或 FAB）与编辑（详情弹层进入）共用，isNew 区分保存方式
class MarkerEditPage extends StatefulWidget {
  const MarkerEditPage({
    super.key,
    required this.editor,
    required this.place,
    this.isNew = false,
  });

  final GuideEditor editor;
  final Place place;
  final bool isNew;

  @override
  State<MarkerEditPage> createState() => _MarkerEditPageState();
}

class _MarkerEditPageState extends State<MarkerEditPage> {
  late final TextEditingController _title;
  late final TextEditingController _desc;

  /// 新建时生成临时 id；编辑时沿用原 id
  late final String _placeId = widget.isNew ? newId('mk') : widget.place.id;

  late String _categoryId;
  late bool _mustVisit;
  late int? _colorValue; // null = 跟随分类默认色
  late String? _iconPath;
  late List<String> _images; // 使用相对路径
  late List<GeoLink> _links;
  late double _lat;
  late double _lng;

  /// 未保存前先挂内存、保存时统一落盘的新照片
  late List<Uint8List> _pendingImages;

  bool _saving = false;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void initState() {
    super.initState();
    final p = widget.place;
    _title = TextEditingController(text: p.title);
    _desc = TextEditingController(text: p.description);
    _categoryId = p.categoryId;
    _mustVisit = p.mustVisit;
    _colorValue = p.colorValue;
    _iconPath = p.iconPath;
    _images = [...p.images];
    _links = [...p.links];
    _lat = p.lat;
    _lng = p.lng;
    _pendingImages = [];
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  // 交互编辑
  Future<void> _addImage() async {
    try {
      final file = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _pendingImages.add(bytes));
    } catch (_) {
      _snack(AppLocalizations.of(context).createNoPhotoPick);
    }
  }

  void _removeImage(int index) {
    if (index < _images.length) {
      // 立即删除并移出列表
      final rel = _images.removeAt(index);
      fireAndForget(MediaStore.deleteImage(rel));
    } else {
      _pendingImages.removeAt(index - _images.length);
    }
    setState(() {});
  }

  Future<void> _uploadIcon() async {
    try {
      final file = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 512);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      try {
        final rel = await MediaStore.savePinIcon(bytes);
        if (!mounted) return;
        setState(() => _iconPath = rel);
      } catch (_) {
        if (!mounted) return;
        _snack(AppLocalizations.of(context).editIconNotSaved);
      }
    } catch (_) {
      if (!mounted) return;
      _snack(AppLocalizations.of(context).createNoPhotoPick);
    }
  }

  Future<void> _rePick() async {
    final point = await Navigator.push<LatLng?>(
      context,
      MaterialPageRoute(
        builder: (_) => PickPointPage(
          initial: LatLng(_lat, _lng),
          source: widget.editor.source,
        ),
      ),
    );
    if (point != null) {
      setState(() {
        _lat = point.latitude;
        _lng = point.longitude;
      });
    }
  }

  Future<void> _addLink() async {
    final link = await showDialog<GeoLink>(
      context: context,
      builder: (ctx) => const _LinkDialog(),
    );
    if (link != null) {
      setState(() => _links.add(link));
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _snack(AppLocalizations.of(context).editTitleRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      final rels = [..._images];
      for (final bytes in _pendingImages) {
        rels.add(await MediaStore.savePlaceImage(widget.editor.guide.id, bytes));
      }
      final place = Place(
        id: _placeId,
        title: _title.text.trim(),
        categoryId: _categoryId,
        lat: _lat,
        lng: _lng,
        mustVisit: _mustVisit,
        description: _desc.text.trim(),
        images: rels,
        links: [..._links],
        colorValue: _colorValue,
        iconPath: _iconPath,
      );
      if (widget.isNew) {
        widget.editor.addPlace(place);
      } else {
        widget.editor.updatePlace(place);
      }
      if (!mounted) return;
      Navigator.pop(context);
      _snack(widget.isNew
          ? AppLocalizations.of(context).markerAdded
          : AppLocalizations.of(context).markerSaved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _displayColor() =>
      _colorValue != null ? Color(_colorValue!) : MarkerCategory.of(_categoryId).color;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.isNew ? t.editNewTitle : t.editEditTitle),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(t.btnSave,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Group(t.groupIdentity, [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _title,
              builder: (context, v, _) => TextField(
                controller: _title,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: t.editTitleHint,
                  errorText:
                      v.text.trim().isEmpty ? null : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in MarkerCategory.all)
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CategoryIcon(
                            cat: cat,
                            iconSize: 15,
                            imageBox: 15,
                            color: _categoryId == cat.id
                                ? Colors.white
                                : cat.color),
                        const SizedBox(width: 5),
                        Text(categoryName(t, cat)),
                      ],
                    ),
                    selected: _categoryId == cat.id,
                    selectedColor: cat.color,
                    backgroundColor: cat.color.withValues(alpha: 0.08),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      color: _categoryId == cat.id
                          ? Colors.white
                          : cat.color,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() {
                      _categoryId = cat.id;
                      if (_colorValue == null) return; // 仍跟随分类
                      // 自定义颜色保留原色
                    }),
                  ),
              ],
            ),
          ]),
          _Group(t.groupPinStyle, [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // 跟随分类
                _Swatch(
                  color: MarkerCategory.of(_categoryId).color,
                  selected: _colorValue == null,
                  onTap: () => setState(() => _colorValue = null),
                  child: Icon(MarkerCategory.of(_categoryId).icon,
                      size: 18, color: Colors.white),
                ),
                for (final c in TravelPalette.pinColors)
                  _Swatch(
                    color: c,
                    selected: c == _displayColor(),
                    onTap: () => setState(() => _colorValue = c.toARGB32()),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.image_outlined, size: 17),
                  label: Text(_iconPath == null
                      ? t.pinUploadCustom
                      : t.pinChangeIcon),
                  onPressed: _uploadIcon,
                ),
                if (_iconPath != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 17),
                    label: Text(t.pinResetIcon),
                    onPressed: () => setState(() => _iconPath = null),
                  ),
                ],
              ],
            ),
          ]),
          _Group(t.groupRules, [
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _mustVisit,
                onChanged: (v) => setState(() => _mustVisit = v),
                title: Text(t.mustSwitchTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(t.mustSwitchSub,
                    style: const TextStyle(fontSize: 11.5)),
                thumbIcon: WidgetStateProperty.resolveWith(
                  (s) => Icon(s.contains(WidgetState.selected)
                      ? Icons.star
                      : Icons.star_border),
                ),
              ),
            ),
          ]),
          _Group(t.gpsCoordTitle, [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_lat >= 0 ? t.latNorth : t.latSouth} ${_lat.abs().toStringAsFixed(6)} · '
                    '${_lng >= 0 ? t.lngEast : t.lngWest} ${_lng.abs().toStringAsFixed(6)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
                TooltipBarrier(
                  child: IconButton(
                    tooltip: t.copyCoords,
                    icon: const Icon(Icons.copy, size: 17),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text:
                              '${_lat.toStringAsFixed(6)}, ${_lng.toStringAsFixed(6)}'));
                      _snack(t.coordsCopied);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.pin_drop_outlined, size: 17),
                    label: Text(t.repickOnMap),
                    onPressed: _rePick,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.navigation_outlined, size: 17),
                    label: Text(t.verifyNav),
                    onPressed: () => NavigatorService.openPlace(
                        context, widget.place, _snack),
                  ),
                ),
              ],
            ),
          ]),
          _Group(t.groupDetails, [
            TextField(
              controller: _desc,
              maxLines: 4,
              decoration: InputDecoration(hintText: t.editDescHint),
            ),
          ]),
          _Group(t.groupPhotos, [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, rel) in _images.indexed)
                  _Thumb(
                    onRemove: () => _removeImage(i),
                    child: RelImage(
                      rel: rel,
                      width: 72,
                      height: 72,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                for (final (i, bytes) in _pendingImages.indexed)
                  _Thumb(
                    onRemove: () => _removeImage(_images.length + i),
                    child: BytesImage(
                      bytes: bytes,
                      width: 72,
                      height: 72,
                    ),
                  ),
                _AddTile(width: 72, height: 72, label: t.addPhoto,
                    onTap: _addImage),
              ],
            ),
          ]),
          _Group(t.groupLinks, [
            for (final (i, link) in _links.indexed)
              _LinkRow(
                link: link,
                onDelete: () => setState(() => _links.removeAt(i)),
                onTap: () => NavigatorService.openUrl(
                    link.url, _snack, fallbackTip: t.linkInvalid),
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_link, size: 17),
              label: Text(t.addLink),
              onPressed: _addLink,
            ),
            if (_links.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(t.noLinks,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ),
          ]),
        ],
      ),
    );
  }
}

/// 封闭小弹窗：添加链接（标题 + URL）
class _LinkDialog extends StatefulWidget {
  const _LinkDialog();

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _url = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.linkDialogTitle),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: InputDecoration(hintText: t.linkNameHint),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _url,
              decoration: const InputDecoration(hintText: 'https://…'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () {
            final url = _url.text.trim();
            final title =
                _title.text.trim().isEmpty ? t.linkDefaultName : _title.text.trim();
            if (url.isEmpty) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(t.urlRequired)));
              return;
            }
            Navigator.pop(context, GeoLink(title, url));
          },
          child: Text(t.btnAdd),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: -4,
          right: -4,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close,
                  size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.child,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? Colors.black : Colors.white,
            width: selected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: selected
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : child,
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.width,
    required this.height,
    required this.label,
    required this.onTap,
  });

  final double width;
  final double height;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1.4),
          color: const Color(0xFFFBF7EF),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo, size: 20, color: AppColors.inkSoft),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 9.5, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.onDelete, required this.onTap});

  final GeoLink link;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          onTap: onTap,
          leading: const Icon(Icons.open_in_new,
              size: 17, color: AppColors.primary),
          title: Text(link.title, style: const TextStyle(fontSize: 13)),
          subtitle: Text(link.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5)),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 17),
            onPressed: onDelete,
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.inkSoft)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}
