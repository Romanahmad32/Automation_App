using AutomationService.Features.EmailVersand.Domain.Services;
using MimeKit;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Entwurfsdatei im E2E-Testmodus (#168): Die <c>.eml</c> entsteht unter
/// <c>Testmodus\Entwuerfe\</c> und wird <b>nicht</b> geöffnet — das echte
/// <c>EntwurfDatei</c> übergäbe sie dem Mailprogramm des Rechners.
///
/// Meldet trotzdem „geöffnet": <c>EntwurfOeffner</c> schreibt daraufhin wie in
/// der Kanzlei den Eintrag im Versandprotokoll (Weg Entwurfsdatei), und genau
/// den soll ein Testlauf sehen.
/// </summary>
public sealed class TestmodusEntwurfDatei(
    TestmodusOrdner ordner,
    TestmodusProtokoll protokoll,
    ILogger<TestmodusEntwurfDatei> logger) : IEntwurfDatei
{
    public bool Oeffne(MimeMessage nachricht)
    {
        ArgumentNullException.ThrowIfNull(nachricht);

        try
        {
            var pfad = ordner.NeueDatei(TestmodusOrdner.Entwuerfe, ".eml");
            nachricht.WriteTo(pfad);
            protokoll.Schreibe(TestmodusProtokoll.Entwurf, referenz: null, ordner.Relativ(pfad));
            return true;
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            // Dieselbe Antwort wie der echte Weg: false, und der Entwurf bricht
            // mit einer Meldung ab, statt still eine Datei zu versprechen.
            logger.LogWarning(ausnahme, "Die Entwurfsdatei des Testmodus ließ sich nicht schreiben.");
            return false;
        }
    }
}
