import 'package:automation_app/core/general_widgets/buttons/dropdowns/template_selector.dart';
import 'package:automation_app/core/general_widgets/form/feld_schluessel.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_senden_bestaetigung.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_versand_dialog.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_manuelle_antwort_dialog.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/referenz_teile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_section.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_aktionsleiste.dart';
import 'package:automation_app/features/word_automation/domain/entities/ablage_format.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ausfuell_formular.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/vorgang_selector.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/manual_reply_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'bedienung.dart';

/// Die Schritte des Hauptwegs (Durchlauf 1 der E2E-Suite, #184), je Reiter
/// einer: Vorgang starten, Antwort im Postfach übernehmen, Schreiben im
/// Word-Assistenten erzeugen, in der Akte ablegen, versenden.
///
/// Hier steht nur die **Bedienung**; was danach geprüft wird, steht im
/// Durchlauf selbst. So liest sich der Durchlauf als Ablauf, und eine geänderte
/// Oberfläche betrifft eine Stelle.
class HauptwegSchritte {
  final Bedienung bedienung;

  HauptwegSchritte(this.bedienung);

  /// Erzeugen, PDF-Vorschau und Ablage als PDF rechnet Word — echt, aber ohne
  /// Außenwirkung. Kalt dauert das spürbar.
  static const Duration wordFrist = Duration(seconds: 120);

  Finder _feld(String name) => find.byKey(FeldSchluessel.fuer(name)!);

  /// Reiter „Vorgang starten": Mandant aus dem Register übernehmen, Unfall
  /// erfassen, „Zentralruf-Formular ausfüllen" — im Testmodus die Attrappe.
  Future<void> vorgangStarten({
    required int mandantId,
    required String mandantFilter,
    required String kennzeichenGegner,
    required String unfalldatum,
  }) async {
    await bedienung.waehleReiter('Vorgang starten');
    await bedienung.waehleAus(
      find.byKey(MandantSection.auswahlSchluessel),
      find.byKey(MandantSection.eintragSchluessel(mandantId)),
      filter: mandantFilter,
    );
    await bedienung.gebeEin(_feld('kennzeichenGegner'), kennzeichenGegner);
    await bedienung.gebeEin(_feld('schadentag'), unfalldatum);
    await bedienung.tippeAktiv(
      find.byKey(VorgangAktionsleiste.zentralrufSchluessel),
    );
    await bedienung.warteAuf(
      find.textContaining('gespeichert. Direkt weiterarbeiten?'),
      was: 'die Bestätigung des gespeicherten Vorgangs',
    );
  }

  /// Postfach: die Antwortmail von Hand einfügen, auswerten lassen und in
  /// den Vorgang übernehmen. Der Testmodus hat kein IMAP-Postfach — eine
  /// simulierte Antwort erreicht den Posteingang deshalb nicht; der manuelle
  /// Weg läuft durch dasselbe Formular und dieselbe Übernahme.
  Future<void> antwortUebernehmen(String mailtext) async {
    await bedienung.tippe(Bedienung.knopf('Zum Postfach'));
    await bedienung.tippe(Bedienung.knopf('Antwort manuell einfügen'));
    await bedienung.gebeEin(
      find.byKey(ManualReplyInput.textSchluessel),
      mailtext,
    );
    await bedienung.tippeAktiv(Bedienung.knopf('Daten extrahieren'));
    await bedienung.tippeAktiv(
      Bedienung.knopf('Übernehmen und Vorlage ausfüllen'),
    );
    await bedienung.warteBisWeg(
      find.byType(MailboxManuelleAntwortDialog),
      was: 'der Dialog „Antwort manuell einfügen"',
    );
  }

  /// Word-Assistent: Vorgang und Vorlage wählen, leere Felder füllen,
  /// erzeugen, die Vorschau bestätigen.
  Future<void> schreibenErstellen({
    required String referenz,
    required String vorlage,
  }) async {
    await bedienung.waehleReiter('Word Automation');
    await bedienung.waehleAus(
      find.byKey(VorgangSelector.feldSchluessel),
      find.byKey(
        VorgangSelector.eintragSchluessel(Vorgang.normalizeReferenz(referenz)),
      ),
      filter: ReferenzTeile.zeichenAus(referenz),
    );
    // Die Vorlageneinträge tragen keinen Key; der Name im Menü ist eindeutig.
    // Nur im Menü suchen: `find.text` träfe auch das Feld, in dem der Filter
    // steht — und ein Tipp darauf schlösse das Menü wieder.
    await bedienung.waehleAus(
      find.byKey(TemplateSelector.feldSchluessel),
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text(vorlage),
      ),
      filter: vorlage,
    );
    final erstellen = Bedienung.knopf('Dokument erstellen');
    await bedienung.warteAuf(
      erstellen,
      frist: wordFrist,
      was: 'das Ausfüllformular',
    );
    await _leereFelderFuellen();
    await bedienung.tippeAktiv(erstellen);
    await bedienung.tippeAktiv(Bedienung.knopf('Bestätigen'), frist: wordFrist);
  }

  /// Speicherschritt: Word und PDF in die Akte des Mandanten legen, die der
  /// Assistent aus dem Vorgang vorwählt.
  Future<void> inAkteAblegen(String mandantName) async {
    await bedienung.warteAuf(
      find.text(mandantName),
      was: 'den vorgewählten Mandanten der Ablage',
    );
    await bedienung.tippe(find.text(AblageFormat.beide.bezeichnung));
    await bedienung.tippeAktiv(Bedienung.knopf('In Akte ablegen'));
    await bedienung.warteAuf(
      Bedienung.knopf('Erneut ablegen'),
      frist: wordFrist,
      was: 'die Bestätigung der Ablage',
    );
  }

  /// Versanddialog: vorbelegt aus Vorgang und Akte; „Senden", dann in der
  /// Rückfrage „Senden" — im Testmodus legt die Attrappe eine `.eml` ab.
  Future<void> versenden() async {
    await bedienung.tippe(Bedienung.knopf('E-Mail verfassen und senden'));
    await bedienung.tippeAktiv(
      find.descendant(
        of: find.byType(EmailVersandDialog),
        matching: Bedienung.knopf('Senden'),
      ),
    );
    await bedienung.tippe(find.byKey(EmailSendenBestaetigung.sendenSchluessel));
    await bedienung.warteBisWeg(
      find.byType(EmailVersandDialog),
      was: 'der Versanddialog nach dem Senden',
    );
  }

  /// Füllt jedes sichtbare, leere Feld des Ausfüllformulars mit „E2E". Die
  /// Vorlage des Ausgangsbestands führt jedes Feld als Pflicht; was der
  /// Vorgang nicht vorbelegt, muss ein Mensch tippen — hier die Suite.
  Future<void> _leereFelderFuellen() async {
    final felder = find.descendant(
      of: find.byType(AusfuellFormular),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              FeldSchluessel.praefix,
            ),
      ),
    );
    final schluessel = [
      for (final element in felder.evaluate()) element.widget.key!,
    ];
    for (final key in schluessel) {
      if (bedienung.textIn(find.byKey(key)).trim().isEmpty) {
        await bedienung.gebeEin(find.byKey(key), 'E2E');
      }
    }
  }
}
