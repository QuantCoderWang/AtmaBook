import 'dart:convert';

/// 损坏 JSON 文本的自愈工具：
///
/// 背景：并发写曾把两段 JSON 拼进同一文件（第一段完整 + 第二段残缺尾巴）。
/// [extractFirstJsonDocument] 用括号深度扫描（识别字符串与转义）找到
/// 首个顶层闭合边界，再校验 parse；成功返回该段原文，失败返回 null。
String? extractFirstJsonDocument(String txt) {
  final s = txt.trimLeft();
  if (s.isEmpty) return null;
  final first = s.codeUnitAt(0);
  if (first != 0x7B && first != 0x5B) return null; // 须以 { 或 [ 开头

  var depth = 0;
  var inStr = false;
  var esc = false;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (inStr) {
      if (esc) {
        esc = false;
      } else if (c == 0x5C) {
        esc = true;
      } else if (c == 0x22) {
        inStr = false;
      }
      continue;
    }
    if (c == 0x22) {
      inStr = true;
      continue;
    }
    if (c == 0x7B || c == 0x5B) {
      depth++;
    } else if (c == 0x7D || c == 0x5D) {
      depth--;
      if (depth == 0) {
        final candidate = s.substring(0, i + 1);
        try {
          final v = jsonDecode(candidate);
          return (v is Map || v is List) ? candidate : null;
        } catch (_) {
          return null; // 首段本身损坏：无法抢救
        }
      }
    }
  }
  return null; // 未找到闭合边界（截断档）
}
