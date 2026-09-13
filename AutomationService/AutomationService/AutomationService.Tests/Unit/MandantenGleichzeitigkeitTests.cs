using System.Data.Common;
using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Services;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Zwei Anfragen, die sich überschneiden — Ablage im Word-Reiter und Zuordnung
/// an der Karte, oder zwei Klicks kurz hintereinander (#132). Jede läuft wie im
/// Dienst mit eigenem Kontext und eigener Verbindung, gegen eine Datenbankdatei:
/// Eine gemeinsame In-Memory-Verbindung wie in den übrigen Tests reihte die
/// beiden von selbst hintereinander und bewiese nichts.
/// </summary>
public sealed class MandantenGleichzeitigkeitTests : IDisposable
{
    private const int Durchgaenge = 10;

    private readonly string _datei = Path.Combine(Path.GetTempPath(), $"mandanten-{Guid.NewGuid():N}.db");

    public MandantenGleichzeitigkeitTests()
    {
        using var db = Kontext();
        db.Database.EnsureCreated();
    }

    // Ohne Pooling, damit die Datei beim Aufräumen nicht mehr offen ist.
    private AutomationDbContext Kontext() => new(
        new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={_datei};Pooling=False")
            .AddInterceptors(new LangsameAbfragen())
            .Options);

    /// <summary>
    /// Hält nach jeder Abfrage kurz an. Ohne das ist das Fenster zwischen Prüfen
    /// und Schreiben so schmal, dass zwei ungeschützte Zuordnungen fast immer
    /// zufällig hintereinander laufen — der Test bliebe grün, auch wenn die
    /// Transaktion fehlt. So ist er es nur mit ihr.
    /// </summary>
    private sealed class LangsameAbfragen : DbCommandInterceptor
    {
        public override async ValueTask<DbDataReader> ReaderExecutedAsync(
            DbCommand command,
            CommandExecutedEventData eventData,
            DbDataReader result,
            CancellationToken cancellationToken = default)
        {
            await Task.Delay(20, cancellationToken);
            return result;
        }
    }

    private async Task<T> MitEigenemKontext<T>(Func<MandantenRepository, Task<T>> aufruf)
    {
        await using var db = Kontext();
        return await aufruf(new MandantenRepository(db, new OrdnerStatusRegister(db)));
    }

    private async Task Anlegen(int id, string nachname, params string[] ordner)
    {
        await using var db = Kontext();
        db.Mandanten.Add(new MandantEntity
        {
            Id = id,
            Nachname = nachname,
            AktenOrdnernamenJson = MandantListen.Schreib(ordner),
            KennzeichenJson = "[]",
        });
        await db.SaveChangesAsync();
    }

    private async Task<Dictionary<int, List<string>>> OrdnerJeMandant()
    {
        await using var db = Kontext();
        return await db.Mandanten.AsNoTracking()
            .ToDictionaryAsync(m => m.Id, m => MandantListen.Lies(m.AktenOrdnernamenJson));
    }

    [Fact]
    public async Task ZweiMandantenGreifenGleichzeitigNachDemselbenOrdner_NurEinerBekommtIhn()
    {
        await Anlegen(1, "Klein");
        await Anlegen(2, "Groß");

        for (var durchgang = 0; durchgang < Durchgaenge; durchgang++)
        {
            var ordner = $"Unfall {durchgang}";
            var ergebnisse = await Task.WhenAll(
                Task.Run(() => Versuche(1, ordner)),
                Task.Run(() => Versuche(2, ordner)));

            ergebnisse.Count(gelungen => gelungen).Should().Be(1, $"Durchgang {durchgang}");
        }

        var bestand = await OrdnerJeMandant();
        (bestand[1].Count + bestand[2].Count).Should().Be(Durchgaenge);
    }

    // Zwei Lösungen am selben Mandanten: Läse jede die Liste für sich und
    // schriebe sie ganz zurück, stünde der zuerst gelöste Ordner wieder da.
    [Fact]
    public async Task ZweiOrdnerWerdenGleichzeitigGeloest_BeideSindWeg()
    {
        for (var durchgang = 0; durchgang < Durchgaenge; durchgang++)
        {
            var id = durchgang + 1;
            await Anlegen(id, $"Klein {durchgang}", "A", "B", "C");

            await Task.WhenAll(
                Task.Run(() => MitEigenemKontext(r => r.OrdnerLoesenAsync(id, "A"))),
                Task.Run(() => MitEigenemKontext(r => r.OrdnerLoesenAsync(id, "B"))));
        }

        (await OrdnerJeMandant()).Values.Should().AllSatisfy(ordner => ordner.Should().Equal("C"));
    }

    private async Task<bool> Versuche(int mandantId, string ordner)
    {
        try
        {
            await MitEigenemKontext(r => r.OrdnerZuordnenAsync(mandantId, ordner, nurPruefen: false));
            return true;
        }
        catch (MandantOrdnerConflictException)
        {
            return false;
        }
    }

    public void Dispose()
    {
        foreach (var datei in new[] { _datei, _datei + "-journal", _datei + "-wal", _datei + "-shm" })
        {
            if (File.Exists(datei)) File.Delete(datei);
        }
    }
}
