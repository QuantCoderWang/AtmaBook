import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../state/guide_editor.dart';
import '../../state/guides_provider.dart';

/// 攻略信息编辑弹出层：内涵标题/简介/封面内容（可修改）
class GuideInfoEditSheet extends StatefulWidget {
  const GuideInfoEditSheet({super.key, required this.editor});

  final GuideEditor editor;

  @override
  State<GuideInfoEditSheet> createState() => _GuideInfoEditSheetState();
}

class _GuideInfoEditSheetState extends State<GuideInfoEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _summary;
  Uint8List? _cover;

  @override
  void initState() {
    super.initState();
    final g = widget.editor.guide;
    _title = TextEditingController(text: g.title);
    _summary = TextEditingController(text: g.summary);
    _cover = context.read<GuidesProvider>().coverPreview(g.id);
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    try {
      final file =
          await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _cover = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).createNoPhotoPick)));
    }
  }

  Future<void> _save() async {
    final guides = context.read<GuidesProvider>();
    final updated = widget.editor.guide.copyWith(
      title: _title.text.trim().isEmpty
          ? widget.editor.guide.title
          : _title.text.trim(),
      summary: _summary.text.trim(),
      updatedAt: DateTime.now(),
    );
    await guides.replace(updated);
    await guides.setCoverBytes(updated.id, _cover);
    final latest = guides.byId(updated.id) ?? updated;
    widget.editor.applyGuide(latest);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).infoSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t.infoSheetTitle,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text(t.infoSheetSub,
                style: const TextStyle(fontSize: 11)),
          ),
          TextField(
            controller: _title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(hintText: t.infoTitleHint),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _summary,
            maxLines: 2,
            decoration: InputDecoration(hintText: t.infoSummaryHint),
          ),
          const SizedBox(height: 12),
          Text(t.infoCoverTitle,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.inkSoft)),
          const SizedBox(height: 8),
          if (_cover != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    _cover!,
                    width: double.infinity,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      _MiniAction(
                        icon: Icons.sync,
                        label: t.infoChangeCover,
                        onTap: _pickCover,
                      ),
                      const SizedBox(width: 6),
                      _MiniAction(
                        icon: Icons.delete_outline,
                        label: t.infoRemoveCover,
                        onTap: () => setState(() => _cover = null),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 17),
              label: Text(t.infoAddCover),
              onPressed: _pickCover,
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.cancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.check, size: 17),
                  label: Text(t.btnSave),
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
