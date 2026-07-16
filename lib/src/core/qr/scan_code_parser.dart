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
    final underlineParts = raw.split('_');
    if (raw.contains('_pay') ||
        (!raw.contains(',') &&
            underlineParts.length >= 2 &&
            underlineParts[0].trim().isNotEmpty &&
            underlineParts[1].trim().isNotEmpty)) {
      return ParsedScanCode(
        type: ScanCodeType.pay,
        raw: raw,
        parts: underlineParts,
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
