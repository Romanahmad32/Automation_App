import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:material_ui/material_ui.dart';

/// Balken und „54 von 92 MB“ im Dialog, während der Dienst lädt (2b).
///
/// Ohne bekannte Größe läuft der Balken unbestimmt — eine erfundene Zahl
/// wäre schlimmer als keine.
class AktualisierungsFortschritt extends StatelessWidget {
  const AktualisierungsFortschritt({required this.stand, super.key});

  final AktualisierungsStand stand;

  static const int _mebibyte = 1024 * 1024;

  /// „54 von 92 MB“. Unter zehn MB mit einer Nachkommastelle, sonst stünde
  /// bei der kleinen Datei des Testmodus lange „0 von 1 MB“ da.
  static String mengenText(int geladen, int? gesamt) {
    String mb(int bytes, {required bool aufrunden}) {
      final wert = bytes / _mebibyte;
      if ((gesamt ?? bytes) >= 10 * _mebibyte) {
        return (aufrunden ? wert.round() : wert.floor()).toString();
      }
      return wert.toStringAsFixed(1).replaceAll('.', ',');
    }

    if (gesamt == null) return '${mb(geladen, aufrunden: false)} MB geladen';
    return '${mb(geladen, aufrunden: false)} von '
        '${mb(gesamt, aufrunden: true)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        LinearProgressIndicator(
          value: stand.anteil,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        Text(
          mengenText(stand.geladenBytes, stand.gesamtBytes),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
