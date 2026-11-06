/// Web 桩：没有文件系统，原片模式不可用，这里直接抛错。
library;

Never _unsupported() =>
    throw StateError('原片打包模式不支持 Web（无文件系统，桌面降级存储）');

Future<String> createTempWorkDir(String prefix) => _unsupported();

Future<void> deleteTempWorkDir(String dirPath) => _unsupported();

Future<int> fileSizeBytes(String absPath) => _unsupported();
