import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/io/storage_adapter.dart';
import '../widgets/tooltip_barrier.dart';
import '../../core/theme.dart';
import '../../data/models/guide.dart';
import '../../data/models/map_source.dart' show GuideRegion;
import '../../l10n/app_localizations.dart';
import '../../services/share_bundle_service.dart';
import '../../services/share_service.dart';
import '../../state/guide_editor.dart';
import '../../state/guides_provider.dart';
import '../guide/guide_info_edit_sheet.dart';
import '../guide/guide_map_page.dart';
import '../photos/photo_wall_gallery_page.dart';
import '../settings/settings_page.dart';
import '../share/full_export_sheet.dart';
import '../tiles/tiles_page.dart';
import 'create_guide_dialog.dart';

/// 攻略笔记本首页：
/// - 空白态 / 攻略卡片（网格与列表两种排布，☰ 菜单一键切换）
/// - 顶部搜索栏（按标题与简介过滤）+ ☰ 功能菜单抽屉
/// - 长按菜单（打开 / 重命名 / 删除）
/// - AppBar 快捷图标：搜索 / 地理相册 / ☰ 菜单
/// - ⋮ 导入分享攻略与全量导出（从 ☰ 菜单进入）。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _gridMode = true;
  bool _searchOpen = false;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _createGuide() async {
    final created = await showDialog<Guide>(
      context: context,
      builder: (_) => const CreateGuideDialog(),
    );
    if (created == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GuideMapPage(guide: created)),
    );
  }

  void _toggleSearch() {
    setState(() {
      if (_searchOpen) {
        _searchOpen = false;
        _searchCtrl.clear();
        _query = '';
      } else {
        _searchOpen = true;
      }
    });
  }

  /// ☰ 功能菜单抽屉：首页动作收口——排布切换 / 离线地图 / 全量导出 /
  /// 导入分享攻略 / 设置；头部带数据目录提示（诊断友好）。
  /// （地理相册自迁出到 AppBar 独立图标按钮）
  Widget _buildMenuDrawer() {
    final t = AppLocalizations.of(context);

    Widget tile({
      required IconData icon,
      required String title,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(icon, size: 21, color: AppColors.ink),
          title: Text(title, style: const TextStyle(fontSize: 14)),
          onTap: onTap,
        ),
      );
    }

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Builder(builder: (context) {
                // 存储未初始化（单测/降级）时不得炸 UI
                String dirLabel = t.dirUnavailable;
                try {
                  dirLabel = activeStorage.locationLabel;
                } catch (_) {}
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    TooltipBarrier(
                      child: Tooltip(
                        message: dirLabel,
                        child: Text(
                          t.menuDirLabel(dirLabel),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10.5, color: AppColors.inkSoft),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            tile(
              icon: _gridMode
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
              title: _gridMode ? t.menuToggleListView : t.menuToggleGridView,
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _gridMode = !_gridMode);
              },
            ),
            tile(
              icon: Icons.map_outlined,
              title: t.menuOfflineMap,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TilesPage()),
                );
              },
            ),
            tile(
              icon: Icons.inventory_2_outlined,
              title: t.menuExportAll,
              onTap: () {
                Navigator.of(context).pop();
                openFullExportSheet(context);
              },
            ),
            tile(
              icon: Icons.download,
              title: t.menuLoadShare,
              onTap: () {
                Navigator.of(context).pop();
                _importShare();
              },
            ),
            tile(
              icon: Icons.settings_outlined,
              title: t.menuSettings,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 导入分享攻略：选文件 → 后台解包校验 → 指纹查重 → 分阶段重映射落盘 → 入库。
  /// 弹窗为「阶段文字 + 进度条 + 可取消」；加载框在任何跳转前先关闭
  Future<void> _importShare() async {
    final t = AppLocalizations.of(context);
    final provider = context.read<GuidesProvider>();
    final group = XTypeGroup(
        label: t.shareFileTypeLabel,
        // 新增功能，使用.tgbundle文件，全量导出大包（单个外层容器，内含若干子文件 .tgshare）
        extensions: ['tgshare', 'zip', 'tgbundle'],
        // iOS 按 UTI 过滤（extensions 在 iOS 不生效；.tgshare 同为 zip 容器）
        uniformTypeIdentifiers: const <String>['public.zip-archive']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    // 进度镜像：ValueNotifier 驱动弹窗，无需重建整个页面
    final progressLabel = ValueNotifier<String>(t.importUnpacking);
    final progressValue = ValueNotifier<double?>(null); // null = 不确定进度
    final cancelFlag = ValueNotifier<bool>(false);
    final messenger = ScaffoldMessenger.of(context);
    final rootNav = Navigator.of(context, rootNavigator: true);

    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.importProgressTitle,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<double?>(
                  valueListenable: progressValue,
                  builder: (_, v, _) => v == null
                      ? const LinearProgressIndicator()
                      : LinearProgressIndicator(value: v.clamp(0.0, 1.0)),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<String>(
                  valueListenable: progressLabel,
                  builder: (_, label, _) => Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: cancelFlag,
                    builder: (_, cancelled, _) => TextButton(
                      onPressed:
                          cancelled ? null : () => cancelFlag.value = true,
                      child: Text(cancelled ? t.importCancelling : t.cancel),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));

    Guide? guideToShow;
    String? failure;
    String? bundleSummary;
    try {
      debugPrint(
          '[tg-import] file=${file.name} ${bytes.length ~/ 1024}KB');
      // .tgbundle 全量包分流——不限体积（1GB 上限仅单攻略包口径），
      // 逐条流式导入（同一时刻只驻留一个内层包），指纹查重自动跳过。
      if (file.name.toLowerCase().endsWith('.tgbundle')) {
        progressLabel.value = t.importBundleProg;
        progressValue.value = null;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final report =
            await ShareBundleService(activeStorage).importAll(
          absPath: file.path,
          onGuide: (parsed) async {
            if (cancelFlag.value) return ShareBundleGuideResult.cancelled;
            progressLabel.value = t.importBundleItem(parsed.guide.title);
            if (parsed.fingerprint.isNotEmpty &&
                provider.hasShareKey(parsed.fingerprint)) {
              debugPrint('[tg-bundle] dedupe-skip ${parsed.guide.title}');
              return ShareBundleGuideResult.skipped;
            }
            final imported = await ShareService(activeStorage).applyImport(
              parsed,
              onProgress: (done, total, label) {
                progressLabel.value = label;
                progressValue.value = total > 0 ? done / total : null;
              },
              isCancelled: () => cancelFlag.value,
            );
            if (imported == null) return ShareBundleGuideResult.cancelled;
            await provider.addImported(
              imported.guide,
              coverBytes: imported.coverBytes,
            );
            debugPrint('[tg-bundle] applied ${imported.guide.id}');
            return ShareBundleGuideResult.applied;
          },
        );
        if (report == null) {
          failure = t.importBundleInvalid;
        } else if (report.applied > 0) {
          bundleSummary =
              t.importBundleReport('${report.applied}', '${report.skipped}',
                  '${report.failed}');
        } else if (report.cancelled) {
          failure = t.importCancelled;
        } else if (report.failed > 0) {
          failure =
              t.importBundleReport('0', '${report.skipped}',
                  '${report.failed}');
        } else {
          failure = t.importCancelled;
        }
      } else if (bytes.length > ShareService.originalCapBytes) {
        failure = t.importTooLarge;
      } else {
        // 解包校验（同步路径，与此前验证可行的行为一致；先让弹窗绘出一帧）
        progressLabel.value = t.importUnpacking;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final parsed = ShareService.parseShare(bytes);
        debugPrint('[tg-import] parse=${parsed != null} '
            'fp=${parsed?.fingerprint} mk=${parsed?.guide.markers.length} '
            'ph=${parsed?.guide.photos.length}');
        if (parsed == null) {
          failure = t.importInvalidFile;
        } else if (cancelFlag.value) {
          failure = t.importCancelled;
        } else {
          // 指纹查重：命中才询问；未命中直接导入（默认执行，不要默认跳过）
          bool proceed = true;
          if (parsed.fingerprint.isNotEmpty &&
              provider.hasShareKey(parsed.fingerprint)) {
            if (!mounted) return;
            progressLabel.value = t.importAwaitingConfirm;
            final again = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(t.importedBeforeTitle),
                content: Text(t.importedBeforeContent(parsed.guide.title)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(t.cancel)),
                  FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(t.btnImportAgain)),
                ],
              ),
            );
            if (again != true) proceed = false;
          }
          if (cancelFlag.value) proceed = false;
          if (!proceed) {
            failure = t.importCancelled;
          } else {
            debugPrint('[tg-import] dedupe-proceed=true, applying…');
            progressLabel.value = t.importRemapping;
            progressValue.value = 0.0;
            final imported = await ShareService(activeStorage).applyImport(
              parsed,
              onProgress: (done, total, label) {
                debugPrint('[tg-import] step $done/$total $label');
                progressLabel.value = label;
                progressValue.value =
                    total > 0 ? done / total : null;
              },
              isCancelled: () => cancelFlag.value,
            );
            debugPrint('[tg-import] apply=${imported != null}');
            if (imported == null) {
              failure = t.importCancelled;
            } else {
              await provider.addImported(
                imported.guide,
                coverBytes: imported.coverBytes,
              );
              debugPrint('[tg-import] addImported ok id=${imported.guide.id}');
              guideToShow = imported.guide;
            }
          }
        }
      }
    } catch (e, st) {
      debugPrint('[tg-import] FAILURE: $e\n$st');
      failure = '$e';
    }

    // —— 先关加载框，再处理结果 ——
    rootNav.pop();
    if (failure != null) {
      failure = failure.startsWith(t.importFailedPrefix)
          ? failure
          : '${t.importFailedPrefix}$failure';
      if (mounted) {
        final t2 = AppLocalizations.of(context);
        unawaited(showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t2.importFailedTitle),
            content: SingleChildScrollView(
              child: SelectableText(failure!,
                  style: const TextStyle(fontSize: 12.5, height: 1.5)),
            ),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(t2.btnOk)),
            ],
          ),
        ));
      }
    } else if (bundleSummary != null) {
      messenger.showSnackBar(SnackBar(content: Text(bundleSummary)));
    } else if (guideToShow != null) {
      if (mounted) {
        final t2 = AppLocalizations.of(context);
        messenger.showSnackBar(SnackBar(
            content: Text(t2.importedToast(
                '${guideToShow.title}${t2.sharedSuffix}'))));
      }
      final toOpen = guideToShow;
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GuideMapPage(guide: toOpen)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final provider = context.watch<GuidesProvider>();
    final all = provider.guides;
    final q = _query.trim().toLowerCase();
    final guides = q.isEmpty
        ? all
        : all
            .where((g) =>
                g.title.toLowerCase().contains(q) ||
                g.summary.toLowerCase().contains(q))
            .toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      endDrawer: _buildMenuDrawer(),
      appBar: AppBar(
        title: _searchOpen
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  hintText: AppLocalizations.of(context).homeSearchHint,
                  prefixIcon:
                      const Icon(Icons.search, size: 18, color: AppColors.inkSoft),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _toggleSearch,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('AtmaBook'),
        actions: [
          TooltipBarrier(
            child: IconButton(
              tooltip: _searchOpen ? t.tooltipCloseSearch : t.tooltipSearch,
              icon: Icon(_searchOpen ? Icons.search_off : Icons.search),
              onPressed: _toggleSearch,
            ),
          ),
          TooltipBarrier(
            child: IconButton(
              tooltip: t.menuGallery,
              icon: const Icon(Icons.photo_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PhotoWallGalleryPage()),
              ),
            ),
          ),
          TooltipBarrier(
            child: IconButton(
              tooltip: t.tooltipMenu,
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ),
        ],
      ),
      floatingActionButton: _searchOpen
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(t.fabNew),
              onPressed: _createGuide,
            ),
      body: all.isEmpty
          ? const _EmptyHome(onCreate: null)
          : guides.isEmpty
              ? _NoResult(query: _query)
              : _gridMode
                  ? LayoutBuilder(
                      builder: (context, c) {
                        // 响应式网格（桌面/平板适配）：
                        // - 窄屏（<720px，手机）维持原 2 列、比例 0.74 不变；
                        // - 大屏（≥720px，桌面 16:9 全屏 / 平板横屏）4 列，
                        //   行高按视口可用高度均分为「最多 2 行」——
                        //   一屏至多 8 篇，单卡更大更易读。
                        final wide = c.maxWidth >= 720;
                        final cols = wide ? 4 : 2;
                        double aspect = 0.74;
                        if (wide) {
                          const pad = 16.0, gap = 14.0;
                          final cardW =
                              (c.maxWidth - pad * 2 - gap * (cols - 1)) /
                                  cols;
                          final cardH = (c.maxHeight - 4 - 96 - gap) / 2;
                          // 极矮高度兜底：行高不小于 220（封面区不至被压没）
                          aspect = cardW / (cardH < 220 ? 220 : cardH);
                        }
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: aspect,
                          ),
                          itemCount: guides.length,
                          itemBuilder: (context, i) =>
                              _GuideCard(guide: guides[i], seed: i),
                        );
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: guides.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          _ListGuideCard(guide: guides[i], seed: i),
                    ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_stories, size: 88, color: Color(0xFFD9CFBF)),
          const SizedBox(height: 20),
          Text(t.homeEmptyTitle,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(t.homeEmptyHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, height: 1.6)),
          if (onCreate != null) ...[
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(t.fabNew),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoResult extends StatelessWidget {
  const _NoResult({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 64, color: Color(0xFFD9CFBF)),
          const SizedBox(height: 14),
          Text(t.homeNoResult(query),
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
        ],
      ),
    );
  }
}

/// 封面右下角「分享」角标（分享攻略识别标注）
class _ShareBadge extends StatelessWidget {
  const _ShareBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 3 : 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
      ),
      child: Icon(Icons.ios_share,
          size: compact ? 10 : 13, color: Colors.white),
    );
  }
}

/// 网格模式卡片
class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide, required this.seed});

  final Guide guide;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final gradient = coverGradient(seed);
    final cover = context.watch<GuidesProvider>().coverPreview(guide.id);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context, guide),
        onLongPress: () => _openMenu(context, guide),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover != null) ...[
                      Image.memory(
                        cover,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                      // 有封面时统计 chips 此前整段缺失——
                      // 现底部加横向渐变纱统一渲染（保证白字 chips 可读）
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.45),
                              ],
                              stops: const [0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ] else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradient,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: 10,
                              bottom: 8,
                              child: Icon(Icons.route,
                                  size: 64,
                                  color: Colors.white
                                      .withValues(alpha: 0.18)),
                            ),
                          ],
                        ),
                      ),
                    // 统计 chips：两分支统一（无封面=渐变卡 / 有封面=照片+纱）
                    Positioned(
                      left: 10,
                      bottom: 8,
                      child: _CardStats(guide: guide),
                    ),
                    if (guide.shared)
                      const Positioned(
                        right: 8,
                        bottom: 8,
                        child: _ShareBadge(),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guide.shared
                        ? '${guide.title}${t.sharedSuffix}'
                        : guide.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    guide.summary.isEmpty
                        ? t.noSummaryParen
                        : guide.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_fmt(guide.updatedAt)} · ${_regionLabel(t, guide)}',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.inkSoft),
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

/// 列表模式卡片（横排）
class _ListGuideCard extends StatelessWidget {
  const _ListGuideCard({required this.guide, required this.seed});

  final Guide guide;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context, guide),
        onLongPress: () => _openMenu(context, guide),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: coverGradient(seed),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (context.watch<GuidesProvider>().coverPreview(guide.id) !=
                        null)
                      Image.memory(
                        context.read<GuidesProvider>().coverPreview(guide.id)!,
                        fit: BoxFit.cover,
                      )
                    else
                      Icon(Icons.photo_outlined,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 24),
                    if (guide.shared)
                      const Positioned(
                        right: 2,
                        bottom: 2,
                        child: _ShareBadge(compact: true),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guide.shared
                          ? '${guide.title}${t.sharedSuffix}'
                          : guide.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      guide.summary.isEmpty
                          ? t.noSummaryParen
                          : guide.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          '${t.placesUnit(guide.markers.length)} · ${t.mustVisitBadge(guide.mustVisitCount)} · ${_fmt(guide.updatedAt)} · ${_regionLabel(t, guide)}',
                          style: const TextStyle(
                              fontSize: 10.5, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

// —— 两种卡片共用逻辑 ——
void _open(BuildContext context, Guide guide) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GuideMapPage(guide: guide),
    ));

void _openMenu(BuildContext context, Guide guide) {
  final t = AppLocalizations.of(context);
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(t.guideActionOpenMap),
            onTap: () => Navigator.pop(sheetCtx),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(t.guideActionInfo),
            onTap: () {
              Navigator.pop(sheetCtx);
              _openInfoSheet(context, guide);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(t.guideActionDelete,
                style: const TextStyle(color: Colors.red)),
            onTap: () => _confirmDelete(context, guide),
          ),
        ],
      ),
    ),
  );
}

void _openInfoSheet(BuildContext context, Guide guide) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => GuideInfoEditSheet(editor: GuideEditor(guide)),
  );
}

void _confirmDelete(BuildContext context, Guide guide) {
  final t = AppLocalizations.of(context);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.deleteGuideTitle),
      content: Text(t.deleteGuideContent(guide.title)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            Navigator.pop(ctx);
            _doDelete(context, guide);
          },
          child: Text(t.btnDelete),
        ),
      ],
    ),
  );
}

Future<void> _doDelete(BuildContext context, Guide guide) async {
  final t = AppLocalizations.of(context);
  await context.read<GuidesProvider>().remove(guide.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.deletedToast(guide.title))));
  }
}

String _regionLabel(AppLocalizations t, Guide guide) =>
    guide.region == GuideRegion.china ? t.regionDomestic : t.regionAbroad;

String _fmt(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// 首页大卡统计 chips ：地点数 + 必去数，
/// 渐变兜底卡与封面照片卡两分支统一渲染
class _CardStats extends StatelessWidget {
  const _CardStats({required this.guide});

  final Guide guide;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        _GlassChip(icon: Icons.place, label: t.placesUnit(guide.markers.length)),
        const SizedBox(width: 6),
        _GlassChip(
          icon: Icons.star,
          label: t.mustVisitBadge(guide.mustVisitCount),
          color: AppColors.accent,
        ),
      ],
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}
