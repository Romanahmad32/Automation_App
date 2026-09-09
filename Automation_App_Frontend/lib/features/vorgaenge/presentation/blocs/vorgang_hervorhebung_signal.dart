import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Übergabekanal für den Sprung aus dem Register in die Vorgangsverwaltung
/// (§6.2): merkt sich die Referenz der Zeile, die der Anwalt im Register
/// angeklickt hat, damit die Liste dort zu ihr scrollt und sie kurz hervorhebt
/// — statt ihn in einer Liste von Hunderten selbst suchen zu lassen.
///
/// Eigenes Signal neben dem [VorgangNavigationSignal]: Das trägt eine
/// **Vorauswahl** für den Word-Assistenten und wird dort auch verbraucht. Ein
/// Sprung in die Verwaltung wählt nichts aus, er zeigt nur hin. Denselben
/// Kanal für beides zu nehmen hieße, dass ein Blick ins Register den nächsten
/// Word-Lauf umstellt.
///
/// Reaktiv über einen [ValueNotifier] — die Tabs bleiben unter `AutoTabsRouter`
/// am Leben, die Verwaltung wird beim erneuten Aktivieren also nicht neu
/// gebaut. Aufgebaut wie `MailboxAuswahlSignal`; der Konsument setzt den Wert
/// nach Verarbeitung über [loesche] zurück.
@lazySingleton
class VorgangHervorhebungSignal {
  final ValueNotifier<String?> pendingReferenz = ValueNotifier<String?>(null);

  /// Hinterlegt die Referenz, zu der die Verwaltung springen soll.
  void setze(String referenz) {
    final bereinigt = referenz.trim();
    pendingReferenz.value = bereinigt.isEmpty ? null : bereinigt;
  }

  /// Setzt das Signal zurück, nachdem es verarbeitet wurde.
  void loesche() => pendingReferenz.value = null;
}
