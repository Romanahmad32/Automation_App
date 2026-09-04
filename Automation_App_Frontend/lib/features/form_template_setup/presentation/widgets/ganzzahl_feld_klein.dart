import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kompaktes Eingabefeld für eine Ganzzahl — vier davon stehen im
/// `DatumsVorbelegungEditor` nebeneinander (Jahre, Monate, Wochen, Tage).
///
/// Bewusst **kein** `GeneralTextField`: das arbeitet auf einem
/// reactive_forms-Control, die Vorbelegung hängt aber an `FieldData` und nicht
/// am Formular der Detailseite. Ein eigenes Control dafür anzulegen hiesse,
/// den Feldnamen-Schlüssel der Seite (`field_0`, …) mit fremden Einträgen zu
/// mischen — die Seite tauscht ihn beim Speichern zurück.
///
/// Leer heisst 0; der Aufrufer liest den Text und parst ihn selbst, damit ein
/// geleertes Feld nicht gleich wieder mit „0" gefüllt wird.
///
/// Die Beschriftung steht als eigener Text **über** dem Feld statt als
/// schwebendes Label im Rahmen: In Feldschriftgrösse (`labelSmall`) blieb sie
/// zu klein, in Zeilenschriftgrösse (`bodyMedium`, wie der Vorlauftext
/// „Vorbelegung: heute +") hätte sie im schmalen Rahmen keinen Platz gehabt,
/// ohne abgeschnitten zu werden. Das Feld selbst bleibt dadurch schlicht:
/// ohne eigenes Label, `isDense`, feste Höhe [feldHoehe] — dieselbe Höhe
/// benutzt `DatumsVorbelegungEditor` für Vorlauftext und Vorschau, damit
/// beide auf der Mitte des Eingaberahmens stehen statt auf der Mitte von
/// Beschriftung und Feld zusammen.
class GanzzahlFeldKlein extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final ValueChanged<String> onChanged;

  const GanzzahlFeldKlein({
    super.key,
    required this.controller,
    required this.labelText,
    required this.onChanged,
  });

  /// Höhe des Eingabefelds, feststehend statt aus dem Innenpolster
  /// hervorgehend — siehe Klassenkommentar.
  static const feldHoehe = 44.0;

  /// Abstand zwischen Beschriftung und Feld, ebenfalls von
  /// `DatumsVorbelegungEditor` mitbenutzt (siehe [feldHoehe]).
  static const beschriftungsAbstand = 4.0;

  static const _feldBreite = 88.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          labelText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: beschriftungsAbstand),
        Tooltip(
          message: 'Anzahl $labelText',
          child: SizedBox(
            width: _feldBreite,
            height: feldHoehe,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
