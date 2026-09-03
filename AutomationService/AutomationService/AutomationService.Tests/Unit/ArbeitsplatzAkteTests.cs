using AutomationService.Features.Backup.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Akten im gemeinsamen Sicherungsordner (#39). Sie tragen die einzige
/// Auskunft, die der zweite Arbeitsplatz beim Öffnen hat — deshalb muss sowohl
/// stimmen, was gelesen wird, als auch was <em>nicht</em>: Der eigene Eintrag
/// darf nie als fremder Stand gelten, und ein unlesbarer Eintrag des anderen
/// Rechners darf den Start hier nicht aufhalten.
/// </summary>
public sealed class ArbeitsplatzAkteTests : IDisposable
{
    readonly string _ordner;

    public ArbeitsplatzAkteTests()
    {
        _ordner = Path.Combine(Path.GetTempPath(), "arbeitsplatz-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_ordner);
    }

    [Fact]
    public void Geschriebene_Akte_kommt_unveraendert_zurueck()
    {
        var eintrag = new ArbeitsplatzEintrag(
            ArbeitsplatzAkte.DieserRechner,
            new DateTime(2026, 8, 31, 17, 12, 4, DateTimeKind.Unspecified),
            new DateTime(2026, 8, 31, 17, 12, 6, DateTimeKind.Unspecified),
            "automation-BUERO-PC-20260831-171206.zip",
            "1.4.2");

        ArbeitsplatzAkte.Schreibe(_ordner, eintrag);

        ArbeitsplatzAkte.LiesEigene(_ordner).Should().Be(eintrag);
    }

    [Fact]
    public void Ohne_eigene_Akte_kommt_null_und_kein_Fehler()
    {
        ArbeitsplatzAkte.LiesEigene(_ordner).Should().BeNull();
        ArbeitsplatzAkte.LiesFremde(_ordner).Should().BeEmpty();
        ArbeitsplatzAkte.LiesFremde(Path.Combine(_ordner, "gibtsnicht")).Should().BeEmpty();
    }

    [Fact]
    public void Der_eigene_Eintrag_gilt_nie_als_fremder_Stand()
    {
        ArbeitsplatzAkte.Schreibe(_ordner, Eintrag(ArbeitsplatzAkte.DieserRechner, 17));
        ArbeitsplatzAkte.Schreibe(_ordner, Eintrag("LAPTOP", 18));

        ArbeitsplatzAkte.LiesFremde(_ordner)
            .Should().ContainSingle().Which.Rechnername.Should().Be("LAPTOP");
    }

    /// <summary>
    /// Ein halb übertragener Eintrag ist im synchronisierten Ordner der
    /// Normalfall, nicht der Sonderfall. Er darf die Akte daneben nicht
    /// mitnehmen.
    /// </summary>
    [Fact]
    public void Unlesbare_Akte_wird_uebersprungen_und_verdeckt_die_anderen_nicht()
    {
        File.WriteAllText(
            Path.Combine(_ordner, ArbeitsplatzAkte.DateinameFuer("KAPUTT")), "{ das ist kein");
        ArbeitsplatzAkte.Schreibe(_ordner, Eintrag("LAPTOP", 18));

        ArbeitsplatzAkte.LiesFremde(_ordner)
            .Should().ContainSingle().Which.Rechnername.Should().Be("LAPTOP");
    }

    /// <summary>
    /// Eine Konfliktkopie des Synchronisierungsdienstes trägt denselben
    /// Rechnernamen im Inhalt. Ohne Entdopplung stünde derselbe Arbeitsplatz
    /// zweimal da — und der ältere der beiden Stände könnte gewinnen.
    /// </summary>
    [Fact]
    public void Konfliktkopie_desselben_Rechners_zaehlt_nur_einmal_und_mit_dem_neueren_Stand()
    {
        ArbeitsplatzAkte.Schreibe(_ordner, Eintrag("LAPTOP", 18));
        File.Copy(
            Path.Combine(_ordner, ArbeitsplatzAkte.DateinameFuer("LAPTOP")),
            Path.Combine(_ordner, ArbeitsplatzAkte.DateinameFuer("LAPTOP-Konflikt")));
        // Der echte Eintrag zieht danach weiter; die Kopie bleibt auf 18 Uhr stehen.
        ArbeitsplatzAkte.Schreibe(_ordner, Eintrag("LAPTOP", 20));

        var fremde = ArbeitsplatzAkte.LiesFremde(_ordner);

        fremde.Should().ContainSingle();
        fremde[0].ZuletztGearbeitet.Hour.Should().Be(20);
    }

    [Fact]
    public void Ein_Rechnername_mit_Pfadtrenner_landet_nicht_ausserhalb_des_Ordners()
    {
        ArbeitsplatzAkte.DateinameFuer(@"BUERO\..\PC")
            .Should().NotContain("\\").And.NotContain("/");
    }

    static ArbeitsplatzEintrag Eintrag(string rechner, int stunde) => new(
        rechner,
        new DateTime(2026, 8, 31, stunde, 0, 0, DateTimeKind.Unspecified),
        new DateTime(2026, 8, 31, stunde, 0, 0, DateTimeKind.Unspecified),
        $"automation-{rechner}-20260831-{stunde:00}0000.zip",
        "1.4.2");

    public void Dispose()
    {
        try
        {
            Directory.Delete(_ordner, recursive: true);
        }
        catch (IOException)
        {
            // Aufraeumen ist best effort.
        }
    }
}
