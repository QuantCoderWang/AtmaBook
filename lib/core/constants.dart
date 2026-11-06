import 'package:flutter/material.dart';

import 'utils/ids.dart';

/// 应用的底色、主色和文字色
class AppColors {
  static const Color bg = Color(0xFFFAF6EE);
  static const Color primary = Color(0xFF00695C);
  static const Color primaryDark = Color(0xFF004D40);
  static const Color accent = Color(0xFFFF7043);
  static const Color ink = Color(0xFF2D2A26);
  static const Color inkSoft = Color(0xFF8D8377);
  static const Color border = Color(0xFFE8E2D6);
}

/// 调色板：Pin 颜色、片区色环、照片占位渐变
class TravelPalette {
  static const List<Color> pinColors = [
    Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFFFDD835), Color(0xFF43A047),
    Color(0xFF00ACC1), Color(0xFF1E88E5), Color(0xFF3949AB), Color(0xFF8E24AA),
    Color(0xFFD81B60), Color(0xFF6D4C41), Color(0xFF78909C), Color(0xFF3D2A26),
  ];

  /// 片区色环（按簇数均匀取色）
  static const List<Color> zoneColors = [
    Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFB8C00),
    Color(0xFF8E24AA), Color(0xFF00ACC1), Color(0xFFC2185B), Color(0xFF5D4037),
  ];

  static const List<List<Color>> photoGradients = [
    [Color(0xFFFFB74D), Color(0xFFFF8A65)],
    [Color(0xFF4FC3F7), Color(0xFF2196F3)],
    [Color(0xFF81C784), Color(0xFF388E3C)],
    [Color(0xFFF06292), Color(0xFFEC407A)],
    [Color(0xFFBA68C8), Color(0xFF7E57C2)],
    [Color(0xFFFFD54F), Color(0xFF00897B)],
  ];
}

/// 地点分类（预设 6 类 + 分类管理覆盖层 / 自定义分类）：
/// 引用面极广（攻略地图 / 图例 / 标记编辑 / 标记抽屉 / 笔记 / 设置），
/// 覆盖层做成静态生效的注册表，所有读取点都直接生效；
/// 覆盖只改 color/icon/image（label 保持翻译语义，词条不动）；
/// 写入方 = 设置页「分类管理」（AppSettings 持久化到 shared_preferences）。
class MarkerCategory {
  const MarkerCategory(this.id, this.label, this.icon, this.color,
      [this.image]);
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  /// 自定义图片图标（MediaStore 相对路径 `pics/icons/i_*.png/jpg`
  /// 内容哈希去重，可能与其他标记/分类共用，不清除）。null = 用内置
  /// icon。显示端（PinWidget / CategoryIcon）同名同尺寸圆裁渲染，
  /// 替换不产生大小差。
  final String? image;

  static const MarkerCategory scenic =
      MarkerCategory('scenic', '景点', Icons.landscape, Color(0xFF1E88E5));
  static const MarkerCategory dining =
      MarkerCategory('dining', '餐饮', Icons.restaurant, Color(0xFFFB8C00));
  static const MarkerCategory hotel =
      MarkerCategory('hotel', '住宿', Icons.hotel, Color(0xFF43A047));
  static const MarkerCategory shopping =
      MarkerCategory('shopping', '购物', Icons.shopping_bag, Color(0xFF8E24AA));
  static const MarkerCategory transport = MarkerCategory(
      'transport', '交通', Icons.directions_subway, Color(0xFF303F9F));
  static const MarkerCategory other =
      MarkerCategory('other', '其他', Icons.location_on, Color(0xFF78909C));

  static const List<MarkerCategory> defaults = [
    scenic, dining, hotel, shopping, transport, other,
  ];

  /// 图标可选池（设置页「图标替换」用；只往尾部追加，保证已存索引跨版本稳定）
  static const List<IconData> iconPalette = [
    Icons.landscape, // 0（= scenic 默认）
    Icons.restaurant, // 1（= dining 默认）
    Icons.hotel, // 2（= hotel 默认）
    Icons.shopping_bag, // 3（= shopping 默认）
    Icons.directions_subway, // 4（= transport 默认）
    Icons.location_on, // 5（= other 默认）
    Icons.park, // 6
    Icons.museum, // 7
    Icons.local_cafe, // 8
    Icons.local_bar, // 9
    Icons.flight, // 10
    Icons.directions_boat, // 11
    Icons.directions_bus, // 12
    Icons.fitness_center, // 13
    Icons.spa, // 14
    Icons.school, // 15
    Icons.theater_comedy, // 16
    Icons.pets, // 17
    Icons.medical_services, // 18
    Icons.star, // 19
  ];

  /// 颜色可选池（设置页配色用；预设六类默认色全部在池内）
  static const List<Color> colorPalette = [
    Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFB8C00),
    Color(0xFF8E24AA), Color(0xFF303F9F), Color(0xFF78909C),
    Color(0xFFE53935), Color(0xFF00897B), Color(0xFFFDD835),
    Color(0xFF3949AB), Color(0xFFD81B60), Color(0xFF6D4C41),
  ];

  // 分类管理的运行时覆盖层
  // AppSettings 启动恢复 / 设置页写入时同步；静态生效，全部读取点直达。
  // 内置覆盖存「池索引」（iconPalette 含全部出厂图标，索引即 0–5）；
  // iconIndex 越界统一钳回池首位（0=landscape）。
  // image = 自定义图片图标相对路径，null/无键 = 未传。
  static Map<String, ({int color, int icon, String? image})> _overrides =
      const {};
  static List<MarkerCategory> _custom = const [];

  /// 生效分类全集：预设六类（套用覆盖）+ 自定义分类
  static List<MarkerCategory> get all => [
        for (final c in defaults)
          _overrides[c.id] != null
              ? MarkerCategory(
                  c.id,
                  c.label,
                  iconPalette[_iconIdx(_overrides[c.id]!.icon)],
                  Color(_overrides[c.id]!.color),
                  _overrides[c.id]!.image)
              : c,
        ..._custom,
      ];

  /// 当前已登记的自定义分类（设置页展示 / 编解码用）
  static List<MarkerCategory> get customs => List.unmodifiable(_custom);

  static MarkerCategory of(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return other; // 已删除自定义分类引用 → 回退「其他」
  }

  static int _iconIdx(int i) => (i >= 0 && i < iconPalette.length) ? i : 0;

  /// 写入/更新一条生效样式（内置=覆盖；自定义=改行，可携带改名）；
  /// 图片图标三态：`clearImage` → 撤下；`imagePath` → 替换；都不传 → 保持。
  /// 返回是否命中既有 id。
  static bool setLook(String id,
      {required int argb,
      required int iconIndex,
      String? label,
      String? imagePath,
      bool clearImage = false}) {
    final idx = _iconIdx(iconIndex);
    for (var i = 0; i < _custom.length; i++) {
      if (_custom[i].id == id) {
        final c = _custom[i];
        final list = [..._custom];
        list[i] = MarkerCategory(
            id,
            (label == null || label.trim().isEmpty)
                ? c.label
                : label.trim(),
            iconPalette[idx],
            Color(argb),
            clearImage ? null : (imagePath ?? c.image));
        _custom = list;
        return true;
      }
    }
    final isBuiltin = defaults.any((c) => c.id == id);
    if (!isBuiltin) return false;
    _overrides = {
      ..._overrides,
      id: (
        color: argb,
        icon: idx,
        image: clearImage ? null : (imagePath ?? _overrides[id]?.image),
      ),
    };
    return true;
  }

  /// 新建自定义分类（id 自动生成前缀 u_；label 交给调用方校验非空）
  static MarkerCategory addCustom(String label, int argb, int iconIndex,
      {String? imagePath}) {
    final idx = _iconIdx(iconIndex);
    final c = MarkerCategory(
        newId('u'), label, iconPalette[idx], Color(argb), imagePath);
    _custom = [..._custom, c];
    return c;
  }

  /// 删除自定义分类（内置不可删 → false；后续引用由 [of] 兜底回「其他」）
  static bool removeCustom(String id) {
    if (!_custom.any((c) => c.id == id)) return false;
    _custom = [for (final c in _custom) if (c.id != id) c];
    return true;
  }

  /// 重置：内置 → 清除覆盖；自定义 → 删除该条
  static bool resetCategory(String id) {
    if (_overrides.containsKey(id)) {
      _overrides = {..._overrides}..remove(id);
      return true;
    }
    return removeCustom(id);
  }

  /// 清空全部覆盖与自定义（回出厂；编码失败兜底 / 测试隔离）
  static void resetToDefaults() {
    _overrides = const {};
    _custom = const [];
  }

  /// 编解码锚点（AppSettings 持久化用）：内置覆盖 + 自定义样式的纯快照
  static Map<String, ({int color, int icon, String? image})>
      overrideSnapshot() => {
            for (final e in _overrides.entries)
              e.key: (
                color: e.value.color,
                icon: e.value.icon,
                image: e.value.image,
              ),
            for (final c in _custom)
              c.id: (
                color: c.color.toARGB32(),
                icon: iconPalette.indexOf(c.icon),
                image: c.image,
              ),
          };

  /// 从快照恢复（设置页编码 JSON 解析后调用；全量替换式，幂等）
  static void restoreSnapshot(
      Map<String, ({int color, int icon, String? image})> builtinSnap,
      List<({String id, String label, int color, int icon, String? image})>
          customs) {
    resetToDefaults();
    _overrides = {
      for (final e in builtinSnap.entries)
        if (defaults.any((d) => d.id == e.key))
          e.key: (
            color: e.value.color,
            icon: _iconIdx(e.value.icon),
            image: e.value.image,
          ),
    };
    _custom = [
      for (final c in customs)
        MarkerCategory(c.id, c.label, iconPalette[_iconIdx(c.icon)],
            Color(c.color), c.image),
    ];
  }
}

/// 默认参数（通过 shared_preferences 持久化）
class AppDefaults {
  /// 片区聚类半径（米）；设置页 1–20 km 可调
  static const double clusterRadiusMeters = 5000;

  /// 最少 2 个点成簇；低于该数量的孤立点各自单独成簇
  static const int clusterMinPoints = 2;
}

/// 标记显示规则（两套）
enum PinDisplayMode {
  icons('图标式 Pin'), // 圆头 + 分类图形（默认）
  colored('彩色大头针'); // 无图形纯色彩大头针，用颜色区分类型
  const PinDisplayMode(this.label);
  final String label;
}

/// 地理相册一次上图的照片数上限（动态加载下性能余量充足）
const int kAlbumDisplayCap = 200;

