using MimeKit;
using MimeKit.Utils;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Baut den Körper der Nachricht: Text, Signatur, Anhänge (§4.7).
///
/// Ohne formatierte Signatur bleibt es beim reinen Text — so ging die Mail
/// bisher hinaus, und für ein Anschreiben mit Anhang genügt das. Liegt eine
/// formatierte Signatur vor, entsteht eine Nachricht mit <b>beiden</b>
/// Fassungen: HTML für die üblichen Mailprogramme, reiner Text als Alternative.
/// Der Empfänger sieht, was sein Programm kann, und niemand bekommt Markup zu
/// lesen.
///
/// Die Bilder gehen als eingebettete Ressourcen mit und werden über eine
/// Content-Id angesprochen (<c>cid:</c>). Ein Verweis auf die Platte des
/// Absenders wäre beim Empfänger ein leeres Kästchen; ein Verweis ins Netz
/// verriete, wann er die Mail öffnet, und viele Programme blockieren ihn.
/// </summary>
internal static class MailRumpf
{
    public static BodyBuilder Baue(
        string text,
        SignaturVersand? signatur,
        IReadOnlyList<GeladenerAnhang> anhaenge)
    {
        var rumpf = new BodyBuilder { TextBody = MitText(text, signatur?.Text ?? string.Empty) };

        if (signatur is not null && signatur.Html.Length > 0)
        {
            rumpf.HtmlBody = MitHtml(text, signatur, rumpf);
        }

        foreach (var anhang in anhaenge)
        {
            rumpf.Attachments.Add(anhang.Dateiname, anhang.Inhalt);
        }

        return rumpf;
    }

    /// <summary>
    /// Eine Leerzeile zwischen Text und Signatur, aber keine zweite: Der
    /// vorbelegte Text endet bereits mit dem Kanzleinamen unter der Grußformel.
    /// </summary>
    private static string MitText(string text, string signatur) =>
        signatur.Length == 0 ? text : $"{text.TrimEnd()}\n\n{signatur}";

    private static string MitHtml(string text, SignaturVersand signatur, BodyBuilder rumpf)
    {
        var html = signatur.Html;
        foreach (var pfad in signatur.BildPfade)
        {
            var bild = rumpf.LinkedResources.Add(pfad);
            bild.ContentId = MimeUtils.GenerateMessageId();
            html = MitQuelle(html, Path.GetFileName(pfad), $"cid:{bild.ContentId}");
        }

        return $"<html><body>{TextAlsHtml.Zeilen(text)}<br><br>{html}</body></html>";
    }

    /// <summary>
    /// Tauscht den Dateinamen in den Bildverweisen gegen die Content-Id.
    /// Verglichen wird ohne Rücksicht auf Groß- und Kleinschreibung: Windows
    /// unterscheidet sie in Dateinamen nicht, Outlooks HTML tut es mitunter
    /// doch — und ein danebengehender Vergleich hieße: Logo weg.
    ///
    /// Getauscht wird an <b>jedem</b> Verweis, nicht nur am ersten: Dasselbe
    /// Bild steht in Outlooks Signatur zweimal — einmal als VML-Form für
    /// Outlook, einmal als <c>&lt;img&gt;</c> für alle übrigen Programme.
    /// </summary>
    private static string MitQuelle(string html, string dateiname, string cid) =>
        BildVerweis.Ersetze(html, verweis =>
            string.Equals(verweis, dateiname, StringComparison.OrdinalIgnoreCase) ? cid : null);
}
