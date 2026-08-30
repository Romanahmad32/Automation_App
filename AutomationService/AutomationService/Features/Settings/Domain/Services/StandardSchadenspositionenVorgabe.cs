namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Die fünf Positionen, mit denen eine Schadensaufstellung ab Werk startet
/// (§4.4) — Reihenfolge und Wortlaut sind der Wortlaut der Anforderung. Sie
/// greifen, solange der Anwalt in den Einstellungen nichts anderes hinterlegt
/// hat, und sie sind der Stand, auf den „Zurücksetzen" (ein Speichern der
/// leeren Liste) zurückführt.
///
/// Wer hier etwas ändert, ändert zuerst <c>REQUIREMENTS.md</c> §4.4 — die
/// Flutter-Seite hält denselben Wortlaut in <c>StandardSchadenspositionen</c>
/// und prüft ihn gegen die Anforderung.
/// </summary>
public static class StandardSchadenspositionenVorgabe
{
    public static readonly IReadOnlyList<string> Bezeichnungen =
    [
        "Reparaturkosten netto nach Gutachten",
        "Wertminderung nach Gutachten",
        "Unkostenpauschale",
        "Abschleppkosten / Standgeldkosten",
        "Sachverständigenkosten",
    ];
}
