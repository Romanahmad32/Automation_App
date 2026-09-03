namespace AutomationService.Features.Backup.Presentation.Dtos;

/// <summary>
/// Ausgang einer Arbeitsplatz-Übernahme (§7.2, #39).
/// </summary>
/// <param name="Uebernommen">
/// <c>false</c> heißt nicht „Fehler", sondern „es gab nichts mehr zu
/// übernehmen": Zwischen der Frage auf dem Bildschirm und dem Klick kann sich
/// der Ordner geändert haben. Die Oberfläche geht dann einfach weiter.
/// </param>
/// <param name="Rechnername">Von wem der Stand kam.</param>
/// <param name="Message">Der Satz, den die App anzeigt.</param>
public sealed record UebernahmeErgebnisDto(
    bool Uebernommen,
    string? Rechnername,
    string Message);
