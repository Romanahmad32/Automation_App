import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';

/// Ab so vielen Tagen ohne Antwort gilt eine Zentralruf-Anfrage als auffällig
/// lange offen (der Zentralruf antwortet üblicherweise binnen weniger Tage).
const int warteHinweisAbTagen = 7;

/// Wie lange ein Vorgang schon auf die Zentralruf-Antwort wartet. Liegt in der
/// domain-Schicht, weil sowohl der Hinweis am einzelnen Vorgang als auch die
/// Kennzahl „Wartet auf Zentralruf" im Dashboard dieselbe Schwelle brauchen —
/// zwei Schwellen würden auseinanderlaufen.
class VorgangWartezeit {
  const VorgangWartezeit._();

  /// Volle Tage seit der Anfrage. [jetzt] ist für Tests überschreibbar.
  static int tageSeitAnfrage(Vorgang vorgang, {DateTime? jetzt}) =>
      (jetzt ?? DateTime.now()).difference(vorgang.angefragtAm).inDays;

  /// True, wenn der Vorgang noch im Status „Angefragt" steht und die Antwort
  /// ungewöhnlich lange ausbleibt — dann muss der Anwalt nachfassen.
  static bool wartetLange(Vorgang vorgang, {DateTime? jetzt}) =>
      vorgang.status == VorgangStatus.angefragt &&
      tageSeitAnfrage(vorgang, jetzt: jetzt) >= warteHinweisAbTagen;
}
