namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Der Ausgangsbestand der Mail-Textvorlagen (§4.7): das Anschreiben, das die
/// Kanzlei bisher als Outlook-Vorlage von Hand wiederverwendet hat. Es wird
/// <b>übernommen, nicht nachgebaut</b> — Wortlaut, Reihenfolge und
/// Höflichkeitsformeln stammen aus der echten Mail
/// (<c>Beispiele/E-Mail Vorlage Text für Mandanten.eml</c>, 25.08.2026).
///
/// Drei Stellen weichen bewusst vom Original ab:
///
/// <list type="bullet">
/// <item>Die Anredezeile lautete dort „Sehr geehrter Herr/Frau," — der
/// Handplatzhalter der Kanzlei. Hier steht der Platzhalter Anrede, damit die
/// App sie aus dem Mandanten bildet.</item>
/// <item>Der persönliche Zusatzgruß stand als feste Zeile darunter (im
/// Beispiel gleich zwei zur Ansicht; wirklich ist es höchstens einer). Hier
/// steht der Platzhalter Grussformel: Sie kommt vom Mandanten (§5.1), und ohne
/// hinterlegte Formel entfällt die Zeile ganz.</item>
/// <item>Unter „Mit freundlichen Grüßen" folgte im Original der komplette
/// Signaturblock der Kanzlei. Der fehlt hier: Die Signatur steht in den
/// Einstellungen und wird beim Versand angehängt (§4.7) — beides zusammen
/// ergäbe sie doppelt.</item>
/// </list>
///
/// Auch der Satz über das Vollmachtsformular fehlt: Die App hängt heute das
/// Anspruchsschreiben an, ein Vollmachtsformular kennt sie nicht. Ein Text,
/// der eine Anlage ankündigt, die nicht mitgeht, wäre schlechter als keiner.
/// </summary>
public static class MailVorlagenVorgabe
{
    /// <summary>
    /// Feste Id des Seeds. Sie steht hier, damit die Migration und ein
    /// späterer Test dieselbe Zeile meinen.
    /// </summary>
    public const int MandantenanschreibenId = 1;

    public const string MandantenanschreibenName = "Anschreiben an den Mandanten";

    public const string MandantenanschreibenBetreff =
        "Ihre Verkehrsunfallsache {{MandantName}} ./. {{VersichererName}} · "
        + "Unser Zeichen: {{Referenz}}";

    /// <summary>
    /// Der Vorlagentext, dessen Zeilen mit LF enden — <b>unabhängig davon, wie
    /// diese Datei ausgecheckt ist</b>.
    ///
    /// Das ist keine Kosmetik: Der Text geht als Seed über <c>HasData</c> ins
    /// Modell. Stünde dort das rohe Literal, trüge es auf Windows CRLF und auf
    /// Linux LF — und EF meldete auf der einen Seite „Changes have been made
    /// to the model since the last migration", während die andere grün ist.
    /// Genau das ist beim Anlegen dieser Vorlage passiert.
    /// </summary>
    public static readonly string Mandantenanschreiben =
        Roh.ReplaceLineEndings("\n");

    const string Roh =
        """
        {{Anrede}},
        {{Grussformel}},

        ich bedanke mich höflichst für das mir entgegengebrachte Vertrauen und die Übertragung des Mandats in vorbezeichneter Angelegenheit.

        In der Anlage überlasse ich Ihnen zur Kenntnisnahme meinen Schriftsatz an die gegnerische Haftpflichtversicherung, welche ich unter Fristsetzung aufgefordert habe, ihre Haftung dem Grunde nach anzuerkennen und Schadensersatz nach Gutachten zu leisten. Die Einzelheiten möchten Sie bitte meinem Schriftsatz entnehmen.

        Nunmehr bleibt die Stellungnahme der gegnerischen Haftpflichtversicherung abzuwarten. Sobald mir das Gutachten vorliegt, werde ich den Schadensersatzanspruch beziffern.

        Für Rückfragen stehe ich Ihnen gerne zur Verfügung. Sobald mir neue Informationen vorliegen, werde ich selbstverständlich wieder berichten.

        Mit freundlichen Grüßen
        """;
}
