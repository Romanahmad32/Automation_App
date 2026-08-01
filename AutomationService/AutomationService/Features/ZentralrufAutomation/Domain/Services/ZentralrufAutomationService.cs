using System.Globalization;
using Microsoft.Extensions.Options;
using Microsoft.Playwright;

namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

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
        var page = await OpenFormPageAsync();
        var filled = new List<string>();
        var skipped = new List<string>();

        await DismissCookieBannerAsync(page);

        // Zuerst "Sind Sie der Geschädigte?" auf "Nein" stellen (Standard ist "Ja"),
        // sonst existiert die Geschädigten-Sektion nicht und die Anfrager-Felder werden zurückgesetzt.
        if (request.Geschaedigter is not null)
        {
            await TrySelectRadioAsync(page, "anfrageformular-geschaedigter-JN", "nein", filled, skipped);
        }

        var anfrager = ResolveAnfrager(request);
        await TrySelectAsync(page, "anfrageformular-anfrager-personentypId", anfrager.Personentyp, filled, skipped);
        await TryFillAsync(page, "anfrageformular-anfrager-name", anfrager.Name, filled, skipped);
        await TryFillAsync(page, "anfrageformular-anfrager-strasseHausnummer", anfrager.StrasseHausnummer, filled, skipped);
        await TryFillAsync(page, "anfrageformular-anfrager-postleitzahl", anfrager.Postleitzahl, filled, skipped);
        await TryFillAsync(page, "anfrageformular-anfrager-ort", anfrager.Ort, filled, skipped);
        await TryFillAsync(page, "anfrageformular-anfrager-emailAdresse", anfrager.EmailAdresse, filled, skipped);
        // "Hiermit bestätige ich die E-Mail-Adresse …" ist (anders als früher) kein
        // Wiederholungsfeld mehr, sondern eine Pflicht-Checkbox.
        await TryCheckAsync(page, "anfrageformular-anfrager-bestaetigungEmail", filled, skipped);
        await TryFillAsync(page, "anfrageformular-anfrager-telefonnummer", anfrager.Telefonnummer, filled, skipped);
        await TryFillAsync(page, "anfrageformular-anfrager-referenz", referenz, filled, skipped);

        await TryFillAsync(
            page,
            "anfrageformular-schadenfall-kennzeichenSchaediger",
            request.KennzeichenSchaediger,
            filled,
            skipped);
        await TryFillAsync(
            page,
            "anfrageformular-schadenfall-schadenTag",
            request.Schadentag.ToString("dd.MM.yyyy", CultureInfo.InvariantCulture),
            filled,
            skipped);

        // Die beiden Einwilligungs-Checkboxen im Abschnitt "Versicherungsermittlung".
        await TryCheckAsync(page, "anfrageformular-bestaetigungAbrufDerDaten", filled, skipped);
        await TryCheckAsync(page, "anfrageformular-datenweitergabeErlaubt", filled, skipped);

        if (request.Geschaedigter is { } geschaedigter)
        {
            await TryFillAsync(page, "anfrageformular-geschaedigter-name", geschaedigter.Name, filled, skipped);
            await TryFillAsync(page, "anfrageformular-geschaedigter-strasseHausnummer", geschaedigter.StrasseHausnummer, filled, skipped);
            await TryFillAsync(page, "anfrageformular-geschaedigter-postleitzahl", geschaedigter.Postleitzahl, filled, skipped);
            await TryFillAsync(page, "anfrageformular-geschaedigter-ort", geschaedigter.Ort, filled, skipped);
            await TryFillAsync(page, "anfrageformular-geschaedigter-kennzeichen", geschaedigter.Kennzeichen, filled, skipped);
        }

        logger.LogInformation(
            "Zentralruf-Formular vorausgefüllt (Referenz {Referenz}). Gefüllt: {Filled}, übersprungen: {Skipped}.",
            referenz,
            filled.Count,
            skipped.Count);

        return new ZentralrufPrefillResult(referenz, filled, skipped);
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
            await using var warmupBrowser = await LaunchBrowserAsync(headless: true);
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
    /// ersatzweise die aus appsettings.json. Einzelne Leerwerte fallen feldweise auf appsettings zurück.
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
                _browser = await LaunchBrowserAsync();
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

    private async Task<IBrowser> LaunchBrowserAsync(bool headless = false)
    {
        // Bevorzugt einen bereits auf dem System installierten Browser, damit beim
        // Kunden nichts nachinstalliert werden muss: Edge ist auf Windows immer
        // vorhanden, Chrome häufig. Beide sind Chromium-basiert und werden von
        // Playwright über "Channels" angesteuert.
        foreach (var channel in new[] { "msedge", "chrome" })
        {
            try
            {
                return await _playwright!.Chromium.LaunchAsync(
                    new BrowserTypeLaunchOptions { Headless = headless, Channel = channel });
            }
            catch (PlaywrightException)
            {
                logger.LogInformation("Browser-Kanal '{Channel}' nicht verfügbar, versuche Alternative.", channel);
            }
        }

        // Fallback: das von Playwright mitgebrachte Chromium (wird bei Bedarf installiert).
        var launchOptions = new BrowserTypeLaunchOptions { Headless = headless };
        try
        {
            return await _playwright!.Chromium.LaunchAsync(launchOptions);
        }
        catch (PlaywrightException exception)
        {
            logger.LogInformation(exception, "Chromium nicht gefunden, installiere Playwright-Browser.");
            var exitCode = Microsoft.Playwright.Program.Main(["install", "chromium"]);
            if (exitCode != 0)
            {
                throw new InvalidOperationException($"Playwright-Browserinstallation fehlgeschlagen (Exit-Code {exitCode}).", exception);
            }

            return await _playwright!.Chromium.LaunchAsync(launchOptions);
        }
    }

    private async Task DismissCookieBannerAsync(IPage page)
    {
        // Der Website-Cookie-Dialog überlagert sonst das gesamte Formular und blockiert alle Klicks.
        // Der Button ist ein <div>, dessen Click-Handler erst per JavaScript gebunden wird —
        // ein zu früher Klick verpufft deshalb. Daher: klicken, prüfen, ob der Dialog wirklich
        // verschwindet, und notfalls erneut versuchen.
        var wrapper = page.Locator("#cookie_modal_wrapper");

        try
        {
            for (var attempt = 0; attempt < 3; attempt++)
            {
                if (await wrapper.CountAsync() == 0 || !await wrapper.IsVisibleAsync())
                {
                    return;
                }

                // "Nur erforderliche Cookies" — bewusst keine Tracking-Einwilligung.
                await TryClickAsync(page, page.Locator("#cookie_modal_button_choose"));

                try
                {
                    await wrapper.WaitForAsync(new LocatorWaitForOptions
                    {
                        State = WaitForSelectorState.Hidden,
                        Timeout = 2000,
                    });
                    return;
                }
                catch (Exception exception) when (exception is TimeoutException or PlaywrightException)
                {
                    // Dialog noch sichtbar — nächster Versuch.
                }
            }

            // Letzte Rettung: Overlay ausblenden, damit das Formular bedienbar bleibt.
            // (Es wird keine Einwilligung gespeichert; der Dialog kann beim nächsten
            // Seitenaufruf erneut erscheinen.)
            await page.EvaluateAsync(
                "document.querySelector('#cookie_modal_wrapper')?.style.setProperty('display', 'none')");
            logger.LogWarning("Cookie-Dialog ließ sich nicht regulär schließen; Overlay wurde ausgeblendet.");
        }
        catch (Exception exception) when (exception is TimeoutException or PlaywrightException)
        {
            logger.LogWarning("Cookie-Dialog konnte nicht behandelt werden: {Reason}", exception.Message);
        }
    }

    private static async Task TryClickAsync(IPage page, ILocator locator)
    {
        try
        {
            await locator.ClickAsync(new LocatorClickOptions { Timeout = 3000 });
        }
        catch (Exception exception) when (exception is TimeoutException or PlaywrightException)
        {
            // Element nicht sichtbar – nichts zu tun.
        }
    }

    private async Task TryFillAsync(IPage page, string elementId, string value, List<string> filled, List<string> skipped)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return;
        }

        try
        {
            // Die IDs sitzen teils auf Angular-Wrapper-Komponenten, teils direkt auf dem Eingabefeld.
            await InnerInput(page, elementId).FillAsync(value, new LocatorFillOptions { Timeout = 5000 });
            filled.Add(elementId);
        }
        catch (Exception exception) when (exception is TimeoutException or PlaywrightException)
        {
            logger.LogWarning("Feld {ElementId} konnte nicht gefüllt werden: {Reason}", elementId, exception.Message);
            skipped.Add(elementId);
        }
    }

    private async Task TrySelectAsync(IPage page, string elementId, string optionLabel, List<string> filled, List<string> skipped)
    {
        if (string.IsNullOrWhiteSpace(optionLabel))
        {
            return;
        }

        try
        {
            await InnerSelect(page, elementId).SelectOptionAsync(
                new SelectOptionValue { Label = optionLabel },
                new LocatorSelectOptionOptions { Timeout = 5000 });
            filled.Add(elementId);
        }
        catch (Exception exception) when (exception is TimeoutException or PlaywrightException)
        {
            // Kein natives <select>: Material-Dropdown öffnen und Option im Overlay anklicken.
            // Die ID sitzt auf der gdvdl-Wrapper-Komponente; klickbar ist nur das
            // innere <mat-select> (mit Suffix "-select"), nicht der Wrapper selbst.
            try
            {
                await page.Locator($"mat-select#{elementId}-select, #{elementId} mat-select").First
                    .ClickAsync(new LocatorClickOptions { Timeout = 3000 });
                await page.Locator("mat-option")
                    .Filter(new LocatorFilterOptions { HasText = optionLabel })
                    .First
                    .ClickAsync(new LocatorClickOptions { Timeout = 3000 });
                filled.Add(elementId);
            }
            catch (Exception fallbackException) when (fallbackException is TimeoutException or PlaywrightException)
            {
                logger.LogWarning(
                    "Auswahl {ElementId} = '{Option}' nicht möglich: {Reason}",
                    elementId,
                    optionLabel,
                    fallbackException.Message);
                skipped.Add(elementId);

                // Ein evtl. noch offenes Dropdown-Overlay schließen, sonst blockiert
                // es alle nachfolgenden Klicks auf dem Formular.
                try
                {
                    await page.Keyboard.PressAsync("Escape");
                }
                catch (PlaywrightException)
                {
                    // Seite ggf. schon geschlossen — ignorieren.
                }
            }
        }
    }

    private async Task TryCheckAsync(IPage page, string elementId, List<string> filled, List<string> skipped)
    {
        try
        {
            await InnerCheckbox(page, elementId).CheckAsync(new LocatorCheckOptions { Timeout = 5000 });
            filled.Add(elementId);
        }
        catch (Exception exception) when (exception is TimeoutException or PlaywrightException)
        {
            // Custom-Checkbox mit verstecktem Input: stattdessen die Komponente anklicken.
            try
            {
                await page.Locator($"#{elementId}").ClickAsync(new LocatorClickOptions { Timeout = 2000 });
                filled.Add(elementId);
            }
            catch (Exception fallbackException) when (fallbackException is TimeoutException or PlaywrightException)
            {
                logger.LogWarning(
                    "Checkbox {ElementId} konnte nicht gesetzt werden: {Reason}",
                    elementId,
                    fallbackException.Message);
                skipped.Add(elementId);
            }
        }
    }

    private async Task TrySelectRadioAsync(IPage page, string elementId, string optionValue, List<string> filled, List<string> skipped)
    {
        try
        {
            // Material-Radio-Buttons sind als "{Gruppen-Id}-{Wert}" benannt.
            await page.Locator($"#{elementId}-{optionValue}")
                .ClickAsync(new LocatorClickOptions { Timeout = 5000 });
            filled.Add(elementId);
        }
        catch (Exception exception) when (exception is TimeoutException or PlaywrightException)
        {
            logger.LogWarning(
                "Auswahl {ElementId} = '{Option}' nicht möglich: {Reason}",
                elementId,
                optionValue,
                exception.Message);
            skipped.Add(elementId);
        }
    }

    private static ILocator InnerInput(IPage page, string elementId) =>
        page.Locator($"input#{elementId}, textarea#{elementId}, #{elementId} input, #{elementId} textarea").First;

    private static ILocator InnerSelect(IPage page, string elementId) =>
        page.Locator($"select#{elementId}, #{elementId} select").First;

    private static ILocator InnerCheckbox(IPage page, string elementId) =>
        page.Locator(
                $"input#{elementId}, #{elementId} input[type=checkbox], #{elementId} input[type=radio]")
            .First;

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
