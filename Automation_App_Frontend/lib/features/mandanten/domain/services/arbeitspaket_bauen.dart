import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';

/// Die Ordner **eines** Mandanten unter dem Schlüssel, unter dem sie
/// zusammengefunden haben. Ein Datensatz statt zweier Listen nebeneinander —
/// so können Schlüssel und Ordner beim Sortieren nicht auseinanderlaufen.
typedef ArbeitspaketGruppe = ({
  String schluessel,
  List<ArbeitspaketOrdner> ordner,
});

/// Setzt aus den offenen Akten-Ordnern das nächste [Arbeitspaket] zusammen.
///
/// **Ein Paket schneidet nach Mandanten, nicht nach Ordnern.** Viele Mandanten
/// haben mehrere Aktenordner. Nach Ordnern geschnitten zerreißt ein Paket
/// dieselbe Person über zwei Sitzungen — und genau daraus entsteht die
/// Dublette, die der Import vermeiden soll: der Agent sieht in Paket 2 eine
/// Person, die er in Paket 1 schon angelegt hat, und legt sie noch einmal an.
/// Nach Mandanten geschnitten kann das gar nicht erst auftreten. [anzahl]
/// zählt deshalb **Gruppen**, nicht Ordner.
///
/// Der Bauer entscheidet **nur über Reihenfolge und Portionsgröße**. Welche
/// Ordner überhaupt offen sind, ist anderswo schon beantwortet:
/// `OrdnernamenMenge` vergleicht Ordnernamen ohne Rücksicht auf die
/// Schreibweise, und `ZuordnungFilter.ansichtVon` teilt zugeordnet / offen /
/// vermerkt auf. Eine zweite Rechnung hier wäre eine zweite Auslegung derselben
/// Regel — und beim ersten Sonderfall liefen die beiden auseinander.
///
/// Aus demselben Grund kommen [Arbeitspaket.ordner] fertig herein: Aktentyp und
/// Namensvorschlag rechnet der Aufrufer aus (`AktentypErkennung`,
/// `nameVorschlagAusOrdner`). `nameVorschlagAusOrdner` liegt in der
/// Präsentationsschicht, und die Domain darf sie nicht kennen — die eine
/// Präfixtabelle bleibt trotzdem die eine.
class ArbeitspaketBauen {
  const ArbeitspaketBauen._();

  /// Was der Anwalt bekommt, wenn er nichts wählt — **Mandanten**, nicht
  /// Ordner. Ein Paket ist damit etwas größer als früher, aber nie mitten in
  /// einer Person zu Ende.
  static const int vorgabeAnzahl = 200;

  /// Obergrenze. Ein Paket, das ein Agent nicht in einem Zug schafft, kommt
  /// halb bearbeitet zurück — und halb bearbeitet ist der Zustand, den die
  /// Paketzählung gerade vermeiden soll.
  static const int hoechsteAnzahl = 1000;

  /// Baut das Paket [paketNummer] aus [offeneOrdner].
  ///
  /// [anzahl] wird auf [hoechsteAnzahl] gedeckelt und auf mindestens 1
  /// angehoben — ein Paket ohne Mandanten wäre ein Knopf ohne Wirkung. Sind
  /// weniger Mandanten offen als angefordert, ist das Paket eben kleiner; das
  /// ist kein Fehler, sondern das Ende der Arbeit.
  static Arbeitspaket baue({
    required List<ArbeitspaketOrdner> offeneOrdner,
    required List<BekannterMandant> bekannteMandanten,
    required int paketNummer,
    required String stammordner,
    required String anleitung,
    required DateTime erstelltAm,
    int anzahl = vorgabeAnzahl,
  }) {
    final gewaehlt = gruppen(offeneOrdner).take(begrenzeAnzahl(anzahl));
    return Arbeitspaket(
      paket: paketNummer,
      erstelltAm: erstelltAm,
      stammordner: stammordner,
      anleitung: anleitung,
      bekannteMandanten: bekannteMandanten,
      ordner: [for (final gruppe in gewaehlt) ...gruppe.ordner],
    );
  }

  /// Die tatsächliche Portionsgröße zu einem Wunsch.
  static int begrenzeAnzahl(int anzahl) {
    if (anzahl < 1) return 1;
    return anzahl > hoechsteAnzahl ? hoechsteAnzahl : anzahl;
  }

  /// [offeneOrdner] nach Mandanten gebündelt, in Paketreihenfolge — die
  /// Rechnung hinter [baue], einzeln greifbar für Anzeige und Test.
  ///
  /// Jeder Ordner landet in genau einer Gruppe, auch der ohne erkennbaren
  /// Namen: verschluckt wird hier nichts.
  static List<ArbeitspaketGruppe> gruppen(
    List<ArbeitspaketOrdner> offeneOrdner,
  ) {
    final nachSchluessel = <String, List<ArbeitspaketOrdner>>{};
    for (final ordner in offeneOrdner) {
      nachSchluessel
          .putIfAbsent(gruppenschluessel(ordner), () => [])
          .add(ordner);
    }
    final ergebnis = [
      for (final eintrag in nachSchluessel.entries)
        (
          schluessel: eintrag.key,
          ordner: eintrag.value..sort(vergleicheOrdner),
        ),
    ];
    return ergebnis..sort(vergleicheGruppen);
  }

  /// Woran zwei Ordner als „derselbe Mandant" erkannt werden: am normalisierten
  /// Namensvorschlag aus dem Ordnernamen.
  ///
  /// Normalisiert wird über [MandantErkennung.normalisiereName] — **dieselbe**
  /// Schreibweise, nach der auch verglichen wird, ob ein Ordner zu einem
  /// erfassten Mandanten passt. Eine zweite Normalisierung hier zerlegte
  /// „Müller" und „Mueller" in zwei Personen, die jede Erkennung daneben für
  /// eine hält.
  ///
  /// Ohne erkennbaren Namen bildet der Ordner eine **eigene** Gruppe über
  /// seinen Ordnernamen. Er fällt damit nicht unter den Tisch, und er zieht
  /// auch keine fremden Ordner an sich: ein leerer Schlüssel wäre der
  /// Sammeltopf, in dem am Ende alles Unerkannte als eine Person stünde.
  static String gruppenschluessel(ArbeitspaketOrdner ordner) {
    final name = [
      MandantErkennung.normalisiereName(ordner.nameVorschlagVorname),
      MandantErkennung.normalisiereName(ordner.nameVorschlagNachname),
    ].where((teil) => teil.isNotEmpty).join(' ');
    return name.isNotEmpty
        ? name
        : MandantErkennung.normalisiereName(ordner.ordnername);
  }

  /// Wie viele **Mandanten** in [ordner] stecken — die Zahl für die
  /// Rückmeldung nach dem Speichern („Paket 3 mit 180 Mandanten und 240
  /// Ordnern gespeichert").
  static int mandantenAnzahl(List<ArbeitspaketOrdner> ordner) =>
      {for (final einzelner in ordner) gruppenschluessel(einzelner)}.length;

  /// Ob in [ordner] mindestens ein Verkehrsunfall-Kandidat steckt.
  static bool hatUnfallkandidat(List<ArbeitspaketOrdner> ordner) =>
      ordner.any((einzelner) => einzelner.aktentyp.istUnfallkandidat);

  /// Gruppen mit mindestens einem Unfallkandidaten zuerst, dann die übrigen;
  /// innerhalb beider alphabetisch nach Schlüssel, ohne Rücksicht auf die
  /// Schreibweise.
  ///
  /// Der Vorrang ist keine Höflichkeit: eine Verkehrsunfall-App braucht aus
  /// Straf-, Bußgeld- und Familiensachen keine Stammdaten. Wer nur die ersten
  /// Pakete abarbeitet, hat trotzdem das Wesentliche erfasst.
  ///
  /// Bei Gleichstand entscheidet die genaue Schreibweise — derselbe Grund wie
  /// bei [vergleicheOrdner]: `List.sort` ist in Dart **nicht stabil**.
  static int vergleicheGruppen(ArbeitspaketGruppe a, ArbeitspaketGruppe b) {
    final unfall = hatUnfallkandidat(a.ordner);
    if (unfall != hatUnfallkandidat(b.ordner)) return unfall ? -1 : 1;
    final vergleich = a.schluessel.toLowerCase().compareTo(
      b.schluessel.toLowerCase(),
    );
    return vergleich != 0 ? vergleich : a.schluessel.compareTo(b.schluessel);
  }

  /// Innerhalb einer Gruppe: alphabetisch nach `ordnername` **ohne Rücksicht
  /// auf Groß-/Kleinschreibung** — dieselbe Auffassung von „gleicher Ordner",
  /// nach der überall sonst verglichen wird (`OrdnernamenMenge`).
  ///
  /// Bei Gleichstand entscheidet die genaue Schreibweise. Das ist kein
  /// Feinschliff: `List.sort` ist in Dart **nicht stabil**, und ohne diesen
  /// zweiten Schlüssel könnte derselbe Bestand zweimal eine andere Reihenfolge
  /// ergeben. Genau darauf verlässt sich aber der Anwalt, der ein abgebrochenes
  /// Paket noch einmal holt: dieselben Ordner, wieder vorn.
  static int vergleicheOrdner(ArbeitspaketOrdner a, ArbeitspaketOrdner b) {
    final vergleich = a.ordnername.toLowerCase().compareTo(
      b.ordnername.toLowerCase(),
    );
    return vergleich != 0 ? vergleich : a.ordnername.compareTo(b.ordnername);
  }
}
