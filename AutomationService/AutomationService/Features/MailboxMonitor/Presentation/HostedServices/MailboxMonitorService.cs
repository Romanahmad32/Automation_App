using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Features.MailboxMonitor.Presentation.Hubs;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using MailKit;
using MailKit.Net.Imap;
using MailKit.Security;
using Microsoft.AspNetCore.SignalR;

namespace AutomationService.Features.MailboxMonitor.Presentation.HostedServices;

/// <summary>
/// Hält eine offene IMAP-Verbindung zum Postfach des Anwalts und lässt sich vom
/// Server per IDLE benachrichtigen, sobald eine neue Mail eintrifft (kein
/// Polling im Takt). Was mit einer Mail passiert, entscheidet der
/// <see cref="MailboxNachrichtenScanner"/>; hier liegt die Verbindung: aufbauen,
/// halten, bei Abriss neu aufbauen.
///
/// Robustheit: IDLE wird vor Ablauf der Server-Obergrenze erneuert
/// (<see cref="MailboxOptions.IdleRefreshMinutes"/>); reißt die Verbindung ab,
/// wird mit exponentiellem Backoff neu verbunden und beim Wiederverbinden eine
/// Handvoll der jüngsten Mails nachgescannt, damit nichts verloren geht.
/// Erkennt der Server kein IDLE, fällt der Dienst auf einen Poll-Takt zurück.
/// </summary>
public sealed class MailboxMonitorService(
    MailboxConfigStore configStore,
    IServiceScopeFactory scopeFactory,
    MailboxConnectionState state,
    IZentralrufReplyParser parser,
    MicrosoftMailOAuthService microsoftOAuth,
    IHubContext<MailboxHub> hub,
    ILogger<MailboxMonitorService> logger) : BackgroundService
{
    // Push-Methodennamen, auf die die Oberfläche horcht (zentral am Hub, damit
    // auch die Entwickler-Simulation dieselben Signale sendet). Die Signale
    // tragen keine Nutzdaten — der Client holt Status bzw. Treffer per REST nach.
    private const string ReplyReceivedEvent = MailboxHub.ReplyReceivedEvent;
    private const string StatusChangedEvent = MailboxHub.StatusChangedEvent;

    // Die für die laufende Verbindung gültige Konfiguration. Es läuft immer nur
    // eine Verbindung, daher genügt ein Feld; bei einer Konfigurationsänderung
    // wird die Verbindung abgebrochen und mit dem neuen Wert neu aufgebaut.
    private MailboxOptions _active = default!;

    // Wird vom CountChanged-Handler abgebrochen, um IDLE bei neuer Mail sofort
    // zu beenden. Nur eine Verbindung läuft gleichzeitig, daher reicht ein Feld.
    private CancellationTokenSource? _idleDone;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        TimeSpan? backoff = null;
        while (!stoppingToken.IsCancellationRequested)
        {
            var options = configStore.Current;
            state.SetConfiguration(options.Enabled, options.IsConfigured);

            if (!options.Enabled || !options.IsConfigured)
            {
                LogInaktiv(options);

                // Untätig bleiben, bis sich die Konfiguration ändert (oder Shutdown).
                await MailboxWartezeiten.WarteAufNeukonfigurationAsync(configStore, stoppingToken);
                backoff = null;
                continue;
            }

            // Token vor dem Linken lesen: Eine Aktualisierung löst genau dieses
            // Token aus und reißt damit die laufende Verbindung ab.
            var changeToken = configStore.ChangeToken;
            using var connectionCts = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken, changeToken);

            try
            {
                await RunConnectionAsync(options, connectionCts.Token);
                // RunConnectionAsync kehrt nur bei Abbruch (Shutdown/Reconfigure) zurück.
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (OperationCanceledException) when (changeToken.IsCancellationRequested)
            {
                logger.LogInformation("Postfach-Konfiguration geändert — verbinde mit den neuen Werten neu.");
                backoff = null;
                continue;
            }
            catch (Exception exception)
            {
                state.MarkDisconnected(exception.Message);
                await NotifyAsync(StatusChangedEvent, CancellationToken.None);
                backoff ??= TimeSpan.FromSeconds(options.ReconnectInitialSeconds);
                logger.LogWarning(
                    exception,
                    "Postfach-Verbindung unterbrochen. Neuer Versuch in {Delay}.",
                    backoff);

                // Wartezeit ist abbrechbar: Ein hinterlegter Zugang/Fix wirkt sofort.
                if (!await MailboxWartezeiten.WarteAsync(backoff.Value, changeToken, stoppingToken))
                {
                    if (stoppingToken.IsCancellationRequested)
                    {
                        break;
                    }
                    // Konfigurationsänderung während des Wartens: sofort neu versuchen.
                    backoff = null;
                    continue;
                }

                backoff = TimeSpan.FromSeconds(
                    Math.Min(backoff.Value.TotalSeconds * 2, options.ReconnectMaxSeconds));
                continue;
            }

            // Sauberer Rücklauf ohne Abbruch ist unerwartet — kurz warten, neu verbinden.
            backoff = TimeSpan.FromSeconds(options.ReconnectInitialSeconds);
        }
    }

    private void LogInaktiv(MailboxOptions options)
    {
        if (!options.Enabled)
        {
            logger.LogInformation("Postfach-Überwachung ist deaktiviert (Mailbox:Enabled = false).");
            return;
        }

        logger.LogWarning(
            "Postfach-Überwachung ist eingeschaltet, aber unvollständig konfiguriert " +
            "(Host/Username/AppPassword). Der Monitor bleibt inaktiv, bis ein Zugang hinterlegt ist.");
    }

    private async Task RunConnectionAsync(MailboxOptions options, CancellationToken stoppingToken)
    {
        _active = options;
        using var client = new ImapClient();
        var scanner = new MailboxNachrichtenScanner(
            options, scopeFactory, parser, logger, MeldeTrefferAsync);

        try
        {
            var secureOptions = _active.UseSsl
                ? SecureSocketOptions.SslOnConnect
                : SecureSocketOptions.StartTlsWhenAvailable;
            await client.ConnectAsync(_active.Host, _active.Port, secureOptions, stoppingToken);
            await MailboxAnmeldung.AuthenticateAsync(client, _active, microsoftOAuth, stoppingToken);

            var folder = string.Equals(_active.Folder, "INBOX", StringComparison.OrdinalIgnoreCase)
                ? client.Inbox
                : await client.GetFolderAsync(_active.Folder, stoppingToken);
            await folder.OpenAsync(FolderAccess.ReadOnly, stoppingToken);

            var idleSupported = client.Capabilities.HasFlag(ImapCapabilities.Idle);
            state.MarkConnected(idleSupported);
            await NotifyAsync(StatusChangedEvent, stoppingToken);
            logger.LogInformation(
                "Postfach verbunden ({Host}, Ordner {Folder}). IDLE: {Mode}.",
                _active.Host,
                _active.Folder,
                idleSupported ? "ja" : "nein – Poll-Modus");

            // Beim (Wieder-)Verbinden einmalig die jüngsten Mails durchsehen.
            await scanner.ScanRecentAsync(folder, stoppingToken);

            if (idleSupported)
            {
                await IdleLoopAsync(client, folder, scanner, stoppingToken);
            }
            else
            {
                await PollLoopAsync(client, folder, scanner, stoppingToken);
            }
        }
        finally
        {
            state.MarkDisconnected(null);
            if (client.IsConnected)
            {
                try
                {
                    await client.DisconnectAsync(true, CancellationToken.None);
                }
                catch (Exception exception)
                {
                    logger.LogDebug(exception, "Sauberes Trennen der IMAP-Verbindung fehlgeschlagen (unkritisch).");
                }
            }
        }
    }

    private async Task IdleLoopAsync(
        ImapClient client,
        IMailFolder folder,
        MailboxNachrichtenScanner scanner,
        CancellationToken stoppingToken)
    {
        void OnCountChanged(object? sender, EventArgs e) => Volatile.Read(ref _idleDone)?.Cancel();

        folder.CountChanged += OnCountChanged;
        try
        {
            while (!stoppingToken.IsCancellationRequested && client.IsConnected)
            {
                using var timeout = new CancellationTokenSource(TimeSpan.FromMinutes(_active.IdleRefreshMinutes));
                Volatile.Write(ref _idleDone, timeout);
                try
                {
                    // doneToken (timeout/CountChanged) beendet IDLE regulär ohne Exception;
                    // stoppingToken bricht beim Shutdown ab und wirft.
                    await client.IdleAsync(timeout.Token, stoppingToken);
                }
                finally
                {
                    Volatile.Write(ref _idleDone, null);
                }

                await scanner.ScanNewAsync(folder, stoppingToken);
            }
        }
        finally
        {
            folder.CountChanged -= OnCountChanged;
        }
    }

    private static async Task PollLoopAsync(
        ImapClient client,
        IMailFolder folder,
        MailboxNachrichtenScanner scanner,
        CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested && client.IsConnected)
        {
            await Task.Delay(TimeSpan.FromMinutes(2), stoppingToken);
            await client.NoOpAsync(stoppingToken);
            await scanner.ScanNewAsync(folder, stoppingToken);
        }
    }

    /// <summary>Ein Treffer wurde abgelegt: Status hochzählen und die Oberfläche wecken.</summary>
    private async Task MeldeTrefferAsync(int gesamt, CancellationToken cancellationToken)
    {
        state.MarkReplyReceived(gesamt);

        // Oberfläche sofort benachrichtigen (Push); sie lädt den Treffer per REST nach.
        await NotifyAsync(ReplyReceivedEvent, cancellationToken);
    }

    /// <summary>
    /// Schickt ein nutzdatenfreies Signal an alle verbundenen Clients. Push ist
    /// best-effort: schlägt es fehl, darf der Monitor nicht abreißen.
    /// </summary>
    private async Task NotifyAsync(string method, CancellationToken cancellationToken)
    {
        try
        {
            await hub.Clients.All.SendAsync(method, cancellationToken);
        }
        catch (Exception exception)
        {
            logger.LogDebug(exception, "SignalR-Push '{Method}' fehlgeschlagen (unkritisch).", method);
        }
    }
}
