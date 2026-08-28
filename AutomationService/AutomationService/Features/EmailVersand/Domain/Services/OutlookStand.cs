namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Welches Outlook auf diesem Rechner steht (§4.7) — und was das für die
/// Funktionen bedeutet, die es brauchen.
///
/// Drei Stellen der App sprechen mit Outlook: der Entwurf, der Griff nach den
/// Anhängen der offenen Nachricht und die Übernahme der Signatur. Alle drei
/// brauchen das <b>klassische</b> Outlook — das aus Microsoft 365/Office, das
/// sich über COM steuern lässt und seine Signaturen als Dateien ablegt.
///
/// Das <b>neue</b> Outlook (die Store-App „Outlook für Windows") kann das
/// nicht: Es meldet keine COM-Schnittstelle an und legt seine Signaturen im
/// Konto ab, nicht auf der Platte. Alle drei Funktionen tun dann still nichts
/// — eine leere Anhangliste, eine leere Signaturliste, ein Entwurf, der als
/// Datei aufgeht. Jedes für sich sieht aus wie ein Aussetzer. Deshalb wird
/// beim Start einmal nachgesehen und der Grund hingeschrieben.
/// </summary>
/// <param name="Klassisch">
/// Das klassische Outlook ist eingerichtet (die COM-Kennung
/// <c>Outlook.Application</c> ist registriert).
/// </param>
/// <param name="Neu">Die Store-App „Outlook für Windows" liegt auf dem Rechner.</param>
public sealed record OutlookStand(bool Klassisch, bool Neu)
{
    /// <summary>Nichts gefunden — der Stand vor der ersten Prüfung und auf Nicht-Windows.</summary>
    public static readonly OutlookStand Keines = new(false, false);

    /// <summary>Ob die drei Outlook-Funktionen überhaupt etwas liefern können.</summary>
    public bool Steuerbar => Klassisch;

    /// <summary>
    /// Der Grund im Klartext, oder null, wenn alles da ist. Er nennt beide
    /// Hälften: was nicht geht und was stattdessen geschieht — eine Absage
    /// ohne Ausweg ist für den Anwalt so gut wie keine Auskunft.
    /// </summary>
    public string? Hinweis
    {
        get
        {
            if (Klassisch)
            {
                return null;
            }

            var was = Neu
                ? "Auf diesem Rechner läuft das neue Outlook (die Store-App). Es lässt sich "
                  + "von außen nicht steuern"
                : "Auf diesem Rechner ist kein klassisches Outlook eingerichtet";

            return $"{was}: „In Outlook öffnen\" legt deshalb eine .eml-Datei an und öffnet sie, "
                + "„Aus der Outlook-Nachricht\" bleibt leer, und die Signatur lässt sich nicht "
                + "übernehmen — sie ist unter „E-Mail-Signatur\" von Hand einzutragen. Der "
                + "Direktversand über das Postfach ist davon nicht betroffen.";
        }
    }
}
