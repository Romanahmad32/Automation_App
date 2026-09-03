using System.ComponentModel.DataAnnotations;
using AutomationService.Core.ErrorHandling;

namespace AutomationService.Features.ZentralrufAutomation.Presentation.Dtos;

/// <summary>
/// Kanzlei-/Anfragerdaten, mit denen der Abschnitt "Anfrager" des Zentralruf-Formulars gefüllt wird.
/// Wird optional vom Client mitgeschickt; fehlt der Block, gelten die Vorgabewerte von
/// <c>ZentralrufAnfragerOptions</c> (Personentyp "Rechtsanwalt", Rest leer) — das Formular
/// bleibt dann bei den Anfragerfeldern leer.
/// </summary>
public class ZentralrufAnfragerDto
{
    [Display(Name = "Die Personenart der Kanzlei")]
    [MaxLength(40, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Personentyp { get; set; } = string.Empty;

    [Display(Name = "Der Name der Kanzlei")]
    [MaxLength(100, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Name { get; set; } = string.Empty;

    [Display(Name = "Straße und Hausnummer der Kanzlei")]
    [MaxLength(100, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string StrasseHausnummer { get; set; } = string.Empty;

    [Display(Name = "Die Postleitzahl der Kanzlei")]
    [MaxLength(10, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Postleitzahl { get; set; } = string.Empty;

    [Display(Name = "Der Ort der Kanzlei")]
    [MaxLength(60, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Ort { get; set; } = string.Empty;

    [Display(Name = "Die E-Mail-Adresse der Kanzlei")]
    [MaxLength(120, ErrorMessage = Validierungstexte.MaxZeichen)]
    [EmailAddress(ErrorMessage = Validierungstexte.EmailForm)]
    public string EmailAdresse { get; set; } = string.Empty;

    [Display(Name = "Die Telefonnummer der Kanzlei")]
    [MaxLength(40, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Telefonnummer { get; set; } = string.Empty;
}
