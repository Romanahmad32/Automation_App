namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Der Draht zum installierten Outlook (§4.7), echt in
/// <see cref="OutlookVerbindung"/>.
///
/// Naht, damit der E2E-Testmodus (#168) ihn ersetzen kann: Schon das
/// Vorwärmen startet outlook.exe, und der Anhang-Griff liest die Nachricht, die
/// der Anwalt gerade offen hat. Beides wirkt auf den echten Rechner, nicht auf
/// den Testbestand. Die Naht sitzt bewusst <b>unter</b>
/// <see cref="EntwurfOeffner"/> — der schreibt das Versandprotokoll selbst, und
/// das soll im Test genauso entstehen wie in der Kanzlei.
/// </summary>
public interface IOutlookVerbindung
{
    /// <summary>
    /// Startet Outlook im Hintergrund, damit der erste echte Zugriff den
    /// Kaltstart nicht bezahlt. Kehrt sofort zurück.
    /// </summary>
    void WaermeVor();

    /// <summary>
    /// True, wenn der Entwurf offen auf dem Schirm steht. False heißt nur „hier
    /// nicht" — das Stichwort für den Dateiweg (<see cref="IEntwurfDatei"/>).
    /// </summary>
    bool OeffneEntwurf(EmailNachricht nachricht);

    /// <summary>
    /// Die Anhänge der Nachricht, die in Outlook gerade offen oder ausgewählt
    /// ist; <see cref="OutlookAnhaenge.Unerreichbar"/>, wenn Outlook nicht
    /// antwortet.
    /// </summary>
    OutlookAnhaenge AnhaengeDerAuswahl();
}
