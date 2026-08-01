using Microsoft.Identity.Client;
using Microsoft.Identity.Client.Extensions.Msal;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Microsoft-Anmeldung (OAuth2) für Outlook.com-/Microsoft-365-Postfächer.
/// Microsoft hat IMAP mit Passwort/App-Passwort im September 2024 abgeschaltet —
/// der Zugriff läuft dort nur noch über XOAUTH2-Tokens.
///
/// Für den Anwalt bleibt es ein Klick: „Mit Microsoft anmelden" öffnet den
/// Standardbrowser, er meldet sich einmal normal an, fertig. Das erhaltene
/// Refresh-Token landet DPAPI-verschlüsselt im MSAL-Cache unter
/// %APPDATA%\AutomationService und wird danach still erneuert — keine erneute
/// Anmeldung, kein App-Passwort.
///
/// Voraussetzung ist die einmalig vom Entwickler angelegte Azure-App-Registrierung
/// (<see cref="MailboxOptions.MicrosoftClientId"/>, Anleitung: docs/OUTLOOK_SETUP.md).
/// </summary>
public sealed class MicrosoftMailOAuthService(
    MailboxConfigStore configStore,
    ILogger<MicrosoftMailOAuthService> logger) : IDisposable
{
    /// <summary>IMAP-Zugriff auf das eigene Postfach; offline_access (Refresh-Token) ergänzt MSAL selbst.</summary>
    private static readonly string[] Scopes = ["https://outlook.office365.com/IMAP.AccessAsUser.All"];

    private readonly SemaphoreSlim _gate = new(1, 1);
    private IPublicClientApplication? _app;
    private string? _appClientId;

    /// <summary>True, wenn die Azure-Client-ID hinterlegt ist und die Anmeldung damit möglich ist.</summary>
    public bool IsAvailable => !string.IsNullOrWhiteSpace(configStore.Current.MicrosoftClientId);

    /// <summary>
    /// Startet die interaktive Anmeldung: öffnet den Standardbrowser auf der
    /// Microsoft-Anmeldeseite (bewusst mit Nutzer im Loop, wie beim Captcha).
    /// Liefert die E-Mail-Adresse des angemeldeten Kontos.
    /// </summary>
    public async Task<string> SignInAsync(CancellationToken cancellationToken)
    {
        var app = await GetAppAsync(cancellationToken);

        // Der Browser wartet auf den Nutzer — großzügiges, aber endliches Zeitfenster.
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromMinutes(5));

        var result = await app
            .AcquireTokenInteractive(Scopes)
            .WithPrompt(Prompt.SelectAccount)
            .ExecuteAsync(timeout.Token);

        logger.LogInformation("Microsoft-Anmeldung erfolgreich für {Account}.", result.Account.Username);
        return result.Account.Username;
    }

    /// <summary>
    /// Holt still (ohne Nutzerinteraktion) ein gültiges Zugriffstoken aus dem
    /// Cache bzw. per Refresh-Token. Null, wenn keine (gültige) Anmeldung
    /// vorliegt und der Nutzer sich (erneut) anmelden muss.
    /// </summary>
    public async Task<string?> GetAccessTokenSilentAsync(CancellationToken cancellationToken)
    {
        var app = await GetAppAsync(cancellationToken);
        var account = (await app.GetAccountsAsync()).FirstOrDefault();
        if (account is null)
        {
            return null;
        }

        try
        {
            var result = await app.AcquireTokenSilent(Scopes, account).ExecuteAsync(cancellationToken);
            return result.AccessToken;
        }
        catch (MsalUiRequiredException exception)
        {
            logger.LogWarning(
                exception,
                "Microsoft-Token für {Account} kann nicht still erneuert werden — erneute Anmeldung nötig.",
                account.Username);
            return null;
        }
    }

    /// <summary>Die E-Mail-Adresse des angemeldeten Microsoft-Kontos, sonst null.</summary>
    public async Task<string?> GetSignedInAccountAsync(CancellationToken cancellationToken)
    {
        if (!IsAvailable)
        {
            return null;
        }

        var app = await GetAppAsync(cancellationToken);
        return (await app.GetAccountsAsync()).FirstOrDefault()?.Username;
    }

    /// <summary>Meldet das Microsoft-Konto ab (entfernt die gecachten Tokens).</summary>
    public async Task SignOutAsync(CancellationToken cancellationToken)
    {
        var app = await GetAppAsync(cancellationToken);
        foreach (var account in await app.GetAccountsAsync())
        {
            await app.RemoveAsync(account);
        }
    }

    /// <summary>
    /// Baut die MSAL-Anwendung lazy auf (und neu, falls die Client-ID in den
    /// appsettings geändert wurde) und hängt den verschlüsselten Datei-Cache an.
    /// </summary>
    private async Task<IPublicClientApplication> GetAppAsync(CancellationToken cancellationToken)
    {
        var clientId = configStore.Current.MicrosoftClientId;
        if (string.IsNullOrWhiteSpace(clientId))
        {
            throw new InvalidOperationException(
                "Für die Microsoft-Anmeldung fehlt die Azure-Client-ID " +
                "(Mailbox:MicrosoftClientId in appsettings.json). Anleitung: docs/OUTLOOK_SETUP.md.");
        }

        await _gate.WaitAsync(cancellationToken);
        try
        {
            if (_app is not null && string.Equals(_appClientId, clientId, StringComparison.OrdinalIgnoreCase))
            {
                return _app;
            }

            var app = PublicClientApplicationBuilder
                .Create(clientId)
                // "common": private Microsoft-Konten (outlook.de/.com) und
                // Microsoft-365-Organisationskonten gleichermaßen.
                .WithAuthority("https://login.microsoftonline.com/common")
                // Loopback-Redirect für den Systembrowser (in der App-Registrierung
                // als "Mobile and desktop applications"-Plattform hinterlegt).
                .WithRedirectUri("http://localhost")
                .Build();

            var cacheDirectory = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "AutomationService");
            var storage = new StorageCreationPropertiesBuilder("msal_token_cache.bin", cacheDirectory).Build();
            var cacheHelper = await MsalCacheHelper.CreateAsync(storage);
            cacheHelper.RegisterCache(app.UserTokenCache);

            _app = app;
            _appClientId = clientId;
            return app;
        }
        finally
        {
            _gate.Release();
        }
    }

    /// <summary>
    /// Gibt die Sperre frei, die den Aufbau der MSAL-Anwendung serialisiert.
    /// Der Dienst ist ein Singleton und lebt bis zum Herunterfahren; entsorgt
    /// wird er vom DI-Container.
    /// </summary>
    public void Dispose() => _gate.Dispose();
}
