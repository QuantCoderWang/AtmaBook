import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:atma_book/core/utils/tile_math.dart';

void main() {
  group('M5-01 瓦片数学', () {
    test('手算口径：z10、1°×1° 框（30–31°N / 120–121°E）→ 16 张', () {
      // Web 墨卡托 z10：x(120°)=853.33, x(121°)=856.18 → 列 853..856 = 4 列
      // y(31°)=419.16, y(30°)=422.47 → 行 419..422 = 4 行
      final tiles = enumerateTiles(
        const LatLng(30.0, 120.0),
        const LatLng(31.0, 121.0),
        [10],
      );
      expect(tiles.length, 16);
      final xs = tiles.map((t) => t.x).toSet();
      final ys = tiles.map((t) => t.y).toSet();
      expect(xs, {853, 854, 855, 856});
      expect(ys, {419, 420, 421, 422});
      expect(tiles.every((t) => t.z == 10), isTrue);
    });

    test('级别缩放单调：z11 ≈ 4×z10（3–5 倍容差），面积守恒方向正确', () {
      const a = LatLng(30.0, 120.0);
      const b = LatLng(31.0, 121.0);
      final z10 = enumerateTiles(a, b, [10]).length;
      final z11 = enumerateTiles(a, b, [11]).length;
      expect(z11, greaterThanOrEqualTo(z10 * 3));
      expect(z11, lessThanOrEqualTo(z10 * 5));
    });

    test('GCJ-02 换算：小框在同瓦片内数量不变；坐标锚点整体平移在已知量级', () {
      // z8 级别单瓦片约 1.4°宽高；30.25/120.15 附近框远高瓦片边界，
      // GCJ 偏移（~0.002–0.006°）不会跨瓦片 → 清单一致
      final plain = enumerateTiles(
          const LatLng(30.25, 120.15), const LatLng(30.28, 120.19), [8]);
      final gcj = enumerateTiles(const LatLng(30.25, 120.15),
          const LatLng(30.28, 120.19), [8],
          gcjSource: true);
      expect(gcj.length, plain.length);
      expect(gcj.length, 1);
      expect(gcj.first.z, plain.first.z);
      expect(gcj.first.x, plain.first.x);
      expect(gcj.first.y, plain.first.y);
    });

    test('零尺寸/退化框：返回空清单（不会炸除 0）', () {
      final t = enumerateTiles(
          const LatLng(30.25, 120.15), const LatLng(30.25, 120.15), [12]);
      expect(t, isEmpty);
    });

    test('越界保护：极小 zoom 不越出世界范围', () {
      final t = enumerateTiles(
          const LatLng(-89.9, 179.9), const LatLng(89.9, -179.9), [2]);
      expect(t.every((c) => c.x >= 0 && c.x < 4 && c.y >= 0 && c.y < 4),
          isTrue);
    });

    test('TileCoord key 与相等性', () {
      const a = TileCoord(10, 853, 419);
      const b = TileCoord(10, 853, 419);
      expect(a, b);
      expect(a.key, '10/853/419');
    });
  });
}
