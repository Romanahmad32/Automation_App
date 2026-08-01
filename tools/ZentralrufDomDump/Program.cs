// Diagnose-Werkzeug: gibt die gerenderte DOM-Struktur ausgewählter Komponenten
// des Zentralruf-Anfrageformulars aus, um stabile Selektoren zu ermitteln.
using Microsoft.Playwright;

using var playwright = await Playwright.CreateAsync();
await using var browser = await playwright.Chromium.LaunchAsync(new BrowserTypeLaunchOptions { Headless = true });
var page = await browser.NewPageAsync(new BrowserNewPageOptions { Locale = "de-DE" });
await page.GotoAsync("https://www.zentralruf.de/online-anfrage/anfrageformular", new PageGotoOptions { WaitUntil = WaitUntilState.NetworkIdle });

// Cookie-Modal-Struktur ausgeben, bevor irgendetwas geklickt wird:
// alle Buttons/Links samt Id und Beschriftung, um den richtigen Schließen-Button zu finden.
var cookieModal = await page.EvaluateAsync<string>(
    """
    () => {
        const wrapper = document.querySelector('#cookie_modal_wrapper');
        if (!wrapper) return '[kein #cookie_modal_wrapper im DOM]';
        const lines = [];
        for (const el of wrapper.querySelectorAll('button, a, input, [id]')) {
            const text = (el.textContent ?? '').trim().replace(/\s+/g, ' ').slice(0, 120);
            lines.push(`<${el.tagName.toLowerCase()}> id=${el.id || '-'} class=${el.className || '-'} | ${text}`);
        }
        return lines.join('\n');
    }
    """);
Console.WriteLine("########## Cookie-Modal ##########");
Console.WriteLine(cookieModal);

try
{
    await page.Locator("#cookie_modal_button_choose").ClickAsync(new LocatorClickOptions { Timeout = 5000 });
    Console.WriteLine("[#cookie_modal_button_choose geklickt]");
    await page.WaitForTimeoutAsync(1000);
    var afterClick = await page.EvaluateAsync<string>(
        """
        () => {
            const wrapper = document.querySelector('#cookie_modal_wrapper');
            if (!wrapper) return '[Modal entfernt]';
            const style = getComputedStyle(wrapper);
            const lines = [`[Modal noch da: display=${style.display}, visibility=${style.visibility}]`];
            for (const el of wrapper.querySelectorAll('button, a')) {
                const text = (el.textContent ?? '').trim().replace(/\s+/g, ' ').slice(0, 120);
                lines.push(`<${el.tagName.toLowerCase()}> id=${el.id || '-'} class=${el.className || '-'} | ${text}`);
            }
            return lines.join('\n');
        }
        """);
    Console.WriteLine("########## Cookie-Modal nach Klick ##########");
    Console.WriteLine(afterClick);
}
catch (Exception)
{
    Console.WriteLine("[Kein Cookie-Modal / Klick fehlgeschlagen]");
}

try
{
    await page.Locator("#anfrageformular-geschaedigter-JN-nein")
        .ClickAsync(new LocatorClickOptions { Timeout = 10000 });
    Console.WriteLine("[JN = nein gesetzt]");
}
catch (Exception exception)
{
    Console.WriteLine($"[JN-Radio FEHLER: {exception.Message}]");
}

await page.WaitForTimeoutAsync(1500);

// Alle Elemente mit anfrageformular-IDs auflisten: Id, Tag, Typ und zugehöriger Label-Text.
var inventory = await page.EvaluateAsync<string>(
    """
    () => {
        const lines = [];
        for (const el of document.querySelectorAll('[id^="anfrageformular"]')) {
            const tag = el.tagName.toLowerCase();
            const type = el.getAttribute('type') ?? '';
            let labelText = '';
            const wrapper = el.closest('mat-checkbox, mat-radio-button, mat-form-field, mat-select, div.form-group') ?? el.parentElement;
            if (wrapper) {
                labelText = (wrapper.textContent ?? '').trim().replace(/\s+/g, ' ').slice(0, 160);
            }
            lines.push(`${el.id} | <${tag} type=${type}> | ${labelText}`);
        }
        return lines.join('\n');
    }
    """);
Console.WriteLine("########## Inventar anfrageformular-IDs ##########");
Console.WriteLine(inventory);

// Alle Checkboxen (auch ohne anfrageformular-Prefix) samt Beschriftung.
var checkboxes = await page.EvaluateAsync<string>(
    """
    () => {
        const lines = [];
        for (const el of document.querySelectorAll('input[type=checkbox], mat-checkbox')) {
            const wrapper = el.closest('mat-checkbox') ?? el;
            const text = (wrapper.textContent ?? '').trim().replace(/\s+/g, ' ').slice(0, 200);
            lines.push(`${el.id || '(ohne id)'} | wrapperId=${wrapper.id || '-'} | ${text}`);
        }
        return lines.join('\n');
    }
    """);
Console.WriteLine("########## Checkboxen ##########");
Console.WriteLine(checkboxes);

// Verifikation der Prefill-Selektoren: Dropdown + Checkboxen setzen und Zustand prüfen.
try
{
    await page.Locator("mat-select#anfrageformular-anfrager-personentypId-select").ClickAsync(new LocatorClickOptions { Timeout = 5000 });
    var optionTexts = await page.Locator("mat-option").AllTextContentsAsync();
    Console.WriteLine("########## Anfragertyp-Optionen ##########");
    Console.WriteLine(string.Join("\n", optionTexts.Select(t => t.Trim())));
    await page.Locator("mat-option").Filter(new LocatorFilterOptions { HasText = "Rechtsanwalt" }).First
        .ClickAsync(new LocatorClickOptions { Timeout = 3000 });
    var selected = await page.Locator("mat-select#anfrageformular-anfrager-personentypId-select").TextContentAsync();
    Console.WriteLine($"[Anfragertyp gewählt: '{selected?.Trim()}']");
}
catch (Exception exception)
{
    Console.WriteLine($"[Anfragertyp FEHLER: {exception.Message}]");
}

foreach (var checkboxId in new[]
         {
             "anfrageformular-bestaetigungAbrufDerDaten",
             "anfrageformular-datenweitergabeErlaubt",
             "anfrageformular-anfrager-bestaetigungEmail",
         })
{
    try
    {
        var input = page.Locator($"input#{checkboxId}, #{checkboxId} input[type=checkbox]").First;
        await input.CheckAsync(new LocatorCheckOptions { Timeout = 5000 });
        Console.WriteLine($"[{checkboxId} checked: {await input.IsCheckedAsync()}]");
    }
    catch (Exception exception)
    {
        Console.WriteLine($"[{checkboxId} FEHLER: {exception.Message}]");
    }
}

// Überschriften/Sektionen, um "Anfragertyp" und "Versicherungsermittlung" zu verorten.
var headings = await page.EvaluateAsync<string>(
    """
    () => {
        const lines = [];
        for (const el of document.querySelectorAll('h1, h2, h3, h4, legend, mat-label, label')) {
            const text = (el.textContent ?? '').trim().replace(/\s+/g, ' ').slice(0, 120);
            if (text) lines.push(`<${el.tagName.toLowerCase()}> for=${el.getAttribute('for') ?? '-'} | ${text}`);
        }
        return lines.join('\n');
    }
    """);
Console.WriteLine("########## Überschriften/Labels ##########");
Console.WriteLine(headings);
