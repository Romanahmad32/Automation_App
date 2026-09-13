using System.Text.RegularExpressions;
using MailKit;
using MimeKit;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Holt <b>einen</b> Anhang einer Posteingangsnachricht ins Zwischenlager und
/// gibt seinen Pfad zurück (§4.3).
///
/// Einzeln und auf Anforderung, nicht im Vorrat: Die Liste zeigt nur, dass
/// etwas dranhängt (aus der Struktur, ohne Abruf). Erst wenn der Anwalt auf
/// den Anhang tippt, geht Inhalt über die Leitung — und zwar genau dieser eine.
/// </summary>
public static partial class PosteingangAnhaenge
{
    /// <summary>
    /// Mehr als das holt sich niemand über eine Vorschau; dafür ist der
    /// Webmailer da. Die Grenze schützt zugleich die eine Verbindung, die der
    /// <see cref="PosteingangDienst"/> zulässt: Ein 200-MB-Anhang würde das
    /// Blättern für die Dauer des Abrufs stillstellen.
    /// </summary>
    public const long MaxAnhangBytes = 30L * 1024 * 1024;

    public static async Task<PosteingangAnhangAblage> LadeAsync(
        IMailFolder folder, string konto, UniqueId uid, string anhangId, CancellationToken ct)
    {
        // Der Teilbezeichner kommt aus der Adresszeile und landet in keiner
        // Datei — geprüft wird er trotzdem streng: Was nicht wie "2.1" aussieht,
        // ist kein Teilbezeichner, sondern ein Versuch.
        if (!Teilbezeichner().IsMatch(anhangId))
        {
            throw new PosteingangException("Unbrauchbare Anhangskennung. Bitte die Nachricht erneut öffnen.", 400);
        }

        var summaries = await folder.FetchAsync(
            [uid], MessageSummaryItems.UniqueId | MessageSummaryItems.BodyStructure, ct);
        var summary = summaries.FirstOrDefault(item => item.UniqueId == uid)
            ?? throw new PosteingangException("Diese Nachricht ist nicht mehr im Posteingang.", 404);
        var teil = summary.Attachments.FirstOrDefault(anhang => anhang.PartSpecifier == anhangId)
            ?? throw new PosteingangException("Dieser Anhang gehört nicht zu der Nachricht.", 400);

        if (teil.Octets > MaxAnhangBytes)
        {
            throw new PosteingangException(
                $"Der Anhang ist größer als {MaxAnhangBytes / 1024 / 1024} MB. "
                + "Bitte diese Nachricht im Webmailer öffnen.", 413);
        }

        var ordner = PosteingangZwischenlager.Ordner(konto, uid.Id);
        var name = PosteingangZwischenlager.SichererName(PosteingangKopf.Dateiname(teil));
        if (PosteingangZwischenlager.Vorhanden(ordner, name, teil.Octets) is { } schonDa)
        {
            return new PosteingangAnhangAblage(name, schonDa, teil.Octets);
        }
        if (PosteingangZwischenlager.BelegteBytes(ordner) + teil.Octets > PosteingangZwischenlager.MaxOrdnerBytes)
        {
            throw new PosteingangException(
                $"Aus dieser Nachricht liegen bereits {PosteingangZwischenlager.MaxOrdnerBytes / 1024 / 1024} MB "
                + "im Zwischenlager. Bitte diese Nachricht im Webmailer öffnen.", 413);
        }

        var entity = await folder.GetBodyPartAsync(uid, teil, ct);
        using (entity)
        {
            var pfad = PosteingangZwischenlager.FreierPfad(ordner, name);
            await SchreibeAsync(entity, pfad, ct);
            return new PosteingangAnhangAblage(Path.GetFileName(pfad), pfad, new FileInfo(pfad).Length);
        }
    }

    /// <summary>
    /// Ein gewöhnlicher Anhang wird dekodiert abgelegt (Base64 gehört nicht in
    /// eine PDF-Datei); eine angehängte Nachricht oder ein mehrteiliger Anhang
    /// wird als Ganzes geschrieben — er hat keinen einzelnen Inhalt.
    /// </summary>
    private static async Task SchreibeAsync(MimeEntity entity, string pfad, CancellationToken ct)
    {
        await using var strom = File.Create(pfad);
        if (entity is MimePart part && part.Content is not null)
        {
            await part.Content.DecodeToAsync(strom, ct);
            return;
        }

        await entity.WriteToAsync(strom, ct);
    }

    [GeneratedRegex(@"^[0-9]+(\.[0-9]+){0,6}$")]
    private static partial Regex Teilbezeichner();
}
