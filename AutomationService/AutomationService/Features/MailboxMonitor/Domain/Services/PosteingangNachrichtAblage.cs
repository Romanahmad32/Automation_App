using System.Globalization;
using MailKit;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Schreibt eine Posteingangsnachricht als <c>.eml</c> ins Zwischenlager.
///
/// Das ist der Weg, eine Mail in die Akte zu legen: Eine <c>.eml</c>-Datei
/// enthält Kopfzeilen, Text und Anhänge unverändert, öffnet sich in jedem
/// Mailprogramm und ist damit das, was ein Anwalt als Beleg braucht — anders
/// als ein Bildschirmfoto der Vorschau.
/// </summary>
public static class PosteingangNachrichtAblage
{
    /// <summary>
    /// Dieselbe Zahl wie für den Nachrichtenordner insgesamt: Eine Mail, die
    /// darüber liegt, gehört ins Mailprogramm und nicht durch diese Leitung.
    /// </summary>
    public const long MaxEmlBytes = 50L * 1024 * 1024;

    /// <summary>Ein Dateiname bleibt handhabbar — ohne Endung höchstens so lang.</summary>
    public const int MaxNameZeichen = 80;

    public static async Task<PosteingangAnhangAblage> LadeAsync(
        IMailFolder folder, string konto, UniqueId uid, CancellationToken ct)
    {
        var summaries = await folder.FetchAsync([uid], MessageSummaryItems.UniqueId
            | MessageSummaryItems.Envelope | MessageSummaryItems.Size
            | MessageSummaryItems.InternalDate, ct);
        var summary = summaries.FirstOrDefault(item => item.UniqueId == uid)
            ?? throw new PosteingangException("Diese Nachricht ist nicht mehr im Posteingang.", 404);

        // Vorab aus der Größenangabe geprüft: Eine Nachricht erst zu holen und
        // dann zu verwerfen, wäre genau die Leitungszeit, die die Grenze spart.
        if (summary.Size > MaxEmlBytes)
        {
            throw new PosteingangException(
                $"Die Nachricht ist größer als {MaxEmlBytes / 1024 / 1024} MB. "
                + "Bitte sie im Webmailer speichern.", 413);
        }

        var ordner = PosteingangZwischenlager.Ordner(konto, uid.Id);
        var name = Dateiname(summary);
        var pfad = PosteingangZwischenlager.FreierPfad(ordner, name);
        var nachricht = await folder.GetMessageAsync(uid, ct);
        using (nachricht)
        {
            await using var strom = File.Create(pfad);
            await nachricht.WriteToAsync(strom, ct);
        }

        return new PosteingangAnhangAblage(Path.GetFileName(pfad), pfad, new FileInfo(pfad).Length);
    }

    /// <summary>
    /// <c>2026-09-13 HUK-COBURG Ihre Schadenmeldung.eml</c> — Datum zuerst,
    /// damit der Ordner der Akte sich von selbst chronologisch sortiert.
    /// </summary>
    public static string Dateiname(IMessageSummary summary)
    {
        var umschlag = summary.Envelope;
        var datum = (summary.InternalDate ?? umschlag?.Date ?? DateTimeOffset.Now)
            .ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var absender = PosteingangKopf.Name(umschlag?.From)
            ?? PosteingangKopf.Adresse(umschlag?.From)
            ?? "Unbekannt";
        var betreff = string.IsNullOrWhiteSpace(umschlag?.Subject) ? "Ohne Betreff" : umschlag.Subject.Trim();
        var roh = PosteingangZwischenlager.Entschaerft($"{datum} {absender} {betreff}");
        var gekuerzt = roh.Length > MaxNameZeichen ? roh[..MaxNameZeichen].TrimEnd() : roh;
        return $"{gekuerzt}.eml";
    }
}
