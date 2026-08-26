using AutomationService.Features.MailboxMonitor.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die verschlüsselte Ablage des Postfach-Passworts. Der Kern ist nicht
/// die Kryptografie selbst (die kommt von Windows), sondern das Verhalten am
/// Rand: Der geschützte Wert darf das Passwort nicht mehr erkennen lassen, und
/// ein unlesbarer Wert darf nicht werfen, sondern muss als "neu eingeben"
/// zurückkommen — sonst startet der Dienst mit einer beschädigten Datei nicht.
/// </summary>
public sealed class PasswortSchutzTests
{
    [Fact]
    public void GeschuetztesPasswortKommtUnveraendertZurueck()
    {
        const string klartext = "s3hr-geheim-üöä!";

        var geschuetzt = PasswortSchutz.Schuetze(klartext);

        geschuetzt.Should().NotBeNullOrEmpty();
        PasswortSchutz.Entschuetze(geschuetzt!).Should().Be(klartext);
    }

    [Fact]
    public void GeschuetzterWertEnthaeltDasPasswortNichtMehrImKlartext()
    {
        const string klartext = "Postfach-Passwort-2026";

        var geschuetzt = PasswortSchutz.Schuetze(klartext);

        geschuetzt.Should().NotContain(klartext);
    }

    [Fact]
    public void LeeresPasswortBleibtLeer()
    {
        PasswortSchutz.Schuetze(string.Empty).Should().BeEmpty();
        PasswortSchutz.Entschuetze(string.Empty).Should().BeEmpty();
    }

    [Theory]
    // Kein Base64.
    [InlineData("kein gültiger wert")]
    // Gültiges Base64, aber kein DPAPI-Block (z. B. von Hand verändert).
    [InlineData("AAAAAAAAAAAAAAAAAAAAAA==")]
    public void UnlesbarerWertLiefertNullStattEinerAusnahme(string abgelegt)
    {
        PasswortSchutz.Entschuetze(abgelegt).Should().BeNull();
    }
}
