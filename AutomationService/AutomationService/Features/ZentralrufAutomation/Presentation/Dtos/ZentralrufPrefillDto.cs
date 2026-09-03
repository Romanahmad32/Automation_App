using System.ComponentModel.DataAnnotations;
using AutomationService.Core.ErrorHandling;

namespace AutomationService.Features.ZentralrufAutomation.Presentation.Dtos;

public class ZentralrufPrefillDto
{
    /// <summary>Laufende Auftragsnummer, z. B. 84.</summary>
    [Display(Name = "Die Auftragsnummer")]
    [Required(ErrorMessage = Validierungstexte.Pflicht)]
    [Range(1, 99999, ErrorMessage = Validierungstexte.Bereich)]
    public int Auftragsnummer { get; set; }

    /// <summary>Zweistelliges Auftragsjahr, z. B. 26. 0 = aktuelles Jahr.</summary>
    [Display(Name = "Das Auftragsjahr")]
    [Range(0, 99, ErrorMessage = Validierungstexte.Bereich)]
    public int Auftragsjahr { get; set; }

    /// <summary>Abteilung, z. B. "C03".</summary>
    [Display(Name = "Die Abteilung")]
    [Required(ErrorMessage = Validierungstexte.Pflicht)]
    [MaxLength(10, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Abteilung { get; set; } = string.Empty;

    /// <summary>Amtliches Kennzeichen des Unfallgegners, z. B. "GG-XY 123".</summary>
    [Display(Name = "Das Kennzeichen des Unfallgegners")]
    [Required(ErrorMessage = Validierungstexte.Pflicht)]
    [MaxLength(12, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string KennzeichenSchaediger { get; set; } = string.Empty;

    /// <summary>Unfalldatum.</summary>
    [Display(Name = "Der Unfalltag")]
    [Required(ErrorMessage = Validierungstexte.Pflicht)]
    public DateOnly Schadentag { get; set; }

    /// <summary>
    /// Optionale, vom Anwender überschriebene Referenz. Ist sie leer, baut das Backend die
    /// Referenz aus Auftragsnummer/-jahr, Abteilung und Kennzeichen zusammen
    /// (<c>ZentralrufAutomationService.BuildReferenz</c>).
    /// </summary>
    [Display(Name = "Die Referenz")]
    [MaxLength(60, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string? Referenz { get; set; }

    public ZentralrufGeschaedigterDto? Geschaedigter { get; set; }

    /// <summary>
    /// Kanzlei-/Anfragerdaten aus den App-Einstellungen. Wenn null, gelten die Vorgabewerte
    /// von <c>ZentralrufAnfragerOptions</c> — die Anfragerfelder bleiben dann leer.
    /// </summary>
    public ZentralrufAnfragerDto? Anfrager { get; set; }
}

public class ZentralrufGeschaedigterDto
{
    [Display(Name = "Der Name des Mandanten")]
    [Required(ErrorMessage = Validierungstexte.Pflicht)]
    [MaxLength(100, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Name { get; set; } = string.Empty;

    [Display(Name = "Straße und Hausnummer des Mandanten")]
    [MaxLength(100, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string StrasseHausnummer { get; set; } = string.Empty;

    [Display(Name = "Die Postleitzahl des Mandanten")]
    [MaxLength(10, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Postleitzahl { get; set; } = string.Empty;

    [Display(Name = "Der Ort des Mandanten")]
    [MaxLength(60, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Ort { get; set; } = string.Empty;

    /// <summary>Kennzeichen des Fahrzeugs des Geschädigten.</summary>
    [Display(Name = "Das Kennzeichen des Mandanten")]
    [MaxLength(12, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Kennzeichen { get; set; } = string.Empty;
}
