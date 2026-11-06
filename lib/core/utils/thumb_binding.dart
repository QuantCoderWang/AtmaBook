/// 解析媒体条目的缩略图配对（条目自带 file/thumb 字段）。
///
/// 配对规则只在定义这一处：数据里的 `wall_photos.json` 条目和攻略内的
/// `PhotoItem` 都自带 `file` + `thumb`，渲染时统一走 [resolveThumbBinding]
/// 或各模型的 `thumbBinding` getter，不依赖数组位序、index 或共享缓存去猜。
///
/// 返回规则：
/// - `thumb` 非空：直接用 thumb（视频取首帧，照片取派生缩略）；
/// - `thumb` 为空：照片回退原图 `file`（旧数据都是这么存的）；
///   视频返回 `''`，不会拿视频原件当图片解码，
///   缺首帧时渲染端走占位块。
library;

/// 解析一条媒体的缩略绑定（配对口径只此一处；参数都取自条目自身）。
String resolveThumbBinding({
  required bool isVideo,
  required String thumb,
  required String file,
}) {
  if (thumb.isNotEmpty) return thumb;
  return isVideo ? '' : file;
}

/// 渲染层「数据身份键」：uid + 配对拼装，Widget diff 按这个匹配。
/// 条目挪位 / 新条目插顶 / 缩放重排都不会让缓存串绑；配对更新
/// （file/thumb 落盘变化）同样会让键变化，强制按新配对重建。
/// 约定：binding 为空串时键以 `|` 结尾——和任何非空路径都不会撞车
/// （相对路径不会为空，也不会以竖线开头）。
String thumbBindingKey(String uid, String binding) => 'tb|$uid|$binding';
