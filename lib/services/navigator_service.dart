import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n_service.dart';
import '../data/models/guide.dart';
/// 外跳导航 / 链接打开（桌面模式下默认导航引导至高德地图）：
/// - 手机端：`geo,lat,lng?q=...` 唤起系统地图 App（系统会弹应用选择器）；
/// - 桌面 / Web：默认使用高德地图导航面板（默认交通选择公交；境内境外同理），
///   失败兜底 OpenStreetMap 坐标直链；
/// - 全部失败：复制坐标到剪贴板并提示。
class NavigatorService {
  static Future<void> openPlace(
    BuildContext context,
    Place place,
    void Function(String message) snack,
  ) async {
    final lat = place.lat.toStringAsFixed(6);
    final lng = place.lng.toStringAsFixed(6);
    final osmUrl =
        'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng';
    final amapUrl = 'https://uri.amap.com/navigation'
        '?to=$lng,$lat,${Uri.encodeComponent(place.title)}'
        '&mode=bus&coordinate=gaode&callnative=0&src=AtmaBook';
    final Uri target = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => Uri(
          scheme: 'geo',
          host: '$lat,$lng',
        ),
      // 桌面/Web 默认高德（uri.amap.com 直开导航面板；mode=bus 公交默认）
      _ => Uri.parse(amapUrl),
    };

    try {
      final ok = await launchUrl(
        target,
        mode: LaunchMode.externalApplication,
      );
      if (ok) return;
    } catch (_) {}
    // 手机端唤起失败 → 退浏览器直链
    if (!identical(target, Uri.parse(''))) {
      try {
        final ok2 =
            await launchUrl(Uri.parse(osmUrl), mode: LaunchMode.externalApplication);
        if (ok2) return;
      } catch (_) {}
    }
    await Clipboard.setData(ClipboardData(
        text: '$lat, $lng')); 
    snack(I18nService.t.navAmapFail);
  }

  static Future<void> openUrl(
    String url,
    void Function(String message) snack, {
    String? fallbackTip,
  }) async {
    final u = Uri.tryParse(url.trim());
    if (u == null || url.trim().isEmpty) {
      snack(fallbackTip ?? I18nService.t.linkInvalid);
      return;
    }
    try {
      final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    snack(I18nService.t.navUrlFail);
  }
}
