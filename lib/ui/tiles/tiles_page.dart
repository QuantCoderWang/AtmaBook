import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/i18n_names.dart';
import '../../core/io/storage_adapter.dart';
import '../../data/models/guide.dart';
import '../../data/models/map_source.dart';
import '../../data/repos/tile_repository.dart';
import '../../l10n/app_localizations.dart';
import 'download_wizard_page.dart';

/// 离线地图管理页：
/// 列表读真目录（名称/源/张数/体积/完成时间），删除确认连文件释放；
/// 新建下载向导（第一步源选择含天地图 tk 校验）。
class TilesPage extends StatefulWidget {
  const TilesPage({super.key});

  @override
  State<TilesPage> createState() => _TilesPageState();
}

class _TilesPageState extends State<TilesPage> {
  late final TileRepository _repo = TileRepository(activeStorage);
  List<TilePack>? _packs;
  final Map<String, int> _sizeBytes = {};

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final packs = await _repo.loadPacks()
      ..sort((a, b) {
        final ca = a.completedAt ?? DateTime(1970);
        final cb = b.completedAt ?? DateTime(1970);
        return cb.compareTo(ca); // 新完成在前
      });
    // 异步补齐实测体积
    for (final p in packs) {
      try {
        final bytes = await _repo.packSizeBytes(p);
        if (mounted) {
          setState(() => _sizeBytes[p.id] = bytes);
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _packs = packs);
  }

  Future<void> _deletePack(TilePack pack) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deletePackTitle),
        content: Text(t.deletePackContent(pack.name, pack.tileCount)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.btnDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deletePack(pack.id);
    _snack(t.packDeletedToast(pack.name));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final packs = _packs;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(t.tilesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.map),
        label: Text(t.fabNewPack),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DownloadWizardPage()),
          );
          _reload(); // 下载完成（或取消）后刷新列表
        },
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            const _Banner(),
            const SizedBox(height: 16),
            if (packs == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (packs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Icon(Icons.map_outlined,
                        size: 40, color: AppColors.inkSoft),
                    const SizedBox(height: 10),
                    Text(t.tilesEmptyTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(t.tilesEmptyHint,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.inkSoft)),
                  ],
                ),
              )
            else
              for (final pack in packs)
                _PackCard(
                  pack: pack,
                  bytes: _sizeBytes[pack.id],
                  onDelete: () => _deletePack(pack),
                ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFAF3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.tilesFoot,
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.inkSoft,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      height: 110,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00695C), Color(0xFF004D40)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.offline_pin, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(t.bannerTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.bannerSub,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.bytes,
    required this.onDelete,
  });

  final TilePack pack;
  final int? bytes;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final source = MapSources.byId(pack.sourceId);
    final isSat = source?.kind == MapKind.satellite;
    final sizeMb = bytes != null
        ? (bytes! / 1024 / 1024)
        : pack.sizeMb;
    final done = pack.completedAt;
    final doneText = done == null
        ? ''
        : ' · ${t.completedOn(t.dateMthDy('${done.month}', '${done.day}'))} '
            '${done.hour.toString().padLeft(2, '0')}:'
            '${done.minute.toString().padLeft(2, '0')}';
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSat ? AppColors.primaryDark : AppColors.primary,
          ),
          child: Icon(isSat ? Icons.satellite_alt : Icons.map,
              color: Colors.white, size: 21),
        ),
        title: Text(pack.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          '${source != null ? mapSourceName(t, source) : '--'}'
          '（${source?.coordLabel ?? '--'}） · ${pack.bboxLabel}\n'
          'z${pack.zoomMin}–${pack.zoomMax} · ${t.tileCountUnit(pack.tileCount)} · '
          '${sizeMb.toStringAsFixed(1)} MB'
          '$doneText',
          style: const TextStyle(
              fontSize: 11, color: AppColors.inkSoft, height: 1.45),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'delete') {
              onDelete();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.snackRefillUnavailable)),
              );
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'refresh', child: Text(t.menuRefill)),
            PopupMenuItem(value: 'delete', child: Text(t.btnDelete)),
          ],
        ),
      ),
    );
  }
}
