import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/geo.dart';
import '../../core/io/storage_adapter.dart';
import '../../data/models/guide.dart';
import '../../data/models/map_source.dart' show GuideRegion;
import '../../data/repos/tile_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/geocode_service.dart';
import '../../state/guides_provider.dart';
import '../../state/settings_provider.dart';

/// 新增攻略向导（两段式）：
///  第 1 步  基础信息：标题 / 简介 / 区域（决定默认地图源）/ 封面图片（可选）
///  第 2 步  范围检索：**真实地理检索**（Nominatim 免密钥；境内可配高德 Key）
///           → 检查该区域是否已有落盘离线瓦片包
///           （已存在 → 直接使用；不存在 → 一键下载）
class CreateGuideDialog extends StatefulWidget {
  const CreateGuideDialog({super.key});

  @override
  State<CreateGuideDialog> createState() => _CreateGuideDialogState();
}

/// 无网络/未检索时的快捷候选：展示与检索同词（中英界面各给一组可直接键入的查询词）
const List<String> _quickQueriesZh = ['杭州', '西湖', '上海', '北京', '巴黎', '东京'];
const List<String> _quickQueriesEn = [
  'Hangzhou', 'West Lake', 'Shanghai', 'Beijing', 'Paris', 'Tokyo',
];

class _CreateGuideDialogState extends State<CreateGuideDialog> {
  int _stage = 0; // 0 基础信息 / 1 检索
  final TextEditingController _title = TextEditingController();
  final TextEditingController _summary = TextEditingController();
  final TextEditingController _search = TextEditingController();
  GuideRegion _region = GuideRegion.china;
  Uint8List? _coverBytes;

  // —— 真实检索状态 ——
  Timer? _debounce;
  int _searchSeq = 0;
  bool _searching = false;
  String? _searchError;
  List<GeoPlaceResult> _results = [];
  final Map<int, TilePack> _packByIndex = {};

  // —— 一键下载 ——
  int? _downloadingIdx;
  double _downloadProgress = 0;
  Timer? _timer;
  final Set<int> _demoDownloaded = {};

  List<TilePack> _cachedPacks = [];
  bool _packsLoaded = false;

  Future<List<TilePack>> _packs() async {
    if (!_packsLoaded) {
      try {
        _cachedPacks =
            await TileRepository(activeStorage).loadPacks();
      } catch (_) {
        _cachedPacks = const [];
      }
      _packsLoaded = true;
    }
    return _cachedPacks;
  }

  Future<void> _runSearch(String q) async {
    final seq = ++_searchSeq;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final amapKey = context.read<AppSettings>().amapKey;
      final results = await GeocodeService().search(
        query: q,
        china: _region == GuideRegion.china,
        amapKey: amapKey,
      );
      if (seq != _searchSeq) return; // 已被更新的检索覆盖，丢弃
      final packs = await _packs();
      final packMap = <int, TilePack>{};
      final sourceId = _region == GuideRegion.china ? 'amap_vector' : 'osm';
      for (var i = 0; i < results.length; i++) {
        TilePack? best;
        double bestKm = double.infinity;
        for (final p in packs) {
          if (p.sourceId != sourceId) continue;
          final cLat = p.centerLat;
          final cLng = p.centerLng;
          if (cLat == null || cLng == null) continue;
          final km =
              haversineMeters(LatLng(results[i].lat, results[i].lng),
                      LatLng(cLat, cLng)) /
                  1000;
          if (km <= 80 && km < bestKm) {
            best = p;
            bestKm = km;
          }
        }
        if (best != null) packMap[i] = best;
      }
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = results;
        _packByIndex
          ..clear()
          ..addAll(packMap);
        _searching = false;
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = const [];
        _searching = false;
        _searchError = AppLocalizations.of(context).createSearchError;
      });
    }
  }

  void _onSearchChanged(String v) {
    setState(() {});
    _debounce?.cancel();
    final q = v.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _searchError = null;
        _packByIndex.clear();
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _runSearch(q);
    });
  }

  double get _dialogHeight => _stage == 0 ? 452 : 508;

  Future<void> _pickCover() async {
    try {
      final file = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _coverBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).createNoPhotoPick)));
    }
  }

  void _startDemoDownload(int idx) {
    setState(() {
      _downloadingIdx = idx;
      _downloadProgress = 0;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _downloadProgress += 0.06);
      if (_downloadProgress >= 1) {
        t.cancel();
        setState(() {
          _downloadingIdx = null;
          _demoDownloaded.add(idx);
        });
      }
    });
  }

  Future<Guide> _finishCreation([GeoPlaceResult? origin]) async {
    final provider = context.read<GuidesProvider>();
    final guide = await provider.create(
      title: _title.text,
      summary: _summary.text,
      region: _region,
      origin: origin == null
          ? null
          : GeoPlaceOrigin(origin.name, origin.lat, origin.lng),
    );
    if (_coverBytes != null) {
      await provider.setCoverBytes(guide.id, _coverBytes);
    }
    return guide;
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _search.dispose();
    _debounce?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 430,
        height: _dialogHeight,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StepDot(active: true, dot: '1', label: t.createStep1),
                  Expanded(
                    child: Container(
                      height: 1.2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: _stage >= 1
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  _StepDot(
                      active: _stage >= 1, dot: '2', label: t.createStep2),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child:
                    _stage == 0 ? _buildBasicStage() : _buildSearchStage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // —— 基础信息 ——
  Widget _buildBasicStage() {
    final t = AppLocalizations.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _title,
      builder: (context, title, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _title,
                    autofocus: true,
                    decoration:
                        InputDecoration(hintText: t.createTitleHint),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _summary,
                    maxLines: 2,
                    decoration:
                        InputDecoration(hintText: t.createSummaryHint),
                  ),
                  const SizedBox(height: 16),
                  Text(t.createRegionTitle,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.inkSoft)),
                  const SizedBox(height: 8),
                  _regionTile(
                    region: GuideRegion.china,
                    icon: Icons.location_city,
                  ),
                  _regionTile(
                    region: GuideRegion.overseas,
                    icon: Icons.public,
                  ),
                  const SizedBox(height: 14),
                  Text(t.createCoverTitle,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.inkSoft)),
                  const SizedBox(height: 8),
                  if (_coverBytes != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            _coverBytes!,
                            width: double.infinity,
                            height: 92,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: InkWell(
                            onTap: () => setState(() => _coverBytes = null),
                            child: Container(
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    OutlinedButton.icon(
                      icon:
                          const Icon(Icons.add_photo_alternate_outlined, size: 17),
                      label: Text(t.createAddCover),
                      onPressed: _pickCover,
                    ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.cancel),
              ),
              FilledButton(
                onPressed: title.text.trim().isEmpty
                    ? null
                    : () => setState(() => _stage = 1),
                child: Text(t.createNext),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // —— 真实范围检索与地图包检查 ——
  Widget _buildSearchStage() {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.public, size: 15, color: AppColors.inkSoft),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                t.createBanner(
                  _region == GuideRegion.china
                      ? t.createWhereChina
                      : t.createWhereAbroad,
                  _region == GuideRegion.china
                      ? t.createSourceAmap
                      : t.createSourceOsm,
                ),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          style: const TextStyle(fontSize: 13.5),
          decoration: InputDecoration(
            isDense: true,
            hintText: t.createSearchHint,
            prefixIcon:
                const Icon(Icons.search, size: 18, color: AppColors.inkSoft),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      _search.clear();
                      _onSearchChanged('');
                    },
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 6),
        Expanded(child: _buildResultArea()),
        Row(
          children: [
            const Icon(Icons.info_outline, size: 13, color: AppColors.inkSoft),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                  t.createScopeFoot,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => _stage = 0),
              child: Text(t.createPrev),
            ),
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final guide = await _finishCreation();
                nav.pop(guide);
              },
              child: Text(t.createSkipStart),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultArea() {
    final t = AppLocalizations.of(context);
    if (_search.text.trim().isEmpty) {
      final quick = Localizations.localeOf(context).languageCode.startsWith('en')
          ? _quickQueriesEn
          : _quickQueriesZh;
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 0, 8),
            child: Text(t.createHotTitle,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.inkSoft)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final q in quick)
                ActionChip(
                  label: Text(q,
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    _search.text = q;
                    _runSearch(q);
                  },
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 12, 0, 0),
            child: Text(
              t.createHotFoot,
              style: const TextStyle(fontSize: 11, color: AppColors.inkSoft,
                  height: 1.6),
            ),
          ),
        ],
      );
    }
    if (_searchError != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.wifi_off, size: 16, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_searchError!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.inkSoft))),
              ],
            ),
          ),
        ],
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(t.createNoMatch,
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.inkSoft)),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final r = _results[i];
        return _OptionTile(
          result: r,
          hasPack: _packByIndex.containsKey(i),
          packName: _packByIndex[i]?.name,
          demoDownloaded: _demoDownloaded.contains(i),
          downloading: _downloadingIdx == i,
          progress: _downloadProgress,
          onDownload: () => _startDemoDownload(i),
          onUse: () async {
            final nav = Navigator.of(context);
            final guide = await _finishCreation(r);
            nav.pop(guide);
          },
        );
      },
    );
  }

  Widget _regionTile({required GuideRegion region, required IconData icon}) {
    final t = AppLocalizations.of(context);
    final bool selected = _region == region;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _region = region;
          // 区域变化后检索结果与包检查需按新源重算
          _packsLoaded = false;
        });
        if (_search.text.trim().isNotEmpty) {
          _runSearch(_search.text.trim());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.inkSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      region == GuideRegion.china
                          ? t.regionTileChina
                          : t.regionTileOverseas,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(
                      region == GuideRegion.china
                          ? t.regionTileChinaDesc
                          : t.regionTileOverseasDesc,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.inkSoft)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? AppColors.primary : AppColors.inkSoft,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.active,
    required this.dot,
    required this.label,
  });

  final bool active;
  final String dot;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.primary : const Color(0xFFE4DECF),
          ),
          child: Text(dot,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, height: 1)),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.primary : AppColors.inkSoft)),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.result,
    required this.hasPack,
    required this.packName,
    required this.demoDownloaded,
    required this.downloading,
    required this.progress,
    required this.onDownload,
    required this.onUse,
  });

  final GeoPlaceResult result;
  final bool hasPack;
  final String? packName;
  final bool demoDownloaded;
  final bool downloading;
  final double progress;
  final VoidCallback onDownload;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final downloaded = hasPack || demoDownloaded;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFBF7EF),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 17, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(result.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: onUse,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor:
                      downloaded ? Colors.green : AppColors.primary,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(downloaded ? t.createBtnUseLocal : t.createBtnUse,
                    style: const TextStyle(fontSize: 11)),
              ),
              if (!downloaded && !downloading) ...[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: onDownload,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(t.createBtnDownload,
                      style: const TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
          if (result.address.isNotEmpty)
            Text(result.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.5, color: AppColors.inkSoft)),
          if (downloading) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: LinearProgressIndicator(minHeight: 3)),
                const SizedBox(width: 8),
                Text('${(progress * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.inkSoft)),
              ],
            ),
          ],
          Text(
            hasPack
                ? t.createPackReady(packName ?? t.createPackFallbackName)
                : demoDownloaded
                    ? t.createDemoDone
                    : t.createNoPack,
            style:
                const TextStyle(fontSize: 10.5, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
