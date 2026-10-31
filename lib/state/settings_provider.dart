import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// 界面语言：默认中文；
/// 跟随系统在读出非中英语言时回退中文（见 resolveUiLocale）。
enum AppLanguage { system, zh, en }

/// 全局设置（持久化到 shared_preferences）：
/// 标记样式 / 语言 / 片区聚类参数 / 服务密钥（高德检索 Key、天地图 tk，均选配）
class AppSettings extends ChangeNotifier {
  final SharedPreferences? _prefs;

  AppSettings._(this._prefs);

  factory AppSettings({SharedPreferences? prefs}) => AppSettings._(prefs);

  static const _kPinMode = 'tg.pinMode';
  static const _kRadiusKm = 'tg.clusterRadiusKm';
  static const _kMinPts = 'tg.clusterMinPoints';
  static const _kAmapKey = 'tg.amapKey';
  static const _kTdtKey = 'tg.tianditu.tk';
  static const _kShareWatermark = 'tg.share.watermark';
  static const _kLanguage = 'tg.language';
  static const _kCategories = 'tg.markerCategories'; // 分类管理

  /// 标记显示规则：图标式 Pin（默认） / 彩色大头针
  PinDisplayMode pinMode = PinDisplayMode.icons;

  /// 界面语言：默认**中文**（跟随系统为可选项，非中英系统语言回退中文）
  AppLanguage language = AppLanguage.zh;

  /// 片区参数（默认 5km / 最少 2 点）
  double clusterRadiusKm = AppDefaults.clusterRadiusMeters / 1000;
  int clusterMinPoints = AppDefaults.clusterMinPoints;

  /// 高德 Web 服务 Key（境内地点检索优先使用，选配）
  String amapKey = '';

  /// 天地图 tk（天地图瓦片源需要，选配）
  String tiandituKey = '';

  /// 分享导出的图片水印文字（默认「分享照片」；空串回落默认值）
  String shareWatermarkText = '分享照片';

  /// 启动时从偏好设置恢复
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppSettings(prefs: prefs);
    s.pinMode = PinDisplayMode.values.firstWhere(
        (e) => e.name == prefs.getString(_kPinMode),
        orElse: () => PinDisplayMode.icons);
    s.language = AppLanguage.values.firstWhere(
        (e) => e.name == prefs.getString(_kLanguage),
        orElse: () => AppLanguage.zh);
    final r = prefs.getDouble(_kRadiusKm);
    s.clusterRadiusKm =
        (r != null && r >= 1 && r <= 20) ? r : AppDefaults.clusterRadiusMeters / 1000;
    s.clusterMinPoints =
        prefs.getInt(_kMinPts) ?? AppDefaults.clusterMinPoints;
    s.amapKey = prefs.getString(_kAmapKey) ?? '';
    s.tiandituKey = prefs.getString(_kTdtKey) ?? '';
    s.shareWatermarkText =
        prefs.getString(_kShareWatermark) ?? '分享照片';
    restoreCategories(prefs.getString(_kCategories)); // 分类管理恢复
    return s;
  }

  void _save(String key, Object value) {
    final p = _prefs;
    if (p == null) return;
    if (value is String) {
      p.setString(key, value);
    } else if (value is double) {
      p.setDouble(key, value);
    } else if (value is int) {
      p.setInt(key, value);
    }
  }

  void setPinMode(PinDisplayMode m) {
    pinMode = m;
    _save(_kPinMode, m.name);
    notifyListeners();
  }

  void setLanguage(AppLanguage v) {
    language = v;
    _save(_kLanguage, v.name);
    notifyListeners();
  }

  /// MaterialApp 用的显式 locale；「跟随系统」返回 null（交给
  /// localeResolutionCallback 折算，见 app.dart——非中英系统语言回退中文）。
  Locale? get explicitLocale => switch (language) {
        AppLanguage.zh => const Locale('zh'),
        AppLanguage.en => const Locale('en'),
        AppLanguage.system => null,
      };

  /// locale 折算（UI 回调与服务层 I18nService 共用同一实现）：
  /// 显式选择优先；跟随系统只认中文/英文，其余语言回退中文。
  Locale resolveUiLocale(Locale? deviceLocale) {
    final explicit = explicitLocale;
    if (explicit != null) return explicit;
    final lang = deviceLocale?.languageCode ?? 'zh';
    return lang == 'en' ? const Locale('en') : const Locale('zh');
  }

  void setClusterRadiusKm(double v) {
    clusterRadiusKm = v.clamp(1, 20);
    _save(_kRadiusKm, clusterRadiusKm);
    notifyListeners();
  }

  void setClusterMinPoints(int v) {
    clusterMinPoints = v;
    _save(_kMinPts, v);
    notifyListeners();
  }

  void setAmapKey(String v) {
    amapKey = v.trim();
    _save(_kAmapKey, amapKey);
    notifyListeners();
  }

  void setTiandituKey(String v) {
    tiandituKey = v.trim();
    _save(_kTdtKey, tiandituKey);
    notifyListeners();
  }

  void setShareWatermarkText(String v) {
    shareWatermarkText = v.trim().isEmpty ? '分享照片' : v.trim();
    _save(_kShareWatermark, shareWatermarkText);
    notifyListeners();
  }

  // —— 分类管理：设置页「地点分类」的持久化与写入入口 ———

  /// 编码当前分类状态（纯函数，测试直用）：内置覆盖 + 自定义定义。
  /// `img` = 自定义图片图标（贯通设置页合并功能）；非空才落键，
  /// 旧格式（无 img）解码兼容。
  static String encodeCategories() {
    final snap = MarkerCategory.overrideSnapshot();
    return jsonEncode({
      'v': 1,
      'builtin': {
        for (final e in snap.entries)
          if (!e.key.startsWith('u_'))
            e.key: {
              'c': e.value.color,
              'i': e.value.icon,
              if (e.value.image != null) 'img': e.value.image,
            },
      },
      'custom': [
        for (final e in snap.entries)
          if (e.key.startsWith('u_'))
            {
              'id': e.key,
              'label': MarkerCategory.of(e.key).label,
              'c': e.value.color,
              'i': e.value.icon,
              if (e.value.image != null) 'img': e.value.image,
            },
      ],
    });
  }

  /// 恢复（load 时调用）：null / 坏 JSON / 未知版本 → 静默回出厂，绝不抛错阻塞启动
  static void restoreCategories(String? json) {
    if (json == null || json.isEmpty) return;
    try {
      final d = (jsonDecode(json) as Map).cast<String, dynamic>();
      if (d['v'] != 1) return;
      final builtin = <String, ({int color, int icon, String? image})>{};
      for (final e in ((d['builtin'] as Map?) ?? const {}).entries) {
        final m = (e.value as Map).cast<String, dynamic>();
        builtin[e.key] = (
          color: (m['c'] as num?)?.toInt() ?? 0,
          icon: (m['i'] as num?)?.toInt() ?? 0,
          image: m['img'] as String?,
        );
      }
      final customs = <({String id, String label, int color, int icon, String? image})>[];
      for (final c in ((d['custom'] as List?) ?? const [])) {
        final m = (c as Map).cast<String, dynamic>();
        customs.add((
          id: m['id'] as String? ?? '',
          label: m['label'] as String? ?? '',
          color: (m['c'] as num?)?.toInt() ?? 0,
          icon: (m['i'] as num?)?.toInt() ?? 0,
          image: m['img'] as String?,
        ));
      }
      MarkerCategory.restoreSnapshot(builtin, customs);
    } catch (_) {
      MarkerCategory.resetToDefaults();
    }
  }

  /// 改样式（内置=换色/换图标；自定义同口径 + 可改名）→ 持久化 → 通知全局生效。
  /// 图片图标三态：clearImage=true 撤下；imagePath 非空替换；
  /// 两者都不传保持现状。
  void setCategoryLook(String id,
      {required int argb,
      required int iconIndex,
      String? label,
      String? imagePath,
      bool clearImage = false}) {
    MarkerCategory.setLook(id,
        argb: argb,
        iconIndex: iconIndex,
        label: label,
        imagePath: imagePath,
        clearImage: clearImage);
    _persistCategories();
  }

  /// 新建自定义分类（调用方保证 label 非空；重复名不校验，自选自用）
  void addMarkerCategory(String label,
      {required int argb, required int iconIndex, String? imagePath}) {
    if (label.trim().isEmpty) return;
    MarkerCategory.addCustom(label.trim(), argb, iconIndex,
        imagePath: imagePath);
    _persistCategories();
  }

  /// 删除自定义分类（引用兜底回「其他」由 MarkerCategory.of 完成）
  void removeMarkerCategory(String id) {
    MarkerCategory.removeCustom(id);
    _persistCategories();
  }

  /// 重置：内置清除覆盖 / 自定义删除该条
  void resetMarkerCategory(String id) {
    MarkerCategory.resetCategory(id);
    _persistCategories();
  }

  void _persistCategories() {
    _save(_kCategories, AppSettings.encodeCategories());
    notifyListeners();
  }
}
