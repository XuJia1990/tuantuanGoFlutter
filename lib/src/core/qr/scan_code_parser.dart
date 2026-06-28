enum ScanCodeType { shop, user, pay, couponWriteOff, unknown }

class ParsedScanCode {
  const ParsedScanCode({
    required this.type,
    required this.raw,
    this.parts = const [],
  });

  final ScanCodeType type;
  final String raw;
  final List<String> parts;
}

class ScanCodeParser {
  ParsedScanCode parse(String raw) {
    if (raw.contains('_pay')) {
      return ParsedScanCode(
        type: ScanCodeType.pay,
        raw: raw,
        parts: raw.split('_'),
      );
    }
    final parts = raw.split(',');
    if (raw.contains(',cop')) {
      return ParsedScanCode(
        type: ScanCodeType.couponWriteOff,
        raw: raw,
        parts: parts,
      );
    }
    if (parts.length == 2) {
      return ParsedScanCode(type: ScanCodeType.user, raw: raw, parts: parts);
    }
    if (parts.length == 1 && parts.first.isNotEmpty) {
      return ParsedScanCode(type: ScanCodeType.shop, raw: raw, parts: parts);
    }
    return ParsedScanCode(type: ScanCodeType.unknown, raw: raw, parts: parts);
  }
}
