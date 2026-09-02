import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/entities/platzhalter_befund.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_platzhalter.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_prefill_matcher.dart';

/// Setzt die `{{Platzhalter}}` einer Mail-Textvorlage (§4.7).
///
/// Zwei Quellen, in dieser Reihenfolge: [MailPlatzhalter.anrede] und
/// [MailPlatzhalter.grussformel] beantwortet der Versand selbst, weil beide von
/// den **Empfängern dieser einen Mail** abhängen und nicht vom Vorgang; alles
/// Übrige löst `VorgangPrefillMatcher` auf — dieselbe Kette wie beim Ausfüllen
/// einer Word-Vorlage.
///
/// **Ein Platzhalter ohne Wert nimmt seine Zeile mit.** Eine Vorlage darf
/// deshalb Zeilen enthalten, die nur manchmal erscheinen — der Zusatzgruß ist
/// genau so eine. Bliebe stattdessen eine leere Zeile stehen, hätte jede Mail
/// an einen Mandanten ohne Grußformel eine Lücke unter der Anrede.
class MailVorlagenFueller {
  final Vorgang? vorgang;
  final Mandant? mandant;

  /// Die Anrede dieser Mail. Sie kommt von aussen (`EmailEntwurfErzeuger`),
  /// weil sie davon abhängt, wer im Feld „An" steht.
  final String anrede;

  /// Ob ausschliesslich der Mandant angeschrieben wird. Nur dann geht der
  /// persönliche Gruß mit.
  final bool nurAnDenMandanten;

  /// Der beim Verfassen gewählte Zusatzgruß (§4.7) — vorbelegt aus dem
  /// Mandanten, änderbar je Mail. Der Wert kommt von aussen, die **Regel**
  /// bleibt hier: [nurAnDenMandanten] entscheidet, ob er überhaupt eingesetzt
  /// wird.
  final String grussformel;

  const MailVorlagenFueller({
    required this.anrede,
    required this.nurAnDenMandanten,
    this.grussformel = '',
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
  String fuelleText(String vorlage) {
    final behalten = <String>[];
    for (final zeile in vorlage.split('\n')) {
      final ersetzt = _ersetzeInZeile(zeile);
      if (ersetzt == null) continue;
      // Zwei Leerzeilen hintereinander sind fast immer der Rest einer
      // entfallenen Zeile — der Absatzabstand ist eine, nicht zwei.
      if (ersetzt.trim().isEmpty &&
          (behalten.isEmpty || behalten.last.trim().isEmpty)) {
        continue;
      }
      behalten.add(ersetzt);
    }
    while (behalten.isNotEmpty && behalten.last.trim().isEmpty) {
      behalten.removeLast();
    }
    return behalten.join('\n');
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
  List<PlatzhalterBefund> befunde(MailVorlage vorlage) {
    final gesehen = <String>{};
    final gefunden = <PlatzhalterBefund>[];

    for (final quelle in [vorlage.betreff, vorlage.text]) {
      for (final treffer in MailPlatzhalter.muster.allMatches(quelle)) {
        final name = treffer.group(1)!.trim();
        if (!gesehen.add(FeldDatenquelleErkennung.normalisiere(name))) continue;

        final wert = _wertFuer(name)?.trim() ?? '';
        gefunden.add(
          PlatzhalterBefund(
            name: name,
            wert: wert,
            herkunft: wert.isEmpty ? '' : _herkunftFuer(name),
          ),
        );
      }
    }
    return gefunden;
  }

  /// Woher der Wert kam, im Klartext. Bewusst grob: Die Übersicht soll den
  /// Wert einordnen, nicht die Datenquelle des Vorlagen-Editors nachbauen.
  String _herkunftFuer(String name) {
    final gesucht = FeldDatenquelleErkennung.normalisiere(name);
    if (gesucht == _anredeSchluessel) return 'aus Anrede und Empfängern';
    if (gesucht == _grussformelSchluessel) return 'beim Verfassen gewählt';
    return 'aus dem Vorgang';
  }

  String? _wertFuer(String name) {
    final gesucht = FeldDatenquelleErkennung.normalisiere(name);
    if (gesucht == _anredeSchluessel) return anrede;
    if (gesucht == _grussformelSchluessel) {
      return nurAnDenMandanten ? grussformel : '';
    }

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

  /// Über die Normalisierung verglichen, damit `{{Grußformel}}` mit ß dasselbe
  /// meint wie `{{Grussformel}}` — beides tippt sich, und beides ist gemeint.
  static final String _grussformelSchluessel =
      FeldDatenquelleErkennung.normalisiere(MailPlatzhalter.grussformel);
}
