import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Was die View zwischen der Mandanten-Karte und dem übrigen Bestand vermittelt
/// — beides braucht keinen Zustand und liegt deshalb hier statt in der ohnehin
/// vollen `vorgang_starten_form_view.dart`.

/// Schreibt die Stammdaten eines Registereintrags in die Felder der Karte.
///
/// Nur die Auswahl im Dropdown darf das. Nach dem Speichern bleiben die Felder
/// unangetastet — auf dem Zentralruf-Weg liegen bis zu drei Minuten dazwischen,
/// in denen der Anwalt weitergetippt haben kann (§1.3, siehe FALLSTRICKE.md).
void uebernimmMandantInFormular(FormGroup form, Mandant mandant) {
  form.control('mandantVorname').updateValue(mandant.vorname);
  form.control('mandantNachname').updateValue(mandant.nachname);
  form.control('mandantStrasse').updateValue(mandant.strasseHausnummer);
  form.control('mandantPlz').updateValue(mandant.postleitzahl);
  form.control('mandantOrt').updateValue(mandant.ort);
  form.control('mandantEmail').updateValue(mandant.emailAdresse);
  form.control('mandantTelefon').updateValue(mandant.telefonnummer);
}

/// Wie viele Vorgänge am Registereintrag [mandantId] hängen (0 ohne Auswahl).
///
/// Die Zahl steht in der Rückfrage, wenn ein geänderter Name den Eintrag
/// umbenennt (§5.1): Eine Warnung ohne sie lässt offen, ob es um einen Vorgang
/// geht oder um dreißig. Gezählt wird im `VorgangCubit` — demselben Bestand,
/// aus dem auch das Register liest. Ist er noch leer, warnt der Dialog ohne
/// Zahl statt mit einer falschen.
int vorgaengeAmMandanten(int? mandantId) {
  if (mandantId == null) return 0;
  return getIt<VorgangCubit>().state
      .where((vorgang) => vorgang.mandantId == mandantId)
      .length;
}
