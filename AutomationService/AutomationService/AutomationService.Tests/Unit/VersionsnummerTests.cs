using AutomationService.Features.Aktualisierung.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Versionsvergleich des Dienstes (#196) — die Fälle des früheren
/// Frontend-Vergleichs, der mit der Update-Prüfung in den Dienst umgezogen ist.
/// </summary>
public sealed class VersionsnummerTests
{
    [Theory]
    [InlineData("1.10.0", "1.9.0", true)]
    [InlineData("2.0.0", "1.99.99", true)]
    [InlineData("1.2.4", "1.2.3", true)]
    [InlineData("1.2.3", "1.2.3", false)]
    [InlineData("1.2.2", "1.2.3", false)]
    [InlineData("v1.3.0", "1.2.0+abc1234", true)]
    [InlineData("v1.2.0", "1.2.0+abc1234", false)]
    [InlineData(" v1.3.0 ", "1.2.0", true)]
    public void Vergleicht_Zahl_fuer_Zahl(string kandidat, string bekannt, bool neuer)
    {
        Versionsnummer.IstNeuer(kandidat, bekannt).Should().Be(neuer);
    }

    [Theory]
    [InlineData("1.3")]
    [InlineData("1.3.0.1")]
    [InlineData("1.3.x")]
    [InlineData("v1.3.0-beta")]
    [InlineData("-1.3.0")]
    [InlineData("1.-3.0")]
    [InlineData("V1.3.0")]
    [InlineData("unbekannt")]
    [InlineData("")]
    [InlineData(null)]
    public void Unlesbares_ist_nie_ein_Update(string? unlesbar)
    {
        Versionsnummer.Lies(unlesbar).Should().BeNull();
        Versionsnummer.IstNeuer(unlesbar, "0.0.1").Should().BeFalse();
        Versionsnummer.IstNeuer("99.0.0", unlesbar).Should().BeFalse("ohne lesbare laufende Version gibt es keinen Vergleich");
    }

    [Fact]
    public void Schreibt_dreistellig_ohne_v_und_Commit()
    {
        Versionsnummer.Lies("v1.10.0+abc")!.ToString().Should().Be("1.10.0");
    }
}
