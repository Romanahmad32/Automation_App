using MailKit;
using MimeKit;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

public static class PosteingangText
{
    // Selbst eine ungewöhnlich große einzelne Mail darf die Oberfläche nicht blockieren.
    public const int MaxTextBytes = 256 * 1024;

    public static async Task<PosteingangInhalt> LadeAsync(IMailFolder folder, UniqueId uid, CancellationToken ct)
    {
        var summaries = await folder.FetchAsync([uid], MessageSummaryItems.UniqueId | MessageSummaryItems.BodyStructure, ct);
        var summary = summaries.FirstOrDefault(item => item.UniqueId == uid)
            ?? throw new PosteingangException("Diese Nachricht ist nicht mehr im Posteingang.", 404);
        var part = summary.TextBody ?? summary.HtmlBody;
        var anhaenge = summary.Attachments.Select(item => item.FileName ?? "Anhang").ToList();
        if (part is null)
        {
            return new PosteingangInhalt("Diese Nachricht enthält keinen darstellbaren Mailtext.", false, anhaenge);
        }
        // Nur den Textteil laden, niemals die Anhänge. Übergroße Texte werden
        // ausdrücklich angezeigt statt sie unbemerkt als vollständig auszugeben.
        if (part.Octets > MaxTextBytes)
        {
            return new PosteingangInhalt(
                "Der Mailtext ist für die Vorschau zu groß. Bitte diese Nachricht im Webmailer öffnen.", true, anhaenge);
        }
        var entity = await folder.GetBodyPartAsync(uid, part, ct);
        using (entity)
        {
            var text = entity is TextPart textPart ? textPart.Text : string.Empty;
            if (part.IsHtml)
            {
                // Keine aktiven Inhalte und kein Nachladen externer Bilder.
                text = ZentralrufReplyEmailExtractor.HtmlToPlainText(text);
            }
            var gekuerzt = text.Length > MaxTextBytes;
            return new PosteingangInhalt(gekuerzt ? text[..MaxTextBytes] : text, gekuerzt, anhaenge);
        }
    }
}
