import 'package:automation_app/features/email_versand/domain/entities/beugung.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/entities/vorlagen_mangel.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_platzhalter.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';

/// Was an einer Mail-Textvorlage **beim Schreiben** schon zu sehen ist (§4.7,
/// ergänzt am 02.09.2026) — Platzhalter, die nie etwas liefern werden.
///
/// **Der Sinn ist der Zeitpunkt.** Dieselbe Auskunft gab bisher nur der
/// Versanddialog (`PlatzhalterFehlstelle`), also Wochen später und an einer
/// Vorlage, die längst als fertig galt: Dort steht dann „kein Feld dieses
/// Namens" unter einer Mail, die gleich hinausgehen soll. Hier steht es unter
/// dem Feld, in dem der Name gerade getippt wurde.
///
/// **Kein Riegel.** Die Prüfung meldet, sie verweigert nichts (§1.3): Eine
/// halb geschriebene Vorlage muss sich speichern lassen, und ob ein Name
/// gemeint war, weiß der Anwalt besser als eine Heuristik über
/// Teilzeichenketten.
class VorlagenPruefung {
  const VorlagenPruefung._();

  /// Alle Platzhalter aus Betreff **und** Text, die nichts liefern werden —
  /// jeder Name nur einmal, in der Reihenfolge des ersten Auftretens.
  ///
  /// Der Betreff zählt zuerst, wie in der Übersicht des Versanddialogs.
  static List<VorlagenMangel> maengel(MailVorlage vorlage) {
    final gefunden = <VorlagenMangel>[];
    for (final name in MailPlatzhalter.namenIn(
      '${vorlage.betreff}\n${vorlage.text}',
    )) {
      final hinweis = _hinweisZu(name);
      if (hinweis != null) {
        gefunden.add(VorlagenMangel(platzhalter: name, hinweis: hinweis));
      }
    }
    return gefunden;
  }

  /// Die Beugungen der Vorlage — Grundlage der Vorschau im Editor. Nur die
  /// **geglückten**: Was keine ergibt, steht als Mangel in [maengel] und wäre
  /// in einer Vorschau eine Zeile ohne Inhalt.
  static List<Beugung> beugungen(MailVorlage vorlage) => [
    for (final name in MailPlatzhalter.namenIn(
      '${vorlage.betreff}\n${vorlage.text}',
    ))
      ?Beugung.aus(name),
  ];

  /// Was an einem Namen auszusetzen ist, oder null, wenn nichts.
  ///
  /// Die Reihenfolge ist die Regel: Eine Beugung wird **als Beugung**
  /// beurteilt, nie als Datenquellenname — sonst bekäme `{{Mandant/}}` die
  /// Auskunft „kein Feld dieses Namens", die am Fehler vorbeigeht.
  static String? _hinweisZu(String name) {
    if (Beugung.istGemeint(name)) return _hinweisZurBeugung(name);
    if (MailPlatzhalter.istEigen(name)) return null;

    final vorschlag = FeldDatenquelleErkennung.erkenne(name);
    if (vorschlag.quelle.istGesetzt) return null;
    // Die Erkennung weiß selbst, wenn ein Name nach **zwei** Angaben klingt
    // (`{{VersicherungPlzOrt}}`) — diesen Satz nicht daneben neu erfinden.
    return vorschlag.hinweis ??
        'kein Feld dieses Namens — die Auswahl unten nennt die gültigen Namen';
  }

  static String? _hinweisZurBeugung(String name) {
    final beugung = Beugung.aus(name);
    if (beugung == null) {
      return 'Beugung unvollständig — zwei oder drei Formen erwartet, jede '
          'nicht leer, z. B. {{Mandant/Mandantin}}';
    }

    // Der Preis der Schreibweise, und hier ist er einzufangen:
    // `{{MandantOrt/MandantPlz}}` ist als Beugung gelesen das Wort
    // „MandantOrt". Trägt eine Form einen Namen aus dem Katalog, war fast
    // sicher keine Beugung gemeint — zwei Angaben brauchen zwei Platzhalter.
    for (final form in [beugung.maennlich, beugung.weiblich]) {
      final katalogName = _alsKatalogname(form);
      if (katalogName != null) {
        return '„$form" ist selbst ein Feldname ($katalogName) — als Beugung '
            'gelesen wird daraus das Wort „$form". Zwei Angaben brauchen zwei '
            'Platzhalter.';
      }
    }
    return null;
  }

  /// Der Klartext der Datenquelle, wenn [form] **genau** einer ihrer Namen
  /// ist; sonst null.
  ///
  /// **Bewusst der genaue Name und nicht `quelleFuer`.** Die Erkennung ist
  /// eine Heuristik über Teilzeichenketten, und sie löst `Mandant`,
  /// `Mandantin` und sogar `Geschädigter` alle auf „Mandant · Name" auf — mit
  /// ihr hätte diese Prüfung ausgerechnet die zwei häufigsten Beugungen
  /// beanstandet. Der Fehlgriff, den sie fangen soll, sieht anders aus: Da
  /// stehen zwei Namen aus der Auswahlliste, und die sind wörtlich zu
  /// erkennen.
  static String? _alsKatalogname(String form) {
    final gesucht = FeldDatenquelleErkennung.normalisiere(form);
    for (final quelle in FeldDatenquelle.waehlbare) {
      if (FeldDatenquelleErkennung.normalisiere(quelle.platzhalter) ==
          gesucht) {
        return quelle.name;
      }
    }
    return null;
  }
}
