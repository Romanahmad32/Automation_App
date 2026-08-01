import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Schmaler, app-weiter Übergabekanal für die Tab-Navigation: Beim Wechsel vom
/// „Vorgang starten"-Tab zum Word-Tab merkt sich das Signal die Referenz des
/// frisch gespeicherten Vorgangs, damit ihn der `VorgangSelector` dort gezielt
/// vorauswählt (statt nur des zuletzt beantworteten Vorgangs).
///
/// Reaktiv über einen [ValueNotifier], weil die Tabs unter `AutoTabsRouter` am
/// Leben bleiben: Der Word-Tab wird beim erneuten Aktivieren nicht neu gebaut,
/// die Auswahl muss also auch bei späteren Wechseln noch ausgelöst werden. Der
/// Konsument setzt den Wert nach Verarbeitung über [loesche] wieder zurück.
@lazySingleton
class VorgangNavigationSignal {
  final ValueNotifier<String?> pendingReferenz = ValueNotifier<String?>(null);

  /// Hinterlegt die Referenz des Vorgangs, der im Word-Tab vorausgewählt werden
  /// soll, und benachrichtigt die Lauscher.
  void setze(String referenz) {
    final bereinigt = referenz.trim();
    pendingReferenz.value = bereinigt.isEmpty ? null : bereinigt;
  }

  /// Setzt das Signal zurück, nachdem es verarbeitet wurde.
  void loesche() => pendingReferenz.value = null;
}
