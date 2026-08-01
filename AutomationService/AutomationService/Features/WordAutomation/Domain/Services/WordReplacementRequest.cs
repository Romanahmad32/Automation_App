namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>
/// Auftrag an den Dokumentenerzeuger: welche Vorlage mit welchen Werten gefüllt
/// wird und wohin das Ergebnis geschrieben werden soll.
///
/// Bewusst ein eigener Typ der Domain und nicht das HTTP-DTO: der Erzeuger soll
/// sich ändern lassen, ohne den HTTP-Vertrag anzufassen — und umgekehrt. Die
/// Presentation bildet ihr DTO hierauf ab (<c>WordReplacementDtoMapping</c>);
/// dort sitzen auch die Eingabeprüfungen (Required/MaxLength/Range), damit
/// ungültige Anfragen am Rand abprallen und nicht erst in der Fachlogik.
/// </summary>
public sealed record WordReplacementRequest
{
    /// <summary>Vollständiger Pfad der .docx-Vorlage.</summary>
    public required string TemplateFilePath { get; init; }

    /// <summary>
    /// Werte je Platzhaltername (ohne geschweifte Klammern). Der Vergleich läuft
    /// ohne Rücksicht auf Groß-/Kleinschreibung — die Vorlagen der Kanzlei
    /// schreiben denselben Platzhalter nicht immer gleich.
    /// </summary>
    public required IReadOnlyDictionary<string, string> ReplacePatterns { get; init; }

    /// <summary>Gewünschter Dateiname ohne Endung; leer = "{Vorlage}_{Datum}".</summary>
    public string OutputFileName { get; init; } = string.Empty;

    /// <summary>Zielverzeichnis; leer = das konfigurierte Ausgabeverzeichnis.</summary>
    public string OutputDirectory { get; init; } = string.Empty;

    /// <summary>Nur für Vorlagen mit Auflistung; null bei Vorlagen ohne Auflistung (HGN).</summary>
    public DamageListing? DamageListing { get; init; }

    /// <summary>
    /// Steuert den Ankreuz-Block "Mein Mandant ☐ ist / ☐ ist nicht
    /// vorsteuerabzugsberechtigt": true kreuzt "ist" an, false "ist nicht".
    /// null = den Block unangetastet lassen (z. B. Vorlagen ohne diesen Abschnitt).
    /// </summary>
    public bool? Vorsteuerabzugsberechtigt { get; init; }
}

/// <summary>
/// Schadensaufstellung für Vorlagen "mit Auflistung": Positionen werden als Tabelle am
/// Platzhalter {{Schadensaufstellung}} eingefügt, die RVG-Kosten als zusätzliche Platzhalter.
/// </summary>
public sealed record DamageListing
{
    public required IReadOnlyList<DamageItem> Items { get; init; }

    /// <summary>Gebührensatz der Geschäftsgebühr, üblicherweise 1,3.</summary>
    public decimal Gebuehrensatz { get; init; } = 1.3m;

    /// <summary>True, wenn der Mandant nicht vorsteuerabzugsberechtigt ist (Umsatzsteuer ausweisen).</summary>
    public bool ApplyVat { get; init; }

    /// <summary>Manuell korrigierte Geschäftsgebühr in €; null = automatisch nach § 13 RVG berechnen.</summary>
    public decimal? GeschaeftsgebuehrOverride { get; init; }

    /// <summary>Manuell korrigierte Auslagenpauschale in €; null = 20 % der Geschäftsgebühr, max. 20 € (Nr. 7002 VV RVG).</summary>
    public decimal? AuslagenpauschaleOverride { get; init; }

    /// <summary>Hintergrundfarbe der Titelzeile der Tabelle als Hex-Wert (z. B. "D9D9D9"); null = Standardgrau.</summary>
    public string? HeaderColorHex { get; init; }
}

/// <summary>Eine Position der Schadensaufstellung.</summary>
public sealed record DamageItem
{
    public required string Description { get; init; }

    public decimal Amount { get; init; }
}
