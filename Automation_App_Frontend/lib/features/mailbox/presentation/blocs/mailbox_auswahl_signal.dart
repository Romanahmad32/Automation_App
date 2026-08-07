import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Übergabekanal für den Sprung von der Startseite ins Postfach: merkt sich die
/// Kennung des Treffers, den der Anwalt dort angetippt hat, damit die
/// Postfach-Ansicht ihn direkt geöffnet zeigt statt einer leeren Auswahl.
///
/// Reaktiv über einen [ValueNotifier] — die Tabs bleiben unter `AutoTabsRouter`
/// am Leben, das Postfach wird beim erneuten Aktivieren also nicht neu gebaut.
/// Aufgebaut wie das [VorgangNavigationSignal] der Vorgänge; der Konsument setzt
/// den Wert nach Verarbeitung über [loesche] zurück.
@lazySingleton
class MailboxAuswahlSignal {
  final ValueNotifier<String?> pendingReplyId = ValueNotifier<String?>(null);

  /// Hinterlegt den im Postfach zu öffnenden Treffer und weckt die Lauscher.
  void setze(String replyId) {
    final bereinigt = replyId.trim();
    pendingReplyId.value = bereinigt.isEmpty ? null : bereinigt;
  }

  /// Setzt das Signal zurück, nachdem es verarbeitet wurde.
  void loesche() => pendingReplyId.value = null;
}
