namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

/// <summary>
/// Aus einer Zentralruf-Antwortmail extrahierte, für das Anspruchsschreiben
/// relevante Daten. Nicht ermittelbare Werte sind <c>null</c>.
/// </summary>
public sealed record ZentralrufReplyData
{
    /// <summary>Eigenes Aktenzeichen aus "Ihr Zeichen:" (Referenz der Anfrage).</summary>
    public string? Referenz { get; init; }

    /// <summary>Laufende Auftragsnummer aus der Referenz (Schema "Nr/Jahr Abteilung_Kennzeichen").</summary>
    public string? ReferenzAuftragsnummer { get; init; }

    /// <summary>Zweistelliges Jahr aus der Referenz.</summary>
    public string? ReferenzJahr { get; init; }

    /// <summary>Abteilungskürzel aus der Referenz.</summary>
    public string? ReferenzAbteilung { get; init; }

    /// <summary>Kennzeichen aus der Referenz, normalisiert (z. B. "GG-XY 123").</summary>
    public string? ReferenzKennzeichen { get; init; }

    /// <summary>
    /// True, wenn der Zentralruf ausdrücklich mitteilt, dass zu der Anfrage
    /// kein Versicherer ermittelt werden konnte (Negativ-Antwort).
    /// </summary>
    public bool KeinVersichererErmittelt { get; init; }

    /// <summary>
    /// True, wenn die Mail eine Zwischennachricht ist: die Auskunft war nicht
    /// sofort möglich (z. B. manuelle Prüfung durch die Fachabteilung oder
    /// ausländisches Kennzeichen / Grüne Karte); die endgültige Antwort folgt
    /// in einer weiteren Mail.
    /// </summary>
    public bool Zwischennachricht { get; init; }

    /// <summary>Datum der ursprünglichen Anfrage ("Ihre Anfrage vom ...").</summary>
    public string? AnfrageDatum { get; init; }

    /// <summary>
    /// Kennzeichen des gegnerischen (angefragten) Fahrzeugs, normalisiert in
    /// die Domänen-Konvention mit Bindestrich (z. B. "GG-XY 123").
    /// </summary>
    public string? Kennzeichen { get; init; }

    /// <summary>Unfalldatum, zu dem der Versicherer ermittelt wurde.</summary>
    public string? UnfallDatum { get; init; }

    /// <summary>Name des gegnerischen Haftpflichtversicherers (ggf. mehrzeilig, mit Leerzeichen verbunden).</summary>
    public string? VersichererName { get; init; }

    /// <summary>Straße und Hausnummer des Versicherers.</summary>
    public string? VersichererStrasse { get; init; }

    /// <summary>Postleitzahl des Versicherers.</summary>
    public string? VersichererPlz { get; init; }

    /// <summary>Ort des Versicherers.</summary>
    public string? VersichererOrt { get; init; }

    public string? VersichererTelefon { get; init; }

    public string? VersichererFax { get; init; }

    public string? VersichererEmail { get; init; }

    /// <summary>Versicherungsschein-Nr. des gegnerischen Fahrzeugs.</summary>
    public string? VersicherungsscheinNr { get; init; }

    public string? Versicherungsbeginn { get; init; }
}
