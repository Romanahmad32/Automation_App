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
public sealed class MailboxConfigStore : IDisposable
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

    /// <summary>
    /// Gibt die zuletzt ausgegebene Änderungsquelle frei. <see cref="NotifyChanged"/>
    /// entsorgt jeweils die abgelöste Quelle; die aktuelle bleibt bis zum
    /// Herunterfahren bestehen und wird hier vom DI-Container mit entsorgt.
    /// </summary>
    public void Dispose()
    {
        lock (_gate)
        {
            _changeSource.Dispose();
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
                    var geladen = persisted.ApplyTo(_seed);

                    if (!string.IsNullOrEmpty(persisted.AppPasswordProtected)
                        && geladen.AppPassword.Length == 0)
                    {
                        _logger.LogWarning(
                            "Das gespeicherte Postfach-Passwort ist nicht lesbar (andere Windows-Anmeldung "
                            + "oder beschädigte Datei). Es muss in den Einstellungen neu eingegeben werden.");
                    }

                    if (persisted.BrauchtUmzug)
                    {
                        // Einmalig: das früher im Klartext abgelegte Passwort
                        // verschlüsselt neu schreiben. Ab hier steht in der
                        // Datei kein lesbares Passwort mehr.
                        Persist(geladen);
                        _logger.LogInformation(
                            "Der gespeicherte Postfach-Zugang wurde auf die verschlüsselte Ablage umgestellt.");
                    }

                    return geladen;
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
        var abzulegen = PersistedMailboxConfig.From(options);
        if (abzulegen is null)
        {
            // Den Zugang mit leerem Passwortfeld abzulegen, hiesse: im Speicher
            // läuft alles weiter, und erst nach dem nächsten Start steht die
            // Überwachung ohne Zugang da — grundlos, soweit irgendwo ablesbar.
            _logger.LogError(
                "Das Postfach-Passwort liess sich nicht verschlüsseln (DPAPI). Der gespeicherte "
                + "Zugang bleibt deshalb unverändert ({Path}); die laufende Sitzung arbeitet mit "
                + "den eingegebenen Werten weiter.",
                _filePath);
            return;
        }

        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_filePath)!);
            var json = JsonSerializer.Serialize(abzulegen, JsonOptions);
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
        // Altlast: bis August 2026 lag das Passwort hier im Klartext. Wird nur
        // noch gelesen (und beim ersten Laden nach AppPasswordProtected
        // umgezogen), nie mehr geschrieben.
        string? AppPassword,
        string Folder,
        string SubjectFilter,
        // DPAPI-verschlüsselt, an das Windows-Benutzerkonto gebunden.
        string? AppPasswordProtected = null)
    {
        /// <summary>
        /// True, wenn die geladene Datei noch ein Klartext-Passwort enthält —
        /// dann schreibt der Store sie einmalig neu, damit der Klartext
        /// verschwindet.
        /// </summary>
        public bool BrauchtUmzug =>
            string.IsNullOrEmpty(AppPasswordProtected) && !string.IsNullOrEmpty(AppPassword);

        /// <returns>
        /// Null, wenn das Passwort sich nicht verschlüsseln liess. Dann darf
        /// nichts abgelegt werden: Ein Datensatz ohne Passwortfeld sähe aus wie
        /// ein Zugang, bei dem nie eines eingetragen war —
        /// <see cref="BrauchtUmzug"/> bliebe false, und niemand käme darauf,
        /// dass hier etwas verlorenging.
        /// </returns>
        public static PersistedMailboxConfig? From(MailboxOptions options)
        {
            var geschuetzt = PasswortSchutz.Schuetze(options.AppPassword);
            return geschuetzt is null
                ? null
                : new(
                    options.Enabled,
                    options.AuthMethod.ToString(),
                    options.Host,
                    options.Port,
                    options.UseSsl,
                    options.Username,
                    // Das Klartextfeld bleibt ab jetzt leer.
                    null,
                    options.Folder,
                    options.SubjectFilter,
                    geschuetzt);
        }

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
            AppPassword = Passwort(),
            Folder = Folder,
            SubjectFilter = SubjectFilter,
            MicrosoftClientId = seed.MicrosoftClientId,
            IdleRefreshMinutes = seed.IdleRefreshMinutes,
            ReconnectInitialSeconds = seed.ReconnectInitialSeconds,
            ReconnectMaxSeconds = seed.ReconnectMaxSeconds,
            InitialScanCount = seed.InitialScanCount,
        };

        /// <summary>
        /// Das Passwort im Klartext: bevorzugt aus dem geschützten Feld, sonst
        /// aus der alten Klartext-Ablage. Ist der geschützte Wert unlesbar (die
        /// Datei stammt aus einer anderen Windows-Anmeldung oder ist beschädigt),
        /// bleibt es leer — die Überwachung meldet dann einen fehlenden Zugang,
        /// und der Anwalt gibt das Passwort einmal neu ein.
        /// </summary>
        private string Passwort() =>
            string.IsNullOrEmpty(AppPasswordProtected)
                ? AppPassword ?? string.Empty
                : PasswortSchutz.Entschuetze(AppPasswordProtected) ?? string.Empty;
    }
}
