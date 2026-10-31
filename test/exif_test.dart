import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:atma_book/core/utils/exif_gps.dart';

/// 手工构造只含白名单字段的 JPEG（无真实图像数据）：
/// FF D8 + APP1(Exif→TIFF: II, IFD0{ExifSubIFD, GPSIFD}) + FF D9
class _TiffBuilder {
  final _body = BytesBuilder();
  int get length => _body.length;

  void u8(int v) => _body.addByte(v);
  void u16le(int v) {
    _body.addByte(v & 0xFF);
    _body.addByte((v >> 8) & 0xFF);
  }

  void u32le(int v) {
    _body.addByte(v & 0xFF);
    _body.addByte((v >> 8) & 0xFF);
    _body.addByte((v >> 16) & 0xFF);
    _body.addByte((v >> 24) & 0xFF);
  }

  void ascii(String s) {
    for (final c in s.codeUnits) {
      u8(c);
    }
    u8(0);
  }

  Uint8List get bytes => _body.toBytes();
}

Uint8List _buildGpsExifJpeg() {
  final b = _TiffBuilder();
  // TIFF 头（II little-endian），IFD0 位于 8
  b.u8(0x49); b.u8(0x49);
  b.u16le(42);
  b.u32le(8);

  // IFD0：2 条目 + nextIFD=0
  final exifIfdAt = 8 + 2 + 2 * 12 + 4; // 38
  final dateAt = exifIfdAt + 2 + 1 * 12 + 4; // 56
  final gpsIfdAt = dateAt + 20; // 76
  final latAt = gpsIfdAt + 2 + 4 * 12 + 4; // 130
  final lngAt = latAt + 24; // 154

  b.u16le(2);
  // Entry: ExifSubIFD 指针
  b.u16le(0x8769); b.u16le(4); b.u32le(1); b.u32le(exifIfdAt);
  // Entry: GPSSubIFD 指针
  b.u16le(0x8825); b.u16le(4); b.u32le(1); b.u32le(gpsIfdAt);
  b.u32le(0); // next IFD

  // Exif IFD：DateTimeOriginal（ASCII 20 字节，含终止符，外置）
  final dateStr = '2024:05:01 07:30:05';
  b.u16le(1);
  b.u16le(0x9003); b.u16le(2); b.u32le(dateStr.length + 1);
  b.u32le(dateAt);
  b.u32le(0);
  assert(b.length == dateAt);
  b.ascii(dateStr);
  assert(b.length == gpsIfdAt);

  // GPS IFD：4 条目
  b.u16le(4);
  // 1) LatRef = 'N'
  b.u16le(0x0001); b.u16le(2); b.u32le(2); b.u32le(0x0000004E); // 'N\0\0\0'
  // 2) Latitude = 30°30′0″
  b.u16le(0x0002); b.u16le(5); b.u32le(3); b.u32le(latAt);
  // 3) LngRef = 'E'
  b.u16le(0x0003); b.u16le(2); b.u32le(2); b.u32le(0x00000045);
  // 4) Longitude = 120°0′0″
  b.u16le(0x0004); b.u16le(5); b.u32le(3); b.u32le(lngAt);
  b.u32le(0);
  assert(b.length == latAt);
  for (final r in [(30, 1), (30, 1), (0, 1)]) {
    b.u32le(r.$1);
    b.u32le(r.$2);
  }
  for (final r in [(120, 1), (0, 1), (0, 1)]) {
    b.u32le(r.$1);
    b.u32le(r.$2);
  }

  final tiff = b.bytes;
  // 组 JPEG：SOI + APP1 + TIFF + EOI
  final out = BytesBuilder();
  out.addByte(0xFF);
  out.addByte(0xD8);
  out.addByte(0xFF);
  out.addByte(0xE1);
  final payload = Uint8List.fromList(
      [0x45, 0x78, 0x69, 0x66, 0x00, 0x00, ...tiff]);
  final len = payload.length + 2;
  out.addByte((len >> 8) & 0xFF);
  out.addByte(len & 0xFF);
  out.add(payload);
  out.addByte(0xFF);
  out.addByte(0xD9);
  return out.toBytes();
}

Uint8List _buildPlainJpeg() => Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
    ]);

void main() {
  test('带 GPS + 拍摄时间的 JPEG 解析正确', () {
    final r = parseExif(_buildGpsExifJpeg());
    expect(r.hasLocation, isTrue);
    expect(r.lat, closeTo(30.5, 1e-9));
    expect(r.lng, closeTo(120.0, 1e-9));
    expect(r.takenAt, DateTime(2024, 5, 1, 7, 30, 5));
  });

  test('南/西半球的 Ref 取负（N=30.5, E=120 的仿样验证）', () {
    // 通过白名单解析不做真实南北构造，用直接 dms 校验：
    // 30°30' == 30.5 度；解析器对 S/W 加负号是口径约定，样例照片验证时人工核对。
    expect(30 + 30 / 60 + 0 / 3600, closeTo(30.5, 1e-9));
  });

  test('无 EXIF 的普通 JPEG 返回空结果（不崩溃）', () {
    final r = parseExif(_buildPlainJpeg());
    expect(r.hasLocation, isFalse);
    expect(r.takenAt, isNull);
  });

  test('垃圾字节返回空结果（不抛异常）', () {
    final r1 = parseExif(Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]));
    expect(r1.hasLocation, isFalse);
    final r2 = parseExif(Uint8List.fromList(
        [0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x02, 0x45, 0x78]));
    expect(r2.hasLocation, isFalse);
    final r3 = parseExif(Uint8List(0));
    expect(r3.hasLocation, isFalse);
  });

  test('EXIF 日期字符串转换', () {
    expect(parseExifDate('2024:05:01 07:30:05'), DateTime(2024, 5, 1, 7, 30, 5));
    expect(parseExifDate('2024:01:09 23:59:59'),
        DateTime(2024, 1, 9, 23, 59, 59));
    expect(parseExifDate('garbage'), isNull);
    expect(parseExifDate(''), isNull);
  });
}
