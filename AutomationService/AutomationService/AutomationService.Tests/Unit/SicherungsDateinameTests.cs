using AutomationService.Features.Backup.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Name eines Sicherungsarchivs — und was er über das Archiv aussagt (#112).
///
/// Der Zeitpunkt im Namen ist die Grundlage der Aufbewahrung: Was hier als
/// lesbar durchgeht, darf gelöscht werden. Der Parser muss deshalb streng sein,
/// und zwar an genau den Stellen, an denen im Ablageordner erfahrungsgemäß etwas
/// liegt, das nicht von hier stammt.
/// </summary>
public sealed class SicherungsDateinameTests
{
    const string Rechner = "BUERO-PC";

    [Fact]
    public void Der_gebaute_Name_wird_wieder_gelesen()
    {
        var zeitpunkt = new DateTime(2026, 3, 12, 14, 7, 5, DateTimeKind.Unspecified);

        var name = SicherungsDateiname.Baue(Rechner, zeitpunkt);

        name.Should().Be("automation-BUERO-PC-20260312-140705.zip");
        SicherungsDateiname.Zeitpunkt(name, Rechner).Should().Be(zeitpunkt);
    }

    /// <summary>
    /// Örtliche Zeit ohne Zeitzone: Geschrieben wird mit <c>DateTime.Now</c>, und
    /// die Staffel rechnet in Kalendertagen. Käme der Zeitpunkt als UTC zurück,
    /// verschöbe sich der Tageswechsel um zwei Stunden.
    /// </summary>
    [Fact]
    public void Der_gelesene_Zeitpunkt_traegt_keine_Zeitzone() =>
        SicherungsDateiname.Zeitpunkt("automation-BUERO-PC-20260312-140705.zip", Rechner)!
            .Value.Kind.Should().Be(DateTimeKind.Unspecified);

    [Theory]
    // Vom Anwalt oder vom Synchronisierer umbenannt.
    [InlineData("automation-BUERO-PC-20260312-140705 - Kopie.zip")]
    [InlineData("automation-BUERO-PC-20260312-140705.zip.bak")]
    // Der andere Arbeitsplatz.
    [InlineData("automation-LAPTOP-20260312-140705.zip")]
    // Ein Rechner, dessen Name mit dem eigenen beginnt: Das Suchmuster findet
    // ihn, gelöscht werden darf er trotzdem nicht.
    [InlineData("automation-BUERO-PC-2-20260312-140705.zip")]
    // Unmögliche Daten — Tag 00 und Monat 13.
    [InlineData("automation-BUERO-PC-20260300-140705.zip")]
    [InlineData("automation-BUERO-PC-20261312-140705.zip")]
    [InlineData("automation-BUERO-PC-.zip")]
    [InlineData("sicherung.zip")]
    public void Was_nicht_der_gebaute_Name_ist_wird_ignoriert(string dateiname) =>
        SicherungsDateiname.Zeitpunkt(dateiname, Rechner).Should().BeNull();

    [Fact]
    public void Das_Suchmuster_greift_nur_die_eigenen_Archive() =>
        SicherungsDateiname.Suchmuster(Rechner).Should().Be("automation-BUERO-PC-*.zip");

    /// <summary>
    /// Die alte Anlaufstelle bleibt bestehen und zeigt hierher — sonst suchten
    /// Aufräumen und Anzeige nach zwei verschiedenen Mustern.
    /// </summary>
    [Fact]
    public void Die_Weiterleitung_der_AutomatischenSicherung_liefert_dasselbe_Muster() =>
        AutomatischeSicherung.SuchmusterFuer(Rechner)
            .Should().Be(SicherungsDateiname.Suchmuster(Rechner));
}
