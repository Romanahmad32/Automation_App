import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/platzhalter_eintrag.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/platzhalter_gruppe.dart';

/// Die Platzhalter, die eine Vorlage aus einem Vorgang füllen kann — als
/// Auswahl, nach Gruppen geordnet (§4.7, §5.3).
///
/// **Abgeleitet, nicht aufgezählt.** Die Liste entsteht aus `FeldDatenquelle`,
/// also aus derselben Aufzählung, die auch die Ersetzung benutzt. Eine
/// handgeschriebene Auswahl daneben hat es gegeben (`MailPlatzhalter.haeufige`,
/// sechs Namen) — mit dem Eingeständnis im Kommentar, dass sie „stillschweigend
/// veraltet". Genau das kann hier nicht passieren: Eine neue Datenquelle
/// erscheint von selbst, und eine ohne Namen macht den Rundlauf-Test rot.
class PlatzhalterKatalog {
  const PlatzhalterKatalog._();

  /// Die Reihenfolge der Gruppen in der Auswahl — vom Empfänger zum Vorgang,
  /// wie der Anwalt eine Mail liest. [PlatzhalterGruppe.verfassen] steht
  /// **vorn**: Anrede und Gruß sind das, was er zuerst schreibt.
  static const List<PlatzhalterGruppe> reihenfolge = [
    PlatzhalterGruppe.verfassen,
    PlatzhalterGruppe.mandant,
    PlatzhalterGruppe.versicherer,
    PlatzhalterGruppe.vorgang,
  ];

  /// Alle Platzhalter, die aus einem Vorgang gefüllt werden.
  static List<PlatzhalterEintrag> vorgangsfelder() => [
    for (final quelle in FeldDatenquelle.waehlbare)
      PlatzhalterEintrag(
        platzhalter: quelle.platzhalter,
        bezeichnung: _ohneGruppenpraefix(quelle),
        gruppe: quelle.gruppe,
      ),
  ];

  /// Die Einträge einer Gruppe, in der Reihenfolge des Katalogs.
  static List<PlatzhalterEintrag> inGruppe(
    List<PlatzhalterEintrag> eintraege,
    PlatzhalterGruppe gruppe,
  ) => eintraege.where((eintrag) => eintrag.gruppe == gruppe).toList();

  /// Der Anzeigename ohne das Gruppenpräfix: In `FeldDatenquelle` heißt es
  /// „Mandant · Name", weil dort ein einzelnes Dropdown alle Quellen zeigt.
  /// Unter einer Gruppenüberschrift „Mandant" wäre die Wiederholung Lärm.
  static String _ohneGruppenpraefix(FeldDatenquelle quelle) {
    const trenner = ' · ';
    final teile = quelle.name.split(trenner);
    return teile.length > 1 ? teile.sublist(1).join(trenner) : quelle.name;
  }
}
