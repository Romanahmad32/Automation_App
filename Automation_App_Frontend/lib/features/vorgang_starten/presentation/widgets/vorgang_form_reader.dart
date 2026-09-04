import 'package:automation_app/core/general_classes/kennzeichen_normalisierung.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/features/sachgebiete/domain/services/abteilung_kuerzel.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Baut die Referenz `Nr/Jahr Abteilung[_Kennzeichen]` aus den Formularwerten.
/// Außerhalb von Verkehrsrecht (kein Gegner-Kennzeichen) entfällt der
/// Kennzeichen-Teil.
String baueReferenz(FormGroup form, String rechtsgebiet) {
  String valueOf(String c) => (form.control(c).value as String?)?.trim() ?? '';
  final nummer = valueOf('auftragsnummer');
  final jahrEingabe = int.tryParse(valueOf('auftragsjahr')) ?? 0;
  final jahr = jahrEingabe == 0 ? DateTime.now().year % 100 : jahrEingabe;
  final abteilung = AbteilungKuerzel.normalisiere(valueOf('abteilung'));
  final basis = '$nummer/${jahr.toString().padLeft(2, '0')} $abteilung';
  if (!RechtsgebietWert.istVerkehrsrecht(rechtsgebiet)) return basis;
  final kennzeichen = kennzeichenAusFormular(valueOf('kennzeichenGegner'));
  return kennzeichen.isEmpty ? basis : '${basis}_$kennzeichen';
}

/// Liest die typisierten Eingaben aus der FormGroup (entkoppelt die View von den
/// Control-Namen).
VorgangStartenDaten leseVorgangDaten(FormGroup form, String rechtsgebiet) {
  String v(String c) => (form.control(c).value as String?)?.trim() ?? '';
  return VorgangStartenDaten(
    auftragsnummer: int.tryParse(v('auftragsnummer')) ?? 0,
    auftragsjahr: int.tryParse(v('auftragsjahr')) ?? 0,
    abteilung: AbteilungKuerzel.normalisiere(v('abteilung')),
    rechtsgebiet: rechtsgebiet,
    referenz: v('referenz'),
    vorname: v('mandantVorname'),
    nachname: v('mandantNachname'),
    strasseHausnummer: v('mandantStrasse'),
    postleitzahl: v('mandantPlz'),
    ort: v('mandantOrt'),
    emailAdresse: v('mandantEmail'),
    telefonnummer: v('mandantTelefon'),
    mandantKennzeichen: kennzeichenAusFormular(v('mandantKennzeichen')),
    kennzeichenGegner: kennzeichenAusFormular(v('kennzeichenGegner')),
    unfalltag: GermanDateField.parseDate(v('schadentag')),
    unfallort: v('unfallort'),
    unfalluhrzeit: v('unfalluhrzeit'),
    polizeiVorgangsnummer: v('polizeiVorgangsnummer'),
  );
}

/// Ein Kennzeichen in der Konvention `HG-E 1427`.
///
/// Das Feld stellt sie beim Verlassen selbst her (`KennzeichenField`) — hier
/// wird sie ein zweites Mal angewandt, weil ein eingefügter Wert das Feld nie
/// verlassen haben muss: Wer `hge1427` einfügt und sofort auf „Speichern"
/// klickt, hätte den Rohwert in Referenz, Vorgang und Registereintrag stehen.
/// Was sich nicht als Kennzeichen lesen lässt, bleibt großgeschrieben stehen
/// statt zu verschwinden.
String kennzeichenAusFormular(String wert) =>
    normalizeKennzeichen(wert) ?? wert.toUpperCase();
