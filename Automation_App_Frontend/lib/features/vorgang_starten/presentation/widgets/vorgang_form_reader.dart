import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/features/sachgebiete/domain/services/abteilung_kuerzel.dart';
import 'package:automation_app/features/sachgebiete/domain/services/rechtsgebiet_ableitung.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_cubit.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_katalog_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Baut die Referenz `Nr/Jahr Abteilung[_Kennzeichen]` aus den Formularwerten.
/// Außerhalb von Verkehrsrecht (kein Gegner-Kennzeichen) entfällt der
/// Kennzeichen-Teil. Das Kennzeichen steht darin, wie es eingegeben wurde
/// ([kennzeichenAusFormular], §4.2).
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

/// Das Rechtsgebiet, das aus der eingetragenen Abteilung folgt (§7.1) — oder
/// `null`, solange der Katalog nicht geladen ist oder die Abteilung keinen
/// Eintrag hat. `null` heisst „nichts vorzuschlagen", nie „Verkehrsrecht".
///
/// Greift auf den app-weiten `SachgebietCubit` zu, wie es die Auswahllisten
/// über `SachgebietKatalogBuilder` auch tun; die Ableitungsregel selbst steht
/// prüfbar in [RechtsgebietAbleitung].
String? rechtsgebietZurAbteilung(FormGroup form) {
  final stand = getIt<SachgebietCubit>().state;
  if (stand is! SachgebietKatalogGeladen) return null;
  return RechtsgebietAbleitung.zuAbteilung(
    stand.auswahl,
    form.control('abteilung').value as String?,
  );
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

/// Ein Kennzeichen, **wie es eingegeben wurde** — gestutzt und mit
/// vereinheitlichtem Leerraum, sonst unverändert (§4.2, geändert am
/// 11.09.2026). Bis dahin brachte diese Stelle den Wert in die Konvention
/// `HG-E 1427`; jetzt schreibt die App kein Kennzeichen mehr um.
///
/// Der Leerraum wird nicht der Schreibweise wegen vereinheitlicht:
/// `ZentralrufReplyParser` zieht ihn in „Ihr Zeichen" ebenso zusammen, und mit
/// einem doppelten Leerzeichen gliche die gespeicherte Referenz der aus der
/// Antwort zurückgelesenen nicht mehr.
String kennzeichenAusFormular(String wert) =>
    wert.trim().replaceAll(RegExp(r'\s+'), ' ');
