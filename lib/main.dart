import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/io/storage_adapter.dart';
import 'data/repos/guide_repository.dart';
import 'services/video_thumb_backfill.dart';
import 'state/guides_provider.dart';
import 'state/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // 初始化media_kit播放器（新增视频功能）

  final storage = await initStorage();
  final guideRepo = GuideRepository(storage);
  final guides = await guideRepo.loadAll();
  // 视频首帧缩略自动补齐（有缺则提取+回写，无缺则略过；
  // 内部先FFmpegRunner.ensure，之后会话available=true再生效导出视频功能）
  await VideoThumbBackfill.run(guides: guides, guideRepo: guideRepo);

  final covers = await guideRepo.loadCovers(guides);
  final settings = await AppSettings.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => GuidesProvider(
            repository: guideRepo,
            guides: guides,
            covers: covers,
          ),
        ),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: const AtmaBookApp(),
    ),
  );
}
