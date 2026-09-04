import 'package:flutter/material.dart';

/// Die Zeile unter dem Seitenkopf der Einstellungen: links die Abschnitte zur
/// Auswahl, rechts die eine Aktion des offenen Abschnitts (der
/// Speichern-Knopf).
///
/// Sie ersetzt die frühere `TabBar` **und** die Fußleiste, die für den
/// Speichern-Knopf nötig gewesen wäre. Der Grund ist Platz, und zwar in beide
/// Richtungen: Eine senkrechte Navigationsleiste stünde neben der ohnehin
/// vorhandenen Seitenleiste der App — bei aufgeklappter Leiste 440 px
/// Navigation nebeneinander, fast ein Drittel eines 1440-px-Fensters. Eine
/// waagerechte Zeile kostet dagegen gar keine Breite, und indem sie den
/// Speichern-Knopf gleich mitnimmt, ist sie zusammen niedriger als die alte
/// Reiterleiste (72 px) allein.
///
/// Der Knopf steht damit oben statt am Ende des Formulars — auf einer Seite
/// mit sechs bis sieben Abschnitten ist das der eigentliche Gewinn: Wer oben
/// ein Feld ändert, muss zum Speichern nicht ans Ende scrollen.
///
/// **Jeder Reiter zeichnet diese Zeile selbst** (über [EinstellungenReiter]),
/// statt dass die Seite sie einmal über den Reitern zeichnet. So bleibt der
/// Speichern-Auftrag dort, wo das Formular liegt, das er speichert; weil alle
/// Reiter dieselbe Zeile an derselben Stelle zeichnen und der
/// `TraegeIndexedStack` ohne Bewegung wechselt, sieht man davon nichts.
class EinstellungenAktionszeile extends StatelessWidget {
  /// Rechts in der Zeile, üblicherweise der `SpeichernButton` des Reiters.
  /// `null` heißt: Dieser Abschnitt speichert sofort beim Ändern (Darstellung,
  /// Schadensaufstellung) oder speichert gar nichts (Über).
  final Widget? aktion;

  const EinstellungenAktionszeile({super.key, this.aktion});

  /// Die Abschnitte in der Reihenfolge, in der `SettingsPage` ihre Ansichten
  /// aufhängt. **Beim Umsortieren beides mitpflegen** — hier steht die
  /// Beschriftung, dort die Ansicht, und der Index ist das einzige Band
  /// dazwischen.
  static const List<({IconData icon, String label})> abschnitte = [
    (icon: Icons.business, label: 'Kanzlei'),
    (icon: Icons.table_rows_outlined, label: 'Schadensaufstellung'),
    (icon: Icons.mail_outline, label: 'E-Mail'),
    (icon: Icons.palette_outlined, label: 'Darstellung'),
    (icon: Icons.backup_outlined, label: 'Datensicherung'),
    (icon: Icons.info_outline, label: 'Über'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `maybeOf`, weil die Reiter in den Widgettests einzeln aufgehängt werden
    // — ohne umschließenden Controller bleibt die Abschnittswahl weg und der
    // Reiter ist für sich bedienbar, statt mit einem Fehler auszusteigen.
    final controller = DefaultTabController.maybeOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        // Nur unten eine Linie: Die obere zeichnet bereits die AppBar
        // (`appBarTheme.shape`), zwei davon ergäben einen doppelten Strich.
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          // Bricht die Auswahl auf schmalen Fenstern um, bleibt die Aktion an
          // der ersten Zeile — sie soll nicht mit nach unten rutschen.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: controller == null
                  ? const SizedBox.shrink()
                  : AnimatedBuilder(
                      // Der Controller meldet den Wechsel, die
                      // DefaultTabController-Inherited nicht.
                      animation: controller,
                      builder: (context, _) => _auswahl(controller),
                    ),
            ),
            if (aktion case final knopf?) ...[const SizedBox(width: 16), knopf],
          ],
        ),
      ),
    );
  }

  Widget _auswahl(TabController controller) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (index, abschnitt) in abschnitte.indexed)
          ChoiceChip(
            selected: controller.index == index,
            onSelected: (_) => controller.animateTo(index),
            // **Die eine Stelle ohne Häkchen** (Ausnahme namentlich in
            // `test/architecture/auswahl_sichtbar_test.dart`): Material
            // ersetzt beim gewählten Chip das Symbol durch das Häkchen —
            // ausgerechnet hier ist dieses Symbol aber die Kennung des
            // Abschnitts. Von sechs Symbolen verschwände immer genau das
            // eine, das man gerade ansieht, und die Zeile ruckte bei jedem
            // Wechsel. Getragen wird die Auswahl stattdessen vom Rahmen in
            // der Primärfarbe (1,5 px gegen 1 px blass, siehe
            // `AuswahlThemes.chips`) samt Füllung.
            showCheckmark: false,
            avatar: Icon(abschnitt.icon, size: 18),
            label: Text(abschnitt.label),
          ),
      ],
    );
  }
}
