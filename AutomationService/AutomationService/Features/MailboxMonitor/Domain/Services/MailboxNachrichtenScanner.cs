using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using MailKit;
using MailKit.Search;
using MimeKit;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Durchsucht einen geöffneten IMAP-Ordner nach Zentralruf-Antworten und legt
/// die Treffer im <see cref="IReceivedReplyStore"/> ab.
///
/// Ein Scanner gehört zu genau einer Verbindung: die zuletzt gesehene UID ist
/// sein Zustand und wird mit der Verbindung verworfen. Die UID ist dabei nur
/// eine Abkürzung — für die Korrektheit sorgt die Dublettenprüfung im Store,
/// weshalb beim Wiederverbinden gefahrlos ein Stück weit zurückgescannt
/// werden kann.
/// </summary>
public sealed class MailboxNachrichtenScanner(
    MailboxOptions options,
    IServiceScopeFactory scopeFactory,
    IZentralrufReplyParser parser,
    ILogger logger,
    Func<int, CancellationToken, Task> beiTreffer)
{
    // Höchste bereits gesehene UID innerhalb der laufenden Verbindung.
    private UniqueId? _highWater;

    /// <summary>Sieht die jüngsten Mails durch — beim (Wieder-)Verbinden.</summary>
    public async Task ScanRecentAsync(IMailFolder folder, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(folder);

        var all = await folder.SearchAsync(SearchQuery.All, cancellationToken);
        var recent = all.Count <= options.InitialScanCount
            ? all
            : all.Skip(all.Count - options.InitialScanCount).ToList();

        await ProcessUidsAsync(folder, recent, cancellationToken);
        _highWater = all.Count > 0 ? all[^1] : null;
    }

    /// <summary>Sieht alles ab der zuletzt gesehenen UID durch — nach IDLE bzw. je Poll-Takt.</summary>
    public async Task ScanNewAsync(IMailFolder folder, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(folder);

        if (_highWater is not { } highWater)
        {
            await ScanRecentAsync(folder, cancellationToken);
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
            if (!string.IsNullOrEmpty(options.SubjectFilter)
                && !subject.Contains(options.SubjectFilter, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var dedupeKey = !string.IsNullOrEmpty(message.MessageId)
                ? message.MessageId
                : $"{folder.UidValidity}:{uid}";

            await ProcessMessageAsync(message, subject, dedupeKey, cancellationToken);
        }
    }

    private async Task ProcessMessageAsync(
        MimeMessage message,
        string subject,
        string dedupeKey,
        CancellationToken cancellationToken)
    {
        // Dublettenprüfung vor dem Parsen, damit beim Reconnect-Nachscannen
        // bereits erfasste Mails nicht erneut ausgewertet werden. Der Store ist
        // DB-gestützt und scoped — der Singleton-Dienst öffnet je Zugriff einen Scope.
        using (var scope = scopeFactory.CreateScope())
        {
            var store = scope.ServiceProvider.GetRequiredService<IReceivedReplyStore>();
            if (await store.ContainsAsync(dedupeKey, cancellationToken))
            {
                return;
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
            return;
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
                return;
            }

            total = await store.CountAsync(cancellationToken);
        }

        logger.LogInformation(
            "Zentralruf-Antwort erfasst (Referenz: {Referenz}, Versicherer: {Versicherer}).",
            data.Referenz ?? "unbekannt",
            data.VersichererName ?? "—");

        await beiTreffer(total, cancellationToken);
    }
}
