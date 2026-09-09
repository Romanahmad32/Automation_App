using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using MailKit;
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

        await ScanBereichAsync(folder, Math.Max(0, folder.Count - options.InitialScanCount), cancellationToken);
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

        var start = await PosteingangLeser.FindeGrenzeAsync(folder.Count, highWater.Id, async index =>
        {
            var summaries = await folder.FetchAsync(index, index, MessageSummaryItems.UniqueId, cancellationToken);
            return summaries.First(item => item.Index == index).UniqueId.Id;
        });
        await ScanBereichAsync(folder, start, cancellationToken);
    }

    private async Task ScanBereichAsync(IMailFolder folder, int start, CancellationToken cancellationToken)
    {
        var ende = folder.Count;
        for (var index = start; index < ende; index += PosteingangLeser.Seitengroesse)
        {
            var summaries = await folder.FetchAsync(index, Math.Min(ende - 1, index + PosteingangLeser.Seitengroesse - 1),
                MessageSummaryItems.UniqueId | MessageSummaryItems.Envelope, cancellationToken);
            foreach (var summary in summaries.OrderBy(item => item.UniqueId.Id))
            {
                if (_highWater is { } water && summary.UniqueId.Id <= water.Id)
                {
                    continue;
                }
                // Erst Kopfzeilen prüfen. Normale Kanzleimails samt Anhängen
                // werden vom Zentralruf-Monitor überhaupt nicht heruntergeladen.
                var subject = summary.Envelope?.Subject ?? string.Empty;
                if (string.IsNullOrEmpty(options.SubjectFilter)
                    || subject.Contains(options.SubjectFilter, StringComparison.OrdinalIgnoreCase))
                {
                    using var message = await folder.GetMessageAsync(summary.UniqueId, cancellationToken);
                    var dedupeKey = !string.IsNullOrEmpty(message.MessageId)
                        ? message.MessageId : $"{folder.UidValidity}:{summary.UniqueId}";
                    await ProcessMessageAsync(message, subject, dedupeKey, cancellationToken);
                }
                _highWater = summary.UniqueId;
            }
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

        // Die Anhänge, bevor die Nachricht aus der Hand geht (§4.3): Der Monitor
        // hat sie ohnehin vollständig geladen, und beim Versand fehlten sie
        // sonst genau dort, wo der Anwalt sie sonst von Hand herüberzieht.
        var anhangPfade = AntwortAnhaenge.LegeAb(message, dedupeKey, logger);

        int total;
        using (var scope = scopeFactory.CreateScope())
        {
            var store = scope.ServiceProvider.GetRequiredService<IReceivedReplyStore>();
            var reply = await store.AddAsync(
                dedupeKey,
                data,
                message.Subject,
                message.From.ToString(),
                warnings,
                text,
                anhangPfade,
                cancellationToken);
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
