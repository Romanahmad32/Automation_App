import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Was die View zwischen der Mandanten-Karte und dem übrigen Bestand vermittelt
/// — es liegt hier statt in der ohnehin vollen
/// `vorgang_starten_form_view.dart`.

/// Der Registerbezug der Seite: die bekannten Mandanten und der, mit dem der
/// Vorgang verknüpft ist.
///
/// Ein reiner Zustandshalter ohne Flutter — die View besitzt ihn, ruft ihn
/// innerhalb von `setState` und behält damit die Hoheit über den Neuaufbau.
/// Getrennt von der View, weil das Register eine eigene Sache ist: Wer am
/// Formular arbeitet, muss dafür nichts wissen, und umgekehrt.
class MandantenStand {
  /// Die bekannten Registereinträge für Auswahl und Wiedererkennung.
  List<Mandant> eintraege = const [];

  /// Der verknüpfte Eintrag (null = neuer Mandant).
  int? gewaehlteId;

  Mandant? get gewaehlter => gewaehlteId == null ? null : finde(gewaehlteId!);

  Mandant? finde(int id) {
    for (final mandant in eintraege) {
      if (mandant.id == id) return mandant;
    }
    return null;
  }

  /// Wie viele Vorgänge am verknüpften Eintrag hängen — die Zahl für die
  /// Warnung vor einer Umbenennung (§5.1).
  int get vorgaenge => vorgaengeAmMandanten(gewaehlteId);

  /// Übernimmt einen im Dropdown gewählten Eintrag: Er füllt die Felder und
  /// wird verknüpft.
  void waehle(FormGroup form, Mandant mandant) {
    uebernimmMandantInFormular(form, mandant);
    gewaehlteId = mandant.id;
  }

  /// Verknüpft einen **gerade gespeicherten** Mandanten — und ergänzt ihn
  /// gleich in der Liste, statt auf das Nachladen zu warten: Das kann
  /// scheitern, ohne es zu melden, und eine Id ohne passenden Eintrag ist so
  /// gut wie keine.
  ///
  /// Die Formularfelder bleiben unangetastet: Der Mandant ist aus ihnen
  /// entstanden, und auf dem Zentralruf-Weg liegen bis zu drei Minuten
  /// dazwischen, in denen der Anwalt weitergetippt haben kann (§1.3 — die App
  /// „überschreibt nichts stillschweigend"). Felder füllt nur [waehle].
  void verknuepfeGespeicherten(Mandant mandant) {
    eintraege = [...eintraege.where((m) => m.id != mandant.id), mandant];
    gewaehlteId = mandant.id;
  }

  /// Holt das Register. Liefert `null`, wenn es nicht zu haben war — dann
  /// bleibt die Karte bei dem, was sie hat, statt zu leeren.
  static Future<List<Mandant>?> hole() async {
    final result = await getIt<UseCase<List<Mandant>, NoParams>>().call(
      const NoParams(),
    );
    return switch (result) {
      Right(value: final mandanten) => mandanten,
      Left() => null,
    };
  }
}

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
