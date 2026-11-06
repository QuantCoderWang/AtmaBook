import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../state/guides_provider.dart';
import '../../state/settings_provider.dart';
import 'categories_card.dart';

/// 设置页：语言 / 标记样式 / 默认地图源 / 片区聚类参数 / 分类管理 / 自定义图标 / 关于
/// 文字在 ARB 词典（默认中文、可切 English）
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(t.navTitleSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _header(t.secLanguage),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<AppLanguage>(
                    segments: [
                      ButtonSegment(
                        value: AppLanguage.zh,
                        label: Text(t.langChinese,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: AppLanguage.en,
                        label: Text(t.langEnglish,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: AppLanguage.system,
                        label: Text(t.langSystem,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {settings.language},
                    onSelectionChanged: (s) =>
                        context.read<AppSettings>().setLanguage(s.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                        visualDensity: VisualDensity.compact),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.languageHint,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                        height: 1.5),
                  ),
                ],
              ),
            ),
          ),

          _header(t.secPinStyle),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<PinDisplayMode>(
                    segments: [
                      ButtonSegment(
                        value: PinDisplayMode.icons,
                        icon: const Icon(Icons.push_pin, size: 16),
                        label: Text(t.settingsPinModeIconsLabel,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: PinDisplayMode.colored,
                        icon: const Icon(Icons.fiber_pin, size: 16),
                        label: Text(t.settingsPinModeColoredLabel,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {settings.pinMode},
                    onSelectionChanged: (s) =>
                        settings.setPinMode(s.first),
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.pinMode == PinDisplayMode.icons
                        ? t.pinHintIcons
                        : t.pinHintColored,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.inkSoft, height: 1.5),
                  ),
                ],
              ),
            ),
          ),

          _header(t.secMapSource),
          Card(
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_city,
                      size: 20, color: AppColors.primary),
                  title: Text(t.mapHomeTitle,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: Text(t.mapHomeSub,
                      style: const TextStyle(fontSize: 10.5)),
                ),
                const Divider(indent: 16),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.public,
                      size: 20, color: AppColors.primary),
                  title: Text(t.mapAbroadTitle,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: Text(t.mapAbroadSub,
                      style: const TextStyle(fontSize: 10.5)),
                ),
              ],
            ),
          ),
          _FootNote(t.mapSourceFoot),

          _header(t.secZone),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(t.zoneRadiusLabel,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${settings.clusterRadiusKm.round()} km',
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                    ],
                  ),
                  Slider(
                    value: settings.clusterRadiusKm,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '${settings.clusterRadiusKm.round()} km',
                    activeColor: AppColors.primary,
                    onChanged: (v) => settings.setClusterRadiusKm(v),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.zoneMinPtsLabel,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
                      ),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 2, label: Text('2')),
                          ButtonSegment(value: 3, label: Text('3')),
                          ButtonSegment(value: 4, label: Text('4')),
                        ],
                        selected: {settings.clusterMinPoints},
                        onSelectionChanged: (s) =>
                            settings.setClusterMinPoints(s.first),
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                            visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.zoneHint,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                        height: 1.6),
                  ),
                ],
              ),
            ),
          ),

          _header(t.secShare),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: settings.shareWatermarkText,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: t.watermarkLabel,
                      hintText: t.watermarkHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => settings.setShareWatermarkText(v),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.watermarkHintText,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.inkSoft, height: 1.6),
                  ),
                ],
              ),
            ),
          ),

          _header(t.secKeys),
          const _KeyCard(),
          _FootNote(t.keysFoot),

          _header(t.secCategories),
          const CategoriesCard(),

          _header(t.secDanger),
          Card(
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.playlist_remove, color: Colors.red),
              title: Text(t.clearAllTitle,
                  style: const TextStyle(
                      fontSize: 13.5, color: Colors.red)),
              subtitle: Text(t.clearAllSub,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.inkSoft)),
              onTap: _confirmClearGuides,
            ),
          ),

          _header(t.secAbout),
          Card(
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.tag, size: 20),
                  title: Text(t.aboutVersion('1.1.0'),
                      style: const TextStyle(fontSize: 13)),
                ),
                const Divider(indent: 16),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.lock_outline, size: 20),
                  title: Text(t.aboutLocalOnly,
                      style: const TextStyle(fontSize: 13)),
                ),
                const Divider(indent: 16),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.copyright, size: 20),
                  title: Text(t.aboutMapSources,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(t.aboutMapSourcesSub,
                      style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 一键清空确认：明确不可恢复提示后执行 removeAll
  Future<void> _confirmClearGuides() async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.clearAllDialogTitle),
        content: Text(t.clearAllDialogContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.confirmClear),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final n = context.read<GuidesProvider>().guides.length;
    await context.read<GuidesProvider>().removeAll();
    if (!mounted) return;
    _snack(AppLocalizations.of(context).clearedToast(n));
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.inkSoft)),
      );
}

class _FootNote extends StatelessWidget {
  const _FootNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 11, color: AppColors.inkSoft, height: 1.6),
      ),
    );
  }
}

/// 服务密钥输入卡：高德 Web Key / 天地图 tk（输入即存偏好设置）
class _KeyCard extends StatefulWidget {
  const _KeyCard();

  @override
  State<_KeyCard> createState() => _KeyCardState();
}

class _KeyCardState extends State<_KeyCard> {
  late final TextEditingController _amap;
  late final TextEditingController _tdt;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppSettings>();
    _amap = TextEditingController(text: s.amapKey);
    _tdt = TextEditingController(text: s.tiandituKey);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _amap.dispose();
    _tdt.dispose();
    super.dispose();
  }

  /// 输入防抖 800ms 后保存，避免每次按键刷盘与通知
  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      context.read<AppSettings>()
        ..setAmapKey(_amap.text)
        ..setTiandituKey(_tdt.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.amapKeyLabel,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _amap,
              obscureText: true,
              onChanged: (_) => _debouncedSave(),
              decoration: InputDecoration(
                isDense: true,
                hintText: t.amapKeyHint,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 12),
            Text(t.tdtKeyLabel,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _tdt,
              obscureText: true,
              onChanged: (_) => _debouncedSave(),
              decoration: InputDecoration(
                isDense: true,
                hintText: t.tdtKeyHint,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
