using AutomationService.Features.EmailVersand.Domain.Services;
using MimeKit;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// SMTP-Einlieferung im E2E-Testmodus (#168): Die fertige Nachricht geht nicht
/// an den Server, sondern als <c>.eml</c> nach <c>Testmodus\Versand\</c> —
/// Empfänger, Betreff, Text, Signatur und Anhänge genau so, wie sie
/// hinausgegangen wären.
///
/// Alles davor und danach läuft echt (<c>SmtpEmailVersender</c>):
/// Zugangsprüfung, Anhangsgrenzen, Signatur, Gesendet-Ablage und der Eintrag
/// im Versandprotokoll der Datenbank. Dafür ist <see cref="ISmtpUebergabe"/>
/// als Naht gebaut.
/// </summary>
public sealed class TestmodusSmtpUebergabe(TestmodusOrdner ordner, TestmodusProtokoll protokoll) : ISmtpUebergabe
{
    public async Task UebergebeAsync(MimeMessage mime, SmtpZugang zugang, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(mime);

        var pfad = ordner.NeueDatei(TestmodusOrdner.Versand, ".eml");
        await mime.WriteToAsync(pfad, cancellationToken);
        protokoll.Schreibe(TestmodusProtokoll.Versand, referenz: null, ordner.Relativ(pfad));
    }
}
