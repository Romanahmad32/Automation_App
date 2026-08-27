using System.Text;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Macht aus den Bytes einer Signaturdatei Text (§4.7).
///
/// Die Kodierung steht nicht fest: Neuere Outlook-Fassungen schreiben UTF-8
/// (meist mit BOM), ältere in der ANSI-Codepage. Blind als UTF-8 zu lesen
/// machte aus jedem Umlaut ein Fragezeichen — bei einer Kanzleisignatur der
/// sichtbarste denkbare Fehler.
/// </summary>
internal static class TextKodierung
{
    public static string AlsText(byte[] bytes)
    {
        if (bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF)
        {
            return Encoding.UTF8.GetString(bytes, 3, bytes.Length - 3);
        }

        if (bytes.Length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE)
        {
            return Encoding.Unicode.GetString(bytes, 2, bytes.Length - 2);
        }

        try
        {
            return new UTF8Encoding(false, throwOnInvalidBytes: true).GetString(bytes);
        }
        catch (DecoderFallbackException)
        {
            // Latin-1 deckt die deutschen Umlaute deckungsgleich mit
            // Windows-1252 ab und ist eingebaut — der CodePages-Provider wäre
            // eine Abhängigkeit für eine Handvoll Zeichen.
            return Encoding.Latin1.GetString(bytes);
        }
    }
}
