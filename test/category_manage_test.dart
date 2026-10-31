import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atma_book/core/constants.dart';
import 'package:atma_book/state/settings_provider.dart';

/// 分类管理（v8.4）回归：MarkerCategory 覆盖层（配色/图标替换/自定义分类）
/// 与 AppSettings 分类持久化编解码的口径锁定。
void main() {
  setUp(MarkerCategory.resetToDefaults);

  group('出厂默认与读取路径', () {
    test('未做任何覆盖时 all 即预设六类，顺序与出厂一致', () {
      expect(MarkerCategory.all.map((c) => c.id),
          MarkerCategory.defaults.map((c) => c.id));
      expect(MarkerCategory.all.length, 6);
      expect(MarkerCategory.of('scenic').color,
          MarkerCategory.scenic.color); // 未覆盖 = 原色
    });

    test('未知 id 兜底「其他」（含已删除自定义分类的场景）', () {
      expect(MarkerCategory.of('no_such_cat'), MarkerCategory.other);
      expect(MarkerCategory.of(''), MarkerCategory.other);
    });
  });

  group('内置分类配色/图标替换', () {
    test('setLook 只改 color/icon，label 保持翻译语义不动', () {
      expect(
          MarkerCategory.setLook('dining',
              argb: 0xFFE53935, iconIndex: 7),
          isTrue);
      final d = MarkerCategory.of('dining');
      expect(d.color, const Color(0xFFE53935));
      expect(d.icon, MarkerCategory.iconPalette[7]);
      expect(d.label, '餐饮'); // label 不许动
      expect(MarkerCategory.of('hotel').color,
          MarkerCategory.hotel.color); // 其余分类不受影响
    });

    test('iconIndex 越界钳回池首位（池底 landscape）', () {
      MarkerCategory.setLook('hotel', argb: 0xFFFDD835, iconIndex: 999);
      expect(MarkerCategory.of('hotel').icon,
          MarkerCategory.iconPalette[0]);
    });

    test('不存在的 id（非自定义非内置）setLook 返回 false', () {
      expect(MarkerCategory.setLook('u_not_exist', argb: 1, iconIndex: 0),
          isFalse);
    });

    test('恢复默认样式：置覆盖后 resetCategory 归出厂', () {
      MarkerCategory.setLook('scenic', argb: 0xFF6D4C41, iconIndex: 13);
      expect(MarkerCategory.resetCategory('scenic'), isTrue);
      expect(MarkerCategory.of('scenic').color, MarkerCategory.scenic.color);
      expect(MarkerCategory.of('scenic').icon, MarkerCategory.scenic.icon);
      expect(MarkerCategory.resetCategory('scenic'), isFalse); // 已无覆盖
    });
  });

  group('自定义分类', () {
    test('新建 → 可被 of 命中；改行含改名；删除后引用兜底回「其他」', () {
      final c = MarkerCategory.addCustom('温泉', 0xFF00897B, 14);
      expect(c.id.startsWith('u_'), isTrue);
      expect(MarkerCategory.all.length, 7);
      expect(MarkerCategory.of(c.id).label, '温泉');
      expect(MarkerCategory.of(c.id).icon, MarkerCategory.iconPalette[14]);

      // 改行：换色 + 换图标 + 改名（trim）
      expect(
          MarkerCategory.setLook(c.id,
              argb: 0xFFD81B60, iconIndex: 9, label: ' 温泉小镇 '),
          isTrue);
      final renamed = MarkerCategory.of(c.id);
      expect(renamed.label, '温泉小镇');
      expect(renamed.color, const Color(0xFFD81B60));
      expect(renamed.icon, MarkerCategory.iconPalette[9]);

      expect(MarkerCategory.removeCustom(c.id), isTrue);
      expect(MarkerCategory.of(c.id), MarkerCategory.other); // 兜底
      expect(MarkerCategory.removeCustom(c.id), isFalse); // 已不存在
    });

    test('内置分类不可删除', () {
      expect(MarkerCategory.removeCustom('scenic'), isFalse);
      expect(MarkerCategory.all.length, 6);
    });

    test('内置可用 resetCategory；自定义 reset = 删除该条', () {
      final c = MarkerCategory.addCustom('垂钓', 0xFF3949AB, 11);
      expect(MarkerCategory.resetCategory(c.id), isTrue);
      expect(MarkerCategory.of(c.id), MarkerCategory.other);
    });
  });

  group('持久化编解码（AppSettings.encodeCategories / restoreCategories）', () {
    test('编码→重置→恢复：内置覆盖与自定义样式原样回来', () {
      MarkerCategory.setLook('scenic', argb: 0xFFE53935, iconIndex: 16);
      final c = MarkerCategory.addCustom('温泉', 0xFF00897B, 14);
      final json = AppSettings.encodeCategories();

      MarkerCategory.resetToDefaults();
      expect(MarkerCategory.all.length, 6); // 重置生效

      AppSettings.restoreCategories(json);
      final s = MarkerCategory.of('scenic');
      expect(s.color, const Color(0xFFE53935));
      expect(s.icon, MarkerCategory.iconPalette[16]);
      expect(s.label, '景点');
      final back = MarkerCategory.of(c.id);
      expect(back.label, '温泉');
      expect(back.color, const Color(0xFF00897B));
      expect(back.icon, MarkerCategory.iconPalette[14]);
      expect(MarkerCategory.customs.length, 1);
    });

    test('restoreCategories(null / 空 / 坏 JSON) 静默回出厂，绝不抛错', () {
      MarkerCategory.setLook('hotel', argb: 0xFFFDD835, iconIndex: 8);
      AppSettings.restoreCategories(null);
      AppSettings.restoreCategories('');
      AppSettings.restoreCategories('{"v":1,"builtin":{bad');
      expect(MarkerCategory.of('hotel').color, MarkerCategory.hotel.color);
      expect(MarkerCategory.all.length, 6);
    });

    test('未知版本号忽略（前向兼容：新版本数据不误读）', () {
      AppSettings.restoreCategories('{"v":99,"builtin":{}}');
      expect(MarkerCategory.all.length, 6);
    });

    test('恢复数据里 iconIndex 越界 → 钳回池首位；未知内置 id 丢弃', () {
      AppSettings.restoreCategories(
          '{"v":1,"builtin":{"scenic":{"c":4294950965,"i":500},'
          '"ghost_cat":{"c":1,"i":1}},"custom":[]}');
      expect(MarkerCategory.of('scenic').icon, MarkerCategory.iconPalette[0]);
      expect(MarkerCategory.all.length, 6); // ghost_cat 不建档
    });

    test('恢复数据无 img 键（旧格式）→ image 为 null，不误报', () {
      AppSettings.restoreCategories(
          '{"v":1,"builtin":{"scenic":{"c":4294950965,"i":3}},"custom":[]}');
      expect(MarkerCategory.of('scenic').image, isNull);
    });
  });

  group('图片图标（v8.4.4 分类合并上传）', () {
    test('setLook imagePath 写入 → 生效；三态保现状语义成立', () {
      MarkerCategory.setLook('scenic',
          argb: 0xFF1E88E5, iconIndex: 2, imagePath: 'pics/icons/i_a.jpg');
      expect(MarkerCategory.of('scenic').image, 'pics/icons/i_a.jpg');

      // 只换色/图标不传图 → 图片保持
      MarkerCategory.setLook('scenic', argb: 0xFFE53935, iconIndex: 9);
      expect(MarkerCategory.of('scenic').image, 'pics/icons/i_a.jpg');

      // 再传新图 → 替换
      MarkerCategory.setLook('scenic',
          argb: 0xFFE53935, iconIndex: 9, imagePath: 'pics/icons/i_b.jpg');
      expect(MarkerCategory.of('scenic').image, 'pics/icons/i_b.jpg');

      // clearImage → 撤下
      MarkerCategory.setLook('scenic',
          argb: 0xFFE53935, iconIndex: 9, clearImage: true);
      expect(MarkerCategory.of('scenic').image, isNull);
    });

    test('自定义分类同样支持图片；覆盖/编解码 round-trip 含 img', () {
      final c = MarkerCategory.addCustom('温泉', 0xFF00897B, 14,
          imagePath: 'pics/icons/i_c.png');
      final json = AppSettings.encodeCategories();

      MarkerCategory.resetToDefaults();
      AppSettings.restoreCategories(json);

      final back = MarkerCategory.of(c.id);
      expect(back.image, 'pics/icons/i_c.png');
      expect(back.label, '温泉');

      // round-trip 后继续可替换/撤下
      expect(
          MarkerCategory.setLook(c.id,
              argb: 0xFF00897B, iconIndex: 14, clearImage: true),
          isTrue);
      expect(MarkerCategory.of(c.id).image, isNull);
    });

    test('内置覆盖带 img → JSON 出 img 键；clearImage 后重新编码 img 消失', () {
      MarkerCategory.setLook('hotel',
          argb: 0xFFFDD835, iconIndex: 8, imagePath: 'pics/icons/i_h.jpg');
      final withImg = AppSettings.encodeCategories();
      expect(withImg.contains('"img":"pics/icons/i_h.jpg"'), isTrue);

      MarkerCategory.setLook('hotel',
          argb: 0xFFFDD835, iconIndex: 8, clearImage: true);
      final noImg = AppSettings.encodeCategories();
      expect(noImg.contains('"img":"pics/icons/i_h.jpg"'), isFalse);

      // 编解码不破坏既有键值
      AppSettings.restoreCategories(withImg);
      expect(MarkerCategory.of('hotel').image, 'pics/icons/i_h.jpg');
    });
  });
}
