import 'dart:math' as math;

/// 白板照片墙布局纯函数：
/// - 地理位置相近的照片聚为一团（贪心算法，簇心距 ≤150m）；
/// - 团内成员围绕簇心**部分重叠**地随机散布（中心距有下限，不可能完全遮盖）；
/// - 全部照片随机倾向左/右 0–45° 之间的某一角度；
/// - 三种贴片尺寸（小/中/大）随机分配给每张照片；
/// - 簇锚点按时间序摆到白板网格槽（种子抖动，同一输入+seed 完全可复现，
///   年份滑窗只做子集显隐，不重排）；
/// - 无定位照片排进剩余空槽（补空位）；
/// - 数量上限由调用方截断（cap）。

/// 布局输入照片点
class WallPhotoPoint {
  const WallPhotoPoint({
    required this.uid,
    this.lat,
    this.lng,
    required this.takenAt,
  });

  final String uid;
  final double? lat;
  final double? lng;
  final DateTime takenAt;

  bool get hasGps => lat != null && lng != null;
}

/// 一个地理照片团（锚点坐标在成员 placement 上，此处只存成员/簇心）
class WallPhotoCluster {
  WallPhotoCluster({
    required this.id,
    this.lat,
    this.lng,
  });

  final String id;
  final double? lat;
  final double? lng;

  final members = <String>[];
}

/// 三种贴片尺寸档位（0=小 1=中 2=大；像素换算在 UI 层）
const int kWallSizeCount = 3;

/// 单张照片在白板上的摆放
class WallPlacement {
  const WallPlacement({
    required this.uid,
    required this.groupId,
    required this.anchorX,
    required this.anchorY,
    required this.offX,
    required this.offY,
    required this.angleDeg,
    required this.stackIndex,
    required this.sizeIndex,
  });

  final String uid;
  final String groupId; // 簇 id 或 'loose'

  /// 簇锚点在墙板上的位置（0..1 墙板比例；墙板可比视口宽得多）
  final double anchorX;
  final double anchorY;

  /// 成员相对锚点的偏移（**视口单位**比例；不随墙板宽度放大 → 团保持紧凑、
  /// 部分重叠关系在任意墙宽下不变）
  final double offX;
  final double offY;

  final double angleDeg; // 贴片旋转（±45° 内，左右随机）

  final int stackIndex; // 同簇内 z 序（越大越在上）
  final int sizeIndex; // 0..2 三种尺寸

  /// 单位墙语义的合成位置（≈锚点+偏移；供快照/测试兼容）
  double get x => (anchorX + offX).clamp(0.0, 1.0);
  double get y => (anchorY + offY).clamp(0.0, 1.0);
}

/// 布局结果
class WallLayoutResult {
  WallLayoutResult(this.placements, this.clusters);

  final List<WallPlacement> placements;
  final List<WallPhotoCluster> clusters;

  WallPhotoCluster? clusterById(String id) {
    for (final c in clusters) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// —— 简化布局：取消地理聚类 ——
/// 照片按「砖墙网格 + 种子抖动」确定性摆上白板：
/// - 随机倾斜（左右 × 0–45°）与三种贴片尺寸保留；
/// - 相邻贴片用行错位（砖缝）+ 少量视觉单位偏移，观感为满墙照片墙；
/// - 不做任何地理分团；同输入+seed 完全可复现，年滑窗仍只做显隐。
WallLayoutResult layoutWallPhotosSimple(
  List<WallPhotoPoint> photos, {
  int seed = 20261021,
}) {
  final n = photos.length;
  if (n == 0) return WallLayoutResult(const [], const []);

  final rng = math.Random(seed);
  final cols = math.max(2, (math.sqrt(n * 1.5)).ceil());
  final rows = math.max(1, ((n + cols - 1) / cols).ceil());

  final placements = <WallPlacement>[];
  for (var i = 0; i < n; i++) {
    final p = photos[i];
    final col = i % cols;
    final row = i ~/ cols;
    // 砖墙错位：奇数行右移半格
    final brick = row.isOdd ? 0.5 : 0.0;
    final jx = (rng.nextDouble() - 0.5) * (1 / cols) * 0.35;
    final jy = (rng.nextDouble() - 0.5) * (1 / rows) * 0.35;
    final ax = ((col + 0.5 + brick) / cols + jx).clamp(0.04, 0.96);
    final ay = (((row + 0.5) / rows) + jy).clamp(0.07, 0.93);
    final mag = rng.nextDouble() * 45;
    final sign = rng.nextBool() ? -1.0 : 1.0;
    placements.add(WallPlacement(
      uid: p.uid,
      // 简化方案无地理团：groupId 即单张 id 的命名空间（不形成聚合）
      groupId: 'loose',
      anchorX: ax,
      anchorY: ay,
      offX: ((rng.nextDouble() - 0.5) * 0.05).clamp(-0.03, 0.03),
      offY: ((rng.nextDouble() - 0.5) * 0.04).clamp(-0.02, 0.02),
      angleDeg: mag * sign,
      stackIndex: i,
      sizeIndex: rng.nextInt(kWallSizeCount),
    ));
  }
  return WallLayoutResult(placements, const []);
}

/// 主入口：把照片点列表摆上白板
/// [seed] 决定随机形态（同一批照片同一 seed → 布局稳定）。
WallLayoutResult layoutWallPhotos(
  List<WallPhotoPoint> photos, {
  int seed = 20261020,
  double clusterEpsilonM = 150,
}) {
  // —— 1. 地理聚类（时间序贪心，合并保留首簇 id，成员与簇心随迁）——
  final clusters = <_Cluster>[];
  for (final p in photos.where((p) => p.hasGps)) {
    _Cluster? best;
    var bestD = clusterEpsilonM;
    for (final c in clusters) {
      final d = _distM(p.lat!, p.lng!, c.lat!, c.lng!);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    if (best == null) {
      clusters.add(
        _Cluster('c${clusters.length}', p.lat!, p.lng)..members.add(p),
      );
    } else {
      best.members.add(p);
      // 簇心滑动（简单平均，近邻团自然汇合）
      best.lat = best.members.map((m) => m.lat!).reduce((a, b) => a + b) /
          best.members.length;
      best.lng = best.members.map((m) => m.lng!).reduce((a, b) => a + b) /
          best.members.length;
    }
  }

  // —— 2. 网格槽规划（簇锚点 + 无定位空槽）——
  final nClusters = clusters.length;
  final nLoose = photos.where((p) => !p.hasGps).length;
  final totalSlots = nClusters + nLoose;
  final cols = math.max(1, math.sqrt(math.max(1, totalSlots) * 1.35).ceil());
  final rows = math.max(1, ((totalSlots + cols - 1) / cols).ceil());
  final cellW = 1 / cols;
  final cellH = math.min(1 / math.max(1, rows), cellW);

  final rng = math.Random(seed);
  final placements = <WallPlacement>[];
  final usedCells = <(int, int)>{};

  int nextCellIdx = 0;
  (int, int) nextCell() {
    // 蛇形遍历网格，取一个未用格
    for (var i = 0; i < cols * rows; i++) {
      final idx = (nextCellIdx + i) % (cols * rows);
      final r = idx ~/ cols;
      final c = idx % cols;
      if (!usedCells.contains((r, c))) {
        nextCellIdx = idx + 1;
        usedCells.add((r, c));
        return (r, c);
      }
    }
    // 兜底（正常不会走到：格数 ≥ 槽数）
    return (0, 0);
  }

  // —— 3. 簇锚点：按时间序摆放到网格 ——
  for (final c in clusters) {
    final cell = nextCell();
    final (r, col) = cell;
    final jx = cellW / 2 + (rng.nextDouble() - 0.5) * cellW * 0.30;
    final jy = cellH / 2 + (rng.nextDouble() - 0.5) * cellH * 0.30;
    final ax = ((col + 0.5) * cellW + jx).clamp(0.04, 0.96);
    final ay = ((r + 0.5) * cellH + jy).clamp(0.04, 0.96);

    // 成员围绕锚点部分重叠散布（最新拍摄压最上）
    final ordered = [...c.members]
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    final placedPts = <(double, double)>[];
    for (final m in ordered) {
      final stack = ordered.indexOf(m);
      double dx = 0;
      double dy = 0;
      if (stack > 0) {
        // 环状散开：随机朝向，半径 0.06–0.11（≈半个贴片宽，保证部分重叠）；
        // 与已放成员中心距 ≥0.06（视口单位），绝不完全遮盖。
        var rad = 0.06 + rng.nextDouble() * 0.05;
        var theta = rng.nextDouble() * 2 * math.pi;
        for (var attempt = 0; attempt < 5; attempt++) {
          dx = math.cos(theta) * rad;
          dy = math.sin(theta) * rad * 0.85; // 白板多为横幅，纵向略压
          var conflict = false;
          for (final (ex, ey) in placedPts) {
            final ddx = ax + dx - ex;
            final ddy = ay + dy - ey;
            if (ddx * ddx + ddy * ddy < 0.06 * 0.06) {
              conflict = true;
              break;
            }
          }
          if (!conflict) break;
          rad += 0.02; // 逐圈外推
          theta = rng.nextDouble() * 2 * math.pi;
        }
      }
      placedPts.add((ax + dx, ay + dy));
      // 倾斜：左/右随机 × 0–45° 随机
      final mag = rng.nextDouble() * 45;
      final sign = rng.nextBool() ? -1.0 : 1.0;
      placements.add(WallPlacement(
        uid: m.uid,
        groupId: c.id,
        anchorX: ax,
        anchorY: ay,
        offX: dx,
        offY: dy,
        angleDeg: mag * sign,
        stackIndex: stack,
        sizeIndex: rng.nextInt(kWallSizeCount),
      ));
    }
  }

  // —— 4. 无定位照片：剩余空槽（补空位），同样随机倾斜+尺寸 ——
  for (final p in photos.where((p) => !p.hasGps)) {
    final cell = nextCell();
    final (r, col) = cell;
    final mag = rng.nextDouble() * 45;
    final sign = rng.nextBool() ? -1.0 : 1.0;
    placements.add(WallPlacement(
      uid: p.uid,
      groupId: 'loose',
      anchorX: ((col + 0.5) * cellW).clamp(0.02, 0.98),
      anchorY: ((r + 0.5) * cellH).clamp(0.02, 0.98),
      // 视口单位：限制在小抖动内（cellW 大时不会把贴片甩远）
      offX: ((rng.nextDouble() - 0.5) * cellW * 0.4).clamp(-0.05, 0.05),
      offY: ((rng.nextDouble() - 0.5) * cellH * 0.4).clamp(-0.04, 0.04),
      angleDeg: mag * sign,
      stackIndex: 0,
      sizeIndex: rng.nextInt(kWallSizeCount),
    ));
  }

  final outClusters = [
    for (final c in clusters)
      WallPhotoCluster(id: c.id, lat: c.lat, lng: c.lng)
        ..members.addAll(c.members.map((m) => m.uid)),
  ];
  return WallLayoutResult(placements, outClusters);
}

double _distM(double la1, double lo1, double la2, double lo2) {
  const r = 6371000.0;
  final rad = math.pi / 180;
  final dLa = (la2 - la1) * rad;
  final dLo = (lo2 - lo1) * rad;
  final a = math.pow(math.sin(dLa / 2), 2) +
      math.cos(la1 * rad) *
          math.cos(la2 * rad) *
          math.pow(math.sin(dLo / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

class _Cluster {
  _Cluster(this.id, this.lat, this.lng);
  final String id;
  final members = <WallPhotoPoint>[];
  double? lat;
  double? lng;
}
