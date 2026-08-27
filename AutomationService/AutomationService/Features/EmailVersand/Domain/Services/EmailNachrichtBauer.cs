using System.Text.RegularExpressions;
using MimeKit;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Baut aus der fachlichen <see cref="EmailNachricht"/> die MIME-Nachricht.
/// Getrennt vom Versand, weil hier alles passiert, was <b>vor</b> dem
/// Verbindungsaufbau scheitern soll: Adressen prüfen, Anhänge einhängen.
/// </summary>
public static partial class EmailNachrichtBauer
{
    /// <param name="nachricht">Die fachliche Nachricht: Empfänger, Betreff, Text, Anhangpfade.</param>
    /// <param name="absenderAdresse">
    /// Adresse des Postfachs. Leer beim Entwurf für das Mailprogramm: Von welchem
    /// Konto der Anwalt dort sendet, entscheidet er selbst — die App setzt keinen
    /// Absender, den Outlook gleich wieder überschreibt.
    /// </param>
    /// <param name="anhaenge">Die bereits eingelesenen Anhänge.</param>
    /// <param name="signatur">
    /// Die Signatur für genau diese Mail, oder null. Ist eine formatierte
    /// Fassung dabei, entsteht eine Nachricht mit HTML- und Textteil
    /// (<see cref="MailRumpf"/>).
    /// </param>
    public static MimeMessage Baue(
        EmailNachricht nachricht,
        string absenderAdresse,
        IReadOnlyList<GeladenerAnhang> anhaenge,
        SignaturVersand? signatur = null)
    {
        var nachrichtObjekt = new MimeMessage();
        if (!string.IsNullOrWhiteSpace(absenderAdresse))
        {
            nachrichtObjekt.From.Add(
                new MailboxAddress(nachricht.AbsenderName.Trim(), absenderAdresse.Trim()));
        }
        nachrichtObjekt.To.AddRange(Adressen(nachricht.An, "Empfänger"));
        nachrichtObjekt.Cc.AddRange(Adressen(nachricht.Kopie, "Kopie-Empfänger"));

        if (nachrichtObjekt.To.Count == 0)
        {
            throw new EmailVersandException(
                EmailVersandFehler.Adresse,
                "Die Mail hat keinen Empfänger.");
        }

        nachrichtObjekt.Subject = nachricht.Betreff.Trim();

        nachrichtObjekt.Body = MailRumpf.Baue(nachricht.Text, signatur, anhaenge).ToMessageBody();
        return nachrichtObjekt;
    }

    /// <summary>
    /// Wandelt die eingetippten Adressen um. Eine unbrauchbare Adresse bricht
    /// den Versand ab und wird namentlich genannt — MailKit würde sonst später
    /// eine englische Serverantwort liefern, in der sie nicht mehr vorkommt.
    /// </summary>
    private static IEnumerable<MailboxAddress> Adressen(IReadOnlyList<string> eingaben, string rolle)
    {
        foreach (var eingabe in eingaben)
        {
            var text = eingabe.Trim();
            if (text.Length == 0)
            {
                continue;
            }

            if (!MailboxAddress.TryParse(text, out var adresse) || !AdressMuster().IsMatch(adresse.Address))
            {
                throw new EmailVersandException(
                    EmailVersandFehler.Adresse,
                    $"\"{text}\" ist keine gültige E-Mail-Adresse ({rolle}).");
            }

            yield return adresse;
        }
    }

    /// <summary>
    /// Grobe Form einer Adresse: etwas, ein @, ein Server mit Punkt. MimeKit
    /// allein genügt hier nicht — sein Parser nimmt auch einen blanken
    /// Bezeichner ohne Domäne an, und der ginge ungeprüft an den Server.
    /// </summary>
    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$")]
    private static partial Regex AdressMuster();
}
