using System.Net;
using System.Text.RegularExpressions;
using MimeKit;

namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

/// <summary>
/// Gewinnt aus der Eingabe (eingefügter Text, .txt-Inhalt oder Base64-kodierte
/// .eml-Datei) den reinen Mailtext für den <see cref="ZentralrufReplyParser"/>.
/// .eml-Dateien sind MIME-kodiert (Quoted-Printable, Base64, HTML-Multipart)
/// und müssen erst dekodiert werden — der Regex-Parser sähe sonst z. B.
/// "=C3=BC" statt "ü" und fände nichts.
/// </summary>
public static partial class ZentralrufReplyEmailExtractor
{
    /// <param name="emailText">Eingefügter Rohtext oder Inhalt einer .txt-Datei.</param>
    /// <param name="emailFileBase64">Komplette .eml-Datei, Base64-kodiert.</param>
    /// <exception cref="FormatException">Base64 oder MIME-Struktur ungültig.</exception>
    public static string ExtractText(string? emailText, string? emailFileBase64)
    {
        if (!string.IsNullOrWhiteSpace(emailFileBase64))
        {
            var bytes = Convert.FromBase64String(emailFileBase64);
            return ExtractFromMime(bytes);
        }

        if (string.IsNullOrWhiteSpace(emailText))
        {
            return string.Empty;
        }

        // Auch eingefügter Text kann eine rohe MIME-Quelle sein (z. B.
        // "Original anzeigen" in Gmail kopiert). Erkennbar am Headerblock.
        if (LooksLikeMimeSource(emailText))
        {
            try
            {
                return ExtractFromMime(System.Text.Encoding.UTF8.GetBytes(emailText));
            }
            catch (FormatException)
            {
                // Fehlerkennung: dann eben als Klartext weiterreichen.
            }
        }

        return emailText;
    }

    private static string ExtractFromMime(byte[] emlBytes)
    {
        MimeMessage message;
        try
        {
            using var stream = new MemoryStream(emlBytes);
            message = MimeMessage.Load(stream);
        }
        catch (Exception exception) when (exception is not OutOfMemoryException)
        {
            throw new FormatException("E-Mail-Datei konnte nicht als MIME gelesen werden.", exception);
        }

        return ExtractFromMessage(message);
    }

    /// <summary>
    /// Wie <see cref="ExtractText"/>, aber für eine bereits geladene
    /// <see cref="MimeMessage"/> — etwa eine vom Postfach-Monitor über IMAP
    /// abgeholte Nachricht. Liefert den dekodierten Textkörper, dem der
    /// Betreff vorangestellt ist (Rückfallebene für den Parser).
    /// </summary>
    /// <exception cref="FormatException">Die Nachricht enthält keinen lesbaren Textteil.</exception>
    public static string ExtractFromMessage(MimeMessage message)
    {
        ArgumentNullException.ThrowIfNull(message);

        var body = message.TextBody;
        if (string.IsNullOrWhiteSpace(body) && message.HtmlBody is { } html)
        {
            body = HtmlToPlainText(html);
        }

        if (string.IsNullOrWhiteSpace(body))
        {
            throw new FormatException("Die E-Mail enthält keinen lesbaren Textteil.");
        }

        // Betreff mitgeben: er enthält Referenz und Anfragedatum und dient dem
        // Parser als Rückfallebene, falls der Body unvollständig ist.
        return string.IsNullOrWhiteSpace(message.Subject)
            ? body
            : $"{message.Subject}\n\n{body}";
    }

    /// <summary>
    /// Heuristik: eine rohe MIME-Quelle beginnt mit einem Headerblock, der
    /// typische Mail-Header enthält, bevor die erste Leerzeile kommt.
    /// </summary>
    private static bool LooksLikeMimeSource(string text)
    {
        var headerBlock = text.Split("\n\n", 2)[0].Replace("\r", string.Empty);
        return MimeHeaderRegex().IsMatch(headerBlock);
    }

    [GeneratedRegex(@"^(MIME-Version|Content-Type|Received|Return-Path)\s*:",
        RegexOptions.Multiline | RegexOptions.IgnoreCase)]
    private static partial Regex MimeHeaderRegex();

    /// <summary>
    /// Sehr einfache HTML-zu-Text-Umwandlung: Blockelemente werden zu
    /// Zeilenumbrüchen, Tags entfernt, Entities dekodiert. Reicht für die
    /// maschinell erzeugten, schlicht formatierten Zentralruf-Mails.
    /// </summary>
    internal static string HtmlToPlainText(string html)
    {
        var text = Regex.Replace(html, @"<(script|style)\b[^>]*>.*?</\1>", string.Empty,
            RegexOptions.Singleline | RegexOptions.IgnoreCase);
        text = Regex.Replace(text, @"<br\s*/?>", "\n", RegexOptions.IgnoreCase);
        text = Regex.Replace(text, @"</(p|div|tr|li|h[1-6]|table)\s*>", "\n", RegexOptions.IgnoreCase);
        text = Regex.Replace(text, @"</td\s*>", " ", RegexOptions.IgnoreCase);
        text = Regex.Replace(text, "<[^>]+>", string.Empty);
        text = WebUtility.HtmlDecode(text);

        // Zeilenweise trimmen und Mehrfach-Leerzeilen eindampfen, damit die
        // Blockerkennung des Parsers (Leerzeile = Blockende) funktioniert.
        var lines = text.Replace("\r\n", "\n").Split('\n').Select(line => line.Trim());
        text = string.Join('\n', lines);
        return Regex.Replace(text, @"\n{3,}", "\n\n").Trim();
    }
}
