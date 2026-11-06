import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/io/storage_adapter.dart';
import '../../core/i18n_names.dart';
import '../../data/models/guide.dart';
import '../../data/models/map_source.dart';
import '../../data/repos/tile_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../state/guide_editor.dart';
import '../../state/settings_provider.dart';

/// 底部弹层：切换在线瓦片地图源 + 已下载离线包
/// 弹层内显式传入编辑器（后 route 拿不到 Provider）；源切换随之持久化到攻略
class MapSourceSheet extends StatefulWidget {
  const MapSourceSheet({super.key, required this.editor});

  final GuideEditor editor;

  @override
  State<MapSourceSheet> createState() => _MapSourceSheetState();
}

class _MapSourceSheetState extends State<MapSourceSheet> {
  late final GuideEditor ed = widget.editor;
  List<TilePack> _packs = const [];

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  Future<void> _loadPacks() async {
    try {
      final packs = await TileRepository(activeStorage).loadPacks();
      if (!mounted) return;
      setState(() => _packs = packs);
    } catch (_) {}
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String get _activeKey => ed.offlinePack == null
      ? ed.source.id
      : TilePack.packKey(ed.offlinePack!.id);

  void _dispatchSelect(String? v) {
    if (v == null) return;
    if (v.startsWith('pack:')) {
      final id = v.substring(5);
      final match = _packs.where((p) => p.id == id).toList();
      if (match.isEmpty) return;
      _onSelectPack(context, ed, match.first);
    } else {
      _onSelect(context, ed, v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // 弹层高度固定，内容交给 Expanded + 列表滚动，避免收起时溢出
    return SizedBox(
      height: 430,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
        child: Column(
          children: [
            ListTile(
              title: Text(t.srcSheetTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              dense: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                t.srcSheetIntro,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.inkSoft, height: 1.5),
              ),
            ),
            Expanded(
              child: RadioGroup<String>(
                groupValue: _activeKey,
                onChanged: _dispatchSelect,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final source in MapSources.all)
                      RadioListTile<String>(
                        value: source.id,
                        title: Row(
                          children: [
                            Icon(
                              source.kind == MapKind.satellite
                                  ? Icons.satellite_alt_outlined
                                  : Icons.map_outlined,
                              size: 17,
                              color: AppColors.inkSoft,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(mapSourceName(t, source),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 6),
                            if (source.recommendedChina)
                              _SourceTag(t.srcTagChinaRec, AppColors.primary),
                            if (source.recommendedOverseas)
                              _SourceTag(t.srcTagOverseasRec, AppColors.accent),
                            if (kIsWeb &&
                                source.coordSystem == CoordSystem.gcj02)
                              _SourceTag(
                                  t.srcTagWebNoDownload, const Color(0xFFB2400F)),
                          ],
                        ),
                        subtitle: Text(
                          '${source.coordLabel} · ${mapKindName(t, source)}'
                          '${_sourceHint(t, source)}'
                          '${source.needsKey ? t.srcTdtKeySuffix : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        dense: true,
                      ),
                    const Divider(height: 4, indent: 16, endIndent: 16),
                    // 已下载的离线包（勾选即切包，立即生效）
                    if (_packs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                        child: Text(
                          t.srcPacksNone,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.inkSoft),
                        ),
                      )
                    else
                      for (final pack in _packs)
                        RadioListTile<String>(
                          value: TilePack.packKey(pack.id),
                          secondary: const Icon(
                              Icons.download_done_outlined,
                              size: 18,
                              color: AppColors.primary),
                          title: Text(
                            '${t.offlinePrefix} ${pack.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${_packSourceName(t, pack)} · z${pack.zoomMin}–${pack.zoomMax}'
                            ' · ${t.tileCountUnit(pack.tileCount)}'
                            '${pack.sizeMb > 0 ? ' · ${pack.sizeMb.toStringAsFixed(1)} MB' : ''}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          dense: true,
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 各源可用性提示：引导避开浏览器内 CORS / 境内不可达源
  String _sourceHint(AppLocalizations t, MapSource source) {
    if (source.id == 'esri_street' ||
        source.id == 'esri_topo' ||
        source.id == 'esri_gray') {
      return t.srcHintEsri;
    }
    if (source.id == 'osm') {
      return t.srcHintOsm;
    }
    return '';
  }

  /// 离线包所属地图源名
  String _packSourceName(AppLocalizations t, TilePack pack) {
    final source = MapSources.byId(pack.sourceId);
    return source == null ? '--' : mapSourceName(t, source);
  }

  void _onSelect(BuildContext context, GuideEditor ed, String v) {
    final source = MapSources.all.firstWhere(
      (s) => s.id == v,
      orElse: () => ed.source,
    );
    if (source.needsKey) {
      final key = context.read<AppSettings>().tiandituKey;
      if (key.isEmpty) {
        _snack(context, AppLocalizations.of(context).snackNeedsTdtKey);
        return;
      }
    }
    ed.setSource(source); // 同步guide.sourceId（JSON 持久化）
    Navigator.pop(context);
  }

  /// 切到离线包源（同弹层关闭即生效）
  void _onSelectPack(BuildContext context, GuideEditor ed, TilePack pack) {
    ed.setPackSource(pack);
    _snack(
        context,
        AppLocalizations.of(context)
            .snackPackSwitched(pack.name));
    Navigator.pop(context);
  }
}

class _SourceTag extends StatelessWidget {
  const _SourceTag(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 9.5, color: color)),
    );
  }
}
