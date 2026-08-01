import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/versicherer_ergaenzung.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/vorgangsdaten_feld.dart';
import 'package:flutter/material.dart';

/// Die editierbaren Textfelder des Vorgangsdaten-Formulars (aus
/// `VorgangsdatenForm` ausgelagert). Markiert je Feld die Datenlage:
/// nicht erkannte Angaben („nicht gefunden") in Fehlerfarbe, aus der
/// Versicherer-Wissensbasis ergänzte Werte mit Herkunftshinweis.
class VorgangsdatenFelderListe extends StatelessWidget {
  final Map<VorgangsdatenFeld, TextEditingController> controllers;

  /// Die ursprünglich ausgewerteten Daten (für die „nicht gefunden"-Markierung).
  final ZentralrufReplyData data;

  /// Aus dem Versicherer-Register ergänzte Felder samt Herkunftshinweis.
  final VersichererErgaenzung ergaenzung;

  const VorgangsdatenFelderListe({
    super.key,
    required this.controllers,
    required this.data,
    required this.ergaenzung,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final feld in VorgangsdatenFeld.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextField(
              controller: controllers[feld],
              decoration: InputDecoration(
                labelText: feld.label,
                border: const OutlineInputBorder(),
                isDense: true,
                helperText: _helperText(feld),
                helperStyle: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: _helperFarbe(theme, feld),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Herkunft/Fehlen der Angabe: ergänzte Felder tragen den Registerhinweis,
  /// nicht erkannte Angaben werden deutlich markiert.
  String? _helperText(VorgangsdatenFeld feld) {
    if (ergaenzung.werte.containsKey(feld)) return ergaenzung.hinweis;
    return feld.wert(data) == null ? 'nicht gefunden' : null;
  }

  Color _helperFarbe(ThemeData theme, VorgangsdatenFeld feld) =>
      ergaenzung.werte.containsKey(feld)
      ? theme.colorScheme.tertiary
      : theme.colorScheme.error;
}
