using System.ComponentModel.DataAnnotations;

namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

/// <summary>
/// Anfrage für die RVG-Kostenvorschau (Live-Berechnung im Schadensaufstellungs-Schritt).
/// Bewusst nur der Gegenstandswert statt der Einzelpositionen – die Beschreibungen
/// sind für die Gebührenberechnung irrelevant.
/// </summary>
public class RvgCalculationRequestDto
{
    [Range(0.01, 100_000_000)]
    public decimal Gegenstandswert { get; set; }

    /// <summary>Gebührensatz der Geschäftsgebühr, üblicherweise 1,3.</summary>
    [Range(0.1, 10)]
    public decimal Gebuehrensatz { get; set; } = 1.3m;

    /// <summary>True, wenn der Mandant nicht vorsteuerabzugsberechtigt ist (Umsatzsteuer ausweisen).</summary>
    public bool ApplyVat { get; set; }

    /// <summary>Manuell korrigierte Geschäftsgebühr in €; null = automatisch nach § 13 RVG berechnen.</summary>
    [Range(0, 10_000_000)]
    public decimal? GeschaeftsgebuehrOverride { get; set; }

    /// <summary>Manuell korrigierte Auslagenpauschale in €; null = 20 % der Geschäftsgebühr, max. 20 € (Nr. 7002 VV RVG).</summary>
    [Range(0, 10_000_000)]
    public decimal? AuslagenpauschaleOverride { get; set; }
}
