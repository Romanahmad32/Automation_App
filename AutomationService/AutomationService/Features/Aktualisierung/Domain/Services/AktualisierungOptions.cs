namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Abschnitt <c>Aktualisierung</c> in appsettings (#196). Im Betrieb bleibt
/// alles auf der Vorgabe; umgestellt wird nur für die Abnahme mit
/// Testversionen, etwa per Umgebungsvariable <c>Aktualisierung__Quelle</c>.
/// </summary>
public sealed class AktualisierungOptions
{
    public const string SectionName = "Aktualisierung";

    public const string VorgabeQuelle =
        "https://api.github.com/repos/Romanahmad32/Automation_App/releases/latest";

    /// <summary>
    /// Adresse im Format von GitHubs <c>releases/latest</c>. Für die Abnahme ein
    /// eigenes Test-Repository — die Antwort muss <c>digest</c> tragen, sonst
    /// lädt der Dienst nicht.
    /// </summary>
    public string Quelle { get; set; } = VorgabeQuelle;

    /// <summary>
    /// Wie lange die Prüfung höchstens dauert. Hinter einer Kanzlei-Firewall
    /// verschwindet eine Anfrage sonst wortlos, und der Dialog wartete auf
    /// eine Antwort, die nie kommt.
    /// </summary>
    public TimeSpan PruefZeitlimit { get; set; } = TimeSpan.FromSeconds(10);

    /// <summary>
    /// Wie lange der Download ohne ein einziges neues Byte weiterläuft. Kein
    /// Gesamtlimit: 85 MB über eine langsame Leitung dürfen dauern, eine tote
    /// Verbindung dagegen hängt ohne Grenze unter Umständen eine Viertelstunde.
    /// </summary>
    public TimeSpan DownloadLeerlauf { get; set; } = TimeSpan.FromSeconds(60);
}
