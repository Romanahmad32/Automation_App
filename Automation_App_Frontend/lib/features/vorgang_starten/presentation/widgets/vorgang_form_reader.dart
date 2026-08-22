import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Baut die Referenz `Nr/Jahr Abteilung[_Kennzeichen]` aus den Formularwerten.
/// Außerhalb von Verkehrsrecht (kein Gegner-Kennzeichen) entfällt der
/// Kennzeichen-Teil.
String baueReferenz(FormGroup form, Rechtsgebiet rechtsgebiet) {
  String valueOf(String c) => (form.control(c).value as String?)?.trim() ?? '';
  final nummer = valueOf('auftragsnummer');
  final jahrEingabe = int.tryParse(valueOf('auftragsjahr')) ?? 0;
  final jahr = jahrEingabe == 0 ? DateTime.now().year % 100 : jahrEingabe;
  final abteilung = valueOf('abteilung');
  final basis = '$nummer/${jahr.toString().padLeft(2, '0')} $abteilung';
  if (rechtsgebiet != Rechtsgebiet.verkehrsrecht) return basis;
  final kennzeichen = valueOf('kennzeichenGegner').toUpperCase();
  return kennzeichen.isEmpty ? basis : '${basis}_$kennzeichen';
}

/// Liest die typisierten Eingaben aus der FormGroup (entkoppelt die View von den
/// Control-Namen).
VorgangStartenDaten leseVorgangDaten(
  FormGroup form,
  Rechtsgebiet rechtsgebiet,
) {
  String v(String c) => (form.control(c).value as String?)?.trim() ?? '';
  return VorgangStartenDaten(
    auftragsnummer: int.tryParse(v('auftragsnummer')) ?? 0,
    auftragsjahr: int.tryParse(v('auftragsjahr')) ?? 0,
    abteilung: v('abteilung'),
    rechtsgebiet: rechtsgebiet,
    referenz: v('referenz'),
    vorname: v('mandantVorname'),
    nachname: v('mandantNachname'),
    strasseHausnummer: v('mandantStrasse'),
    postleitzahl: v('mandantPlz'),
    ort: v('mandantOrt'),
    emailAdresse: v('mandantEmail'),
    telefonnummer: v('mandantTelefon'),
    mandantKennzeichen: v('mandantKennzeichen').toUpperCase(),
    kennzeichenGegner: v('kennzeichenGegner').toUpperCase(),
    unfalltag: GermanDateField.parseDate(v('schadentag')),
    unfallort: v('unfallort'),
    unfalluhrzeit: v('unfalluhrzeit'),
    polizeiVorgangsnummer: v('polizeiVorgangsnummer'),
  );
}
