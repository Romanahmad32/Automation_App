using System.IO.Compression;
using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.Backup.Presentation.HostedServices;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

public sealed class SicherungsZeitgeberStartTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Neustart_sichert_ausstehende_Aenderungen_ohne_neue_Eingabe(bool vorherGesichert)
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        if (vorherGesichert) (await env.Automatik.SchreibeAsync())!.Gelungen.Should().BeTrue();
        var basis = env.Sicherung.Verlauf.Lies();
        await env.Mandant("Vor dem Neustart gespeichert");
        // Der vorherige Lauf brach ab; die Datenbank enthält trotzdem die Eingabe.
        (await env.Automatik.SchreibeAsync(new CancellationToken(true)))!.Gelungen.Should().BeFalse();
        env.Sicherung.Verlauf.Lies().Should().BeEquivalentTo(basis);

        var ergebnis = await ErsterTaktNachStart(env);

        ergebnis!.Gelungen.Should().BeTrue(ergebnis.Meldung);
        env.Sicherung.Verlauf.HatAenderungen().Should().BeFalse();
        Directory.GetFiles(env.Ablage, "*.zip").Should().HaveCount(vorherGesichert ? 2 : 1);
        using var zip = ZipFile.OpenRead(Path.Combine(env.Ablage, ergebnis.Datei!));
        var datenbank = Path.Combine(env.Wurzel, "gesicherter-stand.db");
        zip.GetEntry(SicherungsArchiv.DatenbankEintrag)!.ExtractToFile(datenbank);
        await using var verbindung = new SqliteConnection($"Data Source={datenbank};Pooling=False");
        await verbindung.OpenAsync();
        using var abfrage = verbindung.CreateCommand();
        abfrage.CommandText = "SELECT Nachname FROM Mandanten";
        (await abfrage.ExecuteScalarAsync()).Should().Be("Vor dem Neustart gespeichert");
    }

    [Fact]
    public async Task Neustart_mit_gesichertem_Bestand_erzeugt_kein_neues_Archiv()
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        var vorher = await env.Automatik.SchreibeAsync();
        var basis = env.Sicherung.Verlauf.Lies();

        var danach = await ErsterTaktNachStart(env);

        danach!.Gelungen.Should().BeTrue(danach.Meldung);
        danach.Datei.Should().Be(vorher!.Datei);
        danach.Zeitpunkt.Should().Be(vorher.Zeitpunkt);
        env.Sicherung.Verlauf.Lies().Should().BeEquivalentTo(basis);
        Directory.GetFiles(env.Ablage, "*.zip").Should().ContainSingle();
    }

    static async Task<LetzteSicherung?> ErsterTaktNachStart(SynchronisationsUmgebung env)
    {
        var beobachtet = new BeobachteteSicherung(env.Automatik);
        using var zeitgeber = new SicherungsZeitgeber(beobachtet, () => env.Datenbank,
            NullLogger<SicherungsZeitgeber>.Instance, TimeSpan.FromMilliseconds(20),
            env.Sicherung.Verlauf.Fingerabdruck);
        await zeitgeber.StartAsync(CancellationToken.None);
        try
        {
            // Echter Hosted-Service-Start: TickAsync allein umginge die fehlerhafte Initialisierung.
            return await beobachtet.ErsterLauf.Task.WaitAsync(TimeSpan.FromSeconds(10));
        }
        finally { await zeitgeber.StopAsync(CancellationToken.None); }
    }

    sealed class BeobachteteSicherung(IAutomatischeSicherung sicherung) : IAutomatischeSicherung
    {
        public TaskCompletionSource<LetzteSicherung?> ErsterLauf { get; } =
            new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async Task<LetzteSicherung?> SchreibeAsync(CancellationToken cancellationToken = default)
        {
            var ergebnis = await sicherung.SchreibeAsync(cancellationToken);
            ErsterLauf.TrySetResult(ergebnis);
            return ergebnis;
        }

        public void MerkeArbeitsbeginn() => sicherung.MerkeArbeitsbeginn();
    }
}
