import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_reihenfolge.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_auswahl_feld.dart';
import 'package:flutter/material.dart';

/// Die Filterleiste über dem Register (§6.2): Reihenfolge, Jahrgangsspanne,
/// Stand, Rechtsgebiet.
///
/// Nötig, seit das Register **alle** Zeilen führt — laufende Vorgänge,
/// abgeschlossene und die übernommene Historie der Kanzlei. Bei tausenden
/// Zeilen ist „alles zeigen" ohne Einschränkung keine Ansicht mehr.
///
/// Die Jahrgänge stehen als **Spanne** und nicht mehr als Chip je Jahr: Ein
/// Registerbuch ab 2018 ergab eine Chipreihe, die breiter war als die Tabelle
/// darunter, und beantwortete die häufigste Frage („die letzten drei Jahre")
/// gar nicht. Zwei Felder „Von" und „Bis" sagen dasselbe in einer Zeile.
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
  final List<RegisterZeile> alle;
  final ValueChanged<RegisterFilter> onGeaendert;

  /// Die Leserichtung. Kein Teil des Filters — sie sagt nicht, *welche* Zeilen
  /// zu sehen sind — steht hier aber daneben, weil sie dieselbe Frage bedient:
  /// „Zeig mir den Ausschnitt, der mich angeht."
  final RegisterReihenfolge reihenfolge;
  final ValueChanged<RegisterReihenfolge> onReihenfolge;

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
    required this.reihenfolge,
    required this.onReihenfolge,
    this.katalog = const [],
    this.katalogFehlt = false,
    this.onKatalogErneut,
  });

  @override
  Widget build(BuildContext context) {
    final jahre = RegisterFilter.jahre(alle);
    final rechtsgebiete = RegisterFilter.rechtsgebiete(alle, katalog: katalog);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        RegisterAuswahlFeld<RegisterReihenfolge>(
          hinweis: 'Reihenfolge',
          wert: reihenfolge,
          werte: RegisterReihenfolge.values,
          beschriftung: (richtung) => richtung.bezeichnung,
          onGewaehlt: (richtung) =>
              onReihenfolge(richtung ?? RegisterReihenfolge.vorgabe),
        ),
        ..._jahresfelder(jahre),
        // Zwei Werte statt der fünf Vorgangsstatus: Eine Registerzeile trägt
        // keinen Lebenszyklus — die Historie hat nie einen gehabt, und vom
        // Vorgang liefert der Endpunkt nur, ob er abgeschlossen ist.
        RegisterAuswahlFeld<bool>(
          hinweis: 'Stand',
          alleText: 'Alle Zeilen',
          wert: filter.abgeschlossen,
          werte: const [true, false],
          beschriftung: (fertig) => fertig ? 'Abgeschlossen' : 'Laufend',
          onGewaehlt: (fertig) => onGeaendert(
            filter.mit(
              abgeschlossen: fertig,
              abgeschlossenLoeschen: fertig == null,
            ),
          ),
        ),
        // Nach der Übernahme besteht das Register zum größten Teil aus
        // Historie. Wer die laufende Arbeit sehen will, sucht sie sonst
        // zwischen tausenden Altzeilen.
        RegisterAuswahlFeld<String>(
          hinweis: 'Herkunft',
          alleText: 'Alle Herkünfte',
          wert: filter.quelle,
          werte: const [RegisterQuellen.vorgang, RegisterQuellen.historie],
          beschriftung: (quelle) => quelle == RegisterQuellen.historie
              ? 'Übernommene Historie'
              : 'Vorgänge der App',
          onGewaehlt: (quelle) => onGeaendert(
            filter.mit(quelle: quelle, quelleLoeschen: quelle == null),
          ),
        ),
        RegisterAuswahlFeld<String>(
          hinweis: 'Rechtsgebiet',
          alleText: 'Alle Rechtsgebiete',
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
        if (katalogFehlt) _katalogHinweis(),
        if (!filter.istLeer)
          TextButton.icon(
            onPressed: () => onGeaendert(RegisterFilter.alle),
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Filter zurücksetzen'),
          ),
      ],
    );
  }

  /// „Von" und „Bis" über die Jahrgänge, die es überhaupt gibt.
  ///
  /// Ohne gesetzte Grenze zeigen sie die äußeren Jahrgänge des Bestands statt
  /// „Alle": Die Spanne ist damit immer ablesbar, und der Anwalt sieht auf
  /// einen Blick, wie weit das Register reicht. Ein einziger Jahrgang braucht
  /// keine Spanne — dann steht dort nichts.
  List<Widget> _jahresfelder(List<int> jahre) {
    if (jahre.length < 2) return const [];
    return [
      RegisterAuswahlFeld<int>(
        hinweis: 'Von',
        wert: filter.vonJahr ?? jahre.last,
        werte: jahre,
        beschriftung: (jahr) => '$jahr',
        onGewaehlt: (jahr) => onGeaendert(filter.mit(vonJahr: jahr)),
      ),
      RegisterAuswahlFeld<int>(
        hinweis: 'Bis',
        wert: filter.bisJahr ?? jahre.first,
        werte: jahre,
        beschriftung: (jahr) => '$jahr',
        onGewaehlt: (jahr) => onGeaendert(filter.mit(bisJahr: jahr)),
      ),
    ];
  }

  Widget _katalogHinweis() => SizedBox(
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
  );
}
