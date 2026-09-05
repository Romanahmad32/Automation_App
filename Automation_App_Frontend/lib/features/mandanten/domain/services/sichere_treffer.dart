import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/services/mandanten_namensindex.dart';
import 'package:equatable/equatable.dart';

/// Ein Ordner, der sich ohne Nachlesen einem erfassten Mandanten zuordnen
/// lässt.
class SichererTreffer extends Equatable {
  final String ordnername;
  final Mandant mandant;

  const SichererTreffer({required this.ordnername, required this.mandant});

  @override
  List<Object?> get props => [ordnername, mandant];
}

/// Sucht die offenen Akten-Ordner heraus, deren Mandant schon im Register
/// steht — der Teil der Arbeit, für den es keinen KI-Agenten braucht.
///
/// **Das ist kein zweiter Weg in die Datenbank.** Aus den Treffern entsteht
/// eine [MandantenImportDatei] im Arbeitsspeicher, die durch den vorhandenen
/// Import läuft. Damit gelten unverändert: Vorschau vor dem Schreiben,
/// „Ergänzen nie überschreiben", kein Ordner wird umgehängt, eine Transaktion,
/// Paket-Fortschritt. Eine eigene Zuordnungslogik daneben hätte all das
/// nachzubauen — und beim ersten Sonderfall anders.
///
/// **„Sicher" ist eng gemeint und wird nicht aufgeweicht:**
///
/// * der Namensvorschlag aus dem Ordnernamen liefert einen nicht leeren
///   **Nachnamen** — ein Vorname darf fehlen,
/// * [MandantErkennung.finde] liefert **genau einen** Vorschlag,
/// * und dieser stimmt im Nachnamen nach Normalisierung **genau** überein; im
///   Vornamen ebenso, **sofern** der Ordner einen liefert.
///
/// **Warum der Vorname fehlen darf.** Die echten Aktenordner der Kanzlei
/// heißen `VUnfallursache <Nachname>` und tragen gar keinen Vornamen. „Beide
/// exakt" wäre dort prinzipiell unerfüllbar — die Regel hätte auf dem
/// Produktivbestand ausnahmslos nichts gefunden und damit nur so ausgesehen,
/// als sei sie streng. Die Schadensrichtung bleibt trotzdem gewahrt: Fehlt der
/// Vorname, trägt die Eindeutigkeit allein „**genau ein** Vorschlag", und
/// dieser Vorschlag zählt auch Tippfehler-Nachbarn mit. Zwei „Albrecht" im
/// Register — oder ein „Albrecht" neben einem „Albrccht" — sind damit zwei
/// Vorschläge und kein sicherer Treffer.
///
/// Alles andere — Tippfehler, Tippbeginn, ein reiner Kennzeichen-Treffer, zwei
/// Vorschläge — ist kein sicherer Treffer und bleibt dem Agenten. Der Grund ist
/// die Richtung des Schadens: ein übersehener Ordner kostet eine Zuordnung von
/// Hand, ein falsch zugeordneter kostet eine Akte am falschen Mandanten, und
/// den findet niemand mehr, weil er zugeordnet *aussieht*.
class SichereTreffer {
  const SichereTreffer._();

  /// Woher die erzeugten Zeilen stammen — steht in jeder Zeile der Datei,
  /// damit im Bericht nachvollziehbar bleibt, dass sie nicht aus einer
  /// Aktendurchsicht kommt, sondern allein aus dem Ordnernamen.
  static const String quelle = 'Ordnername';

  /// Selbsteinschätzung der erzeugten Zeilen. „hoch" ist hier keine Höflichkeit
  /// gegen sich selbst: die Regeln oben lassen nur den genauen Namenstreffer
  /// durch.
  static const String sicherheit = 'hoch';

  /// Findet die Ordner, die sich ohne KI-Agenten zuordnen lassen.
  ///
  /// [namensvorschlag] löst einen Ordnernamen in Vor- und Nachnamen auf; die
  /// Präsentation füllt ihn mit `nameVorschlagAusOrdner`. Er kommt von außen
  /// herein, weil dort die **eine** Präfixtabelle ausgewertet wird und die
  /// Domain die Präsentationsschicht nicht kennen darf. Eine zweite Auflösung
  /// hier wäre genau die zweite Auslegung derselben Tabelle, die das Feature
  /// vermeiden soll.
  static List<SichererTreffer> finde({
    required List<Akte> offeneOrdner,
    required List<Mandant> mandanten,
    required ({String vorname, String nachname}) Function(String)
    namensvorschlag,
  }) {
    if (offeneOrdner.isEmpty || mandanten.isEmpty) return const [];

    // Derselbe Vorfilter wie im Ähnlichkeitshinweis: viertausend Ordner gegen
    // mehrere tausend Registereinträge wären sonst Millionen
    // Damerau-Levenshtein-Durchläufe. Der Index schließt nichts aus, was
    // [MandantErkennung] gefunden hätte.
    final index = MandantenNamensindex(mandanten);
    final treffer = <SichererTreffer>[];
    for (final akte in offeneOrdner) {
      final mandant = sichererMandant(
        vorschlag: namensvorschlag(akte.ordnername),
        index: index,
      );
      if (mandant != null) {
        treffer.add(
          SichererTreffer(ordnername: akte.ordnername, mandant: mandant),
        );
      }
    }
    return treffer;
  }

  /// Der eine Mandant zu [vorschlag] — oder `null`, sobald der geringste
  /// Zweifel bleibt.
  static Mandant? sichererMandant({
    required ({String vorname, String nachname}) vorschlag,
    required MandantenNamensindex index,
  }) {
    final vorname = MandantErkennung.normalisiereName(vorschlag.vorname);
    final nachname = MandantErkennung.normalisiereName(vorschlag.nachname);
    // Der Nachname bleibt Pflicht — ohne ihn gäbe es nichts zu vergleichen.
    // Der Vorname darf fehlen: die echten Ordner tragen keinen.
    if (nachname.isEmpty) return null;

    final kandidaten = index.kandidaten(nachname: vorschlag.nachname);
    if (kandidaten.isEmpty) return null;

    // Ohne Kennzeichen: Ein Ordnername ist kein Fahrzeug, und ein Treffer
    // allein über ein Kennzeichen sagt nichts darüber, wessen Akte hier liegt.
    final vorschlaege = MandantErkennung.finde(
      mandanten: kandidaten,
      vorname: vorschlag.vorname,
      nachname: vorschlag.nachname,
    );
    // Die ganze Eindeutigkeit, sobald der Ordner keinen Vornamen liefert:
    // zwei Namensvettern im Register sind zwei Vorschläge und damit kein
    // sicherer Treffer.
    if (vorschlaege.length != 1) return null;

    final mandant = vorschlaege.single.mandant;
    // Der Vorname wird verglichen, **wenn** der Ordner einen liefert. Sonst
    // verlangte die Prüfung eine Angabe, die der Ordnername gar nicht macht —
    // und lehnte jeden echten Ordner ab.
    final passt =
        MandantErkennung.normalisiereName(mandant.nachname) == nachname &&
        (vorname.isEmpty ||
            MandantErkennung.normalisiereName(mandant.vorname) == vorname);
    return passt ? mandant : null;
  }

  /// Baut aus [treffer] eine Importdatei (Fassung 1) für den vorhandenen
  /// Import.
  ///
  /// Mehrere Ordner desselben Mandanten stehen in **einer** Zeile: zwei Zeilen
  /// mit demselben Namen fasste der Import zwar auch zusammen, aber die
  /// Vorschau zeigte sie doppelt, und der Anwalt prüfte dieselbe Person zweimal.
  ///
  /// Geschrieben werden nur Name und Ordner — **keine erfundenen Stammdaten**.
  /// Anschrift, E-Mail und Telefon bleiben leer, damit „Ergänzen nie
  /// überschreiben" gar nichts zu überschreiben versucht: der Registereintrag
  /// weiß über sich selbst mehr als ein Ordnername.
  static MandantenImportDatei alsImportdatei(List<SichererTreffer> treffer) {
    final mandanten = <int, Mandant>{};
    final ordnerJeMandant = <int, List<String>>{};
    for (final einzelner in treffer) {
      final id = einzelner.mandant.id;
      mandanten[id] = einzelner.mandant;
      ordnerJeMandant.putIfAbsent(id, () => []).add(einzelner.ordnername);
    }

    return MandantenImportDatei(
      mandanten: [
        for (final eintrag in ordnerJeMandant.entries)
          ImportMandantEintrag(
            // Die Schreibweise des Registers gewinnt, nicht die des Ordners:
            // „Müller" und „Mueller" gelten als derselbe Name, aber nur die
            // erfasste Fassung trifft den vorhandenen Mandanten wieder.
            vorname: mandanten[eintrag.key]!.vorname,
            nachname: mandanten[eintrag.key]!.nachname,
            aktenOrdnernamen: eintrag.value,
            quelle: quelle,
            sicherheit: sicherheit,
          ),
      ],
    );
  }
}
