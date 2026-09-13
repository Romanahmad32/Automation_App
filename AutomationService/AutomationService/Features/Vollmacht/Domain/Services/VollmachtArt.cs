namespace AutomationService.Features.Vollmacht.Domain.Services;

/// <summary>
/// Die drei Vollmachtsvorlagen der Kanzlei (§4.11). Der Vollmachtstext ist in
/// allen dreien derselbe; sie unterscheiden sich im Kopf („in Sachen", „wegen")
/// und die Unfallvorlage zusätzlich im Abschnitt für Telefon, E-Mail und Konto.
/// </summary>
public enum VollmachtArt
{
    Unfallsachen,
    Bussgeldsachen,
    Strafsache,
}

/// <summary>
/// Namen und Schreibweisen zu <see cref="VollmachtArt"/> — an einer Stelle, weil
/// drei Seiten sie teilen: der Vertrag (Wert), der Vorlagenordner des Anwalts
/// (fester Dateiname) und das mitgelieferte Saatgut (Mustername).
/// </summary>
public static class VollmachtArten
{
    /// <summary>Unterordner des Vorlagenordners, in dem die drei Vorlagen liegen.</summary>
    public const string Unterordner = "Vollmacht";

    public static IReadOnlyList<VollmachtArt> Alle { get; } =
        [VollmachtArt.Unfallsachen, VollmachtArt.Bussgeldsachen, VollmachtArt.Strafsache];

    /// <summary>Der Wert im HTTP-Vertrag: <c>unfallsachen</c>, <c>bussgeldsachen</c>, <c>strafsache</c>.</summary>
    public static string Wert(VollmachtArt art) => art switch
    {
        VollmachtArt.Unfallsachen => "unfallsachen",
        VollmachtArt.Bussgeldsachen => "bussgeldsachen",
        _ => "strafsache",
    };

    /// <summary>Die Art zu einem Vertragswert; null bei einem unbekannten.</summary>
    public static VollmachtArt? AusWert(string? wert) =>
        Alle.Cast<VollmachtArt?>().FirstOrDefault(art =>
            string.Equals(Wert(art!.Value), wert?.Trim(), StringComparison.OrdinalIgnoreCase));

    /// <summary>
    /// Der feste Dateiname im Unterordner <see cref="Unterordner"/>. Ohne „ß"
    /// und ohne Umlaut, damit der Name auf jedem Weg — OneDrive, ZIP-Sicherung,
    /// Kommandozeile — derselbe bleibt.
    /// </summary>
    public static string Dateiname(VollmachtArt art) => art switch
    {
        VollmachtArt.Unfallsachen => "Vollmacht Unfallsachen.docx",
        VollmachtArt.Bussgeldsachen => "Vollmacht Bussgeldsachen.docx",
        _ => "Vollmacht Strafsache.docx",
    };

    /// <summary>
    /// Name des neutralen Musters unter <c>Templates/Vollmacht/</c>. Anders als
    /// der feste Name, weil die <c>.gitignore</c> nur <c>Muster_*.docx</c>
    /// durchlässt: Eine echte Kanzleivorlage unter dem festen Namen soll gar
    /// nicht erst versioniert werden können (docs/RELEASE.md, „Vorlagen").
    /// </summary>
    public static string Mustername(VollmachtArt art) =>
        "Muster_" + Path.GetFileNameWithoutExtension(Dateiname(art)).Replace(' ', '_') + ".docx";
}
