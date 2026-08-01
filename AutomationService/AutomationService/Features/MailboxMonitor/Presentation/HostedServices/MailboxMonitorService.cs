using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Features.MailboxMonitor.Presentation.Hubs;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using MailKit;
using MailKit.Net.Imap;
using MailKit.Search;
using MailKit.Security;
using Microsoft.AspNetCore.SignalR;
using MimeKit;

namespace AutomationService.Features.MailboxMonitor.Presentation.HostedServices;

/// <summary>
/// Hält eine offene IMAP-Verbindung zum Postfach des Anwalts und lässt sich vom
/// Server per IDLE benachrichtigen, sobald eine neue Mail eintrifft (kein
/// Polling im Takt). Passende Mails (Betreff-Filter) werden durch den
/// gemeinsamen Zentralruf-Parser geschickt und als Treffer in der Inbox
/// (<see cref="IReceivedReplyStore"/>) abgelegt.
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

    // Höchste bereits gesehene UID innerhalb der laufenden Verbindung — nur eine
    // Optimierung, die Dublettenprüfung im Store sorgt für die Korrektheit.
    private UniqueId? _highWater;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        TimeSpan? backoff = null;
        while (!stoppingToken.IsCancellationRequested)
        {
            var options = configStore.Current;
            state.SetConfiguration(options.Enabled, options.IsConfigured);

            if (!options.Enabled || !options.IsConfigured)
            {
                if (!options.Enabled)
                {
                    logger.LogInformation("Postfach-Überwachung ist deaktiviert (Mailbox:Enabled = false).");
                }
                else
                {
                    logger.LogWarning(
                        "Postfach-Überwachung ist eingeschaltet, aber unvollständig konfiguriert " +
                        "(Host/Username/AppPassword). Der Monitor bleibt inaktiv, bis ein Zugang hinterlegt ist.");
                }

                // Untätig bleiben, bis sich die Konfiguration ändert (oder Shutdown).
                await WaitForReconfigureAsync(stoppingToken);
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
                if (!await DelayAsync(backoff.Value, changeToken, stoppingToken))
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

    /// <summary>Wartet, bis sich die Konfiguration ändert oder der Host herunterfährt.</summary>
    private async Task WaitForReconfigureAsync(CancellationToken stoppingToken)
    {
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken, configStore.ChangeToken);
        try
        {
            await Task.Delay(Timeout.InfiniteTimeSpan, linked.Token);
        }
        catch (OperationCanceledException)
        {
            // Entweder Shutdown oder Konfigurationsänderung — die Schleife wertet neu aus.
        }
    }

    /// <summary>
    /// Verzögerung, die sowohl durch Shutdown als auch durch eine
    /// Konfigurationsänderung vorzeitig endet. Liefert true, wenn die volle Zeit
    /// abgelaufen ist, false bei vorzeitigem Abbruch.
    /// </summary>
    private static async Task<bool> DelayAsync(TimeSpan delay, CancellationToken changeToken, CancellationToken stoppingToken)
    {
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken, changeToken);
        try
        {
            await Task.Delay(delay, linked.Token);
            return true;
        }
        catch (OperationCanceledException)
        {
            return false;
        }
    }

    private async Task RunConnectionAsync(MailboxOptions options, CancellationToken stoppingToken)
    {
        _active = options;
        using var client = new ImapClient();
        _highWater = null;

        try
        {
            var secureOptions = _active.UseSsl
                ? SecureSocketOptions.SslOnConnect
                : SecureSocketOptions.StartTlsWhenAvailable;
            await client.ConnectAsync(_active.Host, _active.Port, secureOptions, stoppingToken);
            await AuthenticateAsync(client, stoppingToken);

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
            await ProcessRecentAsync(folder, stoppingToken);

            if (idleSupported)
            {
                await IdleLoopAsync(client, folder, stoppingToken);
            }
            else
            {
                await PollLoopAsync(client, folder, stoppingToken);
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

    /// <summary>
    /// Meldet die frische Verbindung am Server an: Gmail-Weg mit App-Passwort,
    /// Outlook-Weg mit einem still erneuerten Microsoft-OAuth-Token (XOAUTH2).
    /// Fehlt die Microsoft-Anmeldung, scheitert der Versuch mit einer klaren
    /// Meldung — sie landet als Status in der Oberfläche, und die erfolgreiche
    /// Anmeldung stößt über das Änderungssignal sofort den nächsten Versuch an.
    /// </summary>
    private async Task AuthenticateAsync(ImapClient client, CancellationToken stoppingToken)
    {
        if (_active.AuthMethod == MailboxAuthMethod.MicrosoftOAuth)
        {
            var accessToken = await microsoftOAuth.GetAccessTokenSilentAsync(stoppingToken)
                ?? throw new AuthenticationException(
                    "Microsoft-Anmeldung erforderlich: Bitte in den Einstellungen unter " +
                    "Postfach-Zugang auf „Mit Microsoft anmelden“ klicken.");
            await client.AuthenticateAsync(new SaslMechanismOAuth2(_active.Username, accessToken), stoppingToken);
            return;
        }

        await client.AuthenticateAsync(_active.Username, _active.AppPassword, stoppingToken);
    }

    private async Task IdleLoopAsync(ImapClient client, IMailFolder folder, CancellationToken stoppingToken)
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

                await ProcessNewAsync(folder, stoppingToken);
            }
        }
        finally
        {
            folder.CountChanged -= OnCountChanged;
        }
    }

    private async Task PollLoopAsync(ImapClient client, IMailFolder folder, CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested && client.IsConnected)
        {
            await Task.Delay(TimeSpan.FromMinutes(2), stoppingToken);
            await client.NoOpAsync(stoppingToken);
            await ProcessNewAsync(folder, stoppingToken);
        }
    }

    private async Task ProcessRecentAsync(IMailFolder folder, CancellationToken cancellationToken)
    {
        var all = await folder.SearchAsync(SearchQuery.All, cancellationToken);
        var recent = all.Count <= _active.InitialScanCount
            ? all
            : all.Skip(all.Count - _active.InitialScanCount).ToList();

        await ProcessUidsAsync(folder, recent, cancellationToken);
        _highWater = all.Count > 0 ? all[^1] : null;
    }

    private async Task ProcessNewAsync(IMailFolder folder, CancellationToken cancellationToken)
    {
        if (_highWater is not { } highWater)
        {
            await ProcessRecentAsync(folder, cancellationToken);
            return;
        }

        // Bereich ab der zuletzt gesehenen UID (inklusive — die Dublettenprüfung
        // verwirft die schon erfasste Nachricht).
        var newUids = await folder.SearchAsync(
            SearchQuery.Uids(new UniqueIdRange(highWater, UniqueId.MaxValue)),
            cancellationToken);

        await ProcessUidsAsync(folder, newUids, cancellationToken);
        if (newUids.Count > 0)
        {
            _highWater = newUids.Max();
        }
    }

    private async Task ProcessUidsAsync(IMailFolder folder, IList<UniqueId> uids, CancellationToken cancellationToken)
    {
        foreach (var uid in uids)
        {
            cancellationToken.ThrowIfCancellationRequested();

            MimeMessage message;
            try
            {
                message = await folder.GetMessageAsync(uid, cancellationToken);
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                logger.LogWarning(exception, "Nachricht {Uid} konnte nicht geladen werden.", uid);
                continue;
            }

            var subject = message.Subject ?? string.Empty;
            if (!string.IsNullOrEmpty(_active.SubjectFilter)
                && !subject.Contains(_active.SubjectFilter, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var dedupeKey = !string.IsNullOrEmpty(message.MessageId)
                ? message.MessageId
                : $"{folder.UidValidity}:{uid}";

            // Dublettenprüfung vor dem Parsen, damit beim Reconnect-Nachscannen
            // bereits erfasste Mails nicht erneut ausgewertet werden. Der Store ist
            // DB-gestützt und scoped — der Singleton-Dienst öffnet je Zugriff einen Scope.
            using (var scope = scopeFactory.CreateScope())
            {
                var store = scope.ServiceProvider.GetRequiredService<IReceivedReplyStore>();
                if (await store.ContainsAsync(dedupeKey, cancellationToken))
                {
                    continue;
                }
            }

            string text;
            try
            {
                text = ZentralrufReplyEmailExtractor.ExtractFromMessage(message);
            }
            catch (FormatException exception)
            {
                logger.LogWarning(
                    exception,
                    "Mail ohne lesbaren Textteil übersprungen (Betreff: {Subject}).",
                    subject);
                continue;
            }

            var data = parser.Parse(text);
            var warnings = ZentralrufReplyWarnings.Collect(data);

            int total;
            using (var scope = scopeFactory.CreateScope())
            {
                var store = scope.ServiceProvider.GetRequiredService<IReceivedReplyStore>();
                var reply = await store.AddAsync(
                    dedupeKey, data, message.Subject, message.From.ToString(), warnings, text, cancellationToken);
                if (reply is null)
                {
                    continue;
                }

                total = await store.CountAsync(cancellationToken);
            }

            state.MarkReplyReceived(total);
            logger.LogInformation(
                "Zentralruf-Antwort erfasst (Referenz: {Referenz}, Versicherer: {Versicherer}).",
                data.Referenz ?? "unbekannt",
                data.VersichererName ?? "—");

            // Oberfläche sofort benachrichtigen (Push); sie lädt den Treffer per REST nach.
            await NotifyAsync(ReplyReceivedEvent, cancellationToken);
        }
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
