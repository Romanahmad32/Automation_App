namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

public class ZentralrufOptions
{
    public const string SectionName = "Zentralruf";

    public string FormUrl { get; init; } = "https://www.zentralruf.de/online-anfrage/anfrageformular";

    /// <summary>Kanzleidaten, mit denen der Abschnitt "Anfrager" vorausgefüllt wird.</summary>
    public ZentralrufAnfragerOptions Anfrager { get; init; } = new();
}

public class ZentralrufAnfragerOptions
{
    public string Personentyp { get; init; } = "Rechtsanwalt";

    public string Name { get; init; } = string.Empty;

    public string StrasseHausnummer { get; init; } = string.Empty;

    public string Postleitzahl { get; init; } = string.Empty;

    public string Ort { get; init; } = string.Empty;

    public string EmailAdresse { get; init; } = string.Empty;

    public string Telefonnummer { get; init; } = string.Empty;
}
