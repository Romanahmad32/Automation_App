import 'package:automation_app/features/email_versand/domain/entities/beugung.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_platzhalter.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/platzhalter_gruppe.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';

/// **Warum** ein Platzhalter leer geblieben ist — und wo die Angabe gepflegt
/// wird (§4.7, ergänzt am 02.09.2026).
///
/// Das ist die Auskunft, die vorher fehlte. Die Übersicht sagte „bleibt leer —
/// die Zeile entfällt", und der Sprung in den Vorlagentext zeigte, wo der
/// Platzhalter steht: beides Dinge, die der Anwalt schon wusste, denn er hat
/// die Vorlage geschrieben. Was er **nicht** wusste: ob die Angabe am Vorgang
/// fehlt, im Register, oder ob er sich im Namen verschrieben hat.
///
/// Der letzte Fall ist der wertvollste: `{{Adresse}}` löst auf **keine**
/// Datenquelle auf und bleibt darum immer leer. Vorher war das von einer
/// wirklich fehlenden Angabe nicht zu unterscheiden.
class PlatzhalterFehlstelle {
  const PlatzhalterFehlstelle._();

  /// Der Satz, der an einem leeren Platzhalter steht. [mitVorgang] false
  /// heisst: Es ist gar kein Vorgang gewählt — dann fehlt nicht die Angabe,
  /// sondern die Akte.
  static String fuer(String name, {required bool mitVorgang}) {
    // Eine geglückte Beugung kommt hier nie an: Sie hat immer eine Form, und
    // dieser Satz steht nur an leer gebliebenen Platzhaltern. Wer hier landet,
    // hat eine Beugung gemeint und sie nicht getroffen — genau das sagen.
    if (Beugung.istGemeint(name)) {
      return 'Beugung unvollständig — zwei oder drei Formen erwartet, '
          'z. B. {{Mandant/Mandantin}}';
    }

    if (MailPlatzhalter.istEigen(name)) {
      return 'wird oben im Dialog gewählt';
    }

    final quelle = FeldDatenquelleErkennung.quelleFuer(name);
    if (!quelle.istGesetzt) {
      // Kein Vorwurf, sondern der wahrscheinlichste Grund: Der Katalog kennt
      // rund dreissig Namen, und die Auswahl in der Vorlagenverwaltung listet
      // sie alle — von Hand getippt ist ein Name schnell danebengegriffen.
      return 'kein Feld dieses Namens — Schreibweise prüfen, die Auswahl in '
          'den Einstellungen nennt die gültigen Namen';
    }

    if (!mitVorgang) return 'kein Vorgang gewählt — oben im Dialog wählbar';

    return switch (quelle.gruppe) {
      PlatzhalterGruppe.mandant => 'im Mandantenregister nicht erfasst',
      PlatzhalterGruppe.versicherer =>
        'weder in der Zentralruf-Antwort noch am Vorgang erfasst',
      _ => 'am Vorgang nicht erfasst',
    };
  }

  /// Der Klartext der Quelle — „Mandant · Telefon" statt `{{MandantTelefon}}`.
  /// Leer für die Platzhalter, die beim Verfassen entstehen: Ihre Namen sagen
  /// schon, was sie sind.
  static String bezeichnungFuer(String name) {
    if (Beugung.istGemeint(name)) return 'Beugung nach der Anredeart';
    if (MailPlatzhalter.istEigen(name)) return '';
    final quelle = FeldDatenquelleErkennung.quelleFuer(name);
    return quelle.istGesetzt ? quelle.name : '';
  }
}
