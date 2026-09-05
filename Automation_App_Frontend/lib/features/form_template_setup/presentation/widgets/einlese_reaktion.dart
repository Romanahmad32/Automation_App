import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_abgleich.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagenname_vorschlag.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/abgleich_dialog.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:flutter/material.dart';

/// Die Rückfrage nach einem Dateiwechsel — [zeigeAbgleichDialog] in
/// Funktionsform, damit [EinleseReaktion] ohne echten Dialog prüfbar bleibt.
typedef AbgleichFrage =
    Future<List<String>> Function(
      BuildContext context, {
      required String dateiname,
      required List<String> felder,
    });

/// Was passiert, wenn eine Word-Datei **fertig gelesen** ist (#104 Stufe 3c) —
/// die beiden Reaktionen des Ablaufs „Datei zuerst":
///
/// 1. **Felder anlegen.** Bei einer neuen Vorlage werden die erkannten
///    Platzhalter von selbst zu Feldern
///    (`VorlagenBearbeitung.automatischUebernehmen`, je Datei einmal). In einer
///    bestehenden Vorlage passiert das nie — dort stünde es gegen Handarbeit,
///    die schon da ist.
/// 2. **Abgleichen.** Hat der Wechsel einer Datei Felder ins Leere laufen
///    lassen ([FeldAbgleich]), fragt der [AbgleichDialog] einmal gesammelt
///    nach, welche davon mitgehen sollen. Gefragt, nicht gelöscht (§1.3).
///
/// **Eigene Klasse ohne Widget-Abhängigkeit**, wie `VorlagenBearbeitung` und
/// `ZuordnungsAktionen`: Die Detailseite setzt nur den `BlocListener` und ruft
/// [verarbeite]; alles, was dabei zu entscheiden ist, liegt hier und ist ohne
/// Seite prüfbar (`einlese_reaktion_test.dart`). Vom Widgetbaum bleibt der
/// [BuildContext] übrig — für die Meldung und den Dialog.
///
/// Die Klasse ist **zustandsbehaftet** und gehört deshalb der Seite, nicht dem
/// `build`: Sie merkt sich den zuletzt gesehenen [VorlagenStand], und ohne
/// dieses Gedächtnis gäbe es kein „vorher", gegen das ein Wechsel abzugleichen
/// wäre.
class EinleseReaktion {
  EinleseReaktion({
    required this.onGeaendert,
    this.gesperrt = nieGesperrt,
    this.dialog = zeigeAbgleichDialog,
  });

  /// Ruft die Seite zum Neuaufbau — Felder sind angelegt oder entfernt worden.
  final VoidCallback onGeaendert;

  /// Ob gerade nichts aufgehen darf. Die Seite meldet hier den Schreibzustand
  /// (`SubmittingFormTemplateData`): Solange gespeichert wird, ist die
  /// Verlassen-Wache gesperrt, und ein offener Dialog finge den Erfolgs-`pop`
  /// der Seite ab (siehe `VorlagenVerlassenWache.gesperrt`).
  final ValueGetter<bool> gesperrt;

  /// Die Rückfrage — im Test durch eine Funktion ohne Dialog ersetzbar.
  final AbgleichFrage dialog;

  /// Der Vorgabewert für [gesperrt]: Wer nichts sagt, sperrt nichts.
  static bool nieGesperrt() => false;

  /// Der zuletzt **verarbeitete** Stand — die Grundlage jedes Abgleichs.
  ///
  /// Zwei Regeln halten ihn brauchbar, und beide haben denselben Grund: Er
  /// darf nur dann weiterrücken, wenn wirklich verglichen wurde.
  ///
  /// * **Nur bekannte Stände.** Beim Dateiwechsel meldet der Bloc erst
  ///   `SlotPlaceholdersLoading`; dieser Zwischenstand ist
  ///   `platzhalterUnbekannt` und überschriebe genau das Wissen, gegen das
  ///   gleich darauf zu vergleichen wäre.
  /// * **Nichts, während eine Frage steht oder gespeichert wird.** Sonst
  ///   verschluckt ein zweiter Slot, der währenddessen fertig wird, seinen
  ///   eigenen Befund: Die nächste Rechnung vergliche gegen einen Stand, in
  ///   dem der Verlust schon eingetreten ist, und niemand fragte je danach.
  VorlagenStand? _letzterStand;

  /// Slots, deren Lesevorgang läuft **oder deren Ergebnis noch nicht
  /// verarbeitet ist**. Daran hängt „gerade neu gelesen": Nur ein Slot, der
  /// von `Loading` nach `Loaded` gewechselt ist, löst die Rückfrage aus — und
  /// nur er weiß, welcher Dateiname darin steht.
  ///
  /// Wird ein Durchlauf abgebrochen, kommen die betroffenen Slots hier zurück
  /// hinein. Merkposten und [_letzterStand] rücken immer zusammen weiter oder
  /// gar nicht; alles andere liesse einen Befund verschwinden.
  final Set<TemplateFileSlot> _ladend = {};

  /// Es steht schon eine Rückfrage — eine zweite darüber wäre nicht mehr zu
  /// beantworten.
  bool _dialogOffen = false;

  /// Der ganze Ablauf zu einem neuen Bloc-Zustand. Die Seite ruft ihn aus
  /// ihrem `BlocListener`, für jeden Zustand genau einmal.
  Future<void> verarbeite(
    BuildContext context,
    VorlagenBearbeitung bearbeitung,
    TemplatePlaceholdersState zustand,
  ) async {
    final fertig = _geradeFertig(zustand);
    _uebernehmen(context, bearbeitung, zustand);
    await _abgleichen(context, bearbeitung, zustand, fertig);
  }

  /// Die Slots, die seit dem letzten Zustand fertig gelesen wurden — und
  /// nebenbei die Fortschreibung von [_ladend].
  List<TemplateFileSlot> _geradeFertig(TemplatePlaceholdersState zustand) {
    final fertig = <TemplateFileSlot>[];
    for (final slot in TemplateFileSlot.values) {
      if (zustand.forSlot(slot) is SlotPlaceholdersLoading) {
        _ladend.add(slot);
      } else if (_ladend.remove(slot)) {
        fertig.add(slot);
      }
    }
    return fertig;
  }

  /// Schritt 1: Aus den gelesenen Platzhaltern Felder machen.
  ///
  /// Über **alle** gelesenen Slots, nicht nur die gerade fertig gewordenen:
  /// `VorlagenBearbeitung.automatischUebernehmen` merkt sich je Slot die Datei
  /// selbst und antwortet zu derselben mit 0 — die Schleife darf also
  /// gefahrlos breiter sein als der Anlass.
  void _uebernehmen(
    BuildContext context,
    VorlagenBearbeitung bearbeitung,
    TemplatePlaceholdersState zustand,
  ) {
    for (final slot in TemplateFileSlot.values) {
      final ergebnis = zustand.forSlot(slot);
      if (ergebnis is! SlotPlaceholdersLoaded) continue;
      final gelesen = ergebnis.placeholders;
      final angelegt = bearbeitung.automatischUebernehmen(slot, gelesen);
      if (angelegt == 0) continue;
      onGeaendert();
      // `hinweis` und nicht `erfolg`: Die Meldung verlangt etwas („prüfen"),
      // und `erfolg` ist nach drei Sekunden weg. Die beiden Zahlen stehen
      // getrennt, weil sie auseinandergehen dürfen — app-eigene Platzhalter
      // und Namensgleiche bekommen kein Feld (`PlatzhalterUebernahme`).
      Rueckmeldung.zeigeHinweis(
        context,
        '${gelesen.length} Platzhalter erkannt, '
        '${angelegt == 1 ? '1 Feld' : '$angelegt Felder'} angelegt — '
        'Typ und Datenquelle vorbelegt. Bitte die Zeilen mit Hinweis prüfen.',
      );
    }
  }

  /// Schritt 2: Was der Wechsel stehen gelassen hat, einmal gesammelt fragen.
  Future<void> _abgleichen(
    BuildContext context,
    VorlagenBearbeitung bearbeitung,
    TemplatePlaceholdersState zustand,
    List<TemplateFileSlot> fertig,
  ) async {
    final nachher = bearbeitung.stand(zustand);
    // Ein Ladezustand oder Lesefehler ist weder Grundlage noch Anlass. Die
    // gerade fertig gewordenen Slots wandern zurück in die Merkliste: Ihr
    // Ergebnis ist noch nicht verarbeitet.
    if (nachher.platzhalterUnbekannt) {
      _ladend.addAll(fertig);
      return;
    }

    final vorher = _letzterStand;
    // Ohne „vorher" ist nichts verschwunden: Das ist der Erstlauf beim Öffnen
    // der Seite. Er legt die Grundlage — und muss sie sofort legen, sonst
    // stünde der Abgleich nie auf einem Vergleichsstand.
    if (vorher == null) {
      _letzterStand = nachher;
      return;
    }

    // Abgebrochen, **bevor** irgendetwas weiterrückt: Was hier übersprungen
    // wird, muss beim nächsten Zustand noch zu finden sein.
    if (_dialogOffen || gesperrt()) {
      _ladend.addAll(fertig);
      return;
    }

    _letzterStand = nachher;
    // Ohne frisch gelesenen Slot gab es keinen Wechsel — wer eine Datei nur
    // entfernt, bekommt keine Rückfrage, sondern die Warnzeilen der
    // Feldertabelle.
    if (fertig.isEmpty) return;

    final verschwunden = FeldAbgleich.verschwundeneFelder(
      feldnamen: bearbeitung.feldnamen,
      vorher: vorher,
      nachher: nachher,
    );
    if (verschwunden.isEmpty) return;

    final pfad = bearbeitung.pfad(fertig.first);
    _dialogOffen = true;
    try {
      final entfernen = await dialog(
        context,
        dateiname: pfad == null
            ? 'der neuen Datei'
            : VorlagennameVorschlag.dateiname(pfad),
        felder: verschwunden,
      );
      // Die Seite kann während der Frage weg sein (Fenster zu, Vorgang
      // gewechselt) — dann ist auch die Bearbeitung nichts mehr wert, und ein
      // `setState` darauf liefe ins Leere.
      if (!context.mounted || entfernen.isEmpty) return;
      bearbeitung.felderEntfernen(entfernen);
      onGeaendert();
    } finally {
      _dialogOffen = false;
    }
  }
}
