/// 缩略图绑定锁——「文件名 ↔ 缩略图名」数据口径的唯一定义点。
///
/// 锁定口径：每条媒体条目在数据模型里**自带** `file` + `thumb`
/// 配对字段（数据 `wall_photos.json` 条目与攻略内 `PhotoItem` 均如此落盘），
/// 渲染一律经 [resolveThumbBinding]（或各模型同口径 getter `thumbBinding`）
/// 按条目自身字段解析配对，绝不依赖数组位序、index 或共享缓存推断。
///
/// 返回值语义：
/// - `thumb` 非空 → 锁定使用 thumb（视频 = 首帧缩略 / 照片 = 派生缩略）；
/// - `thumb` 为空：照片 → 原图 `file` 即缩略（历史数据口径）；
///   视频 → `''`（**绝不把视频原件当图片解码**，缺首帧时渲染端走占位块）。
library;

/// 解析一条媒体的「锁定缩略绑定」（越少参数越不可能搞错——全部取自条目自身）。
String resolveThumbBinding({
  required bool isVideo,
  required String thumb,
  required String file,
}) {
  if (thumb.isNotEmpty) return thumb;
  return isVideo ? '' : file;
}

/// 渲染层「数据身份键」：uid + 锁定配对拼装，Widget diff 按此匹配——
/// 条目挪位 / 新条目插顶 / 缩放重排永不引发缓存串绑；配对更新
/// （file/thumb 落盘变化）同样会使键变化 → 强制按新配对重建。
/// 约定：binding 为空串时键以 `|` 结尾——与任何非空路径配对天然不撞车
/// （相对路径不会为空，也不会以竖线开头）。
String thumbBindingKey(String uid, String binding) => 'tb|$uid|$binding';
