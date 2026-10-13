using AutomationService.Features.EmailVersand.Domain.Services;
using MimeKit;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Kopie in „Gesendet" im E2E-Testmodus (#168): kein IMAP, nur eine Zeile im
/// <see cref="TestmodusProtokoll"/>. Eine eigene Datei bräuchte es nicht — der
/// Inhalt steht schon in der Versand-<c>.eml</c>
/// (<see cref="TestmodusSmtpUebergabe"/>).
///
/// Meldet Erfolg, damit die Oberfläche denselben Weg zeigt wie nach einem
/// gelungenen Versand in der Kanzlei.
/// </summary>
public sealed class TestmodusGesendetAblage(TestmodusProtokoll protokoll) : IGesendetOrdnerAblage
{
    public Task<bool> LegeAbAsync(MimeMessage nachricht, SmtpZugang zugang, CancellationToken cancellationToken)
    {
        protokoll.Schreibe(TestmodusProtokoll.GesendetAblage, referenz: null, datei: null);
        return Task.FromResult(true);
    }
}
