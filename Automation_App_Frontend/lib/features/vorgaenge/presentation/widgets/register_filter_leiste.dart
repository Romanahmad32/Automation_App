import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:flutter/material.dart';

/// Die Filterleiste über dem Register (§6.2): Jahrgang, Status, Rechtsgebiet.
///
/// Nötig, seit das Register **alle** Vorgänge führt und nicht mehr nur die
/// abgeschlossenen — bei ein paar hundert Zeilen ist „alles zeigen" ohne
/// Einschränkung keine Ansicht mehr.
///
/// Die Rechtsgebiets-Auswahl kommt aus dem Sachgebietskatalog (§7.1) plus dem,
/// was nur im Bestand vorkommt ([RegisterFilter.rechtsgebiete]) — der Bestand
/// bleibt also auch filterbar, wenn der Katalog nicht lädt; [katalogFehlt]
/// macht das dann sichtbar statt still.
///
/// Die Auswahl wirkt nur auf den Bildschirm. Was in der Spiegeldatei landet,
/// steht in den Einstellungen; der Hinweis darauf steht in der
/// `RegisterSpiegelLeiste` darunter, damit niemand vom Bildschirm auf die Datei
/// schließt.
class RegisterFilterLeiste extends StatelessWidget {
  final RegisterFilter filter;
  final List<Vorgang> alle;
  final ValueChanged<RegisterFilter> onGeaendert;

  /// Die Rechtsgebiete des Katalogs in Katalogreihenfolge; leer, solange der
  /// Katalog lädt oder nicht erreichbar ist.
  final List<String> katalog;

  /// Ob der Katalog nicht geladen werden konnte — dann filtert die Leiste nur
  /// über die Bestandswerte und sagt das dazu ([onKatalogErneut] lädt nach).
  final bool katalogFehlt;
  final VoidCallback? onKatalogErneut;

  const RegisterFilterLeiste({
    super.key,
    required this.filter,
    required this.alle,
    required this.onGeaendert,
    this.katalog = const [],
    this.katalogFehlt = false,
    this.onKatalogErneut,
  });

  @override
  Widget build(BuildContext context) {
    final jahre = RegisterFilter.jahrgaenge(alle);
    final rechtsgebiete = RegisterFilter.rechtsgebiete(alle, katalog: katalog);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final jahr in jahre)
          FilterChip(
            label: Text(jahr),
            selected: filter.jahr == jahr,
            onSelected: (gewaehlt) => onGeaendert(
              filter.mit(jahr: gewaehlt ? jahr : null, jahrLoeschen: !gewaehlt),
            ),
          ),
        if (jahre.isNotEmpty) const SizedBox(width: 8),
        _auswahl<VorgangStatus>(
          context,
          hinweis: 'Status',
          wert: filter.status,
          werte: VorgangStatus.values,
          beschriftung: (status) => status.displayName,
          onGewaehlt: (status) => onGeaendert(
            filter.mit(status: status, statusLoeschen: status == null),
          ),
        ),
        _auswahl<String>(
          context,
          hinweis: 'Rechtsgebiet',
          wert: filter.rechtsgebiet,
          werte: rechtsgebiete,
          beschriftung: (gebiet) => gebiet,
          onGewaehlt: (gebiet) => onGeaendert(
            filter.mit(
              rechtsgebiet: gebiet,
              rechtsgebietLoeschen: gebiet == null,
            ),
          ),
        ),
        if (katalogFehlt)
          SizedBox(
            width: 420,
            child: Row(
              children: [
                const Expanded(
                  child: FehlerHinweis(
                    nachricht:
                        'Sachgebietskatalog nicht geladen — die Auswahl zeigt '
                        'nur, was im Bestand vorkommt.',
                  ),
                ),
                if (onKatalogErneut != null)
                  TextButton(
                    onPressed: onKatalogErneut,
                    child: const Text('Erneut versuchen'),
                  ),
              ],
            ),
          ),
        if (!filter.istLeer)
          TextButton.icon(
            onPressed: () => onGeaendert(RegisterFilter.alle),
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Filter zurücksetzen'),
          ),
      ],
    );
  }

  /// Ein Auswahlfeld, dessen erster Eintrag „alle" ist. Bewusst kein Chip je
  /// Wert: Status und Rechtsgebiet haben zusammen über zwanzig Ausprägungen,
  /// und so viele Chips wären die Leiste selbst, nicht mehr ihr Inhalt.
  Widget _auswahl<T>(
    BuildContext context, {
    required String hinweis,
    required T? wert,
    required List<T> werte,
    required String Function(T) beschriftung,
    required ValueChanged<T?> onGewaehlt,
  }) {
    final allesText = 'Alle ${hinweis.toLowerCase()}';
    return SizedBox(
      width: _dropdownBreite(context, [allesText, ...werte.map(beschriftung)]),
      child: DropdownButtonFormField<T?>(
        initialValue: wert,
        isDense: true,
        // Ohne `isExpanded` bekommt der Text hier keine Breitenbegrenzung von
        // seiner Zeile und lief mit der angehobenen Schrift (Issue #57) unter
        // den Pfeil hinaus, statt sich einzuordnen — `_dropdownBreite` bemisst
        // das Feld zwar so, dass der längste Eintrag ohnehin passt, aber erst
        // `isExpanded` macht das eine Zusicherung statt eines Zufalls.
        isExpanded: true,
        decoration: InputDecoration(
          labelText: hinweis,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: [
          DropdownMenuItem<T?>(
            value: null,
            child: Text(allesText, overflow: TextOverflow.ellipsis),
          ),
          for (final eintrag in werte)
            DropdownMenuItem<T?>(
              value: eintrag,
              child: Text(
                beschriftung(eintrag),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onGewaehlt,
      ),
    );
  }

  /// Breite, die den längsten Eintrag (samt „Alle …") ohne Kürzung zeigt.
  /// Eine feste Breite passte nicht mehr zu jeder Schriftgröße und jedem
  /// Katalog — sie reichte für „Alle rechtsgebiet" bei der angehobenen
  /// Schrift (Issue #57) nicht mehr, und ein neuer, langer Katalogeintrag
  /// hätte dieselbe Lücke wieder aufgerissen. Gemessen wird mit
  /// `titleMedium`, dem Stil, den `DropdownButtonFormField` ohne eigenes
  /// `style` selbst für seinen Text verwendet (siehe `dropdown.dart`,
  /// `_textStyle`).
  double _dropdownBreite(BuildContext context, List<String> texte) {
    final style = Theme.of(context).textTheme.titleMedium;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      // Ohne die ambiente Textskala misst das Feld enger, als es zeichnet,
      // sobald Windows die Schrift vergrößert — der gerenderte Dropdown-Text
      // nutzt genau diese Skala über `MediaQuery.textScalerOf`.
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    var textBreite = 0.0;
    try {
      for (final text in texte) {
        painter.text = TextSpan(text: text, style: style);
        painter.layout();
        if (painter.width > textBreite) textBreite = painter.width;
      }
    } finally {
      painter.dispose();
    }
    // Innenpolster (12+12) + Pfeil samt Abstand + Sicherheitszuschlag —
    // `isExpanded` würde einen zu knappen Wert notfalls per Ellipsis auffangen,
    // soll das im Regelfall aber nicht müssen.
    const chrome = 88.0;
    const mindestbreite = 160.0;
    final breite = textBreite + chrome;
    return breite < mindestbreite ? mindestbreite : breite;
  }
}
