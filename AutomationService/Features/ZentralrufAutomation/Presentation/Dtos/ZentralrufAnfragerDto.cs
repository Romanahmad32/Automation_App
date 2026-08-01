using System.ComponentModel.DataAnnotations;

namespace AutomationService.Features.ZentralrufAutomation.Presentation.Dtos;

/// <summary>
/// Kanzlei-/Anfragerdaten, mit denen der Abschnitt "Anfrager" des Zentralruf-Formulars gefüllt wird.
/// Wird optional vom Client mitgeschickt; fehlt der Block, gelten die Werte aus appsettings.json
/// (<c>Zentralruf:Anfrager</c>).
/// </summary>
public class ZentralrufAnfragerDto
{
    [MaxLength(40)]
    public string Personentyp { get; set; } = string.Empty;

    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(100)]
    public string StrasseHausnummer { get; set; } = string.Empty;

    [MaxLength(10)]
    public string Postleitzahl { get; set; } = string.Empty;

    [MaxLength(60)]
    public string Ort { get; set; } = string.Empty;

    [MaxLength(120)]
    [EmailAddress]
    public string EmailAdresse { get; set; } = string.Empty;

    [MaxLength(40)]
    public string Telefonnummer { get; set; } = string.Empty;
}
