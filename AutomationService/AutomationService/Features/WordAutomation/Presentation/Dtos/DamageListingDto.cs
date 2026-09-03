using System.ComponentModel.DataAnnotations;
using AutomationService.Core.ErrorHandling;

namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

/// <summary>
/// Schadensaufstellung für Vorlagen "mit Auflistung": Positionen werden als Tabelle am
/// Platzhalter {{Schadensaufstellung}} eingefügt, die RVG-Kosten als zusätzliche Platzhalter.
/// </summary>
public class DamageListingDto
{
    // Drei Grenzen haengen hier zusammen, und wer eine anhebt, muss die anderen
    // ansehen: der Betrag je Position (DamageItemDto.Amount, max. 10 Mio.), diese
    // Anzahl, und der Deckel der Kostenvorschau (RvgCalculationRequestDto
    // .Gegenstandswert, max. 100 Mio.). Schon ab elf ausgereizten Positionen liegt
    // die Summe ueber dem Deckel — die Vorschau antwortet dann mit 400, waehrend
    // sich das Schreiben selbst weiter erzeugen laesst.
    //
    // 100 ist kein fachliches Mass, sondern das Netz: Die Oberflaeche laesst Zeilen
    // ohne Obergrenze hinzufuegen, eine Aufstellung aus einem Verkehrsunfall traegt
    // aber selten mehr als zwei Dutzend. Ohne Grenze nimmt der Endpunkt eine Liste
    // beliebiger Laenge an.
    [Display(Name = "Die Schadensaufstellung")]
    [Required(ErrorMessage = Validierungstexte.Pflicht)]
    [MinLength(1, ErrorMessage = Validierungstexte.MindestensEinEintrag)]
    [MaxLength(100, ErrorMessage = Validierungstexte.MaxEintraege)]
    public List<DamageItemDto> Items { get; set; } = [];

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

    /// <summary>Hintergrundfarbe der Titelzeile der Tabelle als Hex-Wert (z. B. "D9D9D9"); null = Standardgrau.</summary>
    [Display(Name = "Die Farbe der Titelzeile")]
    [RegularExpression("^#?[0-9a-fA-F]{6}$", ErrorMessage = "{0} muss ein 6-stelliger Hex-Farbwert sein (z. B. D9D9D9).")]
    public string? HeaderColorHex { get; set; }
}

public class DamageItemDto
{
    [Display(Name = "Die Bezeichnung")]
    [Required(ErrorMessage = Validierungstexte.Pflicht)]
    [MaxLength(200, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string Description { get; set; } = string.Empty;

    /// <summary>Forderung dieser Position in €; 0,00 = noch nicht beziffert.</summary>
    // Die Untergrenze ist 0 und nicht 0,01: Eine Position, die im Schreiben stehen soll,
    // aber noch aussteht (etwa ein Gutachten ohne Rechnung), ist fachlich gültig. Negative
    // Beträge bleiben unzulässig — ein Abzug ist keine Schadensposition. Gemeldet werden
    // sie im Formular an der Zeile, die sie verursacht (schadenspositionen_pruefung.dart);
    // diese Schranke ist nur noch das Netz dahinter und nennt keine Zeile. Was sie
    // faengt, kommt als ProblemDetails zurueck — den Feldnamen ("Items[3].Amount")
    // traegt ValidierungsAntwort ins detail, damit die Meldung nicht bei "ungueltig"
    // stehen bleibt.
    //
    // Die Nachkommastellen an den Grenzen sind PFLICHT und kein Schönheitsfehler:
    // "0" waehlt die Ueberladung RangeAttribute(int, int), und die rundet den decimal-Wert
    // vor dem Vergleich auf Int32. -0,49 gilt dann als gueltig, und ein Wert jenseits von
    // int.MaxValue wirft eine OverflowException, die RangeAttribute nicht faengt — aus 400
    // wird 500. Genau so war es hier schon einmal; RangeUeberladungTests haelt es fest.
    [Display(Name = "Der Betrag")]
    [Range(0.0, 10_000_000.0, ErrorMessage = Validierungstexte.BereichEuro)]
    public decimal Amount { get; set; }
}
