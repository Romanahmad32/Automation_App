using System.Net;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Macht den getippten Mailtext zu HTML (§4.7) — für den Direktversand
/// (<see cref="MailRumpf"/>) und für den Entwurf in Outlook
/// (<see cref="OutlookNachricht"/>).
///
/// Der Text ist reiner Text und wird auch so behandelt: Alles wird maskiert,
/// nur Zeilenumbrüche werden zu Umbrüchen. Ein Anwalt, der ein &lt; um eine
/// Adresse setzt oder ein &amp; ins Aktenzeichen schreibt, soll es beim
/// Empfänger wiederfinden und nicht die halbe Mail verlieren.
///
/// Eine Stelle statt zweier, weil das Maskieren beidesmal dasselbe leisten
/// muss: Eine Fassung, die einmal nachgezogen wird und einmal nicht, ist die
/// Lücke, durch die der Text ungeprüft hinausgeht.
/// </summary>
internal static class TextAlsHtml
{
    /// <summary>Der blanke Text, wie er im Rumpf einer Nachricht steht.</summary>
    public static string Zeilen(string text) =>
        WebUtility.HtmlEncode(text)
            .Replace("\r\n", "\n", StringComparison.Ordinal)
            .Replace("\n", "<br>", StringComparison.Ordinal);

    /// <summary>
    /// Derselbe Text als eigener Absatz. Outlook führt den Entwurf über
    /// <c>HTMLBody</c>, und dort wird er der bereits eingesetzten Signatur
    /// davorgehängt — ohne umschliessendes <c>div</c> liefe er in sie hinein.
    /// </summary>
    public static string Absatz(string text) => $"<div>{Zeilen(text)}</div>";
}
