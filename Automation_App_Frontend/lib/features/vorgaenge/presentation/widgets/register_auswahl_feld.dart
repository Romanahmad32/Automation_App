import 'package:flutter/material.dart';

/// Ein Auswahlfeld der Registerleiste — Reihenfolge, Von, Bis, Stand,
/// Rechtsgebiet.
///
/// Eigener Baustein, weil es fünf davon nebeneinander gibt: Wären es fünf
/// Fassungen desselben `DropdownButtonFormField`, träfe die nächste Änderung an
/// Höhe, Polster oder Breitenmessung zwei davon und ließe die anderen stehen.
///
/// Bewusst kein Chip je Wert: Stand, Rechtsgebiet und die Jahrgänge haben
/// zusammen weit über zwanzig Ausprägungen, und so viele Chips wären die Leiste
/// selbst, nicht mehr ihr Inhalt.
class RegisterAuswahlFeld<T> extends StatelessWidget {
  /// Die Beschriftung über dem Feld („Von", „Stand").
  final String hinweis;

  final T? wert;
  final List<T> werte;
  final String Function(T) beschriftung;
  final ValueChanged<T?> onGewaehlt;

  /// Beschriftung eines ersten Eintrags ohne Wert („Alle Zeilen") — er setzt
  /// die Auswahl zurück. Null lässt ihn weg: Reihenfolge, Von und Bis haben
  /// immer einen Wert, und ein leerer Eintrag verspräche dort etwas anderes.
  final String? alleText;

  const RegisterAuswahlFeld({
    super.key,
    required this.hinweis,
    required this.wert,
    required this.werte,
    required this.beschriftung,
    required this.onGewaehlt,
    this.alleText,
  });

  @override
  Widget build(BuildContext context) {
    final texte = [?alleText, ...werte.map(beschriftung)];
    return SizedBox(
      width: _breite(context, texte),
      child: DropdownButtonFormField<T?>(
        initialValue: wert,
        isDense: true,
        // Ohne `isExpanded` bekommt der Text hier keine Breitenbegrenzung von
        // seiner Zeile und lief mit der angehobenen Schrift (Issue #57) unter
        // den Pfeil hinaus, statt sich einzuordnen — `_breite` bemisst das Feld
        // zwar so, dass der längste Eintrag ohnehin passt, aber erst
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
          if (alleText != null)
            DropdownMenuItem<T?>(
              value: null,
              child: Text(alleText!, overflow: TextOverflow.ellipsis),
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
  /// Katalog — sie reichte für „Alle Rechtsgebiete" bei der angehobenen
  /// Schrift (Issue #57) nicht mehr, und ein neuer, langer Katalogeintrag
  /// hätte dieselbe Lücke wieder aufgerissen. Gemessen wird mit
  /// `titleMedium`, dem Stil, den `DropdownButtonFormField` ohne eigenes
  /// `style` selbst für seinen Text verwendet (siehe `dropdown.dart`,
  /// `_textStyle`).
  double _breite(BuildContext context, List<String> texte) {
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
    const mindestbreite = 120.0;
    final breite = textBreite + chrome;
    return breite < mindestbreite ? mindestbreite : breite;
  }
}
