import 'package:flutter_test/flutter_test.dart';
import 'package:atma_book/data/repos/guide_repository.dart';
import 'package:atma_book/data/seed_data.dart';
import 'package:atma_book/services/share_service.dart';
import 'package:atma_book/state/guides_provider.dart';

import 'share_service_test.dart' show MemoryStorage;

/// v7.0 S4 回归：**删除已导入的分享攻略后，同一 .tgshare 文件可再次导入生效**
/// 链路：导入 → 指纹命中（hasShareKey=true，查重弹窗条件成立）→ 删除攻略
/// （JSON + pics 目录 + 封面 + 索引清理）→ 指纹不再命中 → 二次导入直接生效
/// （新 id 独立副本，文件重新落盘，无任何残留引用冲突）。
void main() {
  test('删除已导入攻略 → 同文件二次导入仍生效（指纹不再命中，id 全新）', () async {
    final storage = MemoryStorage();
    final guideRepo = GuideRepository(storage);

    // ① 导出（照片不入包——指纹链路只看 guide 内容，与视频欧无关）
    final exporter = ShareService(storage);
    final export = await exporter.build(
      guide: SeedData.buildDemoGuide(),
      includePhotos: false,
      watermarkText: '',
    );
    final fp = export!.fingerprint;

    // ② 第一次导入 + 入库（shared=true / shareKey=指纹）
    final provider1 = GuidesProvider(repository: guideRepo, guides: const []);
    final first = await exporter.applyImport(
        ShareService.parseShare(export.bytes)!);
    expect(first!.guide.shared, isTrue);
    expect(first.guide.shareKey, fp);
    await provider1.addImported(first.guide);
    expect(provider1.hasShareKey(fp), isTrue, reason: '未删除前应命中查重');

    // ③ 删除攻略（走 provider.remove 的完整清理：JSON + pics 目录 + 索引）
    final gId = first.guide.id;
    await provider1.remove(gId);
    expect(provider1.hasShareKey(fp), isFalse, reason: '删除后指纹不应再命中');

    // 落盘确清：JSON 与 pics 目录都应不存在
    expect(storage.texts.containsKey('guides/$gId.json'), isFalse);
    expect(storage.blobs.containsKey('pics/$gId/cover.jpg'), isFalse);

    // ④ 二次导入同一文件：直接生效（不再被查重拦住），id 全新独立副本
    final parsed2 = ShareService.parseShare(export.bytes);
    expect(parsed2, isNotNull);
    final second =
        await exporter.applyImport(parsed2!);
    expect(second, isNotNull);
    expect(second!.guide.id, isNot(gId), reason: '重导必须拿全新 id');
    expect(second.guide.shareKey, fp);
    expect(second.guide.shared, isTrue);

    // ⑤ 重导后的攻略重新入库 → 指纹再次命中（回到第 ② 步状态，闭环）
    final provider2 = GuidesProvider(repository: guideRepo, guides: const []);
    await provider2.addImported(second.guide);
    expect(provider2.hasShareKey(fp), isTrue);
  });

  test('再次导入同文件（未删除场景）仍可生成独立副本（既有行为保持）', () async {
    final storage = MemoryStorage();
    final exporter = ShareService(storage);
    final export = await exporter.build(
        guide: SeedData.buildDemoGuide(),
        includePhotos: false,
        watermarkText: '');
    final a = await exporter.applyImport(
        ShareService.parseShare(export!.bytes)!);
    final b = await exporter.applyImport(
        ShareService.parseShare(export.bytes)!);
    expect(b!.guide.id, isNot(a!.guide.id));
  });
}
