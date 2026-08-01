namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>Momentaufnahme des Postfach-Monitors für den Status-Endpunkt.</summary>
public sealed record MailboxStatus
{
    /// <summary>Überwachung in der Konfiguration eingeschaltet (<see cref="MailboxOptions.Enabled"/>).</summary>
    public required bool Enabled { get; init; }

    /// <summary>Genug Zugangsdaten für einen Verbindungsversuch vorhanden.</summary>
    public required bool Configured { get; init; }

    /// <summary>IMAP-Verbindung steht aktuell und lauscht (IDLE).</summary>
    public required bool Connected { get; init; }

    /// <summary>Server unterstützt IMAP IDLE; sonst läuft der Monitor im Poll-Rückfall.</summary>
    public required bool IdleSupported { get; init; }

    public required DateTimeOffset? LastConnectedAt { get; init; }

    /// <summary>Zeitpunkt der letzten erfassten Antwort.</summary>
    public required DateTimeOffset? LastReplyAt { get; init; }

    /// <summary>Letzte Fehlermeldung (z. B. Anmeldung fehlgeschlagen), für die Diagnose.</summary>
    public required string? LastError { get; init; }

    public required int ReceivedCount { get; init; }
}

/// <summary>
/// Thread-sicherer, veränderlicher Zustand des Postfach-Monitors. Der
/// Hintergrunddienst schreibt, der Controller liest (<see cref="Snapshot"/>).
/// </summary>
public sealed class MailboxConnectionState
{
    private readonly object _gate = new();
    private bool _enabled;
    private bool _configured;
    private bool _connected;
    private bool _idleSupported;
    private DateTimeOffset? _lastConnectedAt;
    private DateTimeOffset? _lastReplyAt;
    private string? _lastError;
    private int _receivedCount;

    public void SetConfiguration(bool enabled, bool configured)
    {
        lock (_gate)
        {
            _enabled = enabled;
            _configured = configured;
        }
    }

    public void MarkConnected(bool idleSupported)
    {
        lock (_gate)
        {
            _connected = true;
            _idleSupported = idleSupported;
            _lastConnectedAt = DateTimeOffset.Now;
            _lastError = null;
        }
    }

    public void MarkDisconnected(string? error)
    {
        lock (_gate)
        {
            _connected = false;
            if (error is not null)
            {
                _lastError = error;
            }
        }
    }

    public void MarkReplyReceived(int totalCount)
    {
        lock (_gate)
        {
            _lastReplyAt = DateTimeOffset.Now;
            _receivedCount = totalCount;
        }
    }

    public MailboxStatus Snapshot()
    {
        lock (_gate)
        {
            return new MailboxStatus
            {
                Enabled = _enabled,
                Configured = _configured,
                Connected = _connected,
                IdleSupported = _idleSupported,
                LastConnectedAt = _lastConnectedAt,
                LastReplyAt = _lastReplyAt,
                LastError = _lastError,
                ReceivedCount = _receivedCount,
            };
        }
    }
}
