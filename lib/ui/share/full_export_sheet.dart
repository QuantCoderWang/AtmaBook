import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/io/storage_adapter.dart';
import '../../data/models/guide.dart';
import '../../data/models/wall_photo.dart';
import '../../data/repos/wall_photo_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/share_bundle_service.dart';
import '../../services/share_service.dart';
import '../../state/guides_provider.dart';

/// 全量导出弹窗：攻略本全体攻略逐个按原片模式打包成**单个** `.tgbundle`
/// 大包（迁移文件 / 多设备共享用）。
/// - 概览（攻略篇数 + 口径说明）→ 进度（k/n 篇 + 当前标题，可取消）→ 完成路径；
/// - 不限制总体积（1 GB 上限仅作用于单包分享），Web 不可用（无文件系统）；
/// - 内容 = 封面 + 标记插图 + 攻略内照片 + 账本归属照片/视频（全部原画质直通）。
Future<void> openFullExportSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => const _FullExportSheet(),
  );
}

enum _Phase { intro, working, done, failed }

class _FullExportSheet extends StatefulWidget {
  const _FullExportSheet();

  @override
  State<_FullExportSheet> createState() => _FullExportSheetState();
}

class _FullExportSheetState extends State<_FullExportSheet> {
  _Phase _phase = _Phase.intro;

  int _done = 0;
  int _total = 0;
  String _label = '';
  String _resultPath = '';
  int _resultBytes = 0;
  String _error = '';
  bool _cancelled = false;

  bool get _originalAvailable => !kIsWeb;

  String _fmtBytes(int b) {
    final t = AppLocalizations.of(context);
    const mb = 1024 * 1024;
    const gb = 1024 * 1024 * 1024;
    if (b >= gb) return t.sizeGb((b / gb).toStringAsFixed(2));
    if (b >= mb) return t.estMb((b / mb).toStringAsFixed(1));
    return t.estKb('$b');
  }

  /// 统计含媒体（照片/视频）的攻略篇数（概览提示用）
  Future<int> _boundCount(List<Guide> guides) async {
    try {
      final ledger = await WallPhotoRepository(activeStorage).load();
      return guides.where((g) =>
              ShareBundleService.extraPhotosFor(ledger, g).isNotEmpty ||
              ShareBundleService.boundVideos(ledger, g.id).isNotEmpty)
          .length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _run() async {
    final t = AppLocalizations.of(context);
    final guides = context.read<GuidesProvider>().guides;
    if (guides.isEmpty) {
      setState(() => _phase = _Phase.failed);
      return;
    }
    setState(() {
      _phase = _Phase.working;
      _cancelled = false;
      _done = 0;
      _total = guides.length;
      _label = t.bundlePreparing;
    });
    String resultPath = '';
    int resultBytes = 0;
    String error = '';
    try {
      // 一次读入，逐篇拆分归属媒体（读取失败按空账本——攻略内照片照常）
      List<WallPhoto> ledger = const <WallPhoto>[];
      try {
        ledger = await WallPhotoRepository(activeStorage).load();
      } catch (_) {}
      final service = ShareBundleService(activeStorage);
      final result = await service.buildAll(
        guides: guides,
        ledger: ledger,
        onProgress: (done, total, title) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
            _label = t.bundlePacking('$done', '$total', title);
          });
        },
        isCancelled: () => _cancelled,
      );
      if (result == null) {
        // 用户取消（中途）——关弹窗即可
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return;
      }
      resultPath = await ShareService(activeStorage).saveExported(result);
      resultBytes = result.sizeBytes;
    } catch (e, st) {
      debugPrint('[tg-bundle] export FAILURE: $e\n$st');
      error = '$e';
    }
    if (!mounted) return;
    setState(() {
      if (error.isEmpty) {
        _phase = _Phase.done;
        _resultPath = resultPath;
        _resultBytes = resultBytes;
      } else {
        _phase = _Phase.failed;
        _error = error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final guides = context.watch<GuidesProvider>().guides;

    Widget body;
    switch (_phase) {
      case _Phase.intro:
        body = _buildIntro(t, guides);
      case _Phase.working:
        body = _buildWorking(t);
      case _Phase.done:
        body = _buildDone(t);
      case _Phase.failed:
        body = _buildFailed(t);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.bundleTitle,
            style: const TextStyle(
                fontSize: 17.5, fontWeight: FontWeight.bold, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            t.bundleSubtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          const Divider(height: 24),
          if (!_originalAvailable) ...[
            Text(t.webBundleUnsupported,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.inkSoft)),
            const SizedBox(height: 16),
          ],
          body,
        ],
      ),
    );
  }

  Widget _buildIntro(AppLocalizations t, List<Guide> guides) {
    final futureBound = _boundCount(guides);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.bundleIntroCount('${guides.length}'),
          style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        Text(
            _originalAvailable
                ? t.bundleIntroNote
                : t.webBundleUnsupported,
            style: const TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.inkSoft)),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: (!_originalAvailable || guides.isEmpty)
              ? null
              : _run,
          child: Text(t.bundleBtnStart),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        // （媒体提示：异步补充，不阻塞首帧）
        FutureBuilder<int>(
          future: futureBound,
          builder: (_, snap) {
            final n = snap.data ?? 0;
            if (n == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t.bundleLedgerHint('$n'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.inkSoft)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWorking(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
              value: _total > 0 ? _done / _total : null),
          const SizedBox(height: 12),
          Text(
            _label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _cancelled = true),
              child: Text(t.importCancelling),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.bundleDoneTitle,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
        ),
        const SizedBox(height: 10),
        Text(
          t.bundleDoneDetail(_resultPath, _fmtBytes(_resultBytes)),
          style: const TextStyle(fontSize: 12, height: 1.55, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.btnOk),
        ),
      ],
    );
  }

  Widget _buildFailed(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _error.isEmpty ? t.bundleFailedEmpty : t.bundleFailedTitle,
          style: const TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.ink),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _error,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.btnOk),
        ),
      ],
    );
  }
}
