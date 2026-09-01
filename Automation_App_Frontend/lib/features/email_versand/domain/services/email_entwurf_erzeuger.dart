import 'package:automation_app/features/email_versand/domain/entities/email_empfaenger_vorschlag.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/empfaenger_art.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';

/// Baut aus den Daten des Vorgangs den Anfang der Mail (§4.7): Empfänger, die
/// die App schon kennt, einen Betreff aus Aktenzeichen und Parteien und einen
/// Textrumpf mit passender Anrede. Der Anwalt vervollständigt nur noch.
///
/// **Dies ist die Stelle, an der später die pflegbaren Mail-Textvorlagen
/// einsetzen** (§4.7, §5.3): Betreff und Text kommen dann aus der Vorlage des
/// jeweiligen Empfängertyps statt aus diesen Methoden — alles andere bleibt.
class EmailEntwurfErzeuger {
  final Vorgang? vorgang;
  final Mandant? mandant;
  final KanzleiSettings kanzlei;

  /// Eine Zentralruf-Antwort, die noch **nicht** in den Vorgang übernommen ist
  /// (§4.3). Im Postfach ist das der Regelfall: Der Treffer liegt vor, die
  /// Übernahme ist der bestätigte Schritt danach. Ohne diesen Weg fehlten dort
  /// genau die Adressen, die auf dem Schirm stehen.
  final ZentralrufReplyData? antwort;

  /// Die gelernte Versicherer-Wissensbasis; füllt eine Lücke, wenn die
  /// Zentralruf-Antwort keine Adresse enthielt (§5.2).
  final List<Versicherer> versicherer;

  const EmailEntwurfErzeuger({
    required this.kanzlei,
    this.vorgang,
    this.mandant,
    this.antwort,
    this.versicherer = const [],
  });

  /// Die maßgebliche Antwort: die mitgegebene schlägt die am Vorgang
  /// gespeicherte, weil sie die jüngere ist.
  ZentralrufReplyData? get _antwort => antwort ?? vorgang?.antwort;

  String get _unfallDatum =>
      (vorgang?.unfallDatum ?? _antwort?.unfallDatum ?? '').trim();

  /// Die bekannten Adressen zum Vorgang, ohne Dubletten. Anklickbar statt
  /// abzutippen — eintippen bleibt trotzdem möglich.
  List<EmailEmpfaengerVorschlag> get vorschlaege {
    final gefunden = <String, EmailEmpfaengerVorschlag>{};

    void merke(EmailEmpfaengerVorschlag vorschlag) {
      final schluessel = vorschlag.adresse.trim().toLowerCase();
      if (schluessel.isEmpty) return;
      gefunden.putIfAbsent(schluessel, () => vorschlag);
    }

    final mandantAdresse = mandant?.emailAdresse.trim() ?? '';
    if (mandantAdresse.isNotEmpty) {
      merke(
        EmailEmpfaengerVorschlag(
          adresse: mandantAdresse,
          bezeichnung: 'Mandant ${mandant!.anzeigename}',
          art: EmpfaengerArt.mandant,
          herkunft: 'aus dem Mandantenregister',
        ),
      );
    }

    final antwort = _antwort;
    final versichererName = (antwort?.versichererName ?? vorgang?.gegner ?? '')
        .trim();
    final ausAntwort = antwort?.versichererEmail?.trim() ?? '';
    if (ausAntwort.isNotEmpty) {
      merke(
        EmailEmpfaengerVorschlag(
          adresse: ausAntwort,
          bezeichnung: versichererName.isEmpty
              ? 'Gegnerische Versicherung'
              : versichererName,
          art: EmpfaengerArt.versicherung,
          herkunft: 'aus der Zentralruf-Antwort',
        ),
      );
    } else if (versichererName.isNotEmpty) {
      final gelernt = _ausRegister(versichererName);
      if (gelernt != null) {
        merke(
          EmailEmpfaengerVorschlag(
            adresse: gelernt.email!.trim(),
            bezeichnung: gelernt.name,
            art: EmpfaengerArt.versicherung,
            herkunft: 'aus früheren Antworten zu diesem Versicherer',
          ),
        );
      }
    }

    return gefunden.values.toList();
  }

  /// Betreff aus Parteien, Unfalldatum und Aktenzeichen — je nach dem, was der
  /// Vorgang hergibt. [mitSchreiben] sagt, ob das Anspruchsschreiben anhängt;
  /// nur dann wird es im Betreff angekündigt. Ohne Vorgang und ohne Schreiben
  /// bleibt der Betreff leer: Eine erfundene Betreffzeile wäre schlimmer als
  /// ein leeres Feld, das erkennbar auf eine Eingabe wartet.
  String betreffFuer({required bool mitSchreiben}) {
    final teile = <String>[
      if (mitSchreiben) 'Anspruchsschreiben',
      if (_parteien.isNotEmpty) _parteien,
    ];

    if (_unfallDatum.isNotEmpty) teile.add('Unfall vom $_unfallDatum');

    final zeichen = vorgang?.aktenzeichen.trim() ?? '';
    if (zeichen.isNotEmpty) teile.add('Unser Zeichen: $zeichen');

    return teile.join(' · ');
  }

  /// Anrede, Bezugssatz und Grußformel — dazwischen bleibt Platz für den
  /// Anwalt. [empfaenger] bestimmt die Anrede: Schreibt er nur dem Mandanten,
  /// wird dieser persönlich angesprochen. Der Bezugssatz („übersende ich
  /// Ihnen anbei …") steht nur bei [mitSchreiben] — ohne Anhang wäre er
  /// schlicht falsch.
  String textFuer(List<String> empfaenger, {required bool mitSchreiben}) {
    final unterschrift = kanzlei.name.trim();
    final bezug = mitSchreiben ? _bezugssatz : '';
    return '''
${anredeFuer(empfaenger)},

$bezug


Mit freundlichen Grüßen

$unterschrift''';
  }

  /// „Sehr geehrter Herr Müller" nur, wenn ausschließlich der Mandant
  /// angeschrieben wird. Sobald die Versicherung mitliest, gilt die neutrale
  /// Form — eine an zwei Empfänger gerichtete Mail kann nur eine Anrede haben.
  String anredeFuer(List<String> empfaenger) =>
      nurAnDenMandanten(empfaenger) && mandant != null
      ? mandant!.briefanrede
      : 'Sehr geehrte Damen und Herren';

  /// Ob im Feld „An" ausschließlich der Mandant steht.
  ///
  /// Öffentlich, weil daran zwei Dinge hängen: die Anrede oben **und** die
  /// persönliche Grußformel in einer Mail-Textvorlage (§4.7). Ein persönlicher
  /// Gruß, den die gegnerische Versicherung mitliest, wäre keiner.
  bool nurAnDenMandanten(List<String> empfaenger) {
    final adressen = empfaenger
        .map((adresse) => adresse.trim().toLowerCase())
        .where((adresse) => adresse.isNotEmpty)
        .toSet();
    final mandantAdresse = mandant?.emailAdresse.trim().toLowerCase() ?? '';

    return mandantAdresse.isNotEmpty &&
        adressen.isNotEmpty &&
        adressen.every((adresse) => adresse == mandantAdresse);
  }

  /// Ein vollständiger Entwurf für den Einstieg: Vorschläge als Empfänger,
  /// Betreff, Text und die mitgegebenen Anhänge.
  EmailEntwurf entwurfMit(List<String> anhangPfade) {
    final adressen = vorschlaege.map((vorschlag) => vorschlag.adresse).toList();
    final mitSchreiben = anhangPfade.isNotEmpty;
    return EmailEntwurf(
      an: adressen,
      betreff: betreffFuer(mitSchreiben: mitSchreiben),
      text: textFuer(adressen, mitSchreiben: mitSchreiben),
      anhangPfade: anhangPfade,
      // Ohne Vorgang bleibt sie leer — dann wird auch nichts protokolliert.
      vorgangReferenz: vorgang?.referenz ?? '',
    );
  }

  String get _parteien {
    final links = (vorgang?.mandantName ?? mandant?.anzeigename ?? '').trim();
    final rechts = (vorgang?.gegner ?? _antwort?.versichererName ?? '').trim();
    if (links.isEmpty && rechts.isEmpty) return '';
    if (rechts.isEmpty) return links;
    if (links.isEmpty) return './. $rechts';
    return '$links ./. $rechts';
  }

  String get _bezugssatz {
    final zusatz = <String>[];
    if (_unfallDatum.isNotEmpty) zusatz.add('Unfall vom $_unfallDatum');

    final schein = _antwort?.versicherungsscheinNr?.trim() ?? '';
    if (schein.isNotEmpty) zusatz.add('Versicherungsschein-Nr. $schein');

    final klammer = zusatz.isEmpty ? '' : ' (${zusatz.join(', ')})';
    final parteien = _parteien;
    final sache = parteien.isEmpty
        ? 'in obiger Angelegenheit'
        : 'in der Schadensache $parteien$klammer';

    return '$sache übersende ich Ihnen anbei das Anspruchsschreiben.';
  }

  /// Der Registereintrag zum Versicherernamen. Die Adresse landet vorausgewählt
  /// im Feld „An" — deshalb entscheidet hier **nicht** die Reihenfolge der
  /// Liste, sondern die Güte des Treffers: erst der genaue Name, dann der
  /// längste Teiltreffer. Das Register füllt das Backend selbsttätig aus jeder
  /// geparsten Antwort; stehen dort „HUK-COBURG" und „HUK-COBURG Allgemeine
  /// Versicherung AG" mit verschiedenen Adressen, darf nicht der Zufall
  /// bestimmen, an wen das Anspruchsschreiben geht.
  Versicherer? _ausRegister(String name) {
    final gesucht = name.trim().toLowerCase();
    if (gesucht.isEmpty) return null;

    Versicherer? bester;
    var besteLaenge = -1;

    for (final eintrag in versicherer) {
      if ((eintrag.email?.trim() ?? '').isEmpty) continue;

      final bekannt = eintrag.name.trim().toLowerCase();
      if (bekannt.isEmpty) continue;
      if (bekannt == gesucht) return eintrag;

      if (bekannt.contains(gesucht) || gesucht.contains(bekannt)) {
        if (bekannt.length > besteLaenge) {
          bester = eintrag;
          besteLaenge = bekannt.length;
        }
      }
    }

    return bester;
  }
}
