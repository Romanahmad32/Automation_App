/// Formatiert einen Betrag im deutschen Format mit Tausenderpunkt und
/// Dezimalkomma (z. B. `1234.5` → `1.234,50`), ohne Währungssymbol.
String euroBetrag(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  return '$buffer,${parts[1]}';
}
