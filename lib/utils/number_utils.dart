/// High-precision formatting utility for thousand separators and file sizes.
class NumberUtils {
  /// Formats an integer with standard thousand separators, e.g. 1234567 -> "1,234,567".
  static String formatInt(int number) {
    final isNegative = number < 0;
    final str = number.abs().toString();
    final buffer = StringBuffer();
    final len = str.length;

    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }

    return isNegative ? '-${buffer.toString()}' : buffer.toString();
  }

  /// Formats a double with thousand separators and decimal places, e.g. 1234.56 -> "1,234.6".
  static String formatDouble(double number, {int decimals = 1}) {
    final parts = number.toStringAsFixed(decimals).split('.');
    final intPart = formatInt(int.parse(parts[0]));
    if (parts.length > 1 && decimals > 0) {
      return '$intPart.${parts[1]}';
    }
    return intPart;
  }

  /// Formats a byte size into a clean readable string with thousand separators.
  static String formatSizeKb(int bytes) {
    return '${formatDouble(bytes / 1024.0, decimals: 1)} KB';
  }

  /// Formats bytes with both KB/MB and full exact byte count in thousand separators.
  static String formatBytesExact(int bytes) {
    if (bytes >= 1024 * 1024) {
      final mb = formatDouble(bytes / (1024.0 * 1024.0), decimals: 2);
      return '$mb MB (${formatInt(bytes)} B)';
    } else if (bytes >= 1024) {
      final kb = formatDouble(bytes / 1024.0, decimals: 1);
      return '$kb KB (${formatInt(bytes)} B)';
    } else {
      return '${formatInt(bytes)} B';
    }
  }
}
