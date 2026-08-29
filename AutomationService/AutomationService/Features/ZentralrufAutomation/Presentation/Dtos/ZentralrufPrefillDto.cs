using System.ComponentModel.DataAnnotations;

namespace AutomationService.Features.ZentralrufAutomation.Presentation.Dtos;

public class ZentralrufPrefillDto
{
    /// <summary>Laufende Auftragsnummer, z. B. 84.</summary>
    [Required]
    [Range(1, 99999)]
    public int Auftragsnummer { get; set; }

    /// <summary>Zweistelliges Auftragsjahr, z. B. 26. 0 = aktuelles Jahr.</summary>
    [Range(0, 99)]
    public int Auftragsjahr { get; set; }

    /// <summary>Abteilung, z. B. "C03".</summary>
    [Required]
    [MaxLength(10)]
    public string Abteilung { get; set; } = string.Empty;

    /// <summary>Amtliches Kennzeichen des Unfallgegners, z. B. "GG-XY 123".</summary>
    [Required]
    [MaxLength(12)]
    public string KennzeichenSchaediger { get; set; } = string.Empty;

    /// <summary>Unfalldatum.</summary>
    [Required]
    public DateOnly Schadentag { get; set; }

    /// <summary>
    /// Optionale, vom Anwender überschriebene Referenz. Ist sie leer, baut das Backend die
    /// Referenz aus Auftragsnummer/-jahr, Abteilung und Kennzeichen zusammen
    /// (<c>ZentralrufAutomationService.BuildReferenz</c>).
    /// </summary>
    [MaxLength(60)]
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
    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(100)]
    public string StrasseHausnummer { get; set; } = string.Empty;

    [MaxLength(10)]
    public string Postleitzahl { get; set; } = string.Empty;

    [MaxLength(60)]
    public string Ort { get; set; } = string.Empty;

    /// <summary>Kennzeichen des Fahrzeugs des Geschädigten.</summary>
    [MaxLength(12)]
    public string Kennzeichen { get; set; } = string.Empty;
}
