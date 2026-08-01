namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

/// <summary>
/// Auftrag an die Browsersteuerung: die Angaben, mit denen das
/// Zentralruf-Anfrageformular vorausgefüllt wird.
///
/// Bewusst ein eigener Typ der Domain und nicht das HTTP-DTO — sonst diktiert
/// der HTTP-Vertrag die Signatur der Fachlogik. Die Presentation bildet ihr DTO
/// hierauf ab (<c>ZentralrufPrefillDtoMapping</c>) und trägt die Eingabeprüfungen.
/// </summary>
public sealed record ZentralrufPrefillRequest
{
    /// <summary>Laufende Auftragsnummer, z. B. 84.</summary>
    public required int Auftragsnummer { get; init; }

    /// <summary>Zweistelliges Auftragsjahr, z. B. 26. 0 = aktuelles Jahr.</summary>
    public int Auftragsjahr { get; init; }

    /// <summary>Abteilung, z. B. "C03".</summary>
    public required string Abteilung { get; init; }

    /// <summary>Amtliches Kennzeichen des Unfallgegners, z. B. "GG-XY 123".</summary>
    public required string KennzeichenSchaediger { get; init; }

    /// <summary>Unfalldatum.</summary>
    public required DateOnly Schadentag { get; init; }

    /// <summary>
    /// Optionale, vom Anwender überschriebene Referenz. Ist sie leer, baut
    /// <see cref="ZentralrufAutomationService.BuildReferenz"/> sie aus
    /// Auftragsnummer/-jahr, Abteilung und Kennzeichen zusammen.
    /// </summary>
    public string? Referenz { get; init; }

    /// <summary>Angaben zum Geschädigten; null = der Anfrager ist selbst der Geschädigte.</summary>
    public ZentralrufGeschaedigter? Geschaedigter { get; init; }

    /// <summary>
    /// Kanzlei-/Anfragerdaten aus den App-Einstellungen. Wenn null, gelten die
    /// Werte aus appsettings.json (<c>Zentralruf:Anfrager</c>); einzelne
    /// Leerwerte fallen feldweise dorthin zurück.
    /// </summary>
    public ZentralrufAnfragerOptions? Anfrager { get; init; }
}

/// <summary>Angaben zum Geschädigten für den gleichnamigen Formularabschnitt.</summary>
public sealed record ZentralrufGeschaedigter
{
    public required string Name { get; init; }

    public string StrasseHausnummer { get; init; } = string.Empty;

    public string Postleitzahl { get; init; } = string.Empty;

    public string Ort { get; init; } = string.Empty;

    /// <summary>Kennzeichen des Fahrzeugs des Geschädigten.</summary>
    public string Kennzeichen { get; init; } = string.Empty;
}
