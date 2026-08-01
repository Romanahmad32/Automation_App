using Microsoft.Playwright;

namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

/// <summary>
/// Startet den Browser für die Formularbedienung.
///
/// Bevorzugt einen bereits auf dem System installierten Browser, damit beim
/// Kunden nichts nachinstalliert werden muss: Edge ist auf Windows immer
/// vorhanden, Chrome häufig. Beide sind Chromium-basiert und werden von
/// Playwright über "Channels" angesteuert. Erst wenn keiner davon startet,
/// greift das von Playwright mitgebrachte Chromium — das notfalls
/// nachinstalliert wird.
/// </summary>
public static class ZentralrufBrowserStart
{
    public static async Task<IBrowser> LaunchAsync(IPlaywright playwright, bool headless, ILogger logger)
    {
        ArgumentNullException.ThrowIfNull(playwright);
        ArgumentNullException.ThrowIfNull(logger);

        foreach (var channel in new[] { "msedge", "chrome" })
        {
            try
            {
                return await playwright.Chromium.LaunchAsync(
                    new BrowserTypeLaunchOptions { Headless = headless, Channel = channel });
            }
            catch (PlaywrightException)
            {
                logger.LogInformation("Browser-Kanal '{Channel}' nicht verfügbar, versuche Alternative.", channel);
            }
        }

        var launchOptions = new BrowserTypeLaunchOptions { Headless = headless };
        try
        {
            return await playwright.Chromium.LaunchAsync(launchOptions);
        }
        catch (PlaywrightException exception)
        {
            logger.LogInformation(exception, "Chromium nicht gefunden, installiere Playwright-Browser.");
            // Voll qualifiziert: der Webhost hat eine eigene Program-Klasse.
            var exitCode = Microsoft.Playwright.Program.Main(["install", "chromium"]);
            if (exitCode != 0)
            {
                throw new InvalidOperationException(
                    $"Playwright-Browserinstallation fehlgeschlagen (Exit-Code {exitCode}).", exception);
            }

            return await playwright.Chromium.LaunchAsync(launchOptions);
        }
    }
}
