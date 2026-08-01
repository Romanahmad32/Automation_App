using System.Text.Json;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Hält die zur Laufzeit gültige Postfach-Konfiguration und macht sie zur Quelle
/// der Wahrheit für den Monitor — anders als ein einmaliger
/// <see cref="IOptions{MailboxOptions}"/>-Snapshot lässt sie sich aus den
/// Einstellungen ändern, ohne die App neu zu starten.
///
/// Persistenz: Der Zugang wird unter
/// %APPDATA%\AutomationService\mailbox_config.json abgelegt (außerhalb des
/// Projektbaums, übersteht Rebuilds). appsettings.json liefert die Startwerte
/// und bleibt die Quelle der Tuning-Felder.
///
/// Änderungssignal: <see cref="ChangeToken"/> wird bei jeder Aktualisierung
/// ausgelöst, damit der laufende Monitor seine Verbindung sofort mit den neuen
/// Werten neu aufbaut (Muster wie ein Konfigurations-Reload-Token).
/// </summary>
public sealed class MailboxConfigStore
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    private readonly object _gate = new();
    private readonly MailboxOptions _seed;
    private readonly string _filePath;
    private readonly ILogger<MailboxConfigStore> _logger;

    private MailboxOptions _current;
    private CancellationTokenSource _changeSource = new();

    public MailboxConfigStore(IOptions<MailboxOptions> seed, ILogger<MailboxConfigStore> logger)
    {
        _seed = seed.Value;
        _logger = logger;

        var directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "AutomationService");
        _filePath = Path.Combine(directory, "mailbox_config.json");

        _current = LoadOrSeed();
    }

    /// <summary>Die aktuell gültige, vollständige Konfiguration.</summary>
    public MailboxOptions Current
    {
        get
        {
            lock (_gate)
            {
                return _current;
            }
        }
    }

    /// <summary>
    /// Token, das beim nächsten <see cref="Update"/> ausgelöst wird. Wer auf eine
    /// Konfigurationsänderung reagieren will, liest dieses Token, bevor er wartet.
    /// </summary>
    public CancellationToken ChangeToken
    {
        get
        {
            lock (_gate)
            {
                return _changeSource.Token;
            }
        }
    }

    /// <summary>
    /// Übernimmt die Änderung, persistiert sie und löst das Änderungssignal aus.
    /// </summary>
    public MailboxOptions Update(MailboxConfigUpdate update)
    {
        lock (_gate)
        {
            _current = update.ApplyTo(_current);
            Persist(_current);
            NotifyChanged();
            return _current;
        }
    }

    /// <summary>
    /// Löst das Änderungssignal aus, ohne die Konfiguration zu ändern — z. B.
    /// nach einer erfolgreichen Microsoft-Anmeldung, damit der Monitor sofort
    /// einen neuen Verbindungsversuch mit dem frischen Token startet.
    /// </summary>
    public void NotifyChanged()
    {
        lock (_gate)
        {
            // Erst das neue Token bereitstellen, dann das alte auslösen — wer
            // gerade ChangeToken liest, bekommt sicher das frische Token.
            var previous = _changeSource;
            _changeSource = new CancellationTokenSource();
            try
            {
                previous.Cancel();
            }
            catch (ObjectDisposedException)
            {
                // Bereits entsorgt — unkritisch.
            }
            previous.Dispose();
        }
    }

    private MailboxOptions LoadOrSeed()
    {
        try
        {
            if (File.Exists(_filePath))
            {
                var json = File.ReadAllText(_filePath);
                var persisted = JsonSerializer.Deserialize<PersistedMailboxConfig>(json);
                if (persisted is not null)
                {
                    return persisted.ApplyTo(_seed);
                }
            }
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                exception,
                "Gespeicherter Postfach-Zugang konnte nicht gelesen werden — es gelten die appsettings-Startwerte.");
        }

        return _seed;
    }

    private void Persist(MailboxOptions options)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_filePath)!);
            var json = JsonSerializer.Serialize(PersistedMailboxConfig.From(options), JsonOptions);
            File.WriteAllText(_filePath, json);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Postfach-Zugang konnte nicht gespeichert werden ({Path}).",
                _filePath);
        }
    }

    /// <summary>
    /// Auf Platte abgelegte Teilmenge: nur der Zugang, nicht die Tuning-Felder.
    /// Letztere bleiben in appsettings.json und werden beim Laden ergänzt.
    /// </summary>
    private sealed record PersistedMailboxConfig(
        bool Enabled,
        // Als Zeichenkette abgelegt (robust gegen Enum-Umbenennungen und alte
        // Dateien ohne das Feld — dann greift der App-Passwort-Standard).
        string? AuthMethod,
        string Host,
        int Port,
        bool UseSsl,
        string Username,
        string AppPassword,
        string Folder,
        string SubjectFilter)
    {
        public static PersistedMailboxConfig From(MailboxOptions options) => new(
            options.Enabled,
            options.AuthMethod.ToString(),
            options.Host,
            options.Port,
            options.UseSsl,
            options.Username,
            options.AppPassword,
            options.Folder,
            options.SubjectFilter);

        public MailboxOptions ApplyTo(MailboxOptions seed) => new()
        {
            Enabled = Enabled,
            AuthMethod = Enum.TryParse<MailboxAuthMethod>(AuthMethod, ignoreCase: true, out var method)
                ? method
                : MailboxAuthMethod.AppPassword,
            Host = Host,
            Port = Port,
            UseSsl = UseSsl,
            Username = Username,
            AppPassword = AppPassword,
            Folder = Folder,
            SubjectFilter = SubjectFilter,
            MicrosoftClientId = seed.MicrosoftClientId,
            IdleRefreshMinutes = seed.IdleRefreshMinutes,
            ReconnectInitialSeconds = seed.ReconnectInitialSeconds,
            ReconnectMaxSeconds = seed.ReconnectMaxSeconds,
            InitialScanCount = seed.InitialScanCount,
        };
    }
}
