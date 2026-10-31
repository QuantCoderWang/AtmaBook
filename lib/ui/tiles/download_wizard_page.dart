import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/geo.dart';
import '../../core/i18n_names.dart';
import '../../core/io/storage_adapter.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/tile_math.dart';
import '../../data/models/guide.dart';
import '../../data/models/map_source.dart';
import '../../data/repos/tile_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/tile_downloader.dart';
import '../../state/settings_provider.dart';
/// 新建离线下载向导：
/// 选源（含天地图 tk 校验）→ 框选范围 → 缩放级别 → 确认 →
/// 真实下载 → pack.json 落盘
class DownloadWizardPage extends StatefulWidget {
  const DownloadWizardPage({super.key});

  @override
  State<DownloadWizardPage> createState() => _DownloadWizardPageState();
}

class _DownloadWizardPageState extends State<DownloadWizardPage> {
  int _step = 0;
  // Web 浏览器内：CORS/可达性 → 默认 Esri（免 Key）；桌面端：境内高德
  MapSource _source = kIsWeb ? MapSources.esriStreet : MapSources.amapVector;
  LatLng? _a;
  LatLng? _b;
  RangeValues _zooms = const RangeValues(11, 16);

  bool _downloading = false;
  bool _done = false;
  String? _doneMsg;
  double _progress = 0;
  String _progressText = '';

  TileDownloadToken _token = TileDownloadToken();

  late final TileRepository _repo = TileRepository(activeStorage);

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  List<int> get _zoomList {
    final lo = _zooms.start.round();
    final hi = _zooms.end.round();
    return [for (var z = lo; z <= hi; z++) z];
  }

  bool get _gcj => _source.coordSystem == CoordSystem.gcj02;

  List<TileCoord> get _tiles {
    if (_a == null || _b == null) return const [];
    return enumerateTiles(_a!, _b!, _zoomList, gcjSource: _gcj);
  }

  int get _estimateTiles => _tiles.length;

  void _onContinue() {
    if (_step == 1 && (_a == null || _b == null)) {
      _snack(AppLocalizations.of(context).wizardNeedRange);
      return;
    }
    if (_step < 3) setState(() => _step += 1);
  }

  Future<void> _startDownload() async {
    if (_a == null || _b == null) return;
    final t = AppLocalizations.of(context);
    final tiles = _tiles;
    if (tiles.isEmpty) {
      _snack(t.rangeTooSmall);
      return;
    }
    if (tiles.length > kHugeTileCount) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t.hugeConfirmTitle),
          content: Text(t.hugeConfirmContent(
              tiles.length,
              (tiles.length * 0.04).toStringAsFixed(0))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.btnRethink)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t.btnContinueDownload)),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;

    _token = TileDownloadToken();
    final downloader = TileDownloader(
      source: _source,
      storage: activeStorage,
      tiandituKey: context.read<AppSettings>().tiandituKey,
    );
    setState(() {
      _downloading = true;
      _done = false;
      _progress = 0;
      _progressText = t.progressInit(tiles.length);
    });

    final packId = newId('pk');
    final report = await downloader.download(
      packId: packId,
      tiles: tiles,
      fileExt: tileExtFor(_source),
      token: _token,
      onProgress: (done, total, bytes) {
        if (!mounted) return;
        setState(() {
          _progress = total == 0 ? 1 : done / total;
          _progressText = AppLocalizations.of(context).progressText(
              done, total, (bytes / 1024 / 1024).toStringAsFixed(1));
        });
      },
    );

    if (report.cancelled || report.earlyAborted) {
      final reason = report.earlyAborted
          ? (kIsWeb && _gcj
              ? t.cancelReasonWebCgj
              : kIsWeb
                  ? t.cancelReasonWeb
                  : t.cancelReasonOffline)
          : t.cancelledKept;
      setState(() {
        _downloading = false;
        _done = false;
        _doneMsg = t.reportStats(
            reason, report.ok, report.skipped, report.failed);
      });
      if (report.ok + report.skipped == 0) {
        _snack(reason);
        return; // 零成功：不写 pack.json（避免产生空包）
      }
      _snack(t.snackAbortedKept);
      return;
    }

    if (report.ok + report.skipped == 0) {
      setState(() {
        _downloading = false;
        _doneMsg = t.downloadedNoneMsg(report.failed);
      });
      _snack(t.snackNoneDownloaded);
      return;
    }

    // 写 pack.json（真实统计）
    final cnt = report.ok + report.skipped;
    final pack = TilePack(
      id: packId,
      name: _packName(),
      sourceId: _source.id,
      bboxLabel: _bboxLabel(),
      zoomMin: _zooms.start.round(),
      zoomMax: _zooms.end.round(),
      tileCount: cnt,
      sizeMb: report.bytesWritten / 1024 / 1024,
      centerLat: _a != null && _b != null
          ? (_a!.latitude + _b!.latitude) / 2
          : null,
      centerLng: _a != null && _b != null
          ? (_a!.longitude + _b!.longitude) / 2
          : null,
      completedAt: DateTime.now(),
      ext: tileExtFor(_source),
    );
    try {
      await _repo.savePackManifest(pack);
    } catch (_) {
      _snack(t.manifestFail);
    }
    setState(() {
      _downloading = false;
      _done = report.allDone;
      _doneMsg = t.doneMsgLine(
          report.allDone ? t.doneLabel : t.donePartial,
          '$report',
          report.elapsed.inSeconds);
    });
    _snack(report.allDone
        ? t.snackPackReady(cnt)
        : t.snackPartialFail(report.failed));
  }

  String _packName() {
    if (_a == null || _b == null) {
      return AppLocalizations.of(context).packNameUnnamed;
    }
    final lat = ((_a!.latitude + _b!.latitude) / 2).toStringAsFixed(2);
    final lng = ((_a!.longitude + _b!.longitude) / 2)
        .toStringAsFixed(2);
    final t = AppLocalizations.of(context);
    return '${mapSourceName(t, _source)} · ($lat, $lng)';
  }

  String _bboxLabel() {
    if (_a == null || _b == null) return '';
    return '${_fmt(_a!)} ~ ${_fmt(_b!)}';
  }

  /// 连线测试：取范围中心对应的一片中位瓦片实测可达性
  Future<void> _probe() async {
    final t = AppLocalizations.of(context);
    final tiles = _tiles;
    if (tiles.isEmpty) {
      _snack(t.needRangeForProbe);
      return;
    }
    final mid = tiles[tiles.length ~/ 2];
    _snack(t.probing);
    final (ok, status, ms) = await TileDownloader.probe(
      _source,
      mid,
      tiandituKey: context.read<AppSettings>().tiandituKey,
    );
    if (!mounted) return;
    final extra = kIsWeb && _gcj ? t.extraWebCgj : '';
    _snack(ok
        ? t.probeOk(status == 200 ? '200' : '$status', ms, extra)
        : kIsWeb
            ? t.probeFailWeb(status == 200 ? '200' : '$status', ms)
            : t.probeFailDesktop(status == 200 ? '200' : '$status', ms));
  }

  String _fmt(LatLng p) => '(${p.latitude.toStringAsFixed(4)}, '
      '${p.longitude.toStringAsFixed(4)})';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(t.wizardTitle)),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _step,
        onStepTapped: (s) {
          if (_downloading) return;
          setState(() => _step = s);
        },
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              if (_downloading)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0x22D32F2F),
                    foregroundColor: Colors.red,
                  ),
                  icon: const Icon(Icons.stop, size: 17),
                  label: Text(t.cancelDownload),
                  onPressed: () => _token.cancelled = true,
                )
              else if (!_done && _step == 3)
                FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: Text(t.startDownload),
                  onPressed: (_a != null && _b != null)
                      ? _startDownload
                      : null,
                )
              else if (!_done)
                TextButton(
                  onPressed: _onContinue,
                  child: Text(t.btnNext,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              if (_step > 0 && !_downloading && !_done)
                TextButton(
                  onPressed: () => setState(() => _step -= 1),
                  child: Text(t.createPrev),
                ),
            ],
          ),
        ),
        steps: [
          Step(
            title: Text(t.stepChooseSource),
            subtitle: Text(mapSourceName(t, _source)),
            isActive: _step >= 0,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final source in MapSources.all)
                      _SourceChip(
                        source: source,
                        selected: _source.id == source.id,
                        t: t,
        onSelected: (on) {
                          if (!on) return;
                          if (source.needsKey) {
                            final tk = context
                                .read<AppSettings>()
                                .tiandituKey;
                            if (tk.isEmpty) {
                              _snack(t.snackNeedsTdtKey);
                              return;
                            }
                          }
                          setState(() => _source = source);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${t.srcRecommendFoot(_gcj ? t.srcNoteGcj : t.srcNoteWgs)}'
                  '${kIsWeb ? t.webPreviewNote : ''}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          Step(
            title: Text(t.stepSelectArea),
            subtitle: Text(
                _a != null && _b != null ? t.areaDone : t.areaHint),
            isActive: _step >= 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 320,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: _a ?? const LatLng(30.25, 120.15),
                        initialZoom: 11,
                        onTap: (tapPos, point) => setState(() {
                          if (_a == null || (_a != null && _b != null)) {
                            _a = point;
                            _b = null;
                          } else {
                            _b = point;
                          }
                        }),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _source.needsKey
                              ? _source.urlTemplate.replaceFirst('{key}',
                                  context.watch<AppSettings>().tiandituKey)
                              : _source.urlTemplate,
                          subdomains: _source.subdomains,
                          userAgentPackageName: 'com.example.atma_book',
                        ),
                        if (_a != null && _b != null)
                          PolygonLayer(
                            polygons: [
                              Polygon(
                                points: [
                                  _a!,
                                  LatLng(_a!.latitude, _b!.longitude),
                                  _b!,
                                  LatLng(_b!.latitude, _a!.longitude),
                                ],
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderColor: AppColors.accent,
                                borderStrokeWidth: 2.5,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(t.pointLabelA(_a == null ? t.notPicked : _fmt(_a!)),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.inkSoft)),
                    const SizedBox(width: 12),
                    Text(t.pointLabelB(_b == null ? t.notPicked : _fmt(_b!)),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.inkSoft)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        _a = null;
                        _b = null;
                      }),
                      child: Text(t.btnClear,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Step(
            title: Text(t.stepChooseZoom),
            subtitle:
                Text('z${_zooms.start.round()} – z${_zooms.end.round()}'),
            isActive: _step >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RangeSlider(
                  values: _zooms,
                  min: 8,
                  max: 18,
                  divisions: 20,
                  labels: RangeLabels(
                    'z${_zooms.start.round()}',
                    'z${_zooms.end.round()}',
                  ),
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _zooms = v),
                ),
                Text(
                  t.zoomFootStep,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          Step(
            title: Text(t.stepConfirm),
            isActive: _step >= 3,
            state:
                _done ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(label: t.rowMapSource, value: mapSourceName(t, _source)),
                _SummaryRow(label: t.rowCoordSys,
                    value: _gcj ? t.coordRowGcj : 'WGS-84'),
                _SummaryRow(
                    label: t.rowRange, value: _bboxLabel()),
                _SummaryRow(
                    label: t.rowZoom,
                    value:
                        'z${_zooms.start.round()} – z${_zooms.end.round()}'),
                _SummaryRow(
                    label: t.rowManifest,
                    value: _a != null && _b != null
                        ? t.manifestValue(_estimateTiles,
                            estimateSizeMb(_estimateTiles).toStringAsFixed(1))
                        : t.manifestPending),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  icon: const Icon(Icons.network_check, size: 17),
                  label: Text(t.probeBtnValue),
                  onPressed: (_a != null && _b != null && !_downloading)
                      ? _probe
                      : null,
                ),
                if (_done && _doneMsg != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_doneMsg!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.green)),
                      ),
                    ],
                  ),
                ],
                if (kIsWeb && _gcj) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x18E65100),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 15, color: Color(0xFFE65100)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.webCgjWarning,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFB2400F)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (_downloading) ...[
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                  Text(_progressText,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkSoft)),
                ] else if (!_done)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.download),
                      label: Text(t.startDownload),
                      onPressed: (_a != null && _b != null)
                          ? _startDownload
                          : null,
                    ),
                  ),
                if (_done || (_doneMsg != null && !_downloading))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _doneMsg ?? '',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.inkSoft),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.source,
    required this.selected,
    required this.onSelected,
    required this.t,
  });

  final MapSource source;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            source.kind == MapKind.satellite
                ? Icons.satellite_alt_outlined
                : Icons.map_outlined,
            size: 15,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
          const SizedBox(width: 5),
          Text(mapSourceName(t, source)),
        ],
      ),
      selected: selected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.ink,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      onSelected: onSelected,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inkSoft)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ],
      ),
    );
  }
}
