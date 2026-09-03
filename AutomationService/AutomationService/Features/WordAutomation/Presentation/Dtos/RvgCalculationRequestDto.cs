using System.ComponentModel.DataAnnotations;
using AutomationService.Core.ErrorHandling;

namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

/// <summary>
/// Anfrage für die RVG-Kostenvorschau (Live-Berechnung im Schadensaufstellungs-Schritt).
/// Bewusst nur der Gegenstandswert statt der Einzelpositionen – die Beschreibungen
/// sind für die Gebührenberechnung irrelevant.
/// </summary>
public class RvgCalculationRequestDto
{
    /// <summary>Summe der Schadenspositionen in €.</summary>
    // 0 ist zugelassen: eine Aufstellung aus lauter noch unbezifferten Positionen summiert
    // sich darauf. Daraus entsteht die unterste Stufe der Gebührentabelle (siehe
    // RvgFeeCalculator.Calculate) — dieselbe Zahl, die dann auch im Dokument steht. Mit der
    // früheren Untergrenze 0,01 bekam die Vorschau dafür ein 400, obwohl das Schreiben
    // sich erzeugen ließ.
    // Nachkommastellen an den Grenzen: siehe DamageItemDto.Amount — ohne sie bindet
    // die int-Ueberladung, und negative Nachkommawerte kaemen durch.
    //
    // [Required] auf einem decimal? und nicht ein blankes decimal: Sobald 0 ein gueltiger
    // Wert ist, unterscheidet ein nicht-nullbares Feld "ausdruecklich 0 geschickt" nicht
    // mehr von "gar nicht geschickt". Ein leerer Rumpf oder ein falsch geschriebener
    // Feldname ergaebe sonst still 51,50 EUR Gebuehren statt eines Fehlers — eine Zahl,
    // der der Anwalt keinen Grund hat zu misstrauen.
    //
    // Was diese Schranken fangen, beantwortet [ApiController] selbst und nicht die
    // Action: 400 mit ProblemDetails, den Feldnamen im detail (ValidierungsAntwort).
    // Die Obergrenze haengt an der Anzahl der Positionen — siehe DamageListingDto.Items.
    [Display(Name = "Der Gegenstandswert")]
    [Required(ErrorMessage = Validierungstexte.Pflicht)]
    [Range(0.0, 100_000_000.0, ErrorMessage = Validierungstexte.BereichEuro)]
    public decimal? Gegenstandswert { get; set; }

    /// <summary>Gebührensatz der Geschäftsgebühr, üblicherweise 1,3.</summary>
    [Display(Name = "Der Gebührensatz")]
    [Range(0.1, 10, ErrorMessage = Validierungstexte.Bereich)]
    public decimal Gebuehrensatz { get; set; } = 1.3m;

    /// <summary>True, wenn der Mandant nicht vorsteuerabzugsberechtigt ist (Umsatzsteuer ausweisen).</summary>
    public bool ApplyVat { get; set; }

    /// <summary>Manuell korrigierte Geschäftsgebühr in €; null = automatisch nach § 13 RVG berechnen.</summary>
    [Display(Name = "Die eingetragene Geschäftsgebühr")]
    [Range(0.0, 10_000_000.0, ErrorMessage = Validierungstexte.BereichEuro)]
    public decimal? GeschaeftsgebuehrOverride { get; set; }

    /// <summary>Manuell korrigierte Auslagenpauschale in €; null = 20 % der Geschäftsgebühr, max. 20 € (Nr. 7002 VV RVG).</summary>
    [Display(Name = "Die eingetragene Auslagenpauschale")]
    [Range(0.0, 10_000_000.0, ErrorMessage = Validierungstexte.BereichEuro)]
    public decimal? AuslagenpauschaleOverride { get; set; }
}
