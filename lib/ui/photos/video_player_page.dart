import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/io/storage_adapter.dart';
import '../../data/models/guide.dart';
import '../../l10n/app_localizations.dart';

/// 视频播放页（media_kit）。
/// Windows 用 libmpv、Android 用系统解码栈，都走硬件解码；
/// 按文件路径流式播放，原件不整读内存；
/// 控制条自适应（进度、暂停、音量、全屏由 AdaptiveVideoControls 提供）；
/// 播放失败有明确的错误态，退出时 dispose 释放播放器。
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.relPath,
    this.title = '',
  });

  /// 视频原件相对路径（存储根：media_kit 经 absolutePath 解析后流式播放）
  final String relPath;
  final String title;

  /// 带 PhotoItem 的统一入口（攻略地图 / 查看器等直接 push）
  static void openWith(BuildContext context, PhotoItem p) {
    if (p.isVideo && p.file.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          relPath: p.file,
          title: p.name.isNotEmpty
              ? p.name
              : AppLocalizations.of(context).videoPlayTitle,
        ),
      ));
    }
  }

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  String _error = '';
  bool _isPathError = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.stream.error.listen((msg) {
      if (mounted) setState(() => _error = msg);
    });
    _open();
  }

  Future<void> _open() async {
    String path;
    try {
      path = activeStorage.absolutePath(widget.relPath);
    } catch (e) {
      setState(() {
        _error = '$e';
        _isPathError = true;
      });
      return;
    }
    await _player.open(Media(path), play: true);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          widget.title.isEmpty ? t.videoPlayTitle : widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: _error.isNotEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 44, color: Colors.white54),
                  const SizedBox(height: 12),
                  Text(
                      _isPathError
                          ? t.pathError(_error)
                          : t.playerError(_error),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.btnBack),
                  ),
                ],
              ),
            )
          : Video(
                controller: _controller,
                controls: AdaptiveVideoControls,
              ),
    );
  }
}
