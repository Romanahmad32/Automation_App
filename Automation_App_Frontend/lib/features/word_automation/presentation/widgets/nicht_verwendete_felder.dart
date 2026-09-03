import 'package:flutter/material.dart';

/// Die Felder der Vorlage, die das Schreiben aus der gerade gewählten
/// Word-Datei nicht einsetzt — eingeklappt statt oben mitgezeigt (#82).
///
/// Ohne diese Karte stehen sie gleichrangig zwischen den Feldern, auf die es
/// ankommt: Wer sie ausfüllt, tippt in den Papierkorb, denn ohne Platzhalter in
/// der aktiven Datei verwirft die Ersetzung den Wert wortlos.
///
/// **Eingeklappt, nicht entfernt** — und das ist keine Zurückhaltung, sondern
/// der Tippstand: Die Controls bleiben in der `FormGroup`, damit
/// `onWerteGeaendert` weiter deren vollständigen Stand meldet. Fiele ein Feld
/// aus der Gruppe, fiele sein Wert beim nächsten Tastendruck aus dem Entwurf —
/// wer das HGN-Schreiben ausfüllt, zur Auflistungs-Fassung wechselt und
/// zurückkommt, verlöre die Eingaben der jeweils anderen Seite.
///
/// Gestaltet wie die anderen aufklappbaren Flächen der App
/// (`MailboxOriginaltextPanel`, `MandantCard`): eigene Karte in der Kartenfarbe
/// des Themes, eine Zeile Untertitel. Die Karte ist nötig, damit sich der
/// Bereich von den grau gefüllten Eingabefeldern abhebt — ein getönter
/// Hintergrund ginge zwischen ihnen unter. Die Akzentfarbe des
/// `VorgangsdatenHinweis` bekommt sie aber nicht: Dies ist kein Befund, auf den
/// der Anwalt reagieren soll, sondern etwas, das ihm aus dem Weg geht.
///
/// **Kein `leading`-Icon** — anders als die beiden genannten Panels, aber wie
/// die drei anderen `ExpansionTile` *innerhalb* eines Formulars
/// (`zuordnungs_dialog`, `import_datei_auswahl`, `damage_listing_form`). Es
/// kostete 40 px, und die reichen in der 450 px schmalen Spalte des
/// Ausfüllschritts über den Zeilenumbruch des Titels.
class NichtVerwendeteFelder extends StatelessWidget {
  /// Die fertig gebauten Feldzeilen. Wie eine Zeile aussieht (Eingabefeld,
  /// Stift daneben), bleibt Sache des Formulars — hier wird nur zugeklappt.
  final List<Widget> felder;

  const NichtVerwendeteFelder({super.key, required this.felder});

  /// Dieselbe Rundung wie die Karte, ohne eigene Linie: Das `ExpansionTile`
  /// zöge im aufgeklappten Zustand sonst seine Vorgabe-Trennlinien quer über
  /// den Kartenrahmen (derselbe Grund wie bei `MandantCard.kartenForm`).
  static const RoundedRectangleBorder _kartenForm = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    side: BorderSide.none,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: _kartenForm,
        collapsedShape: _kartenForm,
        title: Text(
          felder.length == 1
              ? '1 Feld, das dieses Schreiben nicht verwendet'
              : '${felder.length} Felder, die dieses Schreiben nicht verwendet',
        ),
        // Eine Zeile, nicht zwei: zugeklappt soll der Block flach bleiben.
        subtitle: Text(
          'Gehören zur anderen Fassung der Vorlage.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        // Die Folge steht innen statt im Untertitel: Zugeklappt soll die Zeile
        // in einem Blick lesbar sein, und gelesen werden muss der Satz genau
        // dann, wenn jemand aufklappt, um doch etwas einzutragen.
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text(
                'Was hier eingetragen wird, erscheint in diesem Schreiben '
                'nicht — bleibt aber für die andere Fassung erhalten.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              ...felder,
            ],
          ),
        ],
      ),
    );
  }
}
