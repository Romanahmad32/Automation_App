import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/domain/services/entwurf_abweichung.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/entwurfs_sicherung.dart';

/// Alles, was am **angefangenen Stand** hängt, an einer Stelle: wann er zum
/// Vorgang geht und was dabei von ihm mitreist.
///
/// Steht neben dem [WizardCubit] statt in ihm, weil der sonst über seine
/// Längengrenze liefe — und weil der Zusammenhang für sich steht: Der Cubit
/// ruft hier hinein und gibt seinen Zustand mit, entscheidet aber nichts
/// selbst.
///
/// Seit #133 ohne Angebot und ohne Entscheidung: Der Stand kommt beim
/// Wiedereinstieg still zurück, deshalb gibt es hier nichts mehr zu steuern
/// außer der Ablage.
///
/// Die Zustandsübergänge sind **statisch und rein** ([nachZuruecksetzen],
/// [nachWiederherstellung], [zusammengefuehrt]) — nur die Ablage selbst braucht
/// den Vorgangsspeicher.
class EntwurfSicherungSteuerung {
  /// Der app-weite Vorgangsspeicher — der Entwurf liegt am Vorgang, nicht im
  /// Wizard.
  final VorgangCubit _vorgaenge;

  /// Die Ablage samt Bestätigt-Marke.
  final EntwurfsSicherung _sicherung;

  EntwurfSicherungSteuerung(VorgangCubit vorgaenge)
    : _vorgaenge = vorgaenge,
      _sicherung = EntwurfsSicherung(vorgaenge);

  /// Sichert den aktuellen Stand (Einzelheiten und Abbruchgründe in
  /// [EntwurfsSicherung.jetzt]).
  void sichereJetzt(WizardState zustand) => _sicherung.jetzt(
    referenz: zustand.selectedVorgang?.referenz,
    werte: zustand.formDataEntwurf,
    aufstellung: _aufstellung(zustand),
  );

  /// Wie [sichereJetzt], hebt aber zuvor die Bestätigt-Marke auf: Wer wieder
  /// tippt, macht aus dem bestätigten Stand einen angefangenen.
  void nachEingabe(WizardState zustand) {
    _sicherung.hebeBestaetigungAuf();
    sichereJetzt(zustand);
  }

  /// Der Stand ist bestätigt (ein Dokument daraus erzeugt) — ab hier wird
  /// nichts mehr abgelegt, bis wieder jemand tippt.
  void markiereBestaetigt() => _sicherung.markiereBestaetigt();

  /// Räumt den Entwurf am Vorgang **immer** — der Weg für „Eingaben auf
  /// Vorbelegung zurücksetzen": Anders als [nachEingabe] zählt dabei eine
  /// nicht leere Schadensaufstellung nicht als „noch etwas da" (Review-
  /// Nachbesserung #133, Befund 3, siehe [EntwurfsSicherung.loesche]).
  void nachZuruecksetzenGesichert(WizardState zustand) {
    _sicherung.hebeBestaetigungAuf();
    _sicherung.loesche(zustand.selectedVorgang?.referenz);
  }

  /// Ob [referenz] noch zum **aktuell** gewählten Vorgang gehört — beide
  /// `null` (freie Erfassung) zählt als Treffer.
  ///
  /// Nötig gegen eine Race (Review-Nachbesserung #133): Der
  /// `FormWertBeobachter` des alten Formulars meldet aus seinem `dispose()`
  /// heraus manchmal erst **nach** [WizardCubit.selectVorgang]s Emit — dann
  /// trägt [zustand] schon den neuen Vorgang, während die Meldung noch die
  /// Werte des alten Formulars bringt. Ohne diesen Abgleich schriebe der neue
  /// Vorgang die Werte des alten fort. Von [WizardCubit.uebernehmeVorgangsStand]
  /// mitbenutzt, das denselben Abgleich schon vorher von Hand machte.
  bool passtZuAktuellemVorgang(WizardState zustand, String? referenz) {
    final aktuell = zustand.selectedVorgang?.referenz;
    if (aktuell == null || referenz == null) return aktuell == referenz;
    return Vorgang.gleicheReferenz(aktuell, referenz);
  }

  /// Der Zustand nach „Eingaben auf Vorbelegung zurücksetzen".
  ///
  /// Der abgesendete Stand geht mit: Er ist aus diesen Eingaben entstanden, und
  /// stehen zu lassen, woraus gleich ein Schreiben würde, wäre genau die stille
  /// Halbwahrheit, die #133 beseitigt.
  ///
  /// Der angefangene Stand wird **leer**, nicht `null`: `null` heißt „in diesem
  /// Durchgang nie getippt", und dann rührt die Sicherung den Stand am Vorgang
  /// gar nicht erst an — hier soll aber das Gegenteil geschehen. Die leere Menge
  /// ist die ausdrückliche Aussage „nichts von mir", und sie löscht.
  ///
  /// [WizardState.aufbauMarke] zwingt das Formular zum Neuaufbau — ohne sie
  /// hätte der Anwalt gedrückt und nichts geschehen sehen.
  ///
  /// Die Schadensaufstellung bleibt unberührt: Der Knopf steht über dem
  /// Ausfüll**formular** und meint dessen Felder.
  static WizardState nachZuruecksetzen(WizardState zustand) => zustand.copyWith(
    formData: () => null,
    formDataEntwurf: () => const {},
    aufbauMarke: zustand.aufbauMarke + 1,
  );

  /// Der Zustand nach „Rückgängig" an der Meldung darüber.
  static WizardState nachWiederherstellung(
    WizardState zustand,
    Map<String, String> werte,
  ) => zustand.copyWith(
    formDataEntwurf: () => werte,
    aufbauMarke: zustand.aufbauMarke + 1,
  );

  /// Der neue angefangene Stand: die Abweichungen aus dem gemeldeten Formular,
  /// dazu die Felder, die dieses Formular **nicht** kennt.
  ///
  /// Gemeldet wird immer die ganze gerade gezeigte Vorlage. Wer nur ersetzte,
  /// verlöre bei jedem Vorlagenwechsel die Eingaben der anderen — und wer nur
  /// ergänzte, bekäme ein Feld nie wieder auf die Vorbelegung zurück.
  static Map<String, String> zusammengefuehrt({
    required Map<String, String>? bisher,
    required Map<String, String> werte,
    required Map<String, String> vorbelegung,
  }) => {
    for (final eintrag in bisher?.entries ?? const <MapEntry<String, String>>[])
      if (!werte.containsKey(eintrag.key)) eintrag.key: eintrag.value,
    ...EntwurfAbweichung.nurAbweichende(werte: werte, vorbelegung: vorbelegung),
  };

  /// Die Schadensaufstellung, die mitgesichert wird.
  ///
  /// `null` im Wizard heißt **noch nicht geladen**, nicht „gelöscht": Der
  /// Schadensaufstellungs-Schritt meldet immer eine Aufstellung, auch die leere,
  /// und setzt sie nie auf `null` zurück. Auf `null` steht sie dagegen nach
  /// jedem Vorlagen- und Fassungswechsel — schriebe die nächste Sicherung sie
  /// dann als „keine" fort, verlöre ein Hin-und-Her zwischen zwei Vorlagen die
  /// erfassten Positionen. Deshalb gilt in diesem Fall, was am Vorgang steht.
  DamageListing? _aufstellung(WizardState zustand) {
    final eigene = zustand.damageListing;
    if (eigene != null) return eigene;
    final referenz = zustand.selectedVorgang?.referenz;
    if (referenz == null) return null;
    return _vorgaenge.findeZuReferenz(referenz)?.entwurf?.schadensaufstellung;
  }
}
