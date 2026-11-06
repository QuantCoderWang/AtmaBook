import 'dart:typed_data';

/// EXIF 解析结果（GPS + 拍摄时间白名单）
class ExifData {
  const ExifData({this.lat, this.lng, this.takenAt});

  final double? lat;
  final double? lng;
  final DateTime? takenAt;

  bool get hasLocation => lat != null && lng != null;
}

/// 纯 Dart JPEG EXIF 白名单解析（无第三方依赖）：
/// 只读取 APP1 → TIFF → GPS 子 IFD（0x8825）的
/// #1/#2 纬度、#3/#4 经度，以及 Exif 子 IFD（0x8769）的
/// #0x9003 DateTimeOriginal。其余标签一律忽略，遇到畸形数据返回空结果。
ExifData parseExif(Uint8List bytes) {
  try {
    final tiff = _locateTiff(bytes);
    if (tiff == null) return const ExifData();
    final r = _TiffReader(tiff);
    if (r.magic != 42) return const ExifData();

    var gpsIfd = -1;
    var exifIfd = -1;
    _walkIfd(r, r.ifd0Offset, (tag, reader, entryBase) {
      if (tag == 0x8825) {
        gpsIfd = reader.valueUint32(entryBase);
      } else if (tag == 0x8769) {
        exifIfd = reader.valueUint32(entryBase);
      }
    });

    double? lat;
    double? lng;
    DateTime? takenAt;

    if (gpsIfd > 0) {
      String latRef = 'N';
      String lngRef = 'E';
      final latRat = <(int, int)>[];
      final lngRat = <(int, int)>[];
      _walkIfd(r, gpsIfd, (tag, reader, e) {
        switch (tag) {
          case 0x0001: // GPSLatitudeRef（ASCII 2 字节，内联）
            latRef = reader.asciiInline(e);
          case 0x0003:
            lngRef = reader.asciiInline(e);
          case 0x0002:
            latRat.addAll(reader.rationals(e));
          case 0x0004:
            lngRat.addAll(reader.rationals(e));
        }
      });
      if (latRat.length >= 3) lat = _dms(latRat) * (latRef == 'S' ? -1 : 1);
      if (lngRat.length >= 3) lng = _dms(lngRat) * (lngRef == 'W' ? -1 : 1);
      // 合理性校验：越界视为无定位
      if (lat != null && (lat.abs() > 90)) lat = null;
      if (lng != null && (lng.abs() > 180)) lng = null;
    }

    if (exifIfd > 0) {
      String? raw;
      _walkIfd(r, exifIfd, (tag, reader, e) {
        if (tag == 0x9003) raw = reader.asciiValue(e);
      });
      takenAt = parseExifDate(raw ?? '');
    }

    return ExifData(lat: lat, lng: lng, takenAt: takenAt);
  } catch (_) {
    return const ExifData();
  }
}

double _dms(List<(int, int)> parts) {
  final d = parts[0].$1 / parts[0].$2;
  final m = parts.length > 1 ? parts[1].$1 / parts[1].$2 : 0.0;
  final s = parts.length > 2 ? parts[2].$1 / parts[2].$2 : 0.0;
  return d + m / 60 + s / 3600;
}

/// 找到 APP1 Exif 段并返回 TIFF 头（去掉 6 字节 "Exif\0\0"）
Uint8List? _locateTiff(Uint8List b) {
  if (b.length < 12) return null;
  if (b[0] != 0xFF || b[1] != 0xD8) return null; // JPEG SOI
  var i = 2;
  while (i + 4 <= b.length && b[i] == 0xFF) {
    final marker = b[i + 1];
    if (marker == 0x01 ||
        marker == 0xD8 ||
        (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2; // 无长度段
      continue;
    }
    if (marker == 0xDA) break; // 扫描数据开始，其后无 EXIF
    final len = ((b[i + 2] << 8) | b[i + 3]);
    if (len < 2) break;
    if (marker == 0xE1 && i + 10 <= b.length) {
      const hdr = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
      var match = true;
      for (var k = 0; k < 6; k++) {
        if (b[i + 4 + k] != hdr[k]) {
          match = false;
          break;
        }
      }
      if (match) {
        return Uint8List.sublistView(b, i + 10, i + 2 + len);
      }
    }
    i += 2 + len;
  }
  return null;
}

/// 遍历 IFD 的全部条目（tag, reader, 条目基址）
void _walkIfd(
    _TiffReader r, int offset, void Function(int, _TiffReader, int) visit) {
  if (offset <= 0 || offset + 2 > r.bytes.length) return;
  final count = r.u16(offset);
  for (var k = 0; k < count; k++) {
    final e = offset + 2 + k * 12;
    if (e + 12 > r.bytes.length) return;
    visit(r.u16(e), r, e);
  }
}

/// TIFF 字节序读取器
class _TiffReader {
  _TiffReader(this.bytes) {
    bigEndian = bytes.length >= 2 && bytes[0] == 0x4D && bytes[1] == 0x4D;
  }

  final Uint8List bytes;
  late final bool bigEndian;

  int get magic => bytes.length >= 4 ? u16(2) : 0;
  int get ifd0Offset => u32(4);

  int u16(int o) {
    final hi = bytes[o], lo = bytes[o + 1];
    return bigEndian ? (hi << 8) | lo : (lo << 8) | hi;
  }

  int u32(int o) {
    final b0 = bytes[o], b1 = bytes[o + 1], b2 = bytes[o + 2], b3 = bytes[o + 3];
    return bigEndian
        ? (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
        : (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
  }

  /// 条目内联值（≤4 字节域）按字节序读为 uint32（LONG 子 IFD 指针用）
  int valueUint32(int e) => u32(e + 8);

  String asciiInline(int e) {
    final c = u32(e + 4);
    var s = '';
    for (var i = 0; i < c && i < 4; i++) {
      final ch = bytes[e + 8 + i];
      if (ch == 0) break;
      s += String.fromCharCode(ch);
    }
    return s;
  }

  /// ASCII（可能超出内联，需要外部偏移）
  String asciiValue(int e) {
    final type = u16(e + 2);
    final cnt = u32(e + 4);
    final base = type == 2 && cnt <= 4 ? e + 8 : u32(e + 8);
    var s = '';
    for (var i = 0; i < cnt && base + i < bytes.length; i++) {
      final ch = bytes[base + i];
      if (ch == 0) break;
      s += String.fromCharCode(ch);
    }
    return s;
  }

  /// RATIONAL / SRATIONAL 列表（num, den 对）
  List<(int, int)> rationals(int e) {
    final cnt = u32(e + 4);
    final base = u32(e + 8);
    final out = <(int, int)>[];
    for (var i = 0; i < cnt; i++) {
      final o = base + i * 8;
      if (o + 8 > bytes.length) break;
      out.add((u32(o), u32(o + 4)));
    }
    return out;
  }
}

/// 「YYYY:MM:DD HH:MM:SS」（EXIF 日期格式）→ DateTime；失败返回 null
DateTime? parseExifDate(String raw) {
  final parts = raw.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return null;
  final d = parts[0].split(':');
  final t = parts.length > 1 ? parts[1].split(':') : const <String>[];
  if (d.length < 3) return null;
  final y = int.tryParse(d[0]),
      mo = int.tryParse(d[1]),
      da = int.tryParse(d[2]);
  if (y == null || mo == null || da == null) return null;
  final h = t.isNotEmpty ? int.tryParse(t[0]) ?? 0 : 0;
  final mi = t.length > 1 ? int.tryParse(t[1]) ?? 0 : 0;
  final se = t.length > 2 ? int.tryParse(t[2]) ?? 0 : 0;
  try {
    return DateTime(y, mo, da, h, mi, se);
  } catch (_) {
    return null;
  }
}
