/// 全局写串行队列：
///
/// 背景：编辑器高频保存（每次改动 `_commit` → `provider.replace` 落盘，均不等待
/// 上一次写完），并发 `writeAsString` 会在同一文件上互相截断/交错，产生
/// 「两段 JSON 拼接」的损坏档（已实际损坏过一篇用户攻略）。
///
/// 队列化后所有落盘写按提交顺序**逐个**执行，任意时刻至多一个写操作在跑，
/// 彻底消除交错；原子替换（临时文件 → 改名）保证文件任何时刻都是完整文档。
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
