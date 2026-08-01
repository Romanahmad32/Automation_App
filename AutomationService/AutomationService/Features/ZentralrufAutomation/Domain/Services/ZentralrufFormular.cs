using Microsoft.Playwright;

namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

/// <summary>
/// Bedient die geöffnete Zentralruf-Formularseite und protokolliert dabei
/// mit, was gefüllt werden konnte und was nicht.
///
/// Jeder Zugriff ist bewusst duldsam: schlägt ein Feld fehl, wird es in
/// <see cref="Uebersprungen"/> vermerkt und der Rest weiter ausgefüllt. Das
/// Formular ist eine fremde Angular-Seite, die sich jederzeit ändern kann —
/// ein halb vorausgefülltes Formular ist für den Anwalt immer noch nützlich,
/// ein Abbruch mittendrin nicht. Die IDs sitzen teils auf
/// Wrapper-Komponenten, teils direkt auf dem Eingabefeld; die Locator unten
/// decken beide Fälle ab.
/// </summary>
public sealed class ZentralrufFormular(IPage page, ILogger logger)
{
    private readonly List<string> _gefuellt = [];
    private readonly List<string> _uebersprungen = [];

    /// <summary>IDs der Felder, die gesetzt werden konnten.</summary>
    public IReadOnlyList<string> Gefuellt => _gefuellt;

    /// <summary>IDs der Felder, die der Anwalt selbst nachtragen muss.</summary>
    public IReadOnlyList<string> Uebersprungen => _uebersprungen;

    /// <summary>
    /// Schließt den Cookie-Dialog, der sonst das gesamte Formular überlagert und
    /// alle Klicks blockiert. Der Button ist ein &lt;div&gt;, dessen Click-Handler
    /// erst per JavaScript gebunden wird — ein zu früher Klick verpufft deshalb.
    /// Daher: klicken, prüfen, ob der Dialog wirklich verschwindet, und notfalls
    /// erneut versuchen.
    /// </summary>
    public async Task CookieBannerSchliessenAsync()
    {
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
                await TryClickAsync(page.Locator("#cookie_modal_button_choose"));

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

    /// <summary>Trägt einen Wert in ein Text-/Datumsfeld ein. Leerwerte werden übergangen.</summary>
    public async Task FuelleAsync(string elementId, string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return;
        }

        try
        {
            await InnerInput(elementId).FillAsync(value, new LocatorFillOptions { Timeout = 5000 });
            _gefuellt.Add(elementId);
        }
        catch (Exception exception) when (exception is TimeoutException or PlaywrightException)
        {
            logger.LogWarning("Feld {ElementId} konnte nicht gefüllt werden: {Reason}", elementId, exception.Message);
            _uebersprungen.Add(elementId);
        }
    }

    /// <summary>
    /// Wählt einen Eintrag einer Auswahlliste. Kein natives &lt;select&gt;? Dann
    /// wird das Material-Dropdown geöffnet und die Option im Overlay angeklickt.
    /// </summary>
    public async Task WaehleAsync(string elementId, string optionLabel)
    {
        if (string.IsNullOrWhiteSpace(optionLabel))
        {
            return;
        }

        try
        {
            await InnerSelect(elementId).SelectOptionAsync(
                new SelectOptionValue { Label = optionLabel },
                new LocatorSelectOptionOptions { Timeout = 5000 });
            _gefuellt.Add(elementId);
        }
        catch (Exception exception) when (exception is TimeoutException or PlaywrightException)
        {
            await WaehleUeberOverlayAsync(elementId, optionLabel);
        }
    }

    /// <summary>
    /// Rückfall für Material-Dropdowns: Die ID sitzt auf der gdvdl-Wrapper-Komponente;
    /// klickbar ist nur das innere &lt;mat-select&gt; (Suffix "-select"), nicht der
    /// Wrapper selbst.
    /// </summary>
    private async Task WaehleUeberOverlayAsync(string elementId, string optionLabel)
    {
        try
        {
            await page.Locator($"mat-select#{elementId}-select, #{elementId} mat-select").First
                .ClickAsync(new LocatorClickOptions { Timeout = 3000 });
            await page.Locator("mat-option")
                .Filter(new LocatorFilterOptions { HasText = optionLabel })
                .First
                .ClickAsync(new LocatorClickOptions { Timeout = 3000 });
            _gefuellt.Add(elementId);
        }
        catch (Exception exception) when (exception is TimeoutException or PlaywrightException)
        {
            logger.LogWarning(
                "Auswahl {ElementId} = '{Option}' nicht möglich: {Reason}",
                elementId,
                optionLabel,
                exception.Message);
            _uebersprungen.Add(elementId);

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

    /// <summary>Setzt ein Kontrollkästchen; bei versteckten Inputs wird die Komponente angeklickt.</summary>
    public async Task HakeAnAsync(string elementId)
    {
        try
        {
            await InnerCheckbox(elementId).CheckAsync(new LocatorCheckOptions { Timeout = 5000 });
            _gefuellt.Add(elementId);
        }
        catch (Exception exception) when (exception is TimeoutException or PlaywrightException)
        {
            try
            {
                await page.Locator($"#{elementId}").ClickAsync(new LocatorClickOptions { Timeout = 2000 });
                _gefuellt.Add(elementId);
            }
            catch (Exception fallbackException) when (fallbackException is TimeoutException or PlaywrightException)
            {
                logger.LogWarning(
                    "Checkbox {ElementId} konnte nicht gesetzt werden: {Reason}",
                    elementId,
                    fallbackException.Message);
                _uebersprungen.Add(elementId);
            }
        }
    }

    /// <summary>Wählt einen Radio-Button; Material benennt sie als "{Gruppen-Id}-{Wert}".</summary>
    public async Task WaehleRadioAsync(string elementId, string optionValue)
    {
        try
        {
            await page.Locator($"#{elementId}-{optionValue}")
                .ClickAsync(new LocatorClickOptions { Timeout = 5000 });
            _gefuellt.Add(elementId);
        }
        catch (Exception exception) when (exception is TimeoutException or PlaywrightException)
        {
            logger.LogWarning(
                "Auswahl {ElementId} = '{Option}' nicht möglich: {Reason}",
                elementId,
                optionValue,
                exception.Message);
            _uebersprungen.Add(elementId);
        }
    }

    private static async Task TryClickAsync(ILocator locator)
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

    private ILocator InnerInput(string elementId) =>
        page.Locator($"input#{elementId}, textarea#{elementId}, #{elementId} input, #{elementId} textarea").First;

    private ILocator InnerSelect(string elementId) =>
        page.Locator($"select#{elementId}, #{elementId} select").First;

    private ILocator InnerCheckbox(string elementId) =>
        page.Locator($"input#{elementId}, #{elementId} input[type=checkbox], #{elementId} input[type=radio]").First;
}
