using System.ComponentModel.DataAnnotations;

namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

/// <summary>
/// Anfrage an <c>POST api/WordAutomation/arbeitsordner/aufraeumen</c>: welcher
/// Arbeitsordner nach der Ablage in der Akte verschwinden soll.
/// </summary>
public class ArbeitsordnerDto
{
    /// <summary>
    /// Referenz des Vorgangs — derselbe Schlüssel, unter dem das Dokument
    /// erzeugt wurde; leer = der Ordner der freien Erfassung.
    /// </summary>
    [MaxLength(260)]
    public string VorgangSchluessel { get; set; } = string.Empty;
}

/// <param name="Success">
/// False, wenn der Ordner nicht restlos gelöscht werden konnte (etwas darin ist
/// noch geöffnet). Kein Fehlerfall für den Anwalt: sein Dokument liegt zu dem
/// Zeitpunkt bereits in der Akte, hier bleibt nur eine Arbeitskopie liegen.
/// </param>
/// <param name="Message">Erklärung, wenn etwas liegen blieb; sonst null.</param>
public sealed record ArbeitsordnerAufgeraeumtDto(bool Success, string? Message);
