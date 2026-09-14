using MailKit;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>Feste Seiten statt SEARCH ALL oder vollständiger Nachrichten. Kein wachsender UID-Cache.</summary>
public static class PosteingangLeser
{
    public const int Seitengroesse = 50;

    public static async Task<PosteingangSeite> LadeAsync(
        IMailFolder folder, string konto, string? cursor, CancellationToken ct)
    {
        var vorUid = cursor is null ? (uint?)null
            : PosteingangKennung.Decode(cursor, konto, folder.UidValidity).Uid;
        // Beim Blättern wird die Position der UID binär gesucht. Neue Nachrichten
        // und zwischen zwei Seiten gelöschte Mails verschieben so keine Seite.
        var ende = vorUid is null ? folder.Count : await FindeGrenzeAsync(
            folder.Count, vorUid.Value, async index =>
            {
                var result = await folder.FetchAsync(index, index, MessageSummaryItems.UniqueId, ct);
                return result.FirstOrDefault(item => item.Index == index)?.UniqueId.Id
                    ?? throw new PosteingangException("Der Posteingang wurde verändert. Bitte erneut laden.");
            });
        if (ende == 0)
        {
            return new PosteingangSeite([], null, folder.Count);
        }
        var start = Math.Max(0, ende - Seitengroesse);
        // BodyStructure gehört dazu, Body und PreviewText nicht: Die Struktur
        // sagt, ob und wie viele Anhänge dranhängen (die Büroklammer in der
        // Liste), lädt aber keinen Inhalt. Mailtext bleibt dem Öffnen einer
        // einzelnen Nachricht vorbehalten.
        var summaries = await folder.FetchAsync(start, ende - 1,
            MessageSummaryItems.UniqueId | MessageSummaryItems.Envelope | MessageSummaryItems.Flags
            | MessageSummaryItems.Size | MessageSummaryItems.InternalDate
            | MessageSummaryItems.BodyStructure, ct);
        var mails = summaries.Where(item => item.Index >= start && item.Index < ende
                && item.Envelope is not null && (vorUid is null || item.UniqueId.Id < vorUid))
            .OrderByDescending(item => item.UniqueId.Id).Take(Seitengroesse)
            .Select(item => Abbilden(item, konto, folder.UidValidity)).ToList();
        return new PosteingangSeite(mails, start > 0 && mails.Count > 0 ? mails[^1].Id : null, folder.Count);
    }

    /// <summary>Eine Kopfzeile aus dem, was der eine Abruf mitgebracht hat — ohne Nachladen.</summary>
    private static PosteingangEintrag Abbilden(IMessageSummary item, string konto, uint gueltigkeit)
    {
        var umschlag = item.Envelope!;
        var anhaenge = item.Attachments.Count();
        return new PosteingangEintrag(
            new PosteingangKennung(konto, gueltigkeit, item.UniqueId.Id).Encode(),
            umschlag.Subject ?? "(Ohne Betreff)",
            umschlag.From.ToString(),
            PosteingangKopf.Name(umschlag.From),
            PosteingangKopf.Adresse(umschlag.From),
            PosteingangKopf.Adressen(umschlag.To),
            PosteingangKopf.Adressen(umschlag.Cc),
            PosteingangKopf.MailSchluessel(umschlag.MessageId, gueltigkeit, item.UniqueId.Id),
            item.InternalDate ?? umschlag.Date,
            item.Flags?.HasFlag(MessageFlags.Seen) ?? false,
            item.Size ?? 0,
            anhaenge > 0,
            anhaenge);
    }

    /// <summary>Erster Index mit UID >= Grenze; höchstens log2(N) einzelne UID-Abfragen.</summary>
    public static async Task<int> FindeGrenzeAsync(int count, uint vorUid, Func<int, Task<uint>> uidAmIndex)
    {
        var links = 0;
        var rechts = count;
        while (links < rechts)
        {
            var mitte = links + ((rechts - links) / 2);
            if (await uidAmIndex(mitte) < vorUid)
            {
                links = mitte + 1;
            }
            else
            {
                rechts = mitte;
            }
        }
        return links;
    }
}
