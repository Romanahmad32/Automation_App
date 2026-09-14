using MailKit;
using MimeKit;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Liest Absender, Empfänger, Message-Id und Anhangsangaben aus dem, was der
/// Abruf ohnehin schon mitgebracht hat: dem Umschlag (ENVELOPE) und der
/// Struktur (BODYSTRUCTURE).
///
/// <b>Beides kostet keinen zweiten Serverabruf und lädt keinen Mailinhalt.</b>
/// Die BODYSTRUCTURE beschreibt nur, aus welchen Teilen eine Nachricht besteht
/// — wie groß sie sind und wie sie heißen. Genau darauf beruht die Büroklammer
/// in der Liste, ohne dass dafür ein einziges Byte Text oder Anhang über die
/// Leitung geht.
/// </summary>
public static class PosteingangKopf
{
    /// <summary>Der Anzeigename des ersten Absenders; null, wenn nur eine nackte Adresse dasteht.</summary>
    public static string? Name(InternetAddressList? liste)
    {
        var name = Erste(liste)?.Name;
        return string.IsNullOrWhiteSpace(name) ? null : name.Trim();
    }

    /// <summary>Die Mailadresse des ersten Absenders; null, wenn der Umschlag keine trägt.</summary>
    public static string? Adresse(InternetAddressList? liste)
    {
        var adresse = Erste(liste)?.Address;
        return string.IsNullOrWhiteSpace(adresse) ? null : adresse.Trim();
    }

    /// <summary>
    /// Eine Zeile je Empfänger: <c>Name &lt;adresse&gt;</c>, sonst nur die
    /// Adresse. Gruppenadressen werden dabei aufgelöst — der Anwalt will die
    /// Personen sehen, nicht den Verteilernamen.
    /// </summary>
    public static IReadOnlyList<string> Adressen(InternetAddressList? liste) =>
    [
        .. (liste?.Mailboxes ?? []).Select(mailbox => string.IsNullOrWhiteSpace(mailbox.Name)
            ? mailbox.Address
            : $"{mailbox.Name.Trim()} <{mailbox.Address}>"),
    ];

    /// <summary>
    /// Der Schlüssel, unter dem der Monitor <b>dieselbe</b> Nachricht als
    /// Dedupe-Schlüssel ablegt und als <c>MailSchluessel</c> einer erfassten
    /// Zentralruf-Antwort ausliefert: ihre Message-Id ohne spitze Klammern,
    /// hilfsweise <c>uidValidity:uid</c>, wenn der Header fehlt.
    ///
    /// Scanner (<see cref="MailboxNachrichtenScanner"/>) und Posteingang
    /// (<see cref="PosteingangLeser"/>, <see cref="PosteingangText"/>) rufen
    /// <b>diese eine</b> Methode — sonst bildet die eine Seite den Rückfall
    /// und die andere liefert <c>null</c>, und die Oberfläche erkennt eine
    /// bereits erfasste Antwort ohne Message-Id nicht mehr als solche wieder.
    /// </summary>
    public static string MailSchluessel(string? messageId, uint uidValidity, uint uid)
    {
        var wert = messageId?.Trim().TrimStart('<').TrimEnd('>').Trim();
        return string.IsNullOrWhiteSpace(wert) ? $"{uidValidity}:{uid}" : wert;
    }

    /// <summary>
    /// Die Anhänge der Nachricht aus der Struktur — Name, Größe, Medientyp und
    /// der Teilbezeichner, über den sie sich einzeln holen lassen.
    /// </summary>
    public static IReadOnlyList<PosteingangAnhang> Anhaenge(IMessageSummary summary) =>
    [
        .. summary.Attachments.Select(teil => new PosteingangAnhang(
            teil.PartSpecifier ?? string.Empty,
            Dateiname(teil),
            teil.Octets,
            teil.ContentType?.MimeType ?? "application/octet-stream")),
    ];

    /// <summary>
    /// Ein Anhang muss keinen Namen tragen. „Anhang" ist dann besser als eine
    /// leere Zeile, hinter der der Anwalt nichts vermutet.
    /// </summary>
    public static string Dateiname(BodyPartBasic teil) =>
        string.IsNullOrWhiteSpace(teil.FileName) ? "Anhang" : teil.FileName.Trim();

    private static MailboxAddress? Erste(InternetAddressList? liste) =>
        liste?.Mailboxes.FirstOrDefault();
}
