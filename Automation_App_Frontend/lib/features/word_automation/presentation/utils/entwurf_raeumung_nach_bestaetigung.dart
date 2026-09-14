import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Ob der am Vorgang liegende Entwurf geräumt werden muss, nachdem ein
/// Schreiben bestätigt (erzeugt) wurde — `word_automation_page.dart` ruft
/// `VorgangCubit.sichereEntwurf(referenz, null)` nur, wenn dies `true` ist.
///
/// [formData] ist der abgesendete Formularstand des Wizards: `null` heißt, es
/// wurde in dieser Sitzung nichts bestätigt, dann gibt es auch nichts, was
/// einen angefangenen Stand verdrängt hätte. [vorgangVorRueckfluss] ist der
/// Vorgang, wie er **vor** `VorgangRueckfluss.uebernehmeWizardErgebnis` aussah
/// — die setzt `entwurf` im zurückgegebenen Vorgang lokal bereits auf `null`,
/// sein `entwurf`-Feld sagt deshalb nur *davor* noch etwas darüber, ob am
/// Vorgang überhaupt einer lag.
///
/// Ohne diesen zweiten Schutz lief `sichereEntwurf(referenz, null)` ins Leere,
/// sobald kein Entwurf existierte — ein DELETE ohne Gegenstück (Review-
/// Nachbesserung #154 zu #133, Befund 4; derselbe Schutz wie in
/// `entwurfs_sicherung.dart`).
bool sollEntwurfGeraeumtWerden(
  Map<String, String>? formData,
  Vorgang vorgangVorRueckfluss,
) => formData != null && vorgangVorRueckfluss.entwurf != null;
