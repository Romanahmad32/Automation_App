using MimeKit;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Der Ausweichweg des Entwurfs, wenn Outlook nicht da ist (§4.7): die
/// Nachricht als <c>.eml</c> schreiben und öffnen. Echt in
/// <see cref="EntwurfDatei"/>.
///
/// Naht aus demselben Grund wie <see cref="IOutlookVerbindung"/> (#168): Das
/// Öffnen startet das Mailprogramm des Rechners. Im Testmodus wird die Datei
/// nur geschrieben, und <see cref="EntwurfOeffner"/> protokolliert wie immer.
/// </summary>
public interface IEntwurfDatei
{
    /// <summary>
    /// True, wenn die Datei geschrieben und geöffnet ist; false, wenn nicht —
    /// dann bricht der Entwurf mit einer Meldung ab.
    /// </summary>
    bool Oeffne(MimeMessage nachricht);
}
