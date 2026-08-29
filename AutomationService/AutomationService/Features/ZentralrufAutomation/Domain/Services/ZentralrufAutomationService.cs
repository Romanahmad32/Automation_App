using System.Globalization;
using Microsoft.Extensions.Options;
using Microsoft.Playwright;

namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

/// <summary>
/// Öffnet das Zentralruf-Anfrageformular in einem sichtbaren Browserfenster und
/// füllt es voraus. Captcha und Absenden bleiben bewusst beim Anwalt.
///
/// Die Feldbedienung liegt in <see cref="ZentralrufFormular"/>, der
/// Browserstart in <see cref="ZentralrufBrowserStart"/>; hier bleibt die
/// Reihenfolge der Schritte — die ist fachlich, nicht technisch: die Frage
/// "Sind Sie der Geschädigte?" muss zuerst beantwortet sein, sonst existiert
/// der Geschädigten-Abschnitt gar nicht.
/// </summary>
public sealed class ZentralrufAutomationService(
    ILogger<ZentralrufAutomationService> logger,
    IOptions<ZentralrufOptions> options) : IZentralrufAutomationService, IAsyncDisposable
{
    private readonly ZentralrufOptions _options = options.Value;
    private readonly SemaphoreSlim _browserLock = new(1, 1);
    private IPlaywright? _playwright;
    private IBrowser? _browser;

    public async Task<ZentralrufPrefillResult> PrefillAsync(ZentralrufPrefillRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);

        var referenz = BuildReferenz(request);
        var formular = new ZentralrufFormular(await OpenFormPageAsync(), logger);

        await formular.CookieBannerSchliessenAsync();

        // Zuerst "Sind Sie der Geschädigte?" auf "Nein" stellen (Standard ist "Ja"),
        // sonst existiert die Geschädigten-Sektion nicht und die Anfrager-Felder werden zurückgesetzt.
        if (request.Geschaedigter is not null)
        {
            await formular.WaehleRadioAsync("anfrageformular-geschaedigter-JN", "nein");
        }

        var anfrager = ResolveAnfrager(request);
        await formular.WaehleAsync("anfrageformular-anfrager-personentypId", anfrager.Personentyp);
        await formular.FuelleAsync("anfrageformular-anfrager-name", anfrager.Name);
        await formular.FuelleAsync("anfrageformular-anfrager-strasseHausnummer", anfrager.StrasseHausnummer);
        await formular.FuelleAsync("anfrageformular-anfrager-postleitzahl", anfrager.Postleitzahl);
        await formular.FuelleAsync("anfrageformular-anfrager-ort", anfrager.Ort);
        await formular.FuelleAsync("anfrageformular-anfrager-emailAdresse", anfrager.EmailAdresse);
        // "Hiermit bestätige ich die E-Mail-Adresse …" ist (anders als früher) kein
        // Wiederholungsfeld mehr, sondern eine Pflicht-Checkbox.
        await formular.HakeAnAsync("anfrageformular-anfrager-bestaetigungEmail");
        await formular.FuelleAsync("anfrageformular-anfrager-telefonnummer", anfrager.Telefonnummer);
        await formular.FuelleAsync("anfrageformular-anfrager-referenz", referenz);

        await formular.FuelleAsync(
            "anfrageformular-schadenfall-kennzeichenSchaediger",
            request.KennzeichenSchaediger);
        await formular.FuelleAsync(
            "anfrageformular-schadenfall-schadenTag",
            request.Schadentag.ToString("dd.MM.yyyy", CultureInfo.InvariantCulture));

        // Die beiden Einwilligungs-Checkboxen im Abschnitt "Versicherungsermittlung".
        await formular.HakeAnAsync("anfrageformular-bestaetigungAbrufDerDaten");
        await formular.HakeAnAsync("anfrageformular-datenweitergabeErlaubt");

        if (request.Geschaedigter is { } geschaedigter)
        {
            await formular.FuelleAsync("anfrageformular-geschaedigter-name", geschaedigter.Name);
            await formular.FuelleAsync("anfrageformular-geschaedigter-strasseHausnummer", geschaedigter.StrasseHausnummer);
            await formular.FuelleAsync("anfrageformular-geschaedigter-postleitzahl", geschaedigter.Postleitzahl);
            await formular.FuelleAsync("anfrageformular-geschaedigter-ort", geschaedigter.Ort);
            await formular.FuelleAsync("anfrageformular-geschaedigter-kennzeichen", geschaedigter.Kennzeichen);
        }

        logger.LogInformation(
            "Zentralruf-Formular vorausgefüllt (Referenz {Referenz}). Gefüllt: {Filled}, übersprungen: {Skipped}.",
            referenz,
            formular.Gefuellt.Count,
            formular.Uebersprungen.Count);

        return new ZentralrufPrefillResult(referenz, formular.Gefuellt, formular.Uebersprungen);
    }

    public async Task WarmupAsync()
    {
        // Startet Treiber + Chromium einmal headless und verwirft den Browser wieder.
        // Das lädt den Playwright-Node-Prozess und die Chromium-Binärdatei in den
        // OS-Cache, sodass der erste echte (sichtbare) Start deutlich schneller ist.
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        await _browserLock.WaitAsync();
        try
        {
            _playwright ??= await Playwright.CreateAsync();
            await using var warmupBrowser = await ZentralrufBrowserStart.LaunchAsync(_playwright, headless: true, logger);
        }
        finally
        {
            _browserLock.Release();
        }

        logger.LogInformation(
            "[PERF] Warmup der Playwright-Pipeline abgeschlossen: {ElapsedMs} ms",
            stopwatch.ElapsedMilliseconds);
    }

    /// <summary>
    /// Liefert die effektiven Anfragerdaten: bevorzugt die vom Client gesendeten (App-Einstellungen),
    /// ersatzweise <see cref="ZentralrufOptions.Anfrager"/>. Einzelne Leerwerte fallen feldweise
    /// dorthin zurück. Der Rückfall trägt heute nur seine Klassenvorgaben — in der versionierten
    /// appsettings.json steht der Abschnitt bewusst nicht mehr (docs/DATENFLUESSE.md, Kette 4).
    /// </summary>
    private ZentralrufAnfragerOptions ResolveAnfrager(ZentralrufPrefillRequest request)
    {
        var fallback = _options.Anfrager;
        if (request.Anfrager is not { } supplied)
            return fallback;

        static string Pick(string value, string fallbackValue) =>
            string.IsNullOrWhiteSpace(value) ? fallbackValue : value.Trim();

        return new ZentralrufAnfragerOptions
        {
            Personentyp = Pick(supplied.Personentyp, fallback.Personentyp),
            Name = Pick(supplied.Name, fallback.Name),
            StrasseHausnummer = Pick(supplied.StrasseHausnummer, fallback.StrasseHausnummer),
            Postleitzahl = Pick(supplied.Postleitzahl, fallback.Postleitzahl),
            Ort = Pick(supplied.Ort, fallback.Ort),
            EmailAdresse = Pick(supplied.EmailAdresse, fallback.EmailAdresse),
            Telefonnummer = Pick(supplied.Telefonnummer, fallback.Telefonnummer),
        };
    }

    internal static string BuildReferenz(ZentralrufPrefillRequest request)
    {
        // Eine vom Anwender überschriebene Referenz hat Vorrang vor der automatisch
        // zusammengebauten (Vorschau/Bearbeitung auf der Zentralruf-Anfrage-Seite).
        if (!string.IsNullOrWhiteSpace(request.Referenz))
        {
            return request.Referenz.Trim();
        }

        var jahr = request.Auftragsjahr == 0 ? DateTime.Now.Year % 100 : request.Auftragsjahr;
        return $"{request.Auftragsnummer}/{jahr:D2} {request.Abteilung.Trim()}_{request.KennzeichenSchaediger.Trim()}";
    }

    private async Task<IPage> OpenFormPageAsync()
    {
        await _browserLock.WaitAsync();
        try
        {
            _playwright ??= await Playwright.CreateAsync();

            if (_browser is null || !_browser.IsConnected)
            {
                _browser = await ZentralrufBrowserStart.LaunchAsync(_playwright, headless: false, logger);
            }

            // Eigener Kontext pro Anfrage; bleibt offen, damit der Anwalt Captcha löst und absendet.
            var context = await _browser.NewContextAsync(new BrowserNewContextOptions { Locale = "de-DE" });
            var page = await context.NewPageAsync();
            await page.GotoAsync(_options.FormUrl, new PageGotoOptions { WaitUntil = WaitUntilState.NetworkIdle });
            return page;
        }
        finally
        {
            _browserLock.Release();
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (_browser is not null)
        {
            await _browser.DisposeAsync();
        }

        _playwright?.Dispose();
        _browserLock.Dispose();
    }
}
