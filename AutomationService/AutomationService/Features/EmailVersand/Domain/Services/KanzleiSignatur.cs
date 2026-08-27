using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Liefert die Signatur der Kanzlei für den Versand (§4.7 „Signatur").
///
/// Sie steht in den Einstellungen, nicht im Entwurf: Der Anwalt übernimmt sie
/// einmal aus seinem Mailprogramm und pflegt sie dort — nicht je Mail. Deshalb
/// wird sie erst hier angefügt und nicht schon im Formular, wo sie bei jedem
/// Nachziehen der Anrede mitwandern müsste.
///
/// <b>Nur beim Direktversand.</b> Der Entwurf im Mailprogramm bekommt sie
/// nicht: Dort setzt Outlook seine eigene ein, und beide zusammen stünden
/// doppelt unter der Mail.
/// </summary>
public sealed class KanzleiSignatur(AutomationDbContext db, SignaturAblage ablage)
{
    /// <summary>Was in den Einstellungen liegt: Text, HTML-Fassung, Bilder.</summary>
    public async Task<SignaturBlock> BlockAsync(CancellationToken cancellationToken)
    {
        var settings = await db.KanzleiSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId, cancellationToken);

        if (settings is null)
        {
            return SignaturBlock.Keiner;
        }

        var html = settings.MailSignaturHtml.Trim();

        // Nur die Bilder, auf die das gespeicherte HTML noch verweist. Nach
        // einer Uebernahme sind das alle; bleibt einmal eine Datei liegen, soll
        // sie nicht als angebliches Signaturbild in der Oberflaeche auftauchen.
        IReadOnlyList<SignaturBild> bilder = [];
        if (html.Length > 0)
        {
            var abgelegt = ablage.Bilder();
            var verwendet = SignaturHtmlFilter
                .Verwendete(html, abgelegt)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
            bilder = [.. abgelegt.Where(bild => verwendet.Contains(bild.Dateiname))];
        }

        return new SignaturBlock(settings.MailSignatur.Trim(), html, bilder);
    }

    /// <summary>Der Signaturtext allein — für Bereitschaft und Vorschau.</summary>
    public async Task<string> TextAsync(CancellationToken cancellationToken) =>
        (await BlockAsync(cancellationToken)).Text;

    /// <summary>
    /// Die Signatur, fertig für eine bestimmte Nachricht. Was in
    /// <paramref name="ohneBilder"/> steht, hat der Anwalt für diese eine Mail
    /// weggelassen — üblicherweise das schwere Werbebild.
    /// </summary>
    /// <returns>Null, wenn gar keine Signatur hinterlegt ist.</returns>
    public async Task<SignaturVersand?> FuerVersandAsync(
        IReadOnlyList<string> ohneBilder,
        CancellationToken cancellationToken)
    {
        var block = await BlockAsync(cancellationToken);
        if (block.Leer)
        {
            return null;
        }

        if (block.Html.Length == 0)
        {
            return new SignaturVersand(block.Text, string.Empty, []);
        }

        var weggelassen = ohneBilder.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var html = SignaturHtmlFilter.Ohne(block.Html, weggelassen);

        var pfade = new List<string>();
        foreach (var name in SignaturHtmlFilter.Verwendete(html, block.Bilder))
        {
            var pfad = ablage.PfadVon(name);
            if (pfad is not null)
            {
                pfade.Add(pfad);
            }
        }

        return new SignaturVersand(block.Text, html, pfade);
    }
}
