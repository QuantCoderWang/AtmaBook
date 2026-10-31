import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../services/media_store.dart';
import '../../state/settings_provider.dart';
import '../widgets/category_icon.dart';
import '../widgets/tooltip_barrier.dart';

/// 自定义 Pin 图片图标规格（与单标记上传同源同径）：
/// **1:1 正方形 + ≤512px**（pickImage maxWidth 同步钳制长边），
/// 内容哈希去重存 `pics/icons/i_*`，与内置图标同尺寸圆裁渲染，
/// 替换不产生大小差。
const int _kPinIconPx = 512;

/// 地点分类管理卡：
/// - 点击分类行 → 编辑弹窗（配色 / 图标替换；内置分类可恢复默认）；
/// - 尾行「添加」→ 新建自定义分类（名称 + 配色 + 图标，可删除）；
/// - 生效面：分类定义读取统一走 `MarkerCategory` 静态注册表
///   （攻略地图 / 图例 / 标记编辑 / 标记抽屉 / 笔记 零改动直达）；
///   持久化在 AppSettings（shared_preferences，跨会话恢复）。
/// - 界面文案走 l10n categories* 词条（原内嵌双语表已收编 l10n 并退役）。
class CategoriesCard extends StatelessWidget {
  const CategoriesCard({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<AppSettings>(); // 分类变更 → 本卡整卡重建
    final t = AppLocalizations.of(context);

    return Card(
      child: Column(
        children: [
          for (final cat in MarkerCategory.all)
            ListTile(
              dense: true,
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(shape: BoxShape.circle, color: cat.color),
                child: CategoryIcon(
                    cat: cat, iconSize: 15, imageBox: 30, color: Colors.white),
              ),
              title: Text(cat.label, style: const TextStyle(fontSize: 13.5)),
              subtitle: Text(t.categoriesColorHex(_hex(cat.color)),
                  style: const TextStyle(fontSize: 10.5)),
              onTap: () => _editCategory(context, cat),
              trailing: const Icon(Icons.chevron_right, size: 18),
            ),
          ListTile(
            dense: true,
            leading: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.inkSoft, width: 1.2),
              ),
              child: const Icon(Icons.add, size: 15, color: AppColors.inkSoft),
            ),
            title: Text(t.btnAdd, style: const TextStyle(fontSize: 13.5)),
            subtitle: Text(t.categoriesAddSub, style: const TextStyle(fontSize: 10.5)),
            onTap: () => _createCategory(context),
          ),
        ],
      ),
    );
  }

  String _hex(Color c) =>
      c.toARGB32().toRadixString(16).substring(2, 8).toUpperCase();

  /// 编辑既有分类（内置：配色/图标/恢复默认；自定义：再加改名/删除）
  Future<void> _editCategory(BuildContext context, MarkerCategory cat) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _CatEditorDialog(initial: cat, t: t),
    );
    if (changed == true) {
      messenger.showSnackBar(SnackBar(content: Text(t.categoriesSavedSnack)));
    }
  }

  /// 新建自定义分类
  Future<void> _createCategory(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _CatEditorDialog(create: true, t: t),
    );
    if (changed == true) {
      messenger.showSnackBar(SnackBar(content: Text(t.categoriesAddedSnack)));
    }
  }
}

// —— 编辑/新建弹窗 ———
class _CatEditorDialog extends StatefulWidget {
  const _CatEditorDialog({
    this.initial,
    this.create = false,
    required this.t,
  });

  final MarkerCategory? initial; // 新建时 null
  final bool create;
  final AppLocalizations t;

  @override
  State<_CatEditorDialog> createState() => _CatEditorDialogState();
}

class _CatEditorDialogState extends State<_CatEditorDialog> {
  late int _color =
      widget.create ? MarkerCategory.colorPalette[11].toARGB32() : widget.initial!.color.toARGB32();
  late int _iconIndex = widget.create ? 5 : _idxOf(widget.initial!.icon);
  late final TextEditingController _name = TextEditingController(
      text: widget.create ? '' : widget.initial!.label);

  /// 自定义图片图标：null = 未上传/已撤下。
  /// 与池图标互斥——选内置图标或上传图片都会撤下另一侧。
  late String? _imageRel =
      widget.create ? null : widget.initial!.image;

  static int _idxOf(IconData icon) {
    final i = MarkerCategory.iconPalette.indexOf(icon);
    return i < 0 ? 0 : i;
  }

  bool get _isCustom => !widget.create && widget.initial!.id.startsWith('u_');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.create || _isCustom) {
      if (_name.text.trim().isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.t.categoriesNameRequired)));
        return;
      }
    }
    final s = context.read<AppSettings>();
    if (widget.create) {
      s.addMarkerCategory(_name.text,
          argb: _color, iconIndex: _iconIndex, imagePath: _imageRel);
    } else if (_isCustom) {
      s.setCategoryLook(widget.initial!.id,
          argb: _color,
          iconIndex: _iconIndex,
          label: _name.text,
          imagePath: _imageRel,
          clearImage: _imageRel == null);
    } else {
      s.setCategoryLook(widget.initial!.id,
          argb: _color,
          iconIndex: _iconIndex,
          imagePath: _imageRel,
          clearImage: _imageRel == null);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  /// 上传图片图标：相册选图 → 强制 ≤512px → 解码校验 **1:1 正方形**
  /// → MediaStore 内容哈希入库（与单标记自定义 Pin 图同目录同规格）。
  Future<void> _uploadImage() async {
    final texts = widget.t;
    Uint8List? bytes;
    try {
      final file = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: _kPinIconPx.toDouble());
      if (file == null) return;
      bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (w != h) {
        _snack(texts.categoriesImgNotSquare);
        return;
      }
      final rel = await MediaStore.savePinIcon(bytes);
      if (!mounted) return;
      setState(() => _imageRel = rel);
      _snack(texts.categoriesImgSaved);
    } catch (_) {
      _snack(texts.categoriesImgFail);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _delete() async {
    final cat = widget.initial!;
    final nav = Navigator.of(context);
    final s = context.read<AppSettings>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(widget.t.categoriesDeleteTitle),
        content: Text(widget.t.categoriesDeleteWarn),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(widget.t.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(widget.t.btnDelete)),
        ],
      ),
    );
    if (ok == true) {
      s.removeMarkerCategory(cat.id);
      if (mounted) nav.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = widget.t;
    final hasOverride = !widget.create &&
        !_isCustom &&
        MarkerCategory.overrideSnapshot().containsKey(widget.initial!.id);

    return AlertDialog(
      title: Text(widget.create
          ? texts.categoriesNewTitle
          : widget.initial!.label),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.create || _isCustom) ...[
                TextField(
                  controller: _name,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: texts.categoriesNameLabel,
                    hintText: texts.categoriesNameHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(texts.categoriesColorLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _palette(),
              const SizedBox(height: 10),
              Text(texts.categoriesIconLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _iconGrid(),
              const SizedBox(height: 12),
              Text(texts.categoriesImgLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _imagePickerRow(texts),
              const SizedBox(height: 6),
              Text(
                texts.categoriesImgHint,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.inkSoft, height: 1.5),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: Text(widget.t.cancel),
        ),
        if (hasOverride)
          TextButton(
            onPressed: () {
              context.read<AppSettings>()
                  .resetMarkerCategory(widget.initial!.id);
              Navigator.of(context).pop(true);
            },
            child: Text(texts.categoriesResetDefault),
          ),
        if (_isCustom)
          TextButton(
            onPressed: _delete,
            child: Text(widget.t.btnDelete,
                style: const TextStyle(color: Colors.red)),
          ),
        FilledButton(onPressed: _save, child: Text(widget.t.btnSave)),
      ],
    );
  }

  Widget _palette() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in MarkerCategory.colorPalette)
            GestureDetector(
              onTap: () => setState(() => _color = c.toARGB32()),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c,
                  border: Border.all(
                      color: _color == c.toARGB32()
                          ? Colors.white
                          : Colors.transparent,
                      width: 3),
                  boxShadow: [
                    if (_color == c.toARGB32())
                      const BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
              ),
            ),
        ],
      );

  Widget _iconGrid() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < MarkerCategory.iconPalette.length; i++)
            GestureDetector(
              onTap: () => setState(() {
                _iconIndex = i;
                // 选内置图标 → 撤下图片（互斥：显示端图片优先）
                _imageRel = null;
              }),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: _iconIndex == i ? Color(_color) : null,
                  border: Border.all(
                      color: _iconIndex == i
                          ? Color(_color)
                          : AppColors.border,
                      width: 1.4),
                ),
                child: Icon(
                  MarkerCategory.iconPalette[i],
                  size: 20,
                  color: _iconIndex == i ? Colors.white : AppColors.inkSoft,
                ),
              ),
            ),
        ],
      );

  /// 图片图标行：上传/替换 + 撤下 + 预览（44px 圆，与 Pin 视觉一致）
  Widget _imagePickerRow(AppLocalizations texts) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: _imageRel == null
              ? Icon(Icons.add_photo_alternate_outlined,
                  size: 20, color: AppColors.inkSoft)
              : FutureBuilder<Uint8List?>(
                  future: MediaStore.load(_imageRel!),
                  builder: (context, snap) => snap.data != null
                      ? Image.memory(snap.data!,
                          width: 44, height: 44, fit: BoxFit.cover)
                      : Icon(Icons.hourglass_empty,
                          size: 16, color: AppColors.inkSoft),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _imageRel == null
                ? texts.categoriesImgEmpty
                : texts.categoriesImgCurrent,
            style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.image_outlined, size: 17),
          label: Text(_imageRel == null
              ? texts.categoriesImgUpload
              : texts.categoriesImgReplace),
          onPressed: _uploadImage,
        ),
        if (_imageRel != null) ...[
          const SizedBox(width: 8),
          TooltipBarrier(
            child: IconButton(
              tooltip: texts.categoriesImgClear,
              icon: const Icon(Icons.restart_alt, size: 18),
              onPressed: () => setState(() => _imageRel = null),
            ),
          ),
        ],
      ],
    );
  }
}


