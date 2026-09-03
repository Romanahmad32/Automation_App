import 'package:automation_app/features/email_versand/domain/entities/anrede_neutral_grund.dart';
import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_empfaenger_vorschlag.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/empfaenger_art.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';

/// Baut aus den Daten des Vorgangs den Anfang der Mail (§4.7): Empfänger, die
/// die App schon kennt, einen Betreff aus Zeichen und Parteien und einen
/// Textrumpf mit passender Anrede. Der Anwalt vervollständigt nur noch.
///
/// **Das ist die Vorbelegung, nicht die Vorlage.** Wählt der Anwalt eine
/// Mail-Textvorlage (§4.7, §5.3), ersetzt `MailVorlagenFueller` Betreff und
/// Text; diese Methoden bleiben der Rückfall und werden nicht abgeschafft —
/// ohne Vorlage im Bestand sind sie das Einzige, was dasteht. Zwei Auskünfte
/// von hier gelten aber auch dort weiter, weil sie an den Empfängern hängen
/// und nicht am Vorgang: [anredeFuer] und [nurAnDenMandanten].
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

  /// Betreff aus Parteien, Unfalldatum und Zeichen — je nach dem, was der
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

    final zeichen = vorgang?.zeichen.trim() ?? '';
    if (zeichen.isNotEmpty) teile.add('Unser Zeichen: $zeichen');

    return teile.join(' · ');
  }

  /// Anrede, Bezugssatz und Zusatzgruß — dazwischen bleibt Platz für den
  /// Anwalt. [empfaenger] bestimmt die Anrede: Schreibt er nur dem Mandanten,
  /// wird dieser persönlich angesprochen. Der Bezugssatz („übersende ich
  /// Ihnen anbei …") steht nur bei [mitSchreiben] — ohne Anhang wäre er
  /// schlicht falsch.
  /// [zusatzgruss] ist der beim Verfassen gewählte persönliche Gruß (§4.7).
  /// Er steht als eigene Zeile unter der Anrede; ist er leer, entfällt die
  /// Zeile **ganz** — dieselbe Regel wie beim Platzhalter in einer Vorlage,
  /// damit die Vorbelegung nicht anders aussieht als eine Vorlage.
  String textFuer(
    List<String> empfaenger, {
    required bool mitSchreiben,
    String zusatzgruss = '',
    Anredebaustein? anredebaustein,
    bool? anredeNeutral,
    Anrede? geschlecht,
  }) {
    final unterschrift = kanzlei.name.trim();
    final bezug = mitSchreiben ? _bezugssatz : '';
    final gruss = zusatzgruss.trim();
    final grusszeile = gruss.isEmpty ? '' : '\n$gruss,';
    final anrede = anredeFuer(
      empfaenger,
      baustein: anredebaustein,
      neutral: anredeNeutral,
      geschlecht: geschlecht,
    );
    return '''
$anrede,$grusszeile

$bezug


Mit freundlichen Grüßen

$unterschrift''';
  }

  /// Die Anredezeile dieser Mail — **ohne Komma**, das setzt die Vorlage.
  ///
  /// Namentlich angeredet wird nur, wenn ausschließlich der Mandant
  /// angeschrieben wird: Eine an zwei Empfänger gerichtete Mail kann nur eine
  /// Anrede haben. [neutral] übersteuert das auf Wunsch des Anwalts (§4.7,
  /// ergänzt am 02.09.2026) — null heißt „wie der Empfängerkreis es ergibt".
  ///
  /// [baustein] ist der beim Verfassen gewählte **Anfang** (§4.7, §7.1); die
  /// Beugung und das Anredewort setzt er selbst zusammen. Ohne Baustein gilt
  /// [Anredebaustein.rueckfall] — der Bestand kann leer sein, und dann darf
  /// keine Mail ohne Anrede hinausgehen.
  /// [geschlecht] ist die je Mail gewählte Anredeart (§4.7, ergänzt am
  /// 02.09.2026); null heißt „wie am Mandanten hinterlegt" ([geschlechtFuer]).
  String anredeFuer(
    List<String> empfaenger, {
    Anredebaustein? baustein,
    bool? neutral,
    Anrede? geschlecht,
  }) {
    // Hat der Anwalt entschieden, gilt seine Entscheidung — auch gegen den
    // Empfängerkreis: „änderbar" heisst änderbar (§4.7). Nur solange er
    // **nicht** entschieden hat (null), entscheidet das Feld „An".
    final persoenlich = neutral == null
        ? nurAnDenMandanten(empfaenger)
        : !neutral;
    // Der Rückfall geht **denselben** Weg (geändert am 02.09.2026): Bis dahin
    // lief hier `Mandant.briefanrede`, und die liest nur den Registereintrag —
    // die je Mail gewählte Anredeart fiel unter den Tisch, und die Mail redete
    // „Damen und Herren" an, während ihr Text von „unserer Mandantin" schrieb.
    // Ohne Mandanten ist der Nachname leer, und `zeileFuer` trägt die Zeile
    // dann allein („Sehr geehrter Herr", geändert am 03.09.2026); ein eigener
    // Zweig dafür wäre ein zweites Ergebnis. Bis dahin stand hier „wird von
    // selbst neutral" — seit der Änderung das Gegenteil dessen, was geschieht.
    return (baustein ?? Anredebaustein.rueckfall).zeileFuer(
      anrede: geschlechtFuer(geschlecht),
      nachname: mandant?.nachname ?? '',
      persoenlich: persoenlich,
    );
  }

  /// Die für diese Mail geltende Anredeart (§5.1): Die **gewählte** schlägt
  /// die am Mandanten hinterlegte, und fehlt beides, wird nicht geraten.
  ///
  /// Die eine Stelle, an der das entschieden wird — sie beugt sowohl die
  /// Anredezeile als auch `{{Mandant/Mandantin}}` im Vorlagentext. Zwei
  /// Rechnungen nebeneinander liefen auseinander, und dann redete eine Mail
  /// „Frau Meier" an und schriebe im Text von „unserem Mandanten".
  Anrede geschlechtFuer(Anrede? gewaehlt) =>
      gewaehlt ?? mandant?.anrede ?? Anrede.keine;

  /// Ob die Anredezeile ohne Zutun **gebeugt** ausfällt — die Vorauswahl des
  /// Umschalters „neutral anreden". Ohne bekannten Mandanten im Feld „An"
  /// oder ohne Anredeart gibt es nichts persönlich Anzuredendes; die je Mail
  /// **gewählte** Anredeart zählt dabei mit, denn mit ihr ist die Angabe da,
  /// die am Register fehlte.
  bool anredePersoenlichMoeglich(
    List<String> empfaenger, {
    Anrede? geschlecht,
  }) =>
      nurAnDenMandanten(empfaenger) &&
      anredeGebeugtMachbar(geschlecht: geschlecht);

  /// Ob überhaupt eine **gebeugte** Anredezeile möglich wäre, wenn der Anwalt
  /// sie verlangt — ohne Rücksicht auf den Empfängerkreis (ergänzt am
  /// 02.09.2026).
  ///
  /// Der Unterschied zu [anredePersoenlichMoeglich] ist der Umschalter
  /// „neutral anreden": Der wurde nur angeboten, wenn die namentliche Anrede
  /// **schon** galt — also nie in dem Fall, in dem man ihn braucht. Wer an die
  /// Versicherung schrieb und den Mandanten trotzdem namentlich ansprechen
  /// wollte, hatte keinen Griff dafür, obwohl „änderbar" änderbar heisst
  /// (§4.7).
  ///
  /// **Es zählt allein die Anredeart** (geändert am 03.09.2026) — vorher stand
  /// hier zusätzlich ein Mandant mit Nachnamen. Seit [Anredebaustein.zeileFuer]
  /// die Zeile auch ohne Namen beugt („Sehr geehrter Herr"), war das die
  /// falsche Frage: Der Umschalter verschwand ausgerechnet dort, wo die Zeile
  /// gebeugt hinausging und der Anwalt sie zurücknehmen wollte — bei der Mail
  /// an die Versicherung zu einem Vorgang ohne Registermandanten. Deshalb
  /// heisst die Zusage jetzt „gebeugt" und nicht mehr „namentlich": Der Name
  /// ist die Zugabe, die Beugung ist der Schalter. Ohne Anredeart bleibt
  /// wirklich nichts zu schalten — dann ist jede Form dieselbe.
  bool anredeGebeugtMachbar({Anrede? geschlecht}) =>
      geschlechtFuer(geschlecht) != Anrede.keine;

  /// Warum die Anredezeile **neutral** ausfällt (§4.7, ergänzt am
  /// 02.09.2026) — null heisst: sie ist namentlich, oder der Anwalt hat die
  /// neutrale Form selbst angehakt.
  ///
  /// Dieselben Bedingungen wie in [anredeFuer] und [Anredebaustein.zeileFuer],
  /// nur nach ihrem **Grund** befragt: Die Zeile war neutral, und niemand
  /// sagte, weshalb. Die Reihenfolge entscheidet, was der Anwalt liest — erst
  /// der Empfängerkreis (dann ist die neutrale Anrede richtig), dann die
  /// Lücken im Register (dann ist sie eine Aufgabe).
  AnredeNeutralGrund? neutralGrund(
    List<String> empfaenger, {
    bool? neutral,
    Anrede? geschlecht,
  }) {
    // Seine eigene Entscheidung braucht keine Erklärung — das Häkchen steht ja
    // daneben.
    if (neutral == true) return null;
    // Ohne Nachnamen trägt eine gewählte Anredeart die Zeile allein („Sehr
    // geehrter Herr", `Anredebaustein.zeileFuer`, geändert am 03.09.2026).
    // Dann ist sie nicht neutral, und es gibt nichts zu erklären — vor der
    // Mandantenprüfung, denn genau dort fehlt der Nachname.
    if (_nachname.isEmpty && geschlechtFuer(geschlecht) != Anrede.keine) {
      return null;
    }
    if (mandant == null) return AnredeNeutralGrund.keinMandant;

    final persoenlich = neutral == null
        ? nurAnDenMandanten(empfaenger)
        : !neutral;
    if (!persoenlich) {
      // „Der Mandant steht nicht allein im Feld ‚An'" hat drei ganz
      // verschiedene Ursachen, und nur die letzte sieht man. Die Ursache steht
      // vor dem Symptom: Ohne hinterlegte Adresse erkennt `nurAnDenMandanten`
      // den Mandanten nie — auch dann nicht, wenn genau seine Adresse dort
      // eingetippt ist. Und ein leeres Feld „An" ist kein Mitleser, sondern
      // der Anfang; „noch jemand steht dort" wäre dort schlicht falsch.
      if (_mandantAdresse.isEmpty) return AnredeNeutralGrund.keineAdresse;
      if (_adressen(empfaenger).isEmpty) {
        return AnredeNeutralGrund.keinEmpfaenger;
      }
      return AnredeNeutralGrund.mitleser;
    }

    if (mandant!.nachname.trim().isEmpty) {
      return AnredeNeutralGrund.keinNachname;
    }
    if (geschlechtFuer(geschlecht) == Anrede.keine) {
      // Dieselbe Ausnahme wie beim Häkchen oben, und sie war hier zunächst
      // vergessen: `keine` entsteht auf zwei Wegen. Steht am Mandanten nichts,
      // ist es eine Lücke — hat der Anwalt „Keine Angabe" **gewählt**, ist es
      // seine Entscheidung, und die als Mangel zu melden hiesse, ihm seine
      // eigene Wahl vorzuhalten.
      return geschlecht == Anrede.keine
          ? null
          : AnredeNeutralGrund.keineAnredeart;
    }
    return null;
  }

  /// Ob im Feld „An" ausschließlich der Mandant steht.
  ///
  /// Öffentlich wegen der Anrede: Eine an zwei Empfänger gerichtete Mail kann
  /// nur eine haben. Am **Zusatzgruß** hängt das seit dem 02.09.2026 nicht mehr
  /// — den entscheidet die Vorlagenwahl (§4.7, [liestJemandMit]).
  bool nurAnDenMandanten(List<String> empfaenger) {
    final adressen = _adressen(empfaenger);
    final mandantAdresse = _mandantAdresse;

    return mandantAdresse.isNotEmpty &&
        adressen.isNotEmpty &&
        adressen.every((adresse) => adresse == mandantAdresse);
  }

  /// Ob neben dem Mandanten noch jemand mitliest — die Gegenseite etwa.
  ///
  /// Nur ein **Hinweis**, keine Sperre: Ob der persönliche Zusatzgruß trotzdem
  /// mitgeht, entscheidet der Anwalt über die Vorlage (§4.7, geändert am
  /// 02.09.2026). Ist die Mandantenadresse gar nicht bekannt, wird **nichts**
  /// behauptet — dann ist nicht zu unterscheiden, wer da steht, und eine
  /// Warnung auf Verdacht stünde bei jeder Mail ohne Registereintrag.
  bool liestJemandMit(List<String> empfaenger) {
    final mandantAdresse = _mandantAdresse;
    if (mandantAdresse.isEmpty) return false;

    return _adressen(empfaenger).any((adresse) => adresse != mandantAdresse);
  }

  String get _mandantAdresse =>
      mandant?.emailAdresse.trim().toLowerCase() ?? '';

  /// Der Nachname, mit dem namentlich angeredet wird — leer, wenn kein
  /// Mandant im Register steht oder dort keiner hinterlegt ist. Beides führt
  /// zur selben Zeile, deshalb dieselbe Abfrage.
  String get _nachname => mandant?.nachname.trim() ?? '';

  Set<String> _adressen(List<String> empfaenger) => empfaenger
      .map((adresse) => adresse.trim().toLowerCase())
      .where((adresse) => adresse.isNotEmpty)
      .toSet();

  /// Ein vollständiger Entwurf für den Einstieg: Vorschläge als Empfänger,
  /// Betreff, Text und die mitgegebenen Anhänge.
  EmailEntwurf entwurfMit(
    List<String> anhangPfade, {
    String zusatzgruss = '',
    Anredebaustein? anredebaustein,
  }) {
    final mitSchreiben = anhangPfade.isNotEmpty;
    final entwurf = EmailEntwurf(
      an: [for (final vorschlag in vorschlaege) vorschlag.adresse],
      betreff: betreffFuer(mitSchreiben: mitSchreiben),
      anhangPfade: anhangPfade,
      // Ohne Vorgang bleibt sie leer — dann wird auch nichts protokolliert.
      vorgangReferenz: vorgang?.referenz ?? '',
    );
    // Der Text kommt aus **[EmailEntwurf.alleEmpfaenger]** des eben gebauten
    // Entwurfs, nicht aus der Vorschlagsliste (geändert am 03.09.2026). Beide
    // sind hier gleich, weil noch niemand in Kopie steht — aber der Cubit
    // schreibt sich die eingesetzte Anredezeile über `alleEmpfaenger` mit
    // (`anredeImText`) und behauptet dabei, es sei dieselbe Rechnung. Über
    // zwei verschiedene Listen war das eine Zusage auf Widerruf: Sobald hier
    // je ein Empfänger in Kopie entstünde, suchte `TextNachtrag` im Text nach
    // einer Zeile, die nie hineingeschrieben wurde.
    return entwurf.copyWith(
      text: textFuer(
        entwurf.alleEmpfaenger,
        mitSchreiben: mitSchreiben,
        zusatzgruss: zusatzgruss,
        anredebaustein: anredebaustein,
      ),
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
