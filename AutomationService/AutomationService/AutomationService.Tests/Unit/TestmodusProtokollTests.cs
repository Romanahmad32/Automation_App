using AutomationService.Features.DevSimulation.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Das Protokoll und die Dateinamen des E2E-Testmodus (#168) — der Teil, gegen
/// den die Skripte und die E2E-Suite prüfen. Das Format selbst prüft
/// <see cref="TestmodusUmgebung.Zeilen"/> bei jedem Lesen mit.
/// </summary>
public sealed class TestmodusProtokollTests : IDisposable
{
    private readonly TestmodusUmgebung _umgebung = new();

    public void Dispose() => _umgebung.Dispose();

    /// <summary>
    /// Versand, Entwurf und Druck können gleichzeitig schreiben. Ohne Sperre
    /// verschränkten sich zwei Anhänge zu einer Zeile, die kein Parser liest —
    /// und die Suite meldete einen Fehler, wo keiner war.
    /// </summary>
    [Fact]
    public async Task Fuenfzig_parallele_Schreiber_ergeben_fuenfzig_lesbare_Zeilen()
    {
        var schreiber = Enumerable.Range(1, 50).Select(nummer => Task.Run(() =>
            _umgebung.Protokoll.Schreibe(
                TestmodusProtokoll.Druck,
                referenz: null,
                $"Druck/{nummer:D2}_Vollmacht Bußgeldsachen.docx")));

        await Task.WhenAll(schreiber);

        var zeilen = _umgebung.Zeilen();
        zeilen.Should().HaveCount(50);
        zeilen.Select(zeile => zeile.Datei).Should().OnlyHaveUniqueItems();
        zeilen.Should().OnlyContain(zeile => zeile.Aktion == "druck" && zeile.Referenz == null);
    }

    [Fact]
    public void Eine_Zeile_traegt_genau_die_vier_Felder_mit_null_wo_nichts_ist()
    {
        _umgebung.Protokoll.Schreibe(TestmodusProtokoll.GesendetAblage, referenz: null, datei: null);

        var roh = File.ReadAllText(_umgebung.Protokoll.Pfad);
        roh.Should().Contain("\"referenz\":null").And.Contain("\"datei\":null",
            "fehlende Angaben stehen als null da, nicht als fehlendes Feld");
        _umgebung.Zeilen().Should().ContainSingle().Which.Aktion.Should().Be("gesendet-ablage");
    }

    [Fact]
    public void Umlaute_und_Versatz_stehen_lesbar_im_Protokoll()
    {
        _umgebung.Protokoll.Schreibe(TestmodusProtokoll.Druck, referenz: null, "Druck/x_Vollmacht Bußgeldsachen.docx");

        var roh = File.ReadAllText(_umgebung.Protokoll.Pfad);
        roh.Should().Contain("Bußgeldsachen").And.NotContain("\\u", "ein Skript sucht im Klartext");
    }

    [Fact]
    public void Gleiche_Zeit_ergibt_fortlaufend_nummerierte_Namen()
    {
        using var umgebung = new TestmodusUmgebung(new FesteUhr(new DateTimeOffset(2026, 10, 12, 14, 3, 5, 123, TimeSpan.Zero)));

        var namen = Enumerable.Range(1, 3)
            .Select(_ => Path.GetFileName(umgebung.Ordner.NeueDatei(TestmodusOrdner.Versand, ".eml")))
            .ToList();

        namen.Should().Equal("20261012-140305-123.eml", "20261012-140305-123-2.eml", "20261012-140305-123-3.eml");
    }

    [Fact]
    public void Der_Druckname_traegt_den_Originalnamen()
    {
        using var umgebung = new TestmodusUmgebung(new FesteUhr(new DateTimeOffset(2026, 10, 12, 14, 3, 5, 123, TimeSpan.Zero)));

        var pfad = umgebung.Ordner.NeueDatei(TestmodusOrdner.Druck, ".docx", "Vollmacht Strafsache");

        umgebung.Ordner.Relativ(pfad).Should().Be("Druck/20261012-140305-123_Vollmacht Strafsache.docx");
    }

    /// <summary>Eine Uhr, die steht — in UTC, damit der Name nicht an der Zeitzone des Rechners hängt.</summary>
    private sealed class FesteUhr(DateTimeOffset jetzt) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => jetzt.ToUniversalTime();

        public override TimeZoneInfo LocalTimeZone => TimeZoneInfo.Utc;
    }
}
