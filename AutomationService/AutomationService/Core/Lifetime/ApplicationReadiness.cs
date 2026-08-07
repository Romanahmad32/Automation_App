namespace AutomationService.Core.Lifetime;

/// <summary>
/// Merkt sich, ob der Start vollstaendig durchgelaufen ist.
///
/// Der Unterschied ist nicht akademisch: Kestrel nimmt Requests bereits an,
/// bevor die uebrigen Hosted Services ihr StartAsync beendet haben — die
/// Datenbank kann also noch mitten in der Migration stecken, waehrend
/// /health schon antwortet. Wer den Start abwartet, will genau diesen
/// Zustand nicht als "fertig" gemeldet bekommen.
///
/// Gesetzt wird das Signal in Program.cs an ApplicationStarted; dieser Token
/// feuert erst, wenn alle Hosted Services gestartet sind.
/// </summary>
public sealed class ApplicationReadiness
{
    // int statt bool, weil Volatile.Read/Write fuer bool keine Ueberladung hat.
    // Geschrieben wird auf dem Startup-Thread, gelesen auf jedem Request-Thread.
    private int _bereit;

    public bool IstBereit => Volatile.Read(ref _bereit) == 1;

    public void MarkiereBereit() => Volatile.Write(ref _bereit, 1);
}
