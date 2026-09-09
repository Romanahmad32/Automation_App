using Microsoft.AspNetCore.SignalR;

namespace AutomationService.Features.Vorgaenge.Presentation.Hubs;

/// <summary>
/// Push-Kanal des Registers (§6.2). Der Hub hat keine aufrufbaren Methoden — er
/// ist nur der Verbindungspunkt, über den
/// <see cref="HostedServices.RegisterPdfNachzug"/> melden kann, dass die
/// PDF-Fassung fertig ist (<c>registerPdfFertig</c>).
///
/// <para>
/// <b>Eigener Hub und nicht der MailboxHub.</b> Der gehört einem anderen
/// senkrechten Schnitt; ihn mitzubenutzen hieße, das Register an den
/// HTTP-Vertrag der Postfachüberwachung zu binden — <c>SliceIsolationTests</c>
/// schlägt darauf zu Recht an. Der Preis ist eine zweite Verbindung im
/// Frontend, der Gewinn: Ein Umbau am Postfach kann die Registerseite nicht
/// mehr stumm schalten.
/// </para>
///
/// <para>
/// <b>Warum überhaupt ein Push.</b> Seit die Wandlung nachgezogen wird
/// (§6.2 „Word sofort, PDF nachgezogen"), ist die Antwort auf
/// <c>POST api/Vorgaenge/register/export</c> da, bevor das PDF existiert. Ohne
/// diese Meldung bliebe der Oberfläche nur, im Takt nachzufragen — zwanzig
/// Sekunden lang, und danach für alle Fälle weiter.
/// </para>
/// </summary>
public sealed class RegisterHub : Hub
{
    /// <summary>
    /// Die PDF-Fassung ist fertig — oder es steht fest, dass keine entsteht.
    /// Nutzdaten: <see cref="PdfMeldung"/>.
    /// </summary>
    public const string PdfFertigEvent = "registerPdfFertig";

    /// <summary>
    /// Was gemeldet wird. Absichtlich schlicht: der Zustand nach dem Lauf, in
    /// derselben Sprache wie das Stand-DTO daneben
    /// (<c>RegisterSpiegelDto.PdfPfad</c>/<c>PdfFehler</c>), damit die
    /// Oberfläche die Meldung ohne zweite Übersetzung auf denselben Zustand
    /// abbilden kann. Den vollen Stand holt sie wie beim Postfach per REST nach
    /// (<c>GET api/Vorgaenge/register/stand</c>) — der bleibt die einzige
    /// Quelle.
    /// </summary>
    /// <param name="Fertig">Ob jetzt eine PDF-Fassung neben der .docx liegt.</param>
    /// <param name="PdfPfad">Ihr Pfad; null, wenn keine entstand.</param>
    /// <param name="Fehler">
    /// Warum keine entstand — auf einem Rechner ohne Word der erwartbare Fall
    /// und kein Fehlschlag des Spiegels. Null, wenn eine entstand.
    /// </param>
    public sealed record PdfMeldung(bool Fertig, string? PdfPfad, string? Fehler);
}
