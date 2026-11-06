import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/io/storage_adapter.dart';
import '../../data/models/guide.dart';
import '../../data/models/wall_photo.dart';
import '../../data/repos/wall_photo_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ffmpeg_runner.dart';
import '../../services/share_service.dart';
import '../../services/share_temp.dart' as share_temp;
import '../../state/settings_provider.dart';

/// 生成分享文件弹窗：
/// 选项（打包模式分支 + 是否含照片 + 内容筛选 + 体积预估）→ 进度（逐张处理，
/// 可取消）→ 完成路径。
/// - 水印低质版（默认）：现行方案，副本降质 + 烧录水印；
/// - 原片高清版：媒体按原件字节入包（不缩放/不转码/无水印），包体硬上限
///   1 GB——预估超限时提供「剔除条目 / 降质打包（两档选一）」，原图全程只读。
/// 结果通过 SnackBar 告知输出位置。
Future<void> openShareExportSheet(BuildContext context, Guide guide) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _ShareExportSheet(guide: guide),
  );
}

class _ShareExportSheet extends StatefulWidget {
  const _ShareExportSheet({required this.guide});

  final Guide guide;

  @override
  State<_ShareExportSheet> createState() => _ShareExportSheetState();
}

enum _Phase { options, working, done, failed }

class _ShareExportSheetState extends State<_ShareExportSheet> {
  _Phase _phase = _Phase.options;
  bool _includePhotos = true;

  /// 打包模式：false = 水印低质版（默认）；true = 原片高清版
  bool _originalMode = false;

  /// 原片模式剔除的条目 id（照片 / 视频挑选收口）
  final Set<String> _excluded = <String>{};

  /// 原片模式降质档（超限后用户选择；none = 原件直通）
  ShareExportDegrade _degrade = ShareExportDegrade.none;

  /// 原片模式实测尺寸缓存（刷新于模式切换 / 筛选变更）
  int? _originalSizeBytes;

  int _done = 0;
  int _total = 0;
  String _label = '';
  bool _cancelled = false;
  String _resultPath = '';
  String _error = '';

  static const _originalAvailable = !kIsWeb; // 原片模式需文件系统

  List<PhotoItem> get _packablePhotos => [
        for (final p in widget.guide.photos) if (p.file.isNotEmpty) p,
        ..._extraPhotoItems,
      ];

  /// 账本归属本攻略的照片 → 导出用 PhotoItem（经地理相册归属的照片
  /// 不写 Guide.photos，分享链需在此合并；id 用账本原 id，
  /// 接收端照常全量重映射）。与攻略内照片按 id 幂等去重。
  List<PhotoItem> get _extraPhotoItems {
    final knownIds = {for (final p in widget.guide.photos) p.id};
    return [
      for (final w in _ledgerPhotos)
        if (!knownIds.contains(w.id)) _ledgerPhotoToItem(w),
    ];
  }

  /// 媒体条目显示名：name 优先，空名回退拍摄时间（与照片查看器 /
  /// 和照片墙自动命名的规则一样：`2026/10/5 15:28`，账本照片导入链
  /// 不携带源文件名（只传字节 + 内容哈希改名），故不存在文件名可取）。
  static String _mediaLabel(String name, DateTime takenAt) =>
      name.isNotEmpty
          ? name
          : '${takenAt.year}/${takenAt.month}/${takenAt.day} '
              '${takenAt.hour.toString().padLeft(2, '0')}:'
              '${takenAt.minute.toString().padLeft(2, '0')}';

  static PhotoItem _ledgerPhotoToItem(WallPhoto w) => PhotoItem(
        id: w.id,
        lat: w.lat,
        lng: w.lng,
        takenAt: w.takenAt,
        file: w.file,
        thumb: w.thumb,
        name: w.name,
        kind: w.kind,
        durationMs: w.durationMs,
      );

  /// 本攻略归入的视频条数（水印模式需 ffmpeg 转码能力；原片模式原件直通无需）
  int get _videoCount {
    if (!_includePhotos) return 0;
    if (!_originalMode && !FFmpegRunner.available) return 0;
    return _ledgerVideos.length;
  }

  List<WallPhoto> _ledgerVideos = const <WallPhoto>[];

  /// 账本里归属本攻略的照片（kind 不是 video；guideId 绑定，文件在账本）
  List<WallPhoto> _ledgerPhotos = const <WallPhoto>[];

  /// 进入弹窗即预取账本归属媒体（读数据，失败按空计）
  @override
  void initState() {
    super.initState();
    _refreshLedgerMedia();
  }

  Future<void> _refreshLedgerMedia() async {
    if (!_includePhotos) {
      _ledgerVideos = const <WallPhoto>[];
      _ledgerPhotos = const <WallPhoto>[];
      if (mounted) setState(() {});
      return;
    }
    try {
      final ledger = await WallPhotoRepository(activeStorage).load();
      // 照片合成不依赖 ffmpeg；视频仅在原片模式（直通）或有转码能力时打包
      final allowVideos = _originalMode || FFmpegRunner.available;
      _ledgerVideos = [
        for (final w in ledger)
          if (w.isVideo &&
              allowVideos &&
              w.guideId == widget.guide.id &&
              w.file.isNotEmpty)
            w,
      ];
      _ledgerPhotos = [
        for (final w in ledger)
          if (!w.isVideo &&
              w.guideId == widget.guide.id &&
              w.file.isNotEmpty)
            w,
      ];
    } catch (_) {
      _ledgerVideos = const <WallPhoto>[];
      _ledgerPhotos = const <WallPhoto>[];
    }
    if (mounted) {
      setState(() {});
      if (_originalMode) {
        _refreshSize();
      }
    }
  }

  /// 原片模式实测体积（磁盘求和；失败 null → UI 显示「—」）
  Future<void> _refreshSize() async {
    if (!_originalMode || !_includePhotos) {
      _originalSizeBytes = null;
      if (mounted) setState(() {});
      return;
    }
    try {
      final service = ShareService(activeStorage);
      _originalSizeBytes = await service.estimateOriginalBytes(
        guide: widget.guide,
        videos: _ledgerVideos,
        extraPhotos: _extraPhotoItems,
        excludeIds: _excluded,
        includePhotos: _includePhotos,
      );
    } catch (_) {
      _originalSizeBytes = null;
    }
    if (mounted) setState(() {});
  }

  String _fmtBytes(int b) {
    final t = AppLocalizations.of(context);
    const mb = 1024 * 1024;
    const gb = 1024 * 1024 * 1024;
    if (b >= gb) return t.sizeGb((b / gb).toStringAsFixed(2));
    if (b >= mb) return t.estMb((b / mb).toStringAsFixed(1));
    return t.estKb('$b');
  }

  /// 估算分享文件体积
  String get _estimate {
    final t = AppLocalizations.of(context);
    final kb = _includePhotos
        ? (_packablePhotos.length * 142 +
            _ledgerVideos.length * 1536 +
            (widget.guide.coverImage != null ? 150 : 0) +
            8)
        : 8;
    return kb >= 1024 ? t.estMb((kb / 1024).toStringAsFixed(1)) : t.estKb('$kb');
  }

  Future<void> _run() async {
    final t = AppLocalizations.of(context);
    if (_originalMode) {
      // 原片模式：先实测体积，超限就给分流（剔除 / 降质），达标直接打包
      await _refreshLedgerMedia();
      final size =
          await ShareService(activeStorage).estimateOriginalBytes(
        guide: widget.guide,
        videos: _ledgerVideos,
        extraPhotos: _extraPhotoItems,
        excludeIds: _excluded,
        includePhotos: _includePhotos,
      );
      _originalSizeBytes = size;
      if (size > ShareService.originalCapBytes) {
        if (!mounted) return;
        final go = await _openTooBigFlow(size);
        if (go != true) return; // 取消 → 回选项页自行调整
        if (_degrade == ShareExportDegrade.none) {
          // 已剔除条目（或减少内容）→ 回选项页重估，再次达标由用户按打包
          setState(() => _phase = _Phase.options);
          await _refreshSize();
          return;
        }
      }
    }
    if (!mounted) return;
    final watermark =
        context.read<AppSettings>().shareWatermarkText;
    final service = ShareService(activeStorage);
    final ledgerVideos = _ledgerVideos;
    final extraPhotos = _extraPhotoItems;
    setState(() {
      _phase = _Phase.working;
      _cancelled = false;
      _done = 0;
      _label = t.preparing;
    });
    try {
      final result = await service.build(
        guide: widget.guide,
        includePhotos: _includePhotos,
        watermarkText: _originalMode ? '' : watermark,
        videos: ledgerVideos,
        policy: _originalMode
            ? ShareExportPolicy.original
            : ShareExportPolicy.watermarked,
        excludeIds: _excluded,
        degrade: _degrade,
        extraPhotos: extraPhotos,
        onProgress: (done, total, label) => setState(() {
          _done = done;
          _total = total;
          _label = label;
        }),
        isCancelled: () => _cancelled,
      );
      if (result == null) {
        setState(() => _phase = _Phase.options);
        return;
      }
      final path = await service.saveExported(result);
      // 原片模式：临时工作目录随文件搬移收口（目录内不留副本残留）
      if (result.tempPath != null) {
        final dir =
            result.tempPath!.substring(0, result.tempPath!.lastIndexOf('/'));
        await share_temp.deleteTempWorkDir(dir);
      }
      setState(() {
        _phase = _Phase.done;
        _resultPath = path;
      });
    } catch (e) {
      setState(() {
        _phase = _Phase.failed;
        _error = '$e';
      });
    }
  }

  /// 超限分流弹窗（返回 true = 已做出选择：剔除或选定降质档）
  Future<bool?> _openTooBigFlow(int sizeBytes) {
    final t = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFD32F2F), size: 22),
          const SizedBox(width: 8),
          Text(t.tooBigTitle, style: const TextStyle(fontSize: 16.5)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.tooBigMsg(_fmtBytes(sizeBytes)),
                style: const TextStyle(fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 10),
            Text(t.degradeNote,
                style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSoft,
                    height: 1.5)),
            const SizedBox(height: 10),
            StatefulBuilder(
              builder: (ctx2, setLocal) => RadioGroup<ShareExportDegrade>(
                groupValue: _degrade,
                onChanged: (v) =>
                    setLocal(() => _degrade = v ?? ShareExportDegrade.high),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<ShareExportDegrade>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: ShareExportDegrade.high,
                      title: Text(t.degradeHighLabel,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    RadioListTile<ShareExportDegrade>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: ShareExportDegrade.small,
                      title: Text(t.degradeSmallLabel,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () {
              _degrade = ShareExportDegrade.none;
              Navigator.of(ctx).pop(true); // 去筛选
            },
            child: Text(t.tooBigFilter),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.tooBigDegrade),
          ),
        ],
      ),
    );
  }

  /// 内容筛选（原片模式）：照片 + 视频逐条勾选；返回剔除集合更新后重估
  Future<void> _openFilter() async {
    final t = AppLocalizations.of(context);
    final entries = <({String id, String label, bool isVideo})>[
      for (final p in _packablePhotos)
        (
          id: p.id,
          label: _mediaLabel(p.name, p.takenAt),
          isVideo: false,
        ),
      for (final v in _ledgerVideos)
        (
          id: v.id,
          label: _mediaLabel(v.name, v.takenAt),
          isVideo: true,
        ),
    ];
    // 以局部可变集合驱动 StatefulBuilder
    final excluded = {..._excluded};
    final ok = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocal) => AlertDialog(
          title: Text(t.filterMediaTitle,
              style: const TextStyle(fontSize: 16.5)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.filterIncluded(
                    '${entries.length - excluded.length}',
                    '${entries.length}',
                  ),
                  style: TextStyle(
                      fontSize: 12, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      final included = !excluded.contains(e.id);
                      return CheckboxListTile(
                        value: included,
                        dense: true,
                        onChanged: (v) => setLocal(() {
                          v == true
                              ? excluded.remove(e.id)
                              : excluded.add(e.id);
                        }),
                        title: Text(e.label,
                            style: const TextStyle(fontSize: 13.5)),
                        subtitle: e.isVideo
                            ? Text(t.videoTypeGroup,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.inkSoft))
                            : null,
                        secondary: e.isVideo
                            ? const Icon(Icons.videocam_outlined, size: 18)
                            : const Icon(Icons.photo_outlined, size: 18),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(excluded),
              child: Text(t.btnSave),
            ),
          ],
        ),
      ),
    );
    if (ok == null) return;
    setState(() {
      _excluded
        ..clear()
        ..addAll(ok);
    });
    await _refreshSize();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: switch (_phase) {
          _Phase.options => _buildOptions(),
          _Phase.working => _buildWorking(t),
          _Phase.done => _buildDone(t),
          _Phase.failed => _buildFailed(t),
        },
      ),
    );
  }

  Widget _buildOptions() {
    final t = AppLocalizations.of(context);
    final g = widget.guide;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.shareExportTitle,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${t.exportStats('${g.markers.length}', '${_packablePhotos.length}', '$_videoCount', '${g.clusters.length}')}\n'
            '${_originalMode
                ? (_originalSizeBytes != null
                    ? t.estOriginalCap(_fmtBytes(_originalSizeBytes!))
                    : t.estOriginalCap('—'))
                : t.estTotal(_estimate)}',
            style: const TextStyle(fontSize: 12.5, height: 1.7),
          ),
        ),
        const SizedBox(height: 10),
        // 打包模式分支
        Text(t.shareModeLabel,
            style:
                TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.branding_watermark, size: 18),
              label: Text(t.modeWatermarked,
                  style: const TextStyle(fontSize: 13)),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(t.modeOriginal,
                  style: const TextStyle(fontSize: 13)),
              enabled: _originalAvailable,
            ),
          ],
          selected: {_originalMode},
          onSelectionChanged: (sel) {
            final orig = sel.first;
            if (orig == _originalMode) return;
            setState(() {
              _originalMode = orig;
              if (!orig) {
                _degrade = ShareExportDegrade.none;
                _excluded.clear();
                _originalSizeBytes = null;
              }
            });
            _refreshLedgerMedia().then((_) {
              if (_originalMode && mounted) _refreshSize();
            });
          },
        ),
        const SizedBox(height: 4),
        Text(
          _originalMode
              ? (_originalAvailable
                  ? t.modeOriginalDesc
                  : t.webOriginalUnsupported)
              : t.modeWatermarkedDesc,
          style: TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.5),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(t.includePhotosTitle,
              style: TextStyle(fontSize: 13.5)),
          subtitle: Text(
            _includePhotos
                ? (_originalMode
                    ? t.originalVideosNote
                    : '${t.wmFromSettings}${_videoCount > 0 ? t.videoTransTail : ''}')
                : t.noPhotosDesc,
            style: const TextStyle(fontSize: 11.5),
          ),
          value: _includePhotos,
          onChanged: (v) {
            setState(() {
              _includePhotos = v ?? true;
              if (_originalMode) {
                _excluded.clear();
                _originalSizeBytes = null;
                _degrade = ShareExportDegrade.none;
              }
            });
            _refreshLedgerMedia().then((_) {
              if (_originalMode && mounted) _refreshSize();
            });
          },
        ),
        if (_originalMode && _includePhotos) ...[
          TextButton.icon(
            icon: const Icon(Icons.checklist, size: 18),
            label: Text(
              _excluded.isEmpty
                  ? t.filterMediaBtn
                  : t.filterMediaBtnOn('${_excluded.length}'),
              style: const TextStyle(fontSize: 13),
            ),
            onPressed: _openFilter,
          ),
        ],
        if (_originalMode &&
            _includePhotos &&
            _degrade != ShareExportDegrade.none) ...[
          Text(
            t.degradeApplied(
              _degrade == ShareExportDegrade.high
                  ? t.degradeHighLabel
                  : t.degradeSmallLabel,
            ),
            style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          _originalMode
              ? t.receiverNoteOriginal
              : t.receiverNote,
          style: TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.6),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text(t.genBtn),
            onPressed: _run,
          ),
        ),
      ],
    );
  }

  Widget _buildWorking(AppLocalizations t) {
    final ratio = _total > 0 ? _done / _total : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.workingTitle,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: ratio),
        const SizedBox(height: 10),
        Text(t.progressLine('$_done', '$_total', _label),
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _cancelled = true,
            child: Text(t.cancel),
          ),
        ),
      ],
    );
  }

  Widget _buildDone(AppLocalizations t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 22),
          const SizedBox(width: 8),
          Text(t.doneTitle,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_resultPath,
              style: const TextStyle(fontSize: 12, height: 1.5)),
        ),
        const SizedBox(height: 8),
        Text(
          _originalMode ? t.doneNoteOriginal : t.doneNote,
          style:
              TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.6),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.btnFinish),
          ),
        ),
      ],
    );
  }

  Widget _buildFailed(AppLocalizations t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          Text(t.failedTitle,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Text(_error,
            style: const TextStyle(fontSize: 12, height: 1.5)),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(() => _phase = _Phase.options),
            child: Text(t.retryBtn),
          ),
        ),
      ],
    );
  }
}
