/// 全局写串行队列。
///
/// 编辑器高频保存（每次改动 `_commit` → `provider.replace` 落盘，都不等上一次
/// 写完），并发 `writeAsString` 会在同一文件上互相截断/交错，产出「两段 JSON
/// 拼接」的损坏档——这件事实际损坏过一篇用户攻略。
///
/// 队列化后写盘按提交顺序逐个执行，同一时间只有一个写操作在跑，
/// 交错没有了；原子替换（临时文件 → 改名）保证文件任何时刻都是完整文档。
class WriteQueue {
  WriteQueue._();
  static final WriteQueue instance = WriteQueue._();

  Future<void> _tail = Future<void>.value();

  /// 入队一个写任务；任务内部自行负责错误处理（错误不上抛，避免断链）。
  /// 返回本任务实际完成后的 Future。
  Future<void> enqueue(Future<void> Function() job) {
    final done = _tail.then((_) => job(), onError: (_) {});
    _tail = done;
    return done;
  }

  /// 等待排队中的全部写操作完成（测试 / 退出前刷新用）。
  Future<void> get drained => _tail;
}
