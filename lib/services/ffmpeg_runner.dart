import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../core/io/storage_adapter.dart';
/// FFmpeg 外部进程封装（视频链路使用）：
/// - **Windows**：随包附带 `ffmpeg.exe`/`ffprobe.exe`
///   `ffmpeg_runtime/`，见 windows/runner/CMakeLists.txt）；
/// - **Android**：接 `ffmpeg_kit_flutter_new`（同一命令字符串两端共用）；
/// - 提取首帧缩略 / 探测时长；转码降质 + 叠水印。
class FFmpegRunner {
  FFmpegRunner._();

  static bool _probed = false;
  static String? _ffmpegExe;
  static String? _ffprobeExe;

  /// 是否可用（决定导入视频时能否出首帧/时长；不可用走占位兜底）
  static bool get available => _ffmpegExe != null && _ffprobeExe != null;

  /// 惰性定位：exe 同目录 `ffmpeg_runtime/` → PATH（where）
  static Future<void> _ensure() async {
    if (_probed) return;
    _probed = true;
    try {
      // 随包目录：exe 旁 ffmpeg_runtime
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final bundledFf = _join(exeDir, 'ffmpeg_runtime', 'ffmpeg.exe');
      final bundledFp = _join(exeDir, 'ffmpeg_runtime', 'ffprobe.exe');
      if (await File(bundledFf).exists() && await File(bundledFp).exists()) {
        _ffmpegExe = bundledFf;
        _ffprobeExe = bundledFp;
        return;
      }
      // PATH 兜底（避免开发期出现找不到文件的情况）
      final where = await Process.run('where.exe', ['ffmpeg']);
      if (where.exitCode == 0) {
        final path = (where.stdout as String).trim().split('\n').first.trim();
        if (path.isNotEmpty) {
          final dir = File(path).parent.path;
          final fp = _join(dir, 'ffprobe.exe');
          if (await File(fp).exists()) {
            _ffmpegExe = path;
            _ffprobeExe = fp;
          }
        }
      }
    } catch (_) {}
  }

  static String _join(String a, [String? b, String? c]) {
    var p = a;
    if (b != null) p = '$p${Platform.pathSeparator}$b';
    if (c != null) p = '$p${Platform.pathSeparator}$c';
    return p;
  }

  /// 惰性定位公开入口（转码器等外部调用方先 ensure 再读句柄）
  static Future<void> ensure() => _ensure();

  /// ffmpeg 可执行文件绝对路径（ensure 之后有效；null=不可用）
  static String? get ffmpegExe => _ffmpegExe;

  /// 探测时长（ms）：ffprobe 输出秒数 CSV；失败返回 null
  static Future<int?> probeDurationMs(String absVideoPath) async {
    await _ensure();
    if (!available) return null;
    try {
      final r = await Process.run(
        _ffprobeExe!,
        ['-v', 'error', '-show_entries', 'format=duration',
         '-of', 'csv=p=0', absVideoPath],
      );
      if (r.exitCode != 0) return null;
      final secs = double.tryParse(
          (r.stdout as String).trim().split('\n').first.trim());
      if (secs == null || secs <= 0) return null;
      return (secs * 1000).round();
    } catch (_) {
      return null;
    }
  }

  /// 探测视频流分辨率（宽,高）：失败返回 null（转码时兜底 1280×720）
  static Future<(int, int)?> probeVideoSize(String absVideoPath) async {
    await _ensure();
    if (!available) return null;
    try {
      final r = await Process.run(
        _ffprobeExe!,
        ['-v', 'error', '-select_streams', 'v:0',
         '-show_entries', 'stream=width,height', '-of', 'csv=p=0',
         absVideoPath],
      );
      if (r.exitCode != 0) return null;
      final parts = (r.stdout as String).trim().split(',');
      final w = int.tryParse(parts.first.trim());
      final h = int.tryParse(parts.length > 1 ? parts[1].trim() : '');
      if (w == null || h == null || w <= 0 || h <= 0) return null;
      return (w, h);
    } catch (_) {
      return null;
    }
  }

  /// 存储根 pics/videos/ 下的临时文件（转码工作区；转码器复用同一目录）
  static Future<File> tempFileInVideosDir(String prefix, String ext) =>
      _tempFile(prefix, ext);

  /// 提取首帧（取 0.2s 处避开黑场）→ 长边 ≤512 JPEG 字节。
  /// 成功返回字节；失败/不可用返回 null（调用方走占位兜底）。
  static Future<Uint8List?> extractFirstFrame(String absVideoPath) async {
    await _ensure();
    if (!available) return null;

    final tmp = await _tempFile('tg_thumb', '.jpg');
    try {
      final r = await Process.run(
        _ffmpegExe!,
        // -hwaccel auto：GPU 解码（d3d11va 等）≈6× 提速 4K 素材首帧提取；
        // 无硬解环境自动回退软解
        ['-y', '-v', 'error', '-hwaccel', 'auto', '-ss', '0.2', '-i',
         absVideoPath,
         '-frames:v', '1',
         // 表达式内的逗号必须转义（\,）——否则被 ffmpeg 解析为滤镜分隔符，报「No such filter」导致提取全部失败
         '-vf',
         'scale=if(gt(iw\\,ih)\\,min(512\\,iw)\\,-2):'
             'if(gt(iw\\,ih)\\,-2\\,min(512\\,ih))',
         '-q:v', '4', tmp.path],
      );
      if (r.exitCode != 0) return null;
      final f = File(tmp.path);
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    } finally {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }

  /// 存储根下临时文件（复用存储根避免权限差异）
  static Future<File> _tempFile(String prefix, String ext) async {
    final root = activeStorage.locationLabel;
    final dir = Directory('$root${Platform.pathSeparator}pics'
        '${Platform.pathSeparator}videos');
    await dir.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return File('${dir.path}${Platform.pathSeparator}'
        '${prefix}_$stamp$ext');
  }
}
