import 'package:automation_app/features/email_versand/domain/entities/beugung.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/entities/platzhalter_befund.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_platzhalter.dart';
import 'package:automation_app/features/email_versand/domain/services/platzhalter_fehlstelle.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_prefill_matcher.dart';

/// Setzt die `{{Platzhalter}}` einer Mail-Textvorlage (§4.7).
///
/// Drei Quellen, in dieser Reihenfolge. Eine **[Beugung]** trägt ihre Formen
/// selbst bei sich (`{{Mandant/Mandantin}}`) und braucht nur die Anredeart, um
/// zu wissen, welche gilt. [MailPlatzhalter.anrede] und
/// [MailPlatzhalter.zusatzgruss] beantwortet der Versand selbst, weil beide
/// beim Verfassen **dieser einen Mail** entstehen und nicht am Vorgang stehen;
/// alles Übrige löst `VorgangPrefillMatcher` auf — dieselbe Kette wie beim
/// Ausfüllen einer Word-Vorlage.
///
/// **Ein Platzhalter ohne Wert nimmt seine Zeile mit.** Eine Vorlage darf
/// deshalb Zeilen enthalten, die nur manchmal erscheinen — der Zusatzgruß ist
/// genau so eine. Bliebe stattdessen eine leere Zeile stehen, hätte jede Mail
/// ohne gewählten Gruß eine Lücke unter der Anrede. Was dabei übersprungen
/// wurde, bleibt trotzdem auffindbar: [befunde] trägt Stelle und Folge jedes
/// leeren Platzhalters, damit der Dialog auf die Lücke zeigen kann.
class MailVorlagenFueller {
  final Vorgang? vorgang;
  final Mandant? mandant;

  /// Die Anrede dieser Mail. Sie kommt von aussen (`EmailEntwurfErzeuger`),
  /// weil sie davon abhängt, wer im Feld „An" steht.
  final String anrede;

  /// Der beim Verfassen gewählte Zusatzgruß (§4.7) — vorbelegt aus dem
  /// Mandanten, änderbar je Mail.
  ///
  /// Er wird eingesetzt, **wo immer der Platzhalter steht**, und nicht nur bei
  /// einer Mail allein an den Mandanten: Die Vorlagenwahl ist die Entscheidung
  /// (§4.7). Wer eine Vorlage mit `{{Zusatzgruß}}` nimmt, will ihn — auch wenn
  /// die Gegenseite mitliest; darauf hinzuweisen ist Sache des Dialogs, nicht
  /// Sache dieser Ersetzung.
  final String zusatzgruss;

  /// Die Anredeart dieser Mail (§5.1) — sie beugt `{{Mandant/Mandantin}}` im
  /// Vorlagentext (§4.7, ergänzt am 02.09.2026).
  ///
  /// Kommt wie [anrede] von aussen, weil sie je Mail wählbar ist: Vorbelegt
  /// ist, was am Mandanten steht, entscheidend ist, was der Anwalt gewählt hat.
  ///
  /// **Nicht zu verwechseln mit „neutral anreden":** Ob namentlich angeredet
  /// wird, hängt am Empfängerkreis (liest die Gegenseite mit?); welche Form
  /// eines Wortes gilt, hängt am Mandanten. Der häufigste Fall ist der, in dem
  /// beides auseinandergeht — eine Mail an die Versicherung beginnt mit „Sehr
  /// geehrte Damen und Herren" und schreibt im Text von „unserer Mandantin".
  final Anrede geschlecht;

  const MailVorlagenFueller({
    required this.anrede,
    this.zusatzgruss = '',
    this.geschlecht = Anrede.keine,
    this.vorgang,
    this.mandant,
  });

  /// Betreff und Text der Vorlage, gefüllt.
  MailVorlage fuelleVorlage(MailVorlage vorlage) => vorlage.copyWith(
    betreff: fuelleBetreff(vorlage.betreff),
    text: fuelleText(vorlage.text),
  );

  /// Der Nachrichtentext: Zeile für Zeile ersetzt, leer gebliebene Zeilen
  /// entfallen, und wo dadurch zwei Leerzeilen aufeinanderträfen, bleibt eine.
  String fuelleText(String vorlage) =>
      textzeilen(vorlage).whereType<String>().join('\n');

  /// Das Ergebnis **je Vorlagenzeile**, in ihrer Reihenfolge: null heisst, die
  /// Zeile entfällt. Genau das, was [fuelleText] aneinanderfügt.
  ///
  /// Eine Stelle für die ganze Regel, und zwar seit dem 02.09.2026: Die
  /// Gegenüberstellung im Dialog rechnete vorher selbst und kannte dabei nur
  /// das Ersetzen — nicht das Zusammenziehen doppelter Leerzeilen und nicht
  /// das Abschneiden am Ende. Sie zeigte deshalb Zeilen, die in der Mail nicht
  /// stehen, und ausgerechnet dort ist ihr Zweck, zu zeigen, was daraus wurde.
  List<String?> textzeilen(String vorlage) {
    final ergebnis = <String?>[];
    String? zuletzt;

    for (final zeile in vorlage.split('\n')) {
      final ersetzt = _ersetzeInZeile(zeile);
      if (ersetzt == null) {
        ergebnis.add(null);
        continue;
      }
      // Zwei Leerzeilen hintereinander sind fast immer der Rest einer
      // entfallenen Zeile — der Absatzabstand ist eine, nicht zwei. Am Anfang
      // (`zuletzt` null) gilt dasselbe: Dort hält keine Zeile Abstand.
      if (ersetzt.trim().isEmpty &&
          (zuletzt == null || zuletzt.trim().isEmpty)) {
        ergebnis.add(null);
        continue;
      }
      ergebnis.add(ersetzt);
      zuletzt = ersetzt;
    }

    // Leerzeilen am Ende entfallen — die letzte Zeile der Mail trägt Text.
    for (var i = ergebnis.length - 1; i >= 0; i--) {
      final zeile = ergebnis[i];
      if (zeile == null) continue;
      if (zeile.trim().isEmpty) {
        ergebnis[i] = null;
        continue;
      }
      break;
    }
    return ergebnis;
  }

  /// Die Betreffzeile. Dieselbe Regel, nur ohne Zeilen: Bleibt nichts übrig,
  /// bleibt der Betreff leer — eine erfundene Betreffzeile wäre schlimmer als
  /// ein leeres Feld, das erkennbar auf eine Eingabe wartet (§4.7).
  String fuelleBetreff(String vorlage) {
    final ersetzt = _ersetzeInZeile(vorlage) ?? '';
    return ersetzt.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
  }

  /// Die Zeile mit eingesetzten Werten, oder null, wenn sie entfallen soll:
  /// Sie trug mindestens einen Platzhalter, und **keiner** davon hatte einen
  /// Wert.
  String? _ersetzeInZeile(String zeile) {
    var gesehen = 0;
    var gefuellt = 0;

    final ersetzt = zeile.replaceAllMapped(MailPlatzhalter.muster, (treffer) {
      gesehen++;
      final wert = _wertFuer(treffer.group(1)!)?.trim() ?? '';
      if (wert.isNotEmpty) gefuellt++;
      return wert;
    });

    if (gesehen == 0) return zeile;
    if (gefuellt == 0) return null;
    // Wo ein Platzhalter leer blieb, steht sonst sein Zwischenraum noch da —
    // am Zeilenende ein unsichtbares Leerzeichen, das mit hinausginge.
    return ersetzt.trimRight();
  }

  /// Was die Platzhalter dieser Vorlage ergeben — in der Reihenfolge ihres
  /// ersten Auftretens, jeder Name nur einmal. Grundlage der Übersicht im
  /// Versanddialog; **leere Befunde bleiben in der Liste**, denn gerade sie
  /// erklären, warum eine Zeile fehlt.
  ///
  /// Jeder Befund weiss dabei, **wo** er stand (Betreff oder Zeilennummer) und
  /// ob seine Zeile entfällt. Erst das macht die Lücke auffindbar: Im gefüllten
  /// Text ist von einem übersprungenen Platzhalter nichts mehr zu sehen.
  List<PlatzhalterBefund> befunde(MailVorlage vorlage) {
    final gesehen = <String>{};
    final gefunden = <PlatzhalterBefund>[];

    for (final zeile in _zeilen(vorlage)) {
      // Ob die Zeile ganz entfällt, entscheidet sie als Ganzes: Ein einziger
      // gefüllter Platzhalter hält sie am Leben (`_ersetzeInZeile`).
      final entfaellt = _ersetzeInZeile(zeile.text) == null;

      for (final treffer in MailPlatzhalter.muster.allMatches(zeile.text)) {
        final name = treffer.group(1)!.trim();
        if (!gesehen.add(FeldDatenquelleErkennung.normalisiere(name))) continue;

        final wert = _wertFuer(name)?.trim() ?? '';
        gefunden.add(
          PlatzhalterBefund(
            name: name,
            wert: wert,
            herkunft: wert.isEmpty ? '' : _herkunftFuer(name),
            zeile: zeile.nummer,
            zeileEntfaellt: entfaellt,
            bezeichnung: PlatzhalterFehlstelle.bezeichnungFuer(name),
            // Nur im leeren Fall: Wo ein Wert steht, ist nichts zu erklaeren.
            fehlstelle: wert.isEmpty
                ? PlatzhalterFehlstelle.fuer(name, mitVorgang: vorgang != null)
                : '',
          ),
        );
      }
    }
    return gefunden;
  }

  /// Vorlage und Ergebnis Zeile für Zeile — die Gegenüberstellung im Dialog.
  ///
  /// [ergebnis] null heisst: Die Zeile entfällt. Das ist die Auskunft, die ein
  /// blosser Blick in den Vorlagentext nicht gibt — dort steht, was der Anwalt
  /// selbst geschrieben hat; hier steht daneben, was daraus geworden ist.
  /// Die Textzeilen kommen aus [textzeilen] und nicht aus einer eigenen
  /// Rechnung: Was hier steht, muss die Mail auch enthalten — sonst
  /// widerspricht die Spalte „Was daraus wurde" dem, was hinausgeht.
  List<({int nummer, String vorlage, String? ergebnis})> gegenueberstellung(
    MailVorlage vorlage,
  ) {
    final vorlagenzeilen = vorlage.text.split('\n');
    final gefuellt = textzeilen(vorlage.text);

    return [
      (
        nummer: 0,
        vorlage: vorlage.betreff,
        // Der Betreff läuft über `fuelleBetreff`: Er zieht mehrfache
        // Leerzeichen zusammen, die Textzeilen nicht.
        ergebnis: _oderNull(fuelleBetreff(vorlage.betreff), vorlage.betreff),
      ),
      for (var i = 0; i < vorlagenzeilen.length; i++)
        (nummer: i + 1, vorlage: vorlagenzeilen[i], ergebnis: gefuellt[i]),
    ];
  }

  /// Der gefüllte Betreff — oder null, wenn von einer belegten Zeile nichts
  /// übrig blieb.
  String? _oderNull(String gefuellt, String vorlage) {
    if (gefuellt.isNotEmpty) return gefuellt;
    return MailPlatzhalter.muster.hasMatch(vorlage) ? null : gefuellt;
  }

  /// Betreff und Textzeilen als eine Folge, jede mit ihrer Nummer. Der Betreff
  /// zählt als **0** — er hat keine Zeilennummer, und ein eigenes Feld dafür
  /// wäre ein zweiter Weg, dasselbe zu sagen (`PlatzhalterBefund.imBetreff`).
  Iterable<({int nummer, String text})> _zeilen(MailVorlage vorlage) {
    final textzeilen = vorlage.text.split('\n');
    return [
      (nummer: 0, text: vorlage.betreff),
      for (var i = 0; i < textzeilen.length; i++)
        (nummer: i + 1, text: textzeilen[i]),
    ];
  }

  /// Woher der Wert kam, im Klartext. Bewusst grob: Die Übersicht soll den
  /// Wert einordnen, nicht die Datenquelle des Vorlagen-Editors nachbauen.
  String _herkunftFuer(String name) {
    if (Beugung.istGemeint(name)) return 'nach der gewählten Anredeart';

    final gesucht = FeldDatenquelleErkennung.normalisiere(name);
    if (gesucht == _anredeSchluessel) return 'aus Anrede und Empfängern';
    if (gesucht == _zusatzgrussSchluessel) return 'beim Verfassen gewählt';
    return 'aus dem Vorgang';
  }

  String? _wertFuer(String name) {
    // Die Beugung zuerst, und das ist gefahrlos: Ein Schrägstrich kommt in
    // keinem Namen des Katalogs vor, die Fälle können sich nicht überschneiden.
    if (Beugung.istGemeint(name)) {
      return Beugung.aus(name)?.formFuer(geschlecht);
    }

    final gesucht = FeldDatenquelleErkennung.normalisiere(name);
    if (gesucht == _anredeSchluessel) return anrede;
    if (gesucht == _zusatzgrussSchluessel) return zusatzgruss;

    final zumVorgang = vorgang;
    if (zumVorgang == null) return null;
    return VorgangPrefillMatcher.wertFuerNamen(
      name,
      zumVorgang,
      mandant: mandant,
    );
  }

  static final String _anredeSchluessel = FeldDatenquelleErkennung.normalisiere(
    MailPlatzhalter.anrede,
  );

  /// Über die Normalisierung verglichen, damit `{{Zusatzgruss}}` mit ss
  /// dasselbe meint wie `{{Zusatzgruß}}` — beides tippt sich, und beides ist
  /// gemeint.
  static final String _zusatzgrussSchluessel =
      FeldDatenquelleErkennung.normalisiere(MailPlatzhalter.zusatzgruss);
}
