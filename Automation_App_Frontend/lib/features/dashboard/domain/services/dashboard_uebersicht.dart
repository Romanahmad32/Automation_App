import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_wartezeit.dart';

/// Der aufbereitete Stand für die Startseite: welche Vorgänge auf eine Handlung
/// warten und wo das Sachgebiete-Register gerade steht. Reine Auswertung der
/// bereits geladenen Vorgänge — das Dashboard zeigt und verlinkt nur, geändert
/// wird nichts.
class DashboardUebersicht {
  /// Die dringendsten offenen Vorgänge (gekürzt auf `maxOffene`).
  final List<Vorgang> offeneVorgaenge;

  /// Alle offenen Vorgänge — auch die, die nicht mehr in die Karte passen.
  final int anzahlOffen;

  /// Die letzten Zeilen des Registers, aufsteigend nach laufender Nummer.
  final List<Vorgang> registerZeilen;

  /// Gesamtzahl der Registerzeilen (abgeschlossene Vorgänge).
  final int registerGesamt;

  const DashboardUebersicht({
    required this.offeneVorgaenge,
    required this.anzahlOffen,
    required this.registerZeilen,
    required this.registerGesamt,
  });

  /// Wertet den Vorgangsbestand für die Startseite aus. [jetzt] ist für Tests
  /// überschreibbar, [maxOffene]/[maxRegister] begrenzen die Kartenlänge.
  factory DashboardUebersicht.aus(
    List<Vorgang> vorgaenge, {
    DateTime? jetzt,
    int maxOffene = 6,
    int maxRegister = 5,
  }) {
    final zeitpunkt = jetzt ?? DateTime.now();

    final offen =
        vorgaenge.where((v) => v.status != VorgangStatus.versendet).toList()
          ..sort((a, b) {
            final rang = _dringlichkeit(
              a,
              zeitpunkt,
            ).compareTo(_dringlichkeit(b, zeitpunkt));
            // Gleich dringend: der am längsten offene Vorgang zuerst.
            return rang != 0 ? rang : a.angefragtAm.compareTo(b.angefragtAm);
          });

    final register = _registerReihenfolge(vorgaenge);

    return DashboardUebersicht(
      offeneVorgaenge: offen.take(maxOffene).toList(),
      anzahlOffen: offen.length,
      // Der Schwanz der Liste = die zuletzt vergebenen laufenden Nummern; die
      // Reihenfolge bleibt aufsteigend wie im Register selbst.
      registerZeilen: register
          .skip(
            register.length > maxRegister ? register.length - maxRegister : 0,
          )
          .toList(),
      registerGesamt: register.length,
    );
  }

  /// Rang für die Sortierung der offenen Vorgänge: je kleiner, desto eher ist
  /// der Anwalt am Zug. Zuerst, was er sofort weiterbearbeiten kann (die
  /// Antwort liegt vor), dann angefangene Schreiben, dann Anfragen, deren
  /// Antwort verdächtig lange ausbleibt, zuletzt frische Anfragen (Warten ist
  /// dort der Normalfall).
  static int _dringlichkeit(Vorgang vorgang, DateTime jetzt) {
    return switch (vorgang.status) {
      VorgangStatus.beantwortet => 0,
      VorgangStatus.erstellt || VorgangStatus.abgelegt => 1,
      VorgangStatus.angefragt =>
        VorgangWartezeit.wartetLange(vorgang, jetzt: jetzt) ? 2 : 3,
      VorgangStatus.versendet => 4,
    };
  }

  /// Die abgeschlossenen Vorgänge in Registerreihenfolge: aufsteigend nach
  /// laufender Nummer. Vorgänge ohne Nummer stehen vorn — sie sind Ausreißer
  /// und sollen den Ausschnitt am Ende der Liste nicht verdrängen.
  static List<Vorgang> _registerReihenfolge(List<Vorgang> vorgaenge) {
    final zeilen = vorgaenge
        .where((v) => v.status == VorgangStatus.versendet)
        .toList();
    zeilen.sort((a, b) {
      final an = a.laufendeNummer;
      final bn = b.laufendeNummer;
      if (an != null && bn != null && an != bn) return an.compareTo(bn);
      if (an == null && bn != null) return -1;
      if (an != null && bn == null) return 1;
      return _abschlussZeit(a).compareTo(_abschlussZeit(b));
    });
    return zeilen;
  }

  static DateTime _abschlussZeit(Vorgang vorgang) =>
      vorgang.abgeschlossenAm ?? vorgang.angefragtAm;
}
