using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Merkdatei und der Start danach (#196): Der nächste Start meldet, ob die
/// Aktualisierung auf X geklappt hat — und zwar so lange, bis das Frontend es
/// quittiert. Ohne sie gäbe es nach einem gescheiterten Setup nur wieder
/// „Update verfügbar", und der Anwender liefe in eine Schleife.
/// </summary>
public sealed class AktualisierungsMerkdateiTests : IDisposable
{
    private readonly AktualisierungsUmgebung _umgebung = new();

    public void Dispose() => _umgebung.Dispose();

    private void LegeMerkdateiAn(string zielVersion) =>
        _umgebung.Merkdatei.Schreibe(new Merkzettel(zielVersion, DateTimeOffset.Now));

    [Theory]
    [InlineData("1.4.0+def5678", true)]
    [InlineData("1.5.0", true)]
    [InlineData("1.3.0+abc1234", false)]
    [InlineData("unbekannt", false)]
    public void Der_Start_meldet_ob_die_Aktualisierung_geklappt_hat(string laufendeVersion, bool erfolgreich)
    {
        LegeMerkdateiAn("1.4.0");
        using var dienst = _umgebung.Dienst(laufendeVersion);

        dienst.Initialisiere();

        dienst.Stand().LetzteAktualisierung.Should().Be(new LetzteAktualisierung("1.4.0", erfolgreich));
        File.Exists(_umgebung.Ordner.Merkdatei).Should().BeTrue("gelöscht wird erst nach dem Quittieren");
    }

    [Fact]
    public void Ohne_Merkdatei_gibt_es_nichts_zu_melden()
    {
        using var dienst = _umgebung.Dienst();

        dienst.Initialisiere();

        dienst.Stand().LetzteAktualisierung.Should().BeNull();
    }

    [Theory]
    [InlineData("kein JSON")]
    [InlineData("""{ "zielVersion": "irgendwann", "zeitpunkt": "2026-10-14T10:00:00+02:00" }""")]
    [InlineData("""{ "zeitpunkt": "2026-10-14T10:00:00+02:00" }""")]
    public void Eine_unlesbare_Merkdatei_wird_still_verworfen(string inhalt)
    {
        Directory.CreateDirectory(_umgebung.Ordner.Pfad);
        File.WriteAllText(_umgebung.Ordner.Merkdatei, inhalt);
        using var dienst = _umgebung.Dienst();

        dienst.Initialisiere();

        dienst.Stand().LetzteAktualisierung.Should().BeNull();
        File.Exists(_umgebung.Ordner.Merkdatei).Should().BeFalse();
    }

    [Fact]
    public void Quittieren_loescht_die_Merkdatei_und_das_Ergebnis()
    {
        LegeMerkdateiAn("1.4.0");
        using var dienst = _umgebung.Dienst("1.4.0");
        dienst.Initialisiere();

        dienst.QuittiereErgebnis();

        dienst.Stand().LetzteAktualisierung.Should().BeNull();
        File.Exists(_umgebung.Ordner.Merkdatei).Should().BeFalse();
        using var naechsterStart = _umgebung.Dienst("1.4.0");
        naechsterStart.Initialisiere();
        naechsterStart.Stand().LetzteAktualisierung.Should().BeNull("einmal gezeigt ist genug");
    }

    /// <summary>Der ganze Bogen: installieren, Dienst endet, die neue Version startet.</summary>
    [Fact]
    public async Task Nach_dem_Installieren_meldet_der_naechste_Start_das_Ergebnis()
    {
        using (var alt = _umgebung.Dienst())
        {
            await AktualisierungsUmgebung.LadeBisBereit(alt);
            alt.Installiere().Ablehnung.Should().BeNull();
        }

        using var neu = _umgebung.Dienst("1.4.0+def5678");
        neu.Initialisiere();

        neu.Stand().LetzteAktualisierung.Should().Be(new LetzteAktualisierung("1.4.0", Erfolgreich: true));
        neu.Stand().Zustand.Should().Be(AktualisierungsZustand.Unbekannt, "geprüft wird nach dem Start erst auf Anforderung");
    }

    [Fact]
    public void Der_Start_raeumt_alte_Setup_Dateien_weg_und_behaelt_Protokolle()
    {
        Directory.CreateDirectory(_umgebung.Ordner.Pfad);
        string[] weg = ["Automation_App_Setup_1.2.0.exe", "Automation_App_Setup_1.3.0.exe.part"];
        string[] bleibt = ["installer-1.3.0.log", "Automation_App_Setup_1.4.0.exe", AktualisierungsOrdner.Merkdateiname];
        foreach (var name in weg.Concat(bleibt.SkipLast(1)))
        {
            File.WriteAllText(Path.Combine(_umgebung.Ordner.Pfad, name), name);
        }

        LegeMerkdateiAn("1.4.0");
        using var dienst = _umgebung.Dienst("1.3.0");

        dienst.Initialisiere();

        Directory.EnumerateFiles(_umgebung.Ordner.Pfad).Select(Path.GetFileName)
            .Should().BeEquivalentTo(bleibt, "die Setup-Datei der Zielversion bleibt, bis das Ergebnis quittiert ist");
    }

    [Fact]
    public void Ohne_Ordner_startet_der_Dienst_trotzdem()
    {
        using var dienst = _umgebung.Dienst();

        var starten = dienst.Initialisiere;

        starten.Should().NotThrow();
        Directory.Exists(_umgebung.Ordner.Pfad).Should().BeFalse("der Ordner entsteht erst beim ersten Download");
    }
}
