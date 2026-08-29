using System.ComponentModel.DataAnnotations;

namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

/// <summary>
/// Schadensaufstellung für Vorlagen "mit Auflistung": Positionen werden als Tabelle am
/// Platzhalter {{Schadensaufstellung}} eingefügt, die RVG-Kosten als zusätzliche Platzhalter.
/// </summary>
public class DamageListingDto
{
    [Required]
    [MinLength(1)]
    public List<DamageItemDto> Items { get; set; } = [];

    /// <summary>Gebührensatz der Geschäftsgebühr, üblicherweise 1,3.</summary>
    [Range(0.1, 10)]
    public decimal Gebuehrensatz { get; set; } = 1.3m;

    /// <summary>True, wenn der Mandant nicht vorsteuerabzugsberechtigt ist (Umsatzsteuer ausweisen).</summary>
    public bool ApplyVat { get; set; }

    /// <summary>Manuell korrigierte Geschäftsgebühr in €; null = automatisch nach § 13 RVG berechnen.</summary>
    [Range(0.0, 10_000_000.0)]
    public decimal? GeschaeftsgebuehrOverride { get; set; }

    /// <summary>Manuell korrigierte Auslagenpauschale in €; null = 20 % der Geschäftsgebühr, max. 20 € (Nr. 7002 VV RVG).</summary>
    [Range(0.0, 10_000_000.0)]
    public decimal? AuslagenpauschaleOverride { get; set; }

    /// <summary>Hintergrundfarbe der Titelzeile der Tabelle als Hex-Wert (z. B. "D9D9D9"); null = Standardgrau.</summary>
    [RegularExpression("^#?[0-9a-fA-F]{6}$", ErrorMessage = "HeaderColorHex muss ein 6-stelliger Hex-Farbwert sein (z. B. D9D9D9).")]
    public string? HeaderColorHex { get; set; }
}

public class DamageItemDto
{
    [Required]
    [MaxLength(200)]
    public string Description { get; set; } = string.Empty;

    /// <summary>Forderung dieser Position in €; 0,00 = noch nicht beziffert.</summary>
    // Die Untergrenze ist 0 und nicht 0,01: Eine Position, die im Schreiben stehen soll,
    // aber noch aussteht (etwa ein Gutachten ohne Rechnung), ist fachlich gültig. Negative
    // Beträge bleiben unzulässig — ein Abzug ist keine Schadensposition. Gemeldet werden
    // sie im Formular an der Zeile, die sie verursacht (schadenspositionen_pruefung.dart);
    // diese Schranke ist nur noch das Netz dahinter und nennt keine Zeile.
    //
    // Die Nachkommastellen an den Grenzen sind PFLICHT und kein Schönheitsfehler:
    // "0" waehlt die Ueberladung RangeAttribute(int, int), und die rundet den decimal-Wert
    // vor dem Vergleich auf Int32. -0,49 gilt dann als gueltig, und ein Wert jenseits von
    // int.MaxValue wirft eine OverflowException, die RangeAttribute nicht faengt — aus 400
    // wird 500. Genau so war es hier schon einmal; RangeUeberladungTests haelt es fest.
    [Range(0.0, 10_000_000.0)]
    public decimal Amount { get; set; }
}
