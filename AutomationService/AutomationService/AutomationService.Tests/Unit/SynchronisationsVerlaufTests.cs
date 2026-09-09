using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

public class SynchronisationsVerlaufTests
{
    [Fact]
    public async Task Oeffnen_und_Schliessen_macht_unveraenderte_Daten_nicht_neuer()
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        var zuerst = await env.Automatik.SchreibeAsync();
        var revision = env.Sicherung.Verlauf.Lies()!.Eintrag.Revision;
        env.Automatik.MerkeArbeitsbeginn();
        var danach = await env.Automatik.SchreibeAsync();
        danach!.Gelungen.Should().BeTrue(danach.Meldung);
        danach.Datei.Should().Be(zuerst!.Datei);
        danach.Zeitpunkt.Should().Be(zuerst.Zeitpunkt);
        env.Sicherung.Verlauf.Lies()!.Eintrag.Revision.Should().Be(revision);
        Directory.GetFiles(env.Ablage, "*.zip").Should().HaveCount(1);
    }

    [Fact]
    public async Task Auch_eine_reine_Vorlagenaenderung_wird_bereitgestellt()
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        await env.Automatik.SchreibeAsync();
        var zuerst = env.Sicherung.Verlauf.Lies()!.Eintrag.Revision;
        await File.WriteAllTextAsync(Path.Combine(env.Vorlagen, "Brief.docx"), "neuer Inhalt");
        env.Uebergabe.Stand().LokaleAenderungen.Should().BeTrue();
        (await env.Automatik.SchreibeAsync())!.Gelungen.Should().BeTrue();
        env.Sicherung.Verlauf.Lies()!.Eintrag.Vorfahren.Should().Contain(zuerst!);
    }

    [Fact]
    public async Task Herkunft_schlaegt_eine_falsch_eingestellte_Uhr()
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        await env.Automatik.SchreibeAsync();
        var fremd = await env.FremderStand(stunden: -24);
        var stand = env.Uebergabe.Stand();
        stand.Angebot!.Revision.Should().Be(fremd.Revision);
        stand.Konflikt.Should().BeFalse();
        await env.Uebergabe.UebernehmenGeprueftAsync(stand.Pruefkennung, false);
        env.Uebergabe.Stand().Angebot.Should().BeNull();
        var nachUebernahme = await env.Automatik.SchreibeAsync();
        nachUebernahme!.Datei.Should().Be(fremd.Sicherung);
    }

    [Fact]
    public async Task Unterschiedliche_Zweige_brauchen_eine_eigene_Bestaetigung()
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        await env.Automatik.SchreibeAsync();
        await env.FremderStand(nachfolger: false);
        var stand = env.Uebergabe.Stand();
        stand.Konflikt.Should().BeTrue();
        var versuch = () => env.Uebergabe.UebernehmenGeprueftAsync(stand.Pruefkennung, false);
        await versuch.Should().ThrowAsync<InvalidBackupException>();
        await env.Uebergabe.UebernehmenGeprueftAsync(stand.Pruefkennung, true);
    }

    [Fact]
    public async Task Lokale_Aenderung_nach_der_Anzeige_macht_die_Bestaetigung_ungueltig()
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        await env.Automatik.SchreibeAsync();
        await env.FremderStand();
        var stand = env.Uebergabe.Stand();
        await env.Mandant("Neu");
        var versuch = () => env.Uebergabe.UebernehmenGeprueftAsync(stand.Pruefkennung, true);
        await versuch.Should().ThrowAsync<InvalidBackupException>();
    }

    [Fact]
    public async Task Spaeter_eingetroffenes_Archiv_wird_bei_naechster_Pruefung_angeboten()
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        await env.Automatik.SchreibeAsync();
        var fremd = await env.FremderStand();
        var pfad = Path.Combine(env.Ablage, fremd.Sicherung!);
        File.Move(pfad, pfad + ".download");
        env.Uebergabe.Stand().Zustand.Should().Be("warten");
        File.Move(pfad + ".download", pfad);
        env.Uebergabe.Stand().Zustand.Should().Be("angebot");
    }

    [Fact]
    public async Task Beschaedigter_Download_wird_vor_dem_Import_abgewiesen()
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        await env.Automatik.SchreibeAsync();
        var fremd = await env.FremderStand();
        var stand = env.Uebergabe.Stand();
        await using (var datei = File.OpenWrite(Path.Combine(env.Ablage, fremd.Sicherung!)))
            datei.WriteByte(0);
        var versuch = () => env.Uebergabe.UebernehmenGeprueftAsync(stand.Pruefkennung, false);
        await versuch.Should().ThrowAsync<InvalidBackupException>();
        env.Sicherung.Verlauf.Lies()!.Eintrag.Revision.Should().NotBe(fremd.Revision);
    }
}
