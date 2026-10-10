using MailKit;
using MimeKit;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Holt den Inhalt <b>einer</b> geöffneten Nachricht — Kopfdaten, Nur-Text und
/// die entschärfte HTML-Fassung. Anhänge werden dabei nie geladen, nur
/// beschrieben.
/// </summary>
public static class PosteingangText
{
    // Selbst eine ungewöhnlich große einzelne Mail darf die Oberfläche nicht blockieren.
    public const int MaxTextBytes = 256 * 1024;

    private const string ZuGross =
        "Der Mailtext ist für die Vorschau zu groß. Bitte diese Nachricht im Webmailer öffnen.";

    public static async Task<PosteingangInhalt> LadeAsync(IMailFolder folder, UniqueId uid, CancellationToken ct)
    {
        var summaries = await folder.FetchAsync([uid], MessageSummaryItems.UniqueId
            | MessageSummaryItems.BodyStructure | MessageSummaryItems.Envelope
            | MessageSummaryItems.InternalDate, ct);
        var summary = summaries.FirstOrDefault(item => item.UniqueId == uid)
            ?? throw new PosteingangException("Diese Nachricht ist nicht mehr im Posteingang.", 404);
        var umschlag = summary.Envelope;

        // Höchstens zwei Teile je Öffnen: die Textfassung und die HTML-Fassung.
        // Jede wird einzeln gegen die Grenze gehalten — eine überlange
        // HTML-Fassung soll den lesbaren Text nicht mitreißen.
        var html = await LadeTeilAsync(folder, uid, summary.HtmlBody, ct);
        var (text, gekuerzt) = await TextFassungAsync(folder, uid, summary, html, ct);
        var htmlErgebnis = html.Inhalt is null ? null : PosteingangHtmlFilter.FuerAnzeigeMitErgebnis(html.Inhalt);

        return new PosteingangInhalt(
            text,
            gekuerzt,
            htmlErgebnis?.Html,
            html.Gekuerzt,
            htmlErgebnis?.BilderBlockiert ?? false,
            PosteingangKopf.Name(umschlag?.From),
            PosteingangKopf.Adresse(umschlag?.From),
            PosteingangKopf.Adressen(umschlag?.To),
            PosteingangKopf.Adressen(umschlag?.Cc),
            summary.InternalDate ?? umschlag?.Date,
            PosteingangKopf.MailSchluessel(umschlag?.MessageId, folder.UidValidity, uid.Id),
            PosteingangKopf.Anhaenge(summary));
    }

    /// <summary>
    /// Die Nur-Text-Fassung. Gibt es keinen eigenen Textteil, wird die bereits
    /// geholte HTML-Fassung gewandelt — sie ein zweites Mal abzurufen wäre
    /// verschenkte Leitung.
    /// </summary>
    private static async Task<(string Text, bool Gekuerzt)> TextFassungAsync(
        IMailFolder folder, UniqueId uid, IMessageSummary summary, Teilinhalt html, CancellationToken ct)
    {
        if (summary.TextBody is { } teil)
        {
            var roh = await LadeTeilAsync(folder, uid, teil, ct);
            return (roh.Inhalt ?? ZuGross, roh.Gekuerzt);
        }

        if (html.Inhalt is { } quelle)
        {
            var gewandelt = ZentralrufReplyEmailExtractor.HtmlToPlainText(quelle);
            return (Begrenzt(gewandelt), html.Gekuerzt || gewandelt.Length > MaxTextBytes);
        }

        return summary.HtmlBody is null
            ? ("Diese Nachricht enthält keinen darstellbaren Mailtext.", false)
            : (ZuGross, true);
    }

    /// <summary>
    /// Ein Nachrichtenteil als Zeichenkette — oder nichts, wenn er schon laut
    /// Struktur zu groß ist. Dann wird er ausdrücklich <b>nicht</b> abgerufen:
    /// Die Grenze soll die Leitung schonen und nicht erst hinterher kürzen.
    /// </summary>
    private static async Task<Teilinhalt> LadeTeilAsync(
        IMailFolder folder, UniqueId uid, BodyPart? teil, CancellationToken ct)
    {
        if (teil is null)
        {
            return new Teilinhalt(null, false);
        }
        if (teil is BodyPartBasic basic && basic.Octets > MaxTextBytes)
        {
            return new Teilinhalt(null, true);
        }
        var entity = await folder.GetBodyPartAsync(uid, teil, ct);
        using (entity)
        {
            var roh = entity is TextPart textPart ? textPart.Text : string.Empty;
            return new Teilinhalt(Begrenzt(roh), roh.Length > MaxTextBytes);
        }
    }

    private static string Begrenzt(string wert) => wert.Length > MaxTextBytes ? wert[..MaxTextBytes] : wert;

    /// <summary>Inhalt eines Teils; <c>null</c> heißt „nicht geholt", nicht „leer".</summary>
    private readonly record struct Teilinhalt(string? Inhalt, bool Gekuerzt);
}
