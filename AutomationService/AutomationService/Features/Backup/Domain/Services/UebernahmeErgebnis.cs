namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Ausgang einer Arbeitsplatz-Übernahme (§7.2, #39).
/// </summary>
/// <param name="Rechnername">
/// Von wem der Stand kam — oder <c>null</c>, wenn nichts übernommen wurde, weil
/// es beim zweiten Hinsehen kein Angebot mehr gab. Das ist kein Fehler: Zwischen
/// der Frage auf dem Bildschirm und dem Klick kann der Synchronisierungsdienst
/// das Archiv nachgeliefert, ersetzt oder weggeräumt haben, und übernommen wird
/// nur, was in diesem Moment wirklich dasteht.
/// </param>
/// <param name="UebersprungeneVorlagen">
/// Vorlagen, die nicht ersetzt wurden, weil lokal eine abweichende Fassung
/// liegt (#33) — dieselbe Zusage wie beim Einspielen von Hand.
/// </param>
public sealed record UebernahmeErgebnis(
    string? Rechnername,
    IReadOnlyList<string> UebersprungeneVorlagen)
{
    public static readonly UebernahmeErgebnis KeinAngebot = new(null, []);
}
